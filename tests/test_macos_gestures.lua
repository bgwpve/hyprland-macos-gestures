--[[
  Unit tests for macos_gestures.lua
--]]

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("Assertion failed: %s (expected %s, got %s)", tostring(msg), tostring(expected), tostring(actual)))
  end
end

local function assert_true(cond, msg)
  if not cond then
    error(string.format("Assertion failed: %s", tostring(msg)))
  end
end

-- Setup Mock _G.hl environment
_G.hl = {
  registered = {},
  configs = {},
  commands = {},
  gesture = function(desc)
    if desc.action == "unset" then
      for i, d in ipairs(_G.hl.registered) do
        if d.fingers == desc.fingers and d.direction == desc.direction then
          table.remove(_G.hl.registered, i)
          return
        end
      end
      return
    end
    table.insert(_G.hl.registered, desc)
  end,
  config = function(cfg)
    table.insert(_G.hl.configs, cfg)
  end,
  exec_cmd = function(cmd)
    table.insert(_G.hl.commands, cmd)
  end,
}

local gestures = require("macos_gestures")

-- Test 1: Setup with defaults
gestures.setup()

assert_true(#gestures._registered > 0, "Registered gestures count should be > 0")
print("✓ Default setup registered " .. #gestures._registered .. " gestures")

-- Test 2: Verify Touchpad Config was applied
assert_true(#_G.hl.configs > 0, "Touchpad config should have been applied")
local last_cfg = _G.hl.configs[#_G.hl.configs]
assert_eq(last_cfg.misc.middle_click_paste, false, "middle_click_paste should be false")
assert_eq(last_cfg.input.touchpad.natural_scroll, true, "natural_scroll should be true")
assert_eq(last_cfg.input.touchpad.clickfinger_behavior, true, "clickfinger_behavior should be true")
print("✓ Touchpad safety settings verified (middle_click_paste = false, natural_scroll = true)")

-- Test 3: Teardown
gestures.teardown()
assert_eq(#gestures._registered, 0, "Registered list should be empty after teardown")
print("✓ Teardown cleaned up all registered gestures")

-- Test 4: Custom configuration (4-finger only)
gestures.setup({
  fingers = 4,
  touchpad = {
    drag_3fg = 1,
    scroll_factor = 0.5,
  },
  swipe_up = {
    action = "launcher",
  },
})

assert_true(#gestures._registered > 0, "Custom 4-finger setup registered gestures")
local custom_cfg = _G.hl.configs[#_G.hl.configs]
assert_eq(custom_cfg.input.touchpad.drag_3fg, 1, "drag_3fg should be 1")
assert_eq(custom_cfg.input.touchpad.scroll_factor, 0.5, "scroll_factor should be 0.5")
print("✓ Custom 4-finger and 3-finger drag config verified")

-- Test 5: Callable module
gestures.teardown()
gestures({
  verbose = true,
})
assert_true(#gestures._registered > 0, "Calling module directly should setup gestures")
print("✓ Callable module metatable verified")

print("\nAll unit tests passed successfully!")
