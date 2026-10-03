--[[
  macos_gestures.lua
  Lightweight, drop-in macOS trackpad gestures suite for Hyprland (v0.55+ / v0.56+)

  Brings native 1:1 fluid trackpad gestures from macOS to Linux:
    - 1:1 fluid horizontal workspace switching (3-finger & 4-finger swipes)
    - Mission Control: 3/4-finger swipe UP (window overview / special workspace / launcher)
    - App Exposé: 3/4-finger swipe DOWN (fullscreen / maximize toggle)
    - Launchpad: 4-finger pinch IN (application launcher)
    - Show Desktop: 4-finger pinch OUT (clean desktop special workspace)
    - Touchpad safety settings: Disables accidental middle-click paste while keeping
      natural scroll and clickfinger behaviors intact.

  Author: Brent Wassell <bgwpve@gmail.com>
  License: MIT
--]]

local M = {}

M.version = "1.0.0"
_G.__macos_gestures_registered = _G.__macos_gestures_registered or {}
M._registered = _G.__macos_gestures_registered
M.detected_launcher = nil
M.detected_overview = nil

--- Default Configuration
M.defaults = {
  -- Primary finger mode: 3, 4, or "both"
  -- Setting this sets the default for swipe gestures.
  -- 3: Standard macOS trackpad behavior (swipe left/right/up/down with 3 fingers).
  -- 4: 4-finger swipes (ideal for users enabling 3-finger drag).
  -- "both": Enables 1:1 workspace switching for BOTH 3 and 4 fingers simultaneously.
  fingers = "both",

  -- 1:1 Fluid Workspace Switching (Horizontal Swipe)
  workspace_swipe = {
    enabled = true,
    fingers = "both", -- 3, 4, or "both" (inherits M.defaults.fingers if nil)
    scale = 1.0,      -- gesture animation multiplier
  },

  -- Mission Control (Swipe UP)
  -- Actions:
  --   "overview": Auto-detects omarchy-menu overview, hyprexpo, hyprswitch, or special workspace
  --   "special" : Native Hyprland special workspace (default name: "scratchpad")
  --   "launcher": Application launcher (auto-detected: omarchy-menu, rofi, wofi, etc.)
  --   function(): Custom Lua callback
  --   string    : Custom shell command (executed via hl.exec_cmd)
  swipe_up = {
    enabled = true,
    fingers = 3,       -- 3, 4, or "both"
    action = "overview",
    special_workspace = "scratchpad",
    command = nil,     -- Optional explicit shell command override
    scale = 1.0,
  },

  -- App Exposé / Fullscreen (Swipe DOWN)
  -- Actions:
  --   "fullscreen": Native Hyprland fullscreen toggle
  --   "maximize"  : Native Hyprland maximized toggle
  --   function()  : Custom Lua callback
  --   string      : Custom shell command
  swipe_down = {
    enabled = true,
    fingers = 3,       -- 3, 4, or "both"
    action = "fullscreen",
    mode = nil,        -- nil for standard fullscreen, or "maximize"
    scale = 1.0,
  },

  -- Launchpad (4-Finger Pinch IN)
  -- Actions:
  --   "launcher": Opens app launcher (auto-detected: omarchy-menu, rofi, wofi, fuzzel, etc.)
  --   function(): Custom Lua callback
  --   string    : Custom shell command
  pinch_in = {
    enabled = true,
    fingers = 4,
    action = "launcher",
    command = nil,     -- Optional explicit command, e.g. "rofi -show drun"
    scale = 1.0,
  },

  -- Show Desktop (4-Finger Pinch OUT / Spread)
  -- Actions:
  --   "desktop": Native Hyprland special workspace "desktop" (clean view of wallpaper/desktop)
  --   "special": Native Hyprland special workspace
  --   function(): Custom Lua callback
  --   string   : Custom shell command
  pinch_out = {
    enabled = true,
    fingers = 4,
    action = "desktop",
    special_workspace = "desktop",
    command = nil,
    scale = 1.0,
  },

  -- Touchpad Safety & macOS-like Ergonomics
  touchpad = {
    enabled = true,

    -- CRITICAL FOR macOS SWITCHERS: Disables accidental middle-click paste
    -- from primary selection buffer when tapping trackpad or resting fingers.
    disable_middle_click_paste = true,

    -- Natural (inverted) scrolling matching macOS
    natural_scroll = true,

    -- Clickfinger behavior: 1-finger click = left, 2-finger click = right, 3-finger click = middle
    clickfinger_behavior = true,

    -- Tap to click: off. A light tap or a resting palm should never click; press the
    -- pad to click, as on a Mac with "Tap to click" unchecked.
    tap_to_click = false,

    -- Scroll speed multiplier
    scroll_factor = 0.4,

    -- Disable touchpad while typing
    disable_while_typing = false,

    -- 3-finger drag (0 = disabled, 1 = enabled)
    -- Note: If you enable 3-finger drag, set swipe_fingers = 4 to avoid conflict!
    drag_3fg = 0,
  },

  -- Optional verbose notifications
  verbose = false,
}

