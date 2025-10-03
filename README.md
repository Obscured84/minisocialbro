# MiniSocialBro

A minimal social HUD for World of Warcraft (Retail). Shows **Guild** and **Friends** counters under the minimap.  
Hover to open a compact, sticky table with **Name | Zone | Lv | Note**.  
Click a player: **Left = whisper**, **Right = invite**. **Alt+Left** on the bar to move and save position.

> **Author:** Obscured • **Game UI:** Retail 11.0.x / Interface 110200+ • **Optional:** LibDataBroker-1.1, LibDBIcon-1.0

GG & Thx to Bluki

---

## Features

- Two data fields under the minimap: **Guild** and **Friends**
- Sticky tooltip that stays while moving between header and rows
- Optional always-on-top (TOOLTIP strata)
- Tabular layout with zebra rows and compact mode
- Optional guild notes column (public or officer)
- Row actions:
  - **Left click:** whisper player
  - **Right click:** invite to party
- **Alt+Left** drag the bar to reposition; location is stored as absolute position to `UIParent`
- Minimap icon via **LibDBIcon** (fallback native minimap button if missing)
- Fully controllable via `/msb` slash commands

---

## Installation

1. Copy or clone this folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/MiniSocialBro
   ```
2. Ensure the folder contains:
   ```
   MiniSocialBro.toc
   MiniSocialBro.lua
   media/
     msb_logo_32.tga
     msb_logo_64.tga
     msb_logo_128.tga
     msb_logo_256.tga
     msb_logo_preview_512.png
   ```
3. Optional libraries for nicer minimap integration:
   - LibStub
   - LibDataBroker-1.1
   - LibDBIcon-1.0
4. Restart the game or run `/reload`.

> The addon references `media/msb_logo_64.tga` for the minimap icon and `media/msb_logo_256.tga` for the client addon icon. Adjust in `.toc` and `GetAddonIconTexture()` if needed.

---

## Usage

- Hover **Guild** or **Friends** to open the table.
- Move the bar with **Alt + Left-drag**. Position persists across sessions.
- Player row actions: **Left = whisper**, **Right = invite**.
- Tooltip can expand **down** or **up**, and can be forced **topmost**.

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
```

### Tooltip behavior
```txt
/msb tipdir down     # expand downward
/msb tipdir up       # expand upward
/msb tiptop on       # keep tooltip on top (TOOLTIP strata)
```

### Columns & rows
```txt
/msb cols 160 150 34 180   # Name, Zone, Level, Note widths (px)
/msb rows 18               # max visible rows
/msb zebra on              # striped rows on/off
/msb compact on            # tighter row height
```

### Notes
```txt
/msb note on               # show/hide note column
/msb notetype public       # public | officer
```

### Colors (RGB 0–1)
```txt
/msb color label 0.75 0.75 0.85   # label color (“Guild/Friends:”)
/msb color value 0.40 0.70 1.00   # value color (numbers)
```

### Minimap icon & lock
```txt
/msb icon show
/msb icon hide
/msb lock                   # lock the bar
/msb unlock                 # unlock (Alt+Left to move)
```

### Panic button
```txt
/msb reset                  # reset to defaults and reposition
```

---

## Presets

**1) Compact, clean, downward**
```txt
/msb compact on
/msb tipdir down
/msb rows 18
/msb cols 160 160 34 160
/msb zebra on
```

**2) 4K readable, upward, bigger text**
```txt
/msb scale 1.25
/msb font 14
/msb height 22
/msb tipdir up
/msb tiptop on
```

**3) Guild-focused with officer notes, subtle look**
```txt
/msb note on
/msb notetype officer
/msb zebra off
/msb bg 0.7
/msb color label 0.65 0.70 0.90
/msb color value 0.80 0.90 1.00
```

**4) Minimal info only**
```txt
/msb note off
/msb cols 180 180 34 1
/msb zebra on
/msb compact on
```

**5) Hide icon and freeze the bar**
```txt
/msb icon hide
/msb lock
```

---

## File Structure

```
MiniSocialBro/
├─ MiniSocialBro.toc
├─ MiniSocialBro.lua
└─ media/
   ├─ msb_logo_32.tga
   ├─ msb_logo_64.tga
   ├─ msb_logo_128.tga
   ├─ msb_logo_256.tga
   └─ msb_logo_preview_512.png
```

---

## Compatibility

- **Retail** (11.0.x, Interface 110200+).
- **Classic/SoD/HC:** not explicitly supported; may partially work, but Retail APIs are assumed.

---

## Known Issues

- Some UI skin addons may tweak scrollbar width. The addon reclamps internally on tooltip open; if it looks off, close and reopen the tooltip or `/reload`.
- If the bar is locked, Alt+Left-drag won’t move it. Use `/msb unlock` or drag via the fallback minimap icon while holding **Shift** (override lock).

---

## Troubleshooting

- **Bar didn’t keep its position:** move it with **Alt+Left-drag** on the bar itself. Position is saved as absolute to `UIParent` (`posAbs` in SavedVariables).
- **Scrollbar scrolling too far:** the addon clamps the range on every refresh; if you still see overscroll, a skin may override scrollbar internals. Try `/reload`.
- **Reset everything:** `/msb reset`.

---

## Contributing

PRs welcome. Keep changes small and focused. For features:
- Keep the bar lightweight and the UI minimal.
- Avoid heavy dependencies; LibDataBroker/LibDBIcon remain optional.

### Local development
- Place the folder under `_retail_/Interface/AddOns/`.
- Use `/reload` to test changes quickly.
- Capture errors via the default UI or tools like BugSack.

---

## Changelog
### 1.6.8
- Minor Fixes

### 1.6.8
- Modified Tooltip
- Fixed BNet Notes

### 1.6.6
- Added Class Colors
- Fixed Layout in Rows
- Fixed BNet Friends Whisper
### 1.6.5
- Scrollbar anchored inside the tooltip, synchronized with the scroll frame, overscroll clamped
- Sticky tooltip navigation across header/rows
- Player tooltip raised above grid (no overlap)
- Absolute position saving to `UIParent` (stable across sessions)
- Minor UI polish and safer defaults migration

### 1.6.4
- Position persistence reworked to absolute coordinates; legacy positions migrated

### 1.6.3
- Sticky tooltip and visible hint; row hover tooltips simplified

---


## Credits

- **Code & design:** Obscured  
- **Logo:** adapted for MiniSocialBro (see `media/`)
