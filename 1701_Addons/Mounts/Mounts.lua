--[[
    Mounts - Random Mount Selector for Turtle WoW

    Usage: /mount [filter]

    Examples:
        /mount          - Random mount from all available
        /mount turtle   - Random turtle mount
        /mount tiger    - Random tiger mount
        /mount swift    - Random swift/epic mount
]]

Mounts1701 = {}

-- Check if spell name matches the filter
local function MatchesFilter(spellName, filter)
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(spellName), string.lower(filter))
end

-- Find the Mounts spellbook tab and return its info
local function GetMountsTabInfo()
    local numTabs = GetNumSpellTabs()
    for tab = 1, numTabs do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        if name and string.lower(name) == "mounts" then
            return offset, numSpells
        end
    end
    return nil, nil
end

-- Scan the Mounts spellbook tab for mounts
local function GetSpellbookMounts(filter)
    local mounts = {}
    local offset, numSpells = GetMountsTabInfo()

    if not offset or not numSpells then
        return mounts
    end

    -- Spellbook indices are 1-based, offset is 0-based
    -- Spells in this tab are at indices (offset + 1) to (offset + numSpells)
    for i = 1, numSpells do
        local spellIndex = offset + i
        local spellName = GetSpellName(spellIndex, BOOKTYPE_SPELL)

        if spellName and MatchesFilter(spellName, filter) then
            table.insert(mounts, {
                type = "spell",
                name = spellName,
                spellIndex = spellIndex
            })
        end
    end

    return mounts
end

-- Get all available mounts
local function GetAllMounts(filter)
    return GetSpellbookMounts(filter)
end

-- Use a mount
local function UseMount(mount)
    if mount.type == "spell" then
        CastSpell(mount.spellIndex, BOOKTYPE_SPELL)
    end
end

-- Main mount function
local function DoRandomMount(filter)
    -- Trim whitespace from filter
    if filter then
        filter = string.gsub(filter, "^%s*(.-)%s*$", "%1")
        if filter == "" then
            filter = nil
        end
    end

    local mounts = GetAllMounts(filter)

    if table.getn(mounts) == 0 then
        if filter then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFMounts:|r No mounts found matching '" .. filter .. "'")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFMounts:|r No mounts found. Make sure you have mounts in your Mounts spellbook tab.")
        end
        return
    end

    -- Pick a random mount
    local mount = mounts[math.random(1, table.getn(mounts))]
    UseMount(mount)
end

-- Slash command handler
local function SlashCmdHandler(msg)
    DoRandomMount(msg)
end

-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    SLASH_MOUNTS17011 = "/mount"
    SlashCmdList["MOUNTS1701"] = SlashCmdHandler
end)

-- Export for external use
Mounts1701.GetAllMounts = GetAllMounts
Mounts1701.DoRandomMount = DoRandomMount
Mounts1701.GetMountsTabInfo = GetMountsTabInfo
