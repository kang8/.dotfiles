--- chrome-sidebar-toggle.lua
---
--- One hotkey to collapse/expand Chrome's vertical tab strip (Settings →
--- Appearance → Tab strip position = Side). Chrome ships no shortcut for that
--- button, so this finds the AXButton via the macOS Accessibility API and
--- presses it.
---
--- Usage: `require("chrome-sidebar-toggle")` from init.lua. The hotkey binds
--- itself on load.
---
--- Knobs (reload the config after editing):
---
---   M.hotkey      -- {mods, key}, e.g. {{"cmd","alt"}, "t"}.
---   M.buttonNames -- Titles to match against. Case-insensitive substring
---                    match. Titles are localized when the UI language is not
---                    English: run
---                    `require("chrome-sidebar-toggle").dumpButtons()`
---                    and copy the real title out of the Console.
---   M.maxDepth    -- DFS depth cap. The button lives in the tab strip, which
---                    is shallow, so 12 is plenty. Bump to 20 if the search
---                    comes up empty (slower).
---
--- Debugging:
---   hs.console.clearConsole()
---   require("chrome-sidebar-toggle").dumpButtons()

local M = {}

-- ── Config ────────────────────────────────────────────────────────────────

M.hotkey = { { "cmd", "shift" }, "," }
M.buttonNames = { "Collapse tabs", "Expand tabs" }
M.maxDepth = 12

M.bundleID = "com.google.Chrome"

-- Alert when Chrome isn't running / isn't frontmost (false = return silently)
M.alertWhenInactive = false
-- Alert when the button can't be found (usually: vertical tabs aren't enabled)
M.alertWhenNotFound = true
-- Print per-search timing and visited-node count to the Console
M.debug = false

-- Roles to stop descending into. AXWebArea is page content: the button is
-- never in there, and touching it makes Chrome build that renderer's full
-- accessibility tree, which is measurably slow.
M.prunedRoles = { AXWebArea = true }

-- ── Internal state ────────────────────────────────────────────────────────

-- Button cache, keyed by window id, holding axuielement values
local cache = {}

-- ── Helpers ───────────────────────────────────────────────────────────────

--- Show an alert, closing the previous one so rapid presses don't stack them.
local function notify(message)
  hs.alert.closeAll()
  hs.alert.show(message)
end

--- Does the text hit one of M.buttonNames? Case-insensitive, substring match.
local function nameMatches(text)
  if type(text) ~= "string" or text == "" then return false end
  local lowered = text:lower()
  for _, candidate in ipairs(M.buttonNames) do
    -- 4th arg true = plain find, so `-` or `(` in a title isn't read as a
    -- Lua pattern
    if lowered:find(candidate:lower(), 1, true) then return true end
  end
  return false
end

--- Is this element the button we want? Also used to revalidate the cache.
local function isTargetButton(element)
  if type(element) ~= "userdata" then return false end
  if element:attributeValue("AXRole") ~= "AXButton" then return false end
  return nameMatches(element:attributeValue("AXTitle"))
      or nameMatches(element:attributeValue("AXDescription"))
end

--- Depth-first search that returns the first hit immediately. Much faster than
--- hs.axuielement:elementSearch(), which is async and walks the whole subtree.
local function findButton(element, depth, stats)
  if type(element) ~= "userdata" or depth > M.maxDepth then return nil end
  stats.visited = stats.visited + 1

  local role = element:attributeValue("AXRole")
  if role == "AXButton" then
    -- Buttons are leaves: match and return, otherwise don't descend
    if nameMatches(element:attributeValue("AXTitle"))
        or nameMatches(element:attributeValue("AXDescription")) then
      return element
    end
    return nil
  end
  if role and M.prunedRoles[role] then return nil end

  local children = element:attributeValue("AXChildren")
  if type(children) ~= "table" then return nil end
  for _, child in ipairs(children) do
    local found = findButton(child, depth + 1, stats)
    if found then return found end
  end
  return nil
end

--- Returns (axWindowElement, windowId) for Chrome's focused window.
--- requireFrontmost=true returns nil unless Chrome is frontmost; that's the
--- hotkey path. dumpButtons passes false, because it is invoked from the
--- Hammerspoon Console -- at that moment the Console is frontmost, not Chrome.
--- AXFocusedWindow is an app-level attribute, so it still resolves while the
--- app is inactive.
--- Returns nil if any step fails.
local function focusedChromeWindow(requireFrontmost)
  local app = hs.application.get(M.bundleID)
  if not app then
    if requireFrontmost and M.alertWhenInactive then notify("Chrome is not running") end
    return nil
  end

  if requireFrontmost then
    local front = hs.application.frontmostApplication()
    if not front or front:bundleID() ~= M.bundleID then
      if M.alertWhenInactive then notify("Chrome is not frontmost") end
      return nil
    end
  end

  local axApp = hs.axuielement.applicationElement(app)
  if not axApp then return nil end

  local axWindow = axApp:attributeValue("AXFocusedWindow")
  if not axWindow then return nil end

  -- The hs.window id is the cache key; without one we simply don't cache
  local window = app:focusedWindow()
  return axWindow, window and window:id() or nil
