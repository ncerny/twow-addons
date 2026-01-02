--[[
    DamageTracker - Combat Statistics Tracker for WoW 1.12

    Tracks all damage dealt, hits, misses, resists, and other combat stats.
    Designed for comparing gear effectiveness.

    Usage:
        /dmg          - Show current session statistics
        /dmg reset    - Reset all statistics
        /dmg spells   - Show per-spell breakdown
        /dmg melee    - Show melee statistics
        /dmg session  - Show session summary with timing
]]

DamageTracker1701 = {}

-- Session statistics
local stats = {
    -- Timing
    sessionStart = nil,
    combatStart = nil,
    totalCombatTime = 0,
    inCombat = false,

    -- Melee stats
    melee = {
        hits = 0,
        crits = 0,
        misses = 0,
        dodges = 0,
        parries = 0,
        blocks = 0,
        glancing = 0,
        damage = 0,
        critDamage = 0,
    },

    -- Spell stats (aggregate)
    spell = {
        hits = 0,
        crits = 0,
        resists = 0,        -- Full resists
        partialResists = 0, -- Partial resists
        damage = 0,
        critDamage = 0,
        resistedDamage = 0, -- Damage lost to partial resists
    },

    -- Per-spell breakdown
    spells = {},
}

-- Initialize per-spell stats
local function GetSpellStats(spellName)
    if not stats.spells[spellName] then
        stats.spells[spellName] = {
            hits = 0,
            crits = 0,
            resists = 0,
            partialResists = 0,
            damage = 0,
            critDamage = 0,
            resistedDamage = 0,
        }
    end
    return stats.spells[spellName]
end

-- Format a number with commas
local function FormatNumber(n)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Format time in minutes and seconds
local function FormatTime(seconds)
    if seconds < 60 then
        return string.format("%.1fs", seconds)
    else
        local mins = math.floor(seconds / 60)
        local secs = seconds - (mins * 60)
        return string.format("%dm %.1fs", mins, secs)
    end
end

-- Calculate hit rate percentage
local function CalcHitRate(hits, crits, misses)
    local total = hits + crits + misses
    if total == 0 then return 0 end
    return ((hits + crits) / total) * 100
end

-- Calculate crit rate percentage
local function CalcCritRate(hits, crits)
    local total = hits + crits
    if total == 0 then return 0 end
    return (crits / total) * 100
end

-- Combat log parsing patterns (vanilla WoW)
local function ParseMeleeHit(msg)
    -- "You hit <target> for <damage>."
    local _, _, target, damage = string.find(msg, "You hit (.+) for (%d+)%.")
    if target then
        return tonumber(damage), false
    end

    -- "You crit <target> for <damage>."
    _, _, target, damage = string.find(msg, "You crit (.+) for (%d+)%.")
    if target then
        return tonumber(damage), true
    end

    -- "You hit <target> for <damage>. (glancing)"
    _, _, target, damage = string.find(msg, "You hit (.+) for (%d+)%.%s*%(glancing%)")
    if target then
        return tonumber(damage), false, true -- glancing
    end

    return nil
end

local function ParseMeleeMiss(msg)
    -- "You miss <target>."
    if string.find(msg, "^You miss") then
        return "miss"
    end

    -- "Your attack was dodged by <target>." or "You attack. <target> dodges."
    if string.find(msg, "dodged") or string.find(msg, "dodges") then
        return "dodge"
    end

    -- "Your attack was parried by <target>." or "You attack. <target> parries."
    if string.find(msg, "parried") or string.find(msg, "parries") then
        return "parry"
    end

    -- "Your attack was blocked by <target>." or "You attack. <target> blocks."
    if string.find(msg, "blocked") or string.find(msg, "blocks") then
        return "block"
    end

    return nil
end

