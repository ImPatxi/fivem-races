# 🏁 patxi-carrera — FiveM Offroad Race System

A complete offroad race resource for **QBCore / QBox** FiveM servers. Features lobby system, GTA Online-style checkpoints, real-time leaderboard, and NUI interface.

![FiveM](https://img.shields.io/badge/FiveM-QBCore%20%2F%20QBox-orange)
![Lua](https://img.shields.io/badge/Lua-5.4-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Features

- **Lobby system** — Configurable wait time before race starts so all players can register
- **103 ordered checkpoints** — GTA Online-style cylinders with directional arrows
- **Driver-only validation** — Only the vehicle driver can trigger checkpoints; passengers don't count
- **Real-time leaderboard** — Shows all participants sorted by progress and finish time
- **Timer HUD** — Countdown with color states: normal → orange (< 5 min) → red pulsing (< 2 min)
- **Minimap integration** — Current checkpoint (yellow + GPS route) and next checkpoint (blue preview)
- **Cash reward** — Configurable payout on race completion
- **Auto-cleanup** — Race cancels on timeout, player death, or disconnect
- **NPC interactions** — Start NPC to register, finish NPC to view standings (via `ox_target`)

## 📦 Dependencies

| Resource | Required |
|----------|----------|
| [qb-core](https://github.com/qbcore-framework/qb-core) | ✅ |
| [ox_lib](https://github.com/overextended/ox_lib) | ✅ |
| [ox_target](https://github.com/overextended/ox_target) | ✅ |

## 📥 Installation

1. Download or clone this repository into your `resources` folder:
   ```
   resources/[race]/patxi-carrera/
   ```

2. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure patxi-carrera
   ```

3. Restart your server.

## ⚙️ Configuration

All settings are in `config.lua`:

| Setting | Default | Description |
|---------|---------|-------------|
| `Config.RaceName` | `'Offroad 100%'` | Display name |
| `Config.MaxTime` | `30` | Max race duration in minutes |
| `Config.LobbyTime` | `1` | Lobby wait time in minutes |
| `Config.Reward` | `10000` | Cash reward on completion |
| `Config.CheckpointRadius` | `20.0` | Detection radius in meters |
| `Config.MinPlayers` | `1` | Minimum players to start |
| `Config.CheckpointSize` | `10.0` | Cylinder diameter |
| `Config.CheckpointHeight` | `6.0` | Cylinder height |

### NPC Positions

- **Start NPC**: Configurable in `Config.StartNPC.coords`
- **Finish NPC**: Configurable in `Config.FinishNPC.coords`

### Checkpoints

The route is defined as an ordered list of `vector3` coordinates in `Config.Checkpoints`. Edit or replace these to create your own route.

## 🎮 How It Works

```
1. Player approaches Start NPC → ox_target menu appears
2. Player registers → Lobby opens (countdown visible in NUI)
3. Lobby timer ends → Race starts for all registered players
4. Players drive through checkpoints in order (driver seat only)
5. Current + next checkpoint visible as cylinders + minimap blips
6. Timer counts down; < 5min = orange, < 2min = red pulse
7. Leaderboard updates in real-time for all racers
8. Complete all checkpoints → Cash reward + finish position
9. Time runs out → Race cancelled for that player
```

## 📁 File Structure

```
patxi-carrera/
├── fxmanifest.lua      # Resource manifest
├── config.lua          # All configurable settings
├── client.lua          # Client-side: NPCs, checkpoints, NUI bridge
├── server.lua          # Server-side: lobby, race state, rewards
├── html/
│   ├── index.html      # NUI markup
│   ├── style.css       # NUI styles
│   └── script.js       # NUI logic
└── README.md
```

## 🛠️ Customization

### Adding your own route

1. Use a coordinate tool in-game to collect checkpoint positions
2. Replace the `Config.Checkpoints` table in `config.lua` with your `vector3` list
3. Update `Config.StartNPC.coords` and `Config.FinishNPC.coords` accordingly

### Changing the reward type

In `server.lua`, find the `playerFinished` event and modify the `AddMoney` call:

```lua
-- Cash (default)
qbPlayer.Functions.AddMoney('cash', Config.Reward, 'offroad-race-reward')

-- Bank
qbPlayer.Functions.AddMoney('bank', Config.Reward, 'offroad-race-reward')
```

## 📄 License

MIT — Use it, modify it, share it.

## 👤 Author

**Patxi** — CTO & Software Architect