--- Deep merge helper for configuration tables
local function tbl_deep_merge(orig, override)
  if type(override) ~= "table" then
    return override ~= nil and override or orig
  end
  local result = {}
  for k, v in pairs(orig or {}) do
    result[k] = v
  end
  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = tbl_deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

--- Resolve finger count parameter to a list of numbers
local function resolve_fingers(val, fallback)
  local target = val
  if target == nil then
    target = fallback
  end
  if target == "both" then
    return { 3, 4 }
  elseif type(target) == "number" then
    return { target }
  elseif type(target) == "table" then
    return target
  end
  return { 3 }
end

--- Check if an executable exists in PATH
local function command_exists(cmd)
  if not cmd or cmd == "" then
    return false
  end
  local bin = cmd:match("^%S+")
  if not bin then
    return false
  end
  local pipe = io.popen("command -v " .. bin .. " 2>/dev/null")
  if not pipe then
    return false
  end
  local res = pipe:read("*l")
  pipe:close()
  return res ~= nil and res ~= ""
end

--- Auto-detect installed app launcher for Launchpad gesture
function M.detect_launcher()
  if M.detected_launcher then
    return M.detected_launcher
  end

  local candidates = {
    "omarchy-menu toggle apps",
    "rofi -show drun",
    "wofi --show drun",
    "walker",
    "fuzzel",
    "tofi-drun",
  }

  for _, candidate in ipairs(candidates) do
    if command_exists(candidate) then
      M.detected_launcher = candidate
      return candidate
    end
  end

  M.detected_launcher = "omarchy-menu toggle"
  return M.detected_launcher
end

--- Auto-detect overview / Mission Control mechanism
function M.detect_overview()
  if M.detected_overview then
    return M.detected_overview
  end

  if command_exists("omarchy-menu") then
    M.detected_overview = { type = "cmd", target = "omarchy-menu toggle" }
    return M.detected_overview
  end

  -- Default native Hyprland special workspace
  M.detected_overview = { type = "special", workspace = "scratchpad" }
  return M.detected_overview
end

--- Internal helper to safely register a gesture and record it
local function safe_register_gesture(desc)
  if not _G.hl or type(_G.hl.gesture) ~= "function" then
    -- When running outside Hyprland (e.g. testing), record and return
    table.insert(M._registered, desc)
    return true
  end

  -- Record clean definition for teardown
  local unregister_def = {
    fingers = desc.fingers,
    direction = desc.direction,
    mods = desc.mods,
    scale = desc.scale,
    mode = desc.mode,
    workspace_name = desc.workspace_name,
  }

  local success, err = pcall(function()
    _G.hl.gesture(desc)
  end)

  if success then
    table.insert(M._registered, unregister_def)
    return true
  else
    if _G.hl.notification and type(_G.hl.notification.create) == "function" then
      pcall(function()
        _G.hl.notification.create({
          text = "[macos_gestures] Failed to bind " .. tostring(desc.direction) .. " (" .. tostring(desc.fingers) .. "fg): " .. tostring(err),
          timeout = 6000,
          icon = "warning",
        })
      end)
    end
    return false, err
  end
end