local function ParseSpellDamage(msg)
    -- "Your <spell> hits <target> for <damage>. (<resisted> resisted)"
    local _, _, spell, target, damage, resisted = string.find(msg, "Your (.+) hits (.+) for (%d+)%.%s*%((%d+) resisted%)")
    if spell then
        return spell, tonumber(damage), false, tonumber(resisted)
    end

    -- "Your <spell> crits <target> for <damage>. (<resisted> resisted)"
    _, _, spell, target, damage, resisted = string.find(msg, "Your (.+) crits (.+) for (%d+)%.%s*%((%d+) resisted%)")
    if spell then
        return spell, tonumber(damage), true, tonumber(resisted)
    end

    -- "Your <spell> hits <target> for <damage>."
    _, _, spell, target, damage = string.find(msg, "Your (.+) hits (.+) for (%d+)%.")
    if spell then
        return spell, tonumber(damage), false, 0
    end

    -- "Your <spell> crits <target> for <damage>."
    _, _, spell, target, damage = string.find(msg, "Your (.+) crits (.+) for (%d+)%.")
    if spell then
        return spell, tonumber(damage), true, 0
    end

    return nil
end

local function ParseSpellResist(msg)
    -- "Your <spell> was resisted by <target>."
    local _, _, spell, target = string.find(msg, "Your (.+) was resisted by (.+)%.")
    if spell then
        return spell
    end

    -- "Your <spell> failed. <target> is immune."
    _, _, spell = string.find(msg, "Your (.+) failed%.")
    if spell then
        return spell
    end

    return nil
end

-- Event handlers
local function OnMeleeHit(msg)
    local damage, isCrit, isGlancing = ParseMeleeHit(msg)
    if damage then
        stats.melee.damage = stats.melee.damage + damage
        if isCrit then
            stats.melee.crits = stats.melee.crits + 1
            stats.melee.critDamage = stats.melee.critDamage + damage
        elseif isGlancing then
            stats.melee.glancing = stats.melee.glancing + 1
            stats.melee.hits = stats.melee.hits + 1
        else
            stats.melee.hits = stats.melee.hits + 1
        end
    end
end

local function OnMeleeMiss(msg)
    local missType = ParseMeleeMiss(msg)
    if missType then
        if missType == "miss" then
            stats.melee.misses = stats.melee.misses + 1
        elseif missType == "dodge" then
            stats.melee.dodges = stats.melee.dodges + 1
        elseif missType == "parry" then
            stats.melee.parries = stats.melee.parries + 1
        elseif missType == "block" then
            stats.melee.blocks = stats.melee.blocks + 1
        end
    end
end

local function OnSpellDamage(msg)
    local spell, damage, isCrit, resisted = ParseSpellDamage(msg)
    if spell and damage then
        -- Aggregate stats
        stats.spell.damage = stats.spell.damage + damage
        if isCrit then
            stats.spell.crits = stats.spell.crits + 1
            stats.spell.critDamage = stats.spell.critDamage + damage
        else
            stats.spell.hits = stats.spell.hits + 1
        end

        if resisted and resisted > 0 then
            stats.spell.partialResists = stats.spell.partialResists + 1
            stats.spell.resistedDamage = stats.spell.resistedDamage + resisted
        end

        -- Per-spell stats
        local spellStats = GetSpellStats(spell)
        spellStats.damage = spellStats.damage + damage
        if isCrit then
            spellStats.crits = spellStats.crits + 1
            spellStats.critDamage = spellStats.critDamage + damage
        else
            spellStats.hits = spellStats.hits + 1
        end

        if resisted and resisted > 0 then
            spellStats.partialResists = spellStats.partialResists + 1
            spellStats.resistedDamage = spellStats.resistedDamage + resisted
        end
    end
end

local function OnSpellResist(msg)
    local spell = ParseSpellResist(msg)
    if spell then
        stats.spell.resists = stats.spell.resists + 1

        local spellStats = GetSpellStats(spell)
        spellStats.resists = spellStats.resists + 1
    end
end

local function OnCombatStart()
    if not stats.inCombat then
        stats.inCombat = true
        stats.combatStart = GetTime()
    end
end

local function OnCombatEnd()
    if stats.inCombat then
        stats.inCombat = false
        if stats.combatStart then
            stats.totalCombatTime = stats.totalCombatTime + (GetTime() - stats.combatStart)
        end
        stats.combatStart = nil
    end
end

-- Display functions
local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_DamageTracker:|r " .. text)
end

