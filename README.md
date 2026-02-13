# DHUD Lite

Lightweight HUD addon for World of Warcraft 12.0 (Midnight).

Based on [DHUD](https://www.curseforge.com/wow/addons/dhud) — rebuilt from scratch with zero dependencies and full Secret Values compliance.

![Interface](https://img.shields.io/badge/Interface-120001-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- Curved health/power bars with 5-layer health overlays (shield, absorb, heal prediction, damage reduction)
- Class resources: Combo Points, Runes, Chi, Holy Power, Soul Shards, Arcane Charges, Essence
- Unit info with level, name, classification, and reaction coloring
- Alpha fade: Combat > Target > Resting > Idle priority
- Per-character profile system with spec-based auto-switching
- In-game options UI (`/dhudlite options`)

## Install

Copy `DHUDLITE/` to `World of Warcraft/_retail_/Interface/AddOns/DHUDLITE/`

## Commands

| Command | Description |
|---------|-------------|
| `/dhudlite options` | Open settings |
| `/dhudlite visible on\|off` | Show/hide HUD |
| `/dhudlite move on\|off` | Toggle move mode |
| `/dhudlite profile list\|use\|new\|copy\|delete\|reset` | Profile management |
| `/dhudlite reset` | Reset current profile |

## Credits

Based on [DHUD](https://www.curseforge.com/wow/addons/dhud) by MADCAT, Markus Inger, and Howie. [MIT License](DHUDLITE/LICENSE).
