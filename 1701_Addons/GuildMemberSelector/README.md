# Guild Member Selector

A World of Warcraft 1.12 addon that randomly selects a guild member who has been online within the last 5 days.

## Installation

Copy the `GuildMemberSelector` folder to your `Interface/AddOns` directory.

## Usage

| Command | Description |
|---------|-------------|
| `/guildpick` | Pick a random eligible guild member |
| `/gpick` | Alias for /guildpick |
| `/guildpick list` | List all eligible members with their status |
| `/guildpick refresh` | Force refresh the guild roster |
| `/guildpick help` | Show usage information |

## Eligibility

A guild member is considered eligible if they:
- Are currently online, OR
- Have been offline for 5 days or less

## Example Output

```
1701_GuildMemberSelector: Selected: PlayerName
  PlayerName (L60 Warrior) - Online
```

```
1701_GuildMemberSelector: Selected: AnotherPlayer
  AnotherPlayer (L58 Mage) - Offline 2d
```