local function ShowOverview()
    local totalDamage = stats.melee.damage + stats.spell.damage
    local combatTime = stats.totalCombatTime
    if stats.inCombat and stats.combatStart then
        combatTime = combatTime + (GetTime() - stats.combatStart)
    end

    local dps = 0
    if combatTime > 0 then
        dps = totalDamage / combatTime
    end

    Msg("=== Session Statistics ===")
    Msg(string.format("Total Damage: |cFFFFFF00%s|r", FormatNumber(totalDamage)))
    Msg(string.format("Combat Time: |cFFFFFF00%s|r | DPS: |cFFFFFF00%.1f|r", FormatTime(combatTime), dps))

    -- Melee summary
    local meleeTotal = stats.melee.hits + stats.melee.crits
    local meleeMisses = stats.melee.misses + stats.melee.dodges + stats.melee.parries + stats.melee.blocks
    local meleeHitRate = CalcHitRate(stats.melee.hits, stats.melee.crits, meleeMisses)
    local meleeCritRate = CalcCritRate(stats.melee.hits, stats.melee.crits)

    if meleeTotal + meleeMisses > 0 then
        Msg(string.format("Melee: |cFFFFFF00%s|r dmg | %d hits (%d crit) | Hit: %.1f%% | Crit: %.1f%%",
            FormatNumber(stats.melee.damage), meleeTotal, stats.melee.crits, meleeHitRate, meleeCritRate))
        if meleeMisses > 0 then
            Msg(string.format("  Avoided: %d miss, %d dodge, %d parry, %d block",
                stats.melee.misses, stats.melee.dodges, stats.melee.parries, stats.melee.blocks))
        end
    end

    -- Spell summary
    local spellTotal = stats.spell.hits + stats.spell.crits
    local spellHitRate = CalcHitRate(stats.spell.hits, stats.spell.crits, stats.spell.resists)
    local spellCritRate = CalcCritRate(stats.spell.hits, stats.spell.crits)

    if spellTotal + stats.spell.resists > 0 then
        Msg(string.format("Spells: |cFFFFFF00%s|r dmg | %d hits (%d crit) | Hit: %.1f%% | Crit: %.1f%%",
            FormatNumber(stats.spell.damage), spellTotal, stats.spell.crits, spellHitRate, spellCritRate))
        if stats.spell.resists > 0 or stats.spell.partialResists > 0 then
            Msg(string.format("  Resists: %d full, %d partial (|cFFFF0000%s|r dmg lost)",
                stats.spell.resists, stats.spell.partialResists, FormatNumber(stats.spell.resistedDamage)))
        end
    end
end

local function ShowSpellBreakdown()
    Msg("=== Per-Spell Breakdown ===")

    local hasSpells = false
    for spellName, s in pairs(stats.spells) do
        hasSpells = true
        local total = s.hits + s.crits
        local hitRate = CalcHitRate(s.hits, s.crits, s.resists)
        local critRate = CalcCritRate(s.hits, s.crits)
        local avgDmg = 0
        if total > 0 then
            avgDmg = s.damage / total
        end

        Msg(string.format("|cFFFFFF00%s|r:", spellName))
        Msg(string.format("  Dmg: %s | Avg: %.0f | Hits: %d (%d crit)",
            FormatNumber(s.damage), avgDmg, total, s.crits))
        Msg(string.format("  Hit: %.1f%% | Crit: %.1f%% | Resists: %d full, %d partial",
            hitRate, critRate, s.resists, s.partialResists))
    end

    if not hasSpells then
        Msg("No spell data recorded yet.")
    end
end

