# MiniSocialBro

A minimal social HUD for World of Warcraft: shows **Guild** and **Friends** counters under the minimap.  
Hover to open a compact, sortable table with name, zone, level and optional guild notes.  
Left-click a player to **whisper**, right-click to **invite**. Alt+Left on the bar to **move**.

> Author: **Obscured** · Interface: **110200+** (Retail) · Optional: **LibDataBroker-1.1**, **LibDBIcon-1.0**

<img src="media/msb_logo_preview_512.png" alt="MiniSocialBro logo" width="160"/>

---

## Features

- Two data fields under the minimap: **Guild** and **Friends**
- Sticky, topmost tooltip with zebra rows and compact mode
- Tabular layout: **Name | Zone | Lv | Note** (note column optional)
- Click actions per row:
  - **Left**: whisper player
  - **Right**: invite to party
- Alt+Left drag on the bar to reposition; position persists across sessions
- Minimap icon via **LibDBIcon** (falls back to a native minimap button if the library isn’t present)
- Officer/Public note column switch
- Full control via `/msb` slash commands

---

## Installation

1. Copy the folder `MiniSocialBro` into:
   - `World of Warcraft/_retail_/Interface/AddOns/`
2. Optional libraries (for LibDBIcon integration):
   - `LibStub`, `LibDataBroker-1.1`, `LibDBIcon-1.0`
3. Restart the game or run `/reload`.

**Icon:** place the provided TGA/PNG files in `MiniSocialBro/media/`.  
The addon references an icon via `Interface\AddOns\MiniSocialBro\media\msb_logo_64.tga` by default (adjust in code if needed).

---

## Usage

- Hover **Guild** or **Friends** to open the table.
- Move the bar: **Alt + Left-drag** on the bar.
- Row actions: **Left = whisper**, **Right = invite**.
- Tooltip direction and topmost behavior are configurable.

---

## Slash Commands

### Basics (size & look)
```txt
/msb width 300
/msb height 20
/msb scale 1.0
/msb font 12
/msb bg 0.8          # background alpha (0–1)
/msb accent on       # bottom accent line on/off
