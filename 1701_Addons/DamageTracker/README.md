# DamageTracker

A combat statistics addon for WoW 1.12 that tracks all your damage output, hits, misses, and resists. Designed for comparing gear effectiveness.

## Installation

1. Copy the `DamageTracker` folder to your `Interface/AddOns` directory
2. Restart WoW or `/reload` if already in-game

## Commands

| Command | Description |
|---------|-------------|
| `/dmg` | Show overall session statistics |
| `/dmg reset` | Reset all statistics and start a new session |
| `/dmg spells` | Show per-spell breakdown |
| `/dmg melee` | Show detailed melee statistics |
| `/dmg session` | Show session timing information |
| `/dmg help` | Display available commands |

Aliases: `/damage`, `/dt`

## What Gets Tracked

### Melee
- **Hits & Crits** - Successful melee attacks with damage totals
- **Glancing Blows** - Reduced damage hits against higher level targets
- **Misses** - Attacks that missed entirely
- **Dodges** - Attacks dodged by the target
- **Parries** - Attacks parried by the target
- **Blocks** - Attacks blocked by the target

### Spells
- **Hits & Crits** - Successful spell casts with damage totals
- **Full Resists** - Spells completely resisted (0 damage)
- **Partial Resists** - Spells that dealt reduced damage
- **Resisted Damage** - Total damage lost to partial resists

### Session
- **Combat Time** - Actual time spent in combat
- **DPS** - Damage per second based on combat time
- **Session Duration** - Total time since addon load or last reset

## Example Output

```
1701_DamageTracker: === Session Statistics ===
1701_DamageTracker: Total Damage: 45,230
1701_DamageTracker: Combat Time: 3m 24.5s | DPS: 221.4
1701_DamageTracker: Melee: 12,450 dmg | 45 hits (12 crit) | Hit: 93.8% | Crit: 26.7%
1701_DamageTracker:   Avoided: 2 miss, 1 dodge, 0 parry, 0 block
1701_DamageTracker: Spells: 32,780 dmg | 28 hits (8 crit) | Hit: 96.6% | Crit: 28.6%
1701_DamageTracker:   Resists: 1 full, 3 partial (520 dmg lost)
```

## API

The addon exposes functions for external use:

```lua
-- Get the full stats table
local stats = DamageTracker1701.GetStats()

-- Reset all statistics
DamageTracker1701.Reset()

-- Display the overview
DamageTracker1701.ShowOverview()
```

### Stats Table Structure

```lua
stats = {
    sessionStart = <timestamp>,
    totalCombatTime = <seconds>,
    inCombat = <boolean>,

    melee = {
        hits, crits, misses, dodges, parries, blocks, glancing,
        damage, critDamage
    },

    spell = {
        hits, crits, resists, partialResists,
        damage, critDamage, resistedDamage
    },

    spells = {
        ["Spell Name"] = {
            hits, crits, resists, partialResists,
            damage, critDamage, resistedDamage
        },
        ...
    }
}
```

## Use Cases

- **Gear Comparison**: Reset stats, fight for a few minutes, note your DPS/hit rate. Swap gear, reset, repeat. Compare results.
- **Hit Cap Testing**: Check your miss rate against raid bosses to see if you need more +hit
- **Spell Resist Analysis**: Track which spells get resisted most to optimize spell penetration
- **Crit Rate Validation**: Verify your actual crit rate matches your character sheet