local function ShowMeleeBreakdown()
    Msg("=== Melee Statistics ===")

    local total = stats.melee.hits + stats.melee.crits
    local misses = stats.melee.misses + stats.melee.dodges + stats.melee.parries + stats.melee.blocks

    if total + misses == 0 then
        Msg("No melee data recorded yet.")
        return
    end

    local avgDmg = 0
    local avgCritDmg = 0
    if total > 0 then
        avgDmg = stats.melee.damage / total
    end
    if stats.melee.crits > 0 then
        avgCritDmg = stats.melee.critDamage / stats.melee.crits
    end

    Msg(string.format("Total Damage: |cFFFFFF00%s|r", FormatNumber(stats.melee.damage)))
    Msg(string.format("Swings: %d total (%d hits, %d crits, %d glancing)", total + misses, stats.melee.hits, stats.melee.crits, stats.melee.glancing))
    Msg(string.format("Average Hit: %.0f | Average Crit: %.0f", avgDmg, avgCritDmg))
    Msg(string.format("Hit Rate: %.1f%% | Crit Rate: %.1f%%",
        CalcHitRate(stats.melee.hits, stats.melee.crits, misses),
        CalcCritRate(stats.melee.hits, stats.melee.crits)))
    Msg(string.format("Avoided: %d miss, %d dodge, %d parry, %d block",
        stats.melee.misses, stats.melee.dodges, stats.melee.parries, stats.melee.blocks))
end

local function ShowSessionInfo()
    local sessionTime = 0
    if stats.sessionStart then
        sessionTime = GetTime() - stats.sessionStart
    end

    local combatTime = stats.totalCombatTime
    if stats.inCombat and stats.combatStart then
        combatTime = combatTime + (GetTime() - stats.combatStart)
    end

    local combatPercent = 0
    if sessionTime > 0 then
        combatPercent = (combatTime / sessionTime) * 100
    end

    Msg("=== Session Info ===")
    Msg(string.format("Session Duration: |cFFFFFF00%s|r", FormatTime(sessionTime)))
    Msg(string.format("Time in Combat: |cFFFFFF00%s|r (%.1f%%)", FormatTime(combatTime), combatPercent))
    Msg(string.format("Currently: %s", stats.inCombat and "|cFFFF0000In Combat|r" or "|cFF00FF00Out of Combat|r"))
end

local function ResetStats()
    stats.sessionStart = GetTime()
    stats.combatStart = nil
    stats.totalCombatTime = 0
    stats.inCombat = false

    stats.melee = {
        hits = 0,
        crits = 0,
        misses = 0,
        dodges = 0,
        parries = 0,
        blocks = 0,
        glancing = 0,
        damage = 0,
        critDamage = 0,
    }

    stats.spell = {
        hits = 0,
        crits = 0,
        resists = 0,
        partialResists = 0,
        damage = 0,
        critDamage = 0,
        resistedDamage = 0,
    }

    stats.spells = {}

    Msg("Statistics reset. New session started.")
end

-- Slash command handler
local function SlashCmdHandler(msg)
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1") -- trim

    if msg == "reset" then
        ResetStats()
    elseif msg == "spells" or msg == "spell" then
        ShowSpellBreakdown()
    elseif msg == "melee" then
        ShowMeleeBreakdown()
    elseif msg == "session" then
        ShowSessionInfo()
    elseif msg == "help" then
        Msg("Commands:")
        Msg("  /dmg - Show overview statistics")
        Msg("  /dmg reset - Reset all statistics")
        Msg("  /dmg spells - Show per-spell breakdown")
        Msg("  /dmg melee - Show melee statistics")
        Msg("  /dmg session - Show session timing info")
    else
        ShowOverview()
    end
end

-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
frame:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Enter combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leave combat

frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        SLASH_DAMAGETRACKER17011 = "/dmg"
        SLASH_DAMAGETRACKER17012 = "/damage"
        SLASH_DAMAGETRACKER17013 = "/dt"
        SlashCmdList["DAMAGETRACKER1701"] = SlashCmdHandler
        stats.sessionStart = GetTime()
        Msg("Loaded. Type /dmg for stats, /dmg help for commands.")

    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" then
        OnMeleeHit(arg1)
        OnCombatStart()

    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
        OnMeleeMiss(arg1)
        OnCombatStart()

    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        OnSpellDamage(arg1)
        OnCombatStart()

    elseif event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" then
        OnSpellResist(arg1)
        OnCombatStart()

    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()

    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    end
end)

-- Export for external use
DamageTracker1701.GetStats = function() return stats end
DamageTracker1701.Reset = ResetStats
DamageTracker1701.ShowOverview = ShowOverview
