# hyprland-macos-gestures 🍏✨

> Lightweight, drop-in macOS trackpad gestures suite for **Hyprland (v0.55+ / v0.56+)** written in native Lua (`hl.gesture`).

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hyprland 0.55+](https://img.shields.io/badge/Hyprland-0.55%2B%20%7C%200.56%2B-blueviolet.svg)](https://hyprland.org)
[![Lua 5.1+](https://img.shields.io/badge/Lua-5.1%2B%20%2F%20LuaJIT-000080.svg)](https://www.lua.org)

Thousands of developers transitioning from macOS to Linux and Hyprland miss Apple's butter-smooth trackpad gestures. Historically, Linux users had to rely on external user-space daemons like `fusuma` or `touchegg`, which operated on coarse thresholds and lacked interactive, **1:1 fluid finger tracking**.

Starting in version 0.55, **Hyprland introduced a native 1:1 Lua gesture engine**. `hyprland-macos-gestures` brings the complete, iconic macOS trackpad gesture experience to Hyprland with zero external dependencies, zero bloat, and full customization.

---

## 🎯 Gesture Mapping

| macOS Gesture | Physical Action | Hyprland Action | Default Suite Behavior |
| :--- | :--- | :--- | :--- |
| **Swipe Between Spaces** | 3 or 4 fingers swipe **Left / Right** | `action = "workspace"` | **1:1 Fluid Workspace Switching** (continuous interactive sliding tracking your fingers) |
| **Mission Control** | 3 or 4 fingers swipe **Up** | Window Overview / Special | Toggles Overview / `special:scratchpad` (auto-detects `omarchy-menu`, `hyprexpo`, or scratchpad) |
| **App Exposé** | 3 or 4 fingers swipe **Down** | `action = "fullscreen"` | Toggles fullscreen/maximize on the active window |
| **Launchpad** | 4 fingers **Pinch In** | App Launcher | Launches application menu (auto-detects `omarchy-menu`, `rofi`, `wofi`, `walker`, `fuzzel`) |
| **Show Desktop** | 4 fingers **Pinch Out / Spread** | Show Desktop | Toggles clean `special:desktop` workspace |
| **Accidental Paste Guard** | Palm rest / 3-finger tap | `misc:middle_click_paste = false` | **Disables accidental primary paste** while keeping clickfinger right-click intact |

---

## ✨ Features

- **True 1:1 Continuous Tracking**: Workspaces slide interactively in real-time under your fingers using Hyprland's native compositor animation physics.
- **Both 3-Finger & 4-Finger Support**: Choose 3-finger swipes, 4-finger swipes, or enable **both simultaneously**.
- **Touchpad Safety Built-in**: Automatically prevents catastrophic accidental pastes from the middle-click / primary selection buffer (`misc:middle_click_paste = false`), while preserving two-finger right-click (`clickfinger_behavior = true`) and natural inverted scrolling (`natural_scroll = true`).
- **Auto-Detection**: Automatically detects your desktop environment (Omarchy or vanilla Hyprland) and launcher (`omarchy-menu`, `rofi`, `wofi`, `walker`, `fuzzel`).
- **Idempotent & Hot-Reload Safe**: Cleanly tracks registered gestures in memory so hot-reloading your Hyprland configuration (`hyprctl reload`) never triggers `Gesture will be overshadowed` errors.
- **Single File & Zero Dependencies**: Drop `macos_gestures.lua` into your config directory and you're done.

---

## 🚀 Installation & Drop-In Setup

### 1. Download `macos_gestures.lua`

Clone the repo or download the single file into your Hyprland config directory:

```bash
# Clone directly into your Hyprland configuration
mkdir -p ~/.config/hypr
curl -sSL https://raw.githubusercontent.com/bgwpve/hyprland-macos-gestures/main/macos_gestures.lua \
  -o ~/.config/hypr/macos_gestures.lua
```

---

### 2A. For Omarchy Users

Omarchy natively configures Hyprland using modular Lua files in `~/.config/hypr/`.

1. Open `~/.config/hypr/input.lua`:
   ```bash
   $EDITOR ~/.config/hypr/input.lua
   ```

2. Replace any existing `hl.gesture(...)` lines with:
   ```lua
   -- Load macOS trackpad gestures suite
   require("macos_gestures").setup()
   ```

3. Save and reload Hyprland (`hyprctl reload` or Super+Shift+R).

---

### 2B. For Vanilla Hyprland Users (v0.55+ / v0.56+)

1. In your `~/.config/hypr/hyprland.lua`:
   ```lua
   -- Add ~/.config/hypr to package.path if not already present
   package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path

   -- Enable macOS Trackpad Gestures
   require("macos_gestures").setup()
   ```

2. That's it! All gestures and touchpad safety settings are now active.

---

## 🛠️ Configuration & Customization

`hyprland-macos-gestures` works out of the box with zero configuration, but every aspect can be customized to match your exact workflow.

### Example: Custom Setup

```lua
local gestures = require("macos_gestures")

gestures.setup({
  -- Choose: 3, 4, or "both"
  -- "both" enables horizontal workspace switching for both 3-finger and 4-finger swipes
  fingers = "both",

  -- 1:1 Workspace swipe options
  workspace_swipe = {
    enabled = true,
    fingers = "both", -- 3, 4, or "both"
    scale = 1.0,      -- gesture distance multiplier
  },

  -- Mission Control (Swipe UP)
  swipe_up = {
    enabled = true,
    fingers = 3,       -- 3, 4, or "both"
    action = "overview", -- "overview", "special", "launcher", or custom function
    special_workspace = "scratchpad", -- used if action = "special"
    command = nil,     -- e.g. "rofi -show window" or "hyprctl dispatch hyprexpo:expo toggle"
  },

  -- App Exposé (Swipe DOWN)
  swipe_down = {
    enabled = true,
    fingers = 3,       -- 3, 4, or "both"
    action = "fullscreen", -- "fullscreen", "maximize", or custom function
    mode = nil,        -- nil (standard fullscreen) or "maximize"
  },

  -- Launchpad (4-Finger Pinch IN)
  pinch_in = {
    enabled = true,
    fingers = 4,
    action = "launcher", -- "launcher", custom function, or custom command
    command = nil,       -- e.g. "rofi -show drun"
  },

  -- Show Desktop (4-Finger Pinch OUT)
  pinch_out = {
    enabled = true,
    fingers = 4,
    action = "desktop",  -- toggles special workspace "desktop"
    special_workspace = "desktop",
  },

  -- Touchpad Safety & Preferences
  touchpad = {
    enabled = true,
    disable_middle_click_paste = true, -- PREVENTS ACCIDENTAL PASTES!
    natural_scroll = true,             -- Inverted macOS-style scroll
    clickfinger_behavior = true,       -- 1fg=left click, 2fg=right click, 3fg=middle click
    tap_to_click = false,              -- Press to click; a tap never clicks
    scroll_factor = 0.4,
    disable_while_typing = false,
    drag_3fg = 0,                      -- Set to 1 if you want 3-finger drag (see note below)
  },

  verbose = false, -- Set to true for notification popups on load
})
```

---

### Using 3-Finger Drag (macOS Accessibility Style)

If you love macOS **3-Finger Drag** (moving windows with 3 fingers without clicking):
1. In `macos_gestures.lua` config, set `touchpad.drag_3fg = 1`.
2. Set your swipe gestures to **4 fingers** (`fingers = 4`).

```lua
require("macos_gestures").setup({
  fingers = 4,
  touchpad = {
    drag_3fg = 1,
  },
})
```

This prevents 3-finger drag from competing with 3-finger workspace switching!

---

### Custom Lua Callbacks

You can assign any Lua function to `action` for any gesture:

```lua
require("macos_gestures").setup({
  swipe_up = {
    action = function()
      -- Run any custom logic or notifications
      hl.notification.create({ text = "Mission Control triggered!", timeout = 2000 })
      hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
    end,
  },
})
```

---

## 🛡️ Why Disabling Middle-Click Paste Matters

On Linux (both X11 and Wayland), clicking or tapping with three fingers pastes text from the **Primary Selection buffer** into the focused window. 

For users coming from macOS, this causes constant frustration:
- Resting fingers on the trackpad or tapping triggers unintended pastes into terminals, code editors, or chat windows.
- Often, sensitive tokens, code snippets, or clipboard history get accidentally inserted into terminals and run as commands.

`hyprland-macos-gestures` sets `misc:middle_click_paste = false` by default, protecting you from accidental pastes while fully preserving:
- Two-finger click for right-click (`clickfinger_behavior = true`).
- Standard clipboard paste (Ctrl+V / Cmd+V / Super+V).

---

## ❓ FAQ & Troubleshooting

### Q: Why do I get "Gesture will be overshadowed by a previous gesture"?
If you previously registered a gesture in your `~/.config/hypr/input.lua` or `hyprland.lua` (such as `hl.gesture({ fingers = 3, direction = "horizontal", ... })`), Hyprland forbids adding a duplicate gesture. 

**Fix**: Remove or comment out any manual `hl.gesture` calls from your existing config files before calling `require("macos_gestures").setup()`. `hyprland-macos-gestures` manages the entire gesture lifecycle cleanly for you.

### Q: Which Hyprland versions are supported?
Hyprland **v0.55.0 and above** (including v0.56+), which feature the native Lua configuration and gesture system.

---

## 🧪 Testing

A standalone test suite is included in `tests/test_macos_gestures.lua`. You can execute it directly with Lua:

```bash
LUA_PATH="./?.lua;;" lua tests/test_macos_gestures.lua
```

---

## 📄 License

MIT License © 2026 [Brent Wassell](https://github.com/bgwpve). See [LICENSE](LICENSE) for details.