--- Unregister all gestures registered by this module
function M.teardown()
  if _G.hl and type(_G.hl.gesture) == "function" then
    for _, def in ipairs(M._registered) do
      local unset_cmd = {
        fingers = def.fingers,
        direction = def.direction,
        action = "unset",
        mods = def.mods,
        scale = def.scale,
        mode = def.mode,
        workspace_name = def.workspace_name,
      }
      pcall(function()
        _G.hl.gesture(unset_cmd)
      end)
    end
  end

  for i = #M._registered, 1, -1 do
    table.remove(M._registered, i)
  end
end

--- Apply touchpad ergonomics and safety configuration
local function apply_touchpad_config(opts)
  if not _G.hl or type(_G.hl.config) ~= "function" then
    return
  end

  local t = opts.touchpad
  if not t or not t.enabled then
    return
  end

  local cfg = {
    misc = {},
    input = {
      touchpad = {},
    },
  }

  if t.disable_middle_click_paste ~= nil then
    -- Disabling middle click paste prevents primary buffer text insertions on tap/rest
    cfg.misc.middle_click_paste = not t.disable_middle_click_paste
  end

  if t.natural_scroll ~= nil then
    cfg.input.touchpad.natural_scroll = t.natural_scroll
  end

  if t.clickfinger_behavior ~= nil then
    cfg.input.touchpad.clickfinger_behavior = t.clickfinger_behavior
  end

  if t.tap_to_click ~= nil then
    cfg.input.touchpad.tap_to_click = t.tap_to_click
  end

  if t.scroll_factor ~= nil then
    cfg.input.touchpad.scroll_factor = t.scroll_factor
  end

  if t.disable_while_typing ~= nil then
    cfg.input.touchpad.disable_while_typing = t.disable_while_typing
  end

  if t.drag_3fg ~= nil then
    cfg.input.touchpad.drag_3fg = t.drag_3fg
  end

  pcall(function()
    _G.hl.config(cfg)
  end)
end