end

--- Drop cache entries that went stale (window closed).
local function pruneCache()
  for id, element in pairs(cache) do
    if not element:isValid() then cache[id] = nil end
  end
end

-- ── Public API ────────────────────────────────────────────────────────────

--- Collapse/expand the vertical tab strip. This is the hotkey callback.
function M.toggle()
  -- true = also raise the system permission panel when not yet granted
  if not hs.accessibilityState(true) then
    notify("Grant Hammerspoon Accessibility access, then retry")
    return
  end

  local axWindow, windowId = focusedChromeWindow(true)
  if not axWindow then return end

  -- 1) Try the cache: isValid + title still matches. The title flips between
  --    Collapse/Expand on every press, but both names are in M.buttonNames,
  --    so it keeps matching either way.
  local button = windowId and cache[windowId] or nil
  if button and not (button:isValid() and isTargetButton(button)) then
    cache[windowId] = nil
    button = nil
  end

  -- 2) Only search on a cache miss
  if not button then
    local stats = { visited = 0 }
    local startedAt = hs.timer.absoluteTime()
    button = findButton(axWindow, 0, stats)
    if M.debug then
      print(string.format(
        "[chrome-sidebar-toggle] search: %.1fms, %d nodes visited, %s",
        (hs.timer.absoluteTime() - startedAt) / 1e6, stats.visited,
        button and "found" or "NOT FOUND"))
    end

    if not button then
      if M.alertWhenNotFound then notify("Vertical tab strip not found") end
      return
    end
    if windowId then
      pruneCache()
      cache[windowId] = button
    end
  end

  -- performAction returns the element on success, false if rejected, nil on error
  if not button:performAction("AXPress") then
    if windowId then cache[windowId] = nil end
    if M.alertWhenNotFound then notify("Could not press the tab strip button") end
  end
end

--- Print every AXButton in the current Chrome window to the Hammerspoon
--- Console. Use it to find the real title when the UI isn't English and
--- M.buttonNames doesn't match.
function M.dumpButtons()
  if not hs.accessibilityState(true) then
    print("[chrome-sidebar-toggle] no Accessibility permission")
    return
  end

  local axWindow = focusedChromeWindow(false)
  if not axWindow then
    print("[chrome-sidebar-toggle] no focused Chrome window (is Chrome running?)")
    return
  end

  --- AXFrame is an {x,y,w,h} table; fall back to a placeholder if absent.
  local function fmtFrame(frame)
    if type(frame) ~= "table" then return "frame=?" end
    return string.format("frame={x=%.0f,y=%.0f,w=%.0f,h=%.0f}",
      frame.x or 0, frame.y or 0, frame.w or 0, frame.h or 0)
  end

  local found = 0
  local function walk(element, depth)
    if type(element) ~= "userdata" or depth > M.maxDepth then return end
    local role = element:attributeValue("AXRole")
    if role == "AXButton" then
      found = found + 1
      print(string.format(
        '  [%02d] depth=%d role=%s title=%q desc=%q id=%q %s',
        found, depth, tostring(role),
        tostring(element:attributeValue("AXTitle")),
        tostring(element:attributeValue("AXDescription")),
        tostring(element:attributeValue("AXIdentifier")),
        fmtFrame(element:attributeValue("AXFrame"))))
      return
    end
    if role and M.prunedRoles[role] then return end
    local children = element:attributeValue("AXChildren")
    if type(children) ~= "table" then return end
    for _, child in ipairs(children) do walk(child, depth + 1) end
  end

  print(string.format("[chrome-sidebar-toggle] AXButtons within depth %d:", M.maxDepth))
  walk(axWindow, 0)
  print(string.format(
    "[chrome-sidebar-toggle] %d button(s). Pick the one whose frame sits at the "
    .. "top of the sidebar (small x, small y) and copy its title or desc into "
    .. "M.buttonNames.", found))
end

--- Clear the cache (after changing config, or if the AX tree looks off).
function M.clearCache()
  cache = {}
end

--- Bind the hotkey. Re-binding unbinds the old one first, so you can tweak
--- M.hotkey in the Console and call this again.
function M.bind()
  if M._hotkey then M._hotkey:delete() end
  M._hotkey = hs.hotkey.bind(M.hotkey[1], M.hotkey[2], M.toggle)
  return M._hotkey
end

M.bind()

return M
