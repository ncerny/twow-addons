--[[
    GuildMemberSelector - Random Guild Member Picker for WoW 1.12

    Usage:
        /guildpick           - Pick a random guild member (online within 5 days)
        /guildpick list      - List all eligible members
        /guildpick refresh   - Force refresh the guild roster

    Notes:
        - Only selects members who have been online within the last 5 days
        - Members currently online are always eligible
        - Requires you to be in a guild
]]

GuildMemberSelector1701 = {}

-- Configuration
local MAX_OFFLINE_DAYS = 5
local MAX_OFFLINE_HOURS = MAX_OFFLINE_DAYS * 24

-- State
local pendingAction = nil
local lastRosterUpdate = 0

-- Calculate total hours offline from years, months, days, hours
local function CalculateOfflineHours(years, months, days, hours)
    years = years or 0
    months = months or 0
    days = days or 0
    hours = hours or 0

    -- Approximate: 365 days/year, 30 days/month
    local totalDays = (years * 365) + (months * 30) + days
    return (totalDays * 24) + hours
end

-- Check if a member is eligible (online or was online within MAX_OFFLINE_DAYS)
local function IsMemberEligible(index)
    local name, rank, rankIndex, level, class, zone, note, officerNote, online, status = GetGuildRosterInfo(index)

    if not name then
        return false, nil
    end

    -- Online members are always eligible
    if online then
        return true, {
            name = name,
            rank = rank,
            level = level,
            class = class,
            zone = zone,
            online = true,
            offlineHours = 0
        }
    end

    -- For offline members, check last online time
    -- In 1.12, we need to get the years, months, days, hours since last online
    local years, months, days, hours = GetGuildRosterLastOnline(index)

    -- If the function doesn't exist or returns nil, try alternate approach
    if years == nil then
        -- Some servers/versions may not have this function
        -- In that case, we'll include the member if they're in the roster
        -- (roster typically only shows recently active members by default)
        return true, {
            name = name,
            rank = rank,
            level = level,
            class = class,
            zone = zone,
            online = false,
            offlineHours = -1  -- Unknown
        }
    end

    local offlineHours = CalculateOfflineHours(years, months, days, hours)

    if offlineHours <= MAX_OFFLINE_HOURS then
        return true, {
            name = name,
            rank = rank,
            level = level,
            class = class,
            zone = zone,
            online = false,
            offlineHours = offlineHours
        }
    end

    return false, nil
end

-- Get all eligible guild members
local function GetEligibleMembers()
    local eligible = {}

    -- Make sure offline members are shown in the roster
    SetGuildRosterShowOffline(true)

    local numMembers = GetNumGuildMembers()

    for i = 1, numMembers do
        local isEligible, memberInfo = IsMemberEligible(i)
        if isEligible and memberInfo then
            table.insert(eligible, memberInfo)
        end
    end

    return eligible
end

-- Pick a random eligible member
local function PickRandomMember()
    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r You are not in a guild!")
        return nil
    end

    local eligible = GetEligibleMembers()

    if table.getn(eligible) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r No eligible guild members found (online within " .. MAX_OFFLINE_DAYS .. " days).")
        return nil
    end

    local member = eligible[math.random(1, table.getn(eligible))]
    return member
end

-- Format member info for display
local function FormatMemberInfo(member)
    local status
    if member.online then
        status = "|cFF00FF00Online|r"
    elseif member.offlineHours < 0 then
        status = "|cFFFFFF00Offline (unknown duration)|r"
    elseif member.offlineHours < 24 then
        status = "|cFFFFFF00Offline " .. member.offlineHours .. "h|r"
    else
        local days = math.floor(member.offlineHours / 24)
        status = "|cFFFFFF00Offline " .. days .. "d|r"
    end

    return string.format("%s (L%d %s) - %s", member.name, member.level, member.class, status)
end

-- Execute the random pick and announce
local function DoRandomPick()
    local member = PickRandomMember()

    if member then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r Selected: |cFFFFD700" .. member.name .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("  " .. FormatMemberInfo(member))
    end

    return member
end

-- List all eligible members
local function ListEligibleMembers()
    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r You are not in a guild!")
        return
    end

    local eligible = GetEligibleMembers()

    if table.getn(eligible) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r No eligible guild members found.")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r Eligible members (online within " .. MAX_OFFLINE_DAYS .. " days): " .. table.getn(eligible))

    -- Sort by online status, then by name
    table.sort(eligible, function(a, b)
        if a.online and not b.online then return true end
        if not a.online and b.online then return false end
        return a.name < b.name
    end)

    for _, member in ipairs(eligible) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. FormatMemberInfo(member))
    end
end

-- Request guild roster update and execute pending action
local function RefreshRoster(action)
    pendingAction = action
    GuildRoster()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r Refreshing guild roster...")
end

-- Slash command handler
local function SlashCmdHandler(msg)
    -- Trim and lowercase the message
    if msg then
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        msg = string.lower(msg)
    end

    if msg == "list" then
        -- Check if roster is fresh enough (within 60 seconds)
        if time() - lastRosterUpdate > 60 then
            RefreshRoster("list")
        else
            ListEligibleMembers()
        end
    elseif msg == "refresh" then
        RefreshRoster(nil)
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector Usage:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  /guildpick - Pick a random guild member")
        DEFAULT_CHAT_FRAME:AddMessage("  /guildpick list - List all eligible members")
        DEFAULT_CHAT_FRAME:AddMessage("  /guildpick refresh - Force refresh roster")
        DEFAULT_CHAT_FRAME:AddMessage("  Eligible: online within last " .. MAX_OFFLINE_DAYS .. " days")
    else
        -- Default action: pick random member
        if time() - lastRosterUpdate > 60 then
            RefreshRoster("pick")
        else
            DoRandomPick()
        end
    end
end

-- Event handler
local function OnEvent()
    if event == "VARIABLES_LOADED" then
        -- Register slash commands
        SLASH_GUILDMEMBERSELECTOR17011 = "/guildpick"
        SLASH_GUILDMEMBERSELECTOR17012 = "/gpick"
        SlashCmdList["GUILDMEMBERSELECTOR1701"] = SlashCmdHandler

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector|r loaded. Use /guildpick to select a random guild member.")

    elseif event == "GUILD_ROSTER_UPDATE" then
        lastRosterUpdate = time()

        -- Execute any pending action
        if pendingAction == "pick" then
            DoRandomPick()
        elseif pendingAction == "list" then
            ListEligibleMembers()
        elseif pendingAction == nil then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_GuildMemberSelector:|r Guild roster updated.")
        end
        pendingAction = nil
    end
end

-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", OnEvent)

-- Export for external use
GuildMemberSelector1701.PickRandomMember = PickRandomMember
GuildMemberSelector1701.GetEligibleMembers = GetEligibleMembers
GuildMemberSelector1701.ListEligibleMembers = ListEligibleMembers
GuildMemberSelector1701.DoRandomPick = DoRandomPick