--- Setup the macOS gestures suite
-- @param user_opts (optional table) User configuration overrides
function M.setup(user_opts)
  local opts = tbl_deep_merge(M.defaults, user_opts or {})

  -- Clean up any prior gestures registered by this module
  M.teardown()

  -- 1. Apply Touchpad Safety and macOS Ergonomics
  apply_touchpad_config(opts)

  -- 2. 1:1 Horizontal Workspace Switching (Fluid Swipe)
  if opts.workspace_swipe and opts.workspace_swipe.enabled then
    local ws_fingers = resolve_fingers(opts.workspace_swipe.fingers, opts.fingers)
    for _, f in ipairs(ws_fingers) do
      safe_register_gesture({
        fingers = f,
        direction = "horizontal",
        action = "workspace",
        scale = opts.workspace_swipe.scale,
      })
    end
  end

  -- 3. Mission Control (Swipe UP)
  if opts.swipe_up and opts.swipe_up.enabled then
    local up_fingers = resolve_fingers(opts.swipe_up.fingers, opts.fingers)
    local act = opts.swipe_up.action

    for _, f in ipairs(up_fingers) do
      if type(act) == "function" then
        safe_register_gesture({
          fingers = f,
          direction = "up",
          action = act,
          scale = opts.swipe_up.scale,
        })
      elseif type(opts.swipe_up.command) == "string" then
        safe_register_gesture({
          fingers = f,
          direction = "up",
          action = function()
            if _G.hl and _G.hl.exec_cmd then
              _G.hl.exec_cmd(opts.swipe_up.command)
            end
          end,
          scale = opts.swipe_up.scale,
        })
      elseif act == "special" then
        safe_register_gesture({
          fingers = f,
          direction = "up",
          action = "special",
          workspace_name = opts.swipe_up.special_workspace or "scratchpad",
          scale = opts.swipe_up.scale,
        })
      elseif act == "launcher" then
        local launcher_cmd = opts.swipe_up.command or M.detect_launcher()
        safe_register_gesture({
          fingers = f,
          direction = "up",
          action = function()
            if _G.hl and _G.hl.exec_cmd then
              _G.hl.exec_cmd(launcher_cmd)
            end
          end,
          scale = opts.swipe_up.scale,
        })
      else -- default "overview"
        local ov = M.detect_overview()
        if ov.type == "cmd" then
          safe_register_gesture({
            fingers = f,
            direction = "up",
            action = function()
              if _G.hl and _G.hl.exec_cmd then
                _G.hl.exec_cmd(ov.target)
              end
            end,
            scale = opts.swipe_up.scale,
          })
        else
          safe_register_gesture({
            fingers = f,
            direction = "up",
            action = "special",
            workspace_name = ov.workspace or opts.swipe_up.special_workspace or "scratchpad",
            scale = opts.swipe_up.scale,
          })
        end
      end
    end
  end

  -- 4. App Exposé / Fullscreen (Swipe DOWN)
  if opts.swipe_down and opts.swipe_down.enabled then
    local down_fingers = resolve_fingers(opts.swipe_down.fingers, opts.fingers)
    local act = opts.swipe_down.action

    for _, f in ipairs(down_fingers) do
      if type(act) == "function" then
        safe_register_gesture({
          fingers = f,
          direction = "down",
          action = act,
          scale = opts.swipe_down.scale,
        })
      elseif type(opts.swipe_down.command) == "string" then
        safe_register_gesture({
          fingers = f,
          direction = "down",
          action = function()
            if _G.hl and _G.hl.exec_cmd then
              _G.hl.exec_cmd(opts.swipe_down.command)
            end
          end,
          scale = opts.swipe_down.scale,
        })
      elseif act == "maximize" then
        safe_register_gesture({
          fingers = f,
          direction = "down",
          action = "fullscreen",
          mode = "maximize",
          scale = opts.swipe_down.scale,
        })
      else -- default "fullscreen"
        safe_register_gesture({
          fingers = f,
          direction = "down",
          action = "fullscreen",
          mode = opts.swipe_down.mode,
          scale = opts.swipe_down.scale,
        })
      end
    end
  end

  -- 5. Launchpad (4-Finger Pinch IN)
  if opts.pinch_in and opts.pinch_in.enabled then
    local pin_fingers = opts.pinch_in.fingers or 4
    local act = opts.pinch_in.action

    if type(act) == "function" then
      safe_register_gesture({
        fingers = pin_fingers,
        direction = "pinchin",
        action = act,
        scale = opts.pinch_in.scale,
      })
    elseif type(opts.pinch_in.command) == "string" then
      safe_register_gesture({
        fingers = pin_fingers,
        direction = "pinchin",
        action = function()
          if _G.hl and _G.hl.exec_cmd then
            _G.hl.exec_cmd(opts.pinch_in.command)
          end
        end,
        scale = opts.pinch_in.scale,
      })
    else -- default "launcher"
      local launcher_cmd = opts.pinch_in.command or M.detect_launcher()
      safe_register_gesture({
        fingers = pin_fingers,
        direction = "pinchin",
        action = function()
          if _G.hl and _G.hl.exec_cmd then
            _G.hl.exec_cmd(launcher_cmd)
          end
        end,
        scale = opts.pinch_in.scale,
      })
    end
  end

  -- 6. Show Desktop (4-Finger Pinch OUT / Spread)
  if opts.pinch_out and opts.pinch_out.enabled then
    local pout_fingers = opts.pinch_out.fingers or 4
    local act = opts.pinch_out.action

    if type(act) == "function" then
      safe_register_gesture({
        fingers = pout_fingers,
        direction = "pinchout",
        action = act,
        scale = opts.pinch_out.scale,
      })
    elseif type(opts.pinch_out.command) == "string" then
      safe_register_gesture({
        fingers = pout_fingers,
        direction = "pinchout",
        action = function()
          if _G.hl and _G.hl.exec_cmd then
            _G.hl.exec_cmd(opts.pinch_out.command)
          end
        end,
        scale = opts.pinch_out.scale,
      })
    else -- default "desktop"
      safe_register_gesture({
        fingers = pout_fingers,
        direction = "pinchout",
        action = "special",
        workspace_name = opts.pinch_out.special_workspace or "desktop",
        scale = opts.pinch_out.scale,
      })
    end
  end

  if opts.verbose and _G.hl and _G.hl.notification then
    pcall(function()
      _G.hl.notification.create({
        text = "macOS Trackpad Gestures loaded (" .. tostring(#M._registered) .. " gestures)",
        timeout = 3000,
        icon = "ok",
      })
    end)
  end

  return M
end

-- Allow calling module directly: require("macos_gestures")({ ... })
setmetatable(M, {
  __call = function(_, opts)
    return M.setup(opts)
  end,
})

return M
