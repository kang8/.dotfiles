hs.loadSpoon("SpoonInstall")
Install=spoon.SpoonInstall

-- Auto reload config on change
-- https://www.hammerspoon.org/Spoons/SpoonInstall.html
Install:andUse("ReloadConfiguration")
spoon.ReloadConfiguration:start()
hs.alert.show("Config loaded")

-- https://www.hammerspoon.org/Spoons/InputSourceSwitch.html
Install:andUse("InputSourceSwitch")
spoon.InputSourceSwitch:setApplications({
    ["kitty"] = "ABC",
    ["PyCharm"] = "ABC",
    ["WebStorm"] = "ABC",
    ["Fork"] = "ABC",
    ["IntelliJ IDEA"] = "ABC",
    ["DataGrip"] = "ABC",
    ["kitty-quick-access"] = { source = "ABC", watcher = "application" },
})
spoon.InputSourceSwitch:start()

-- InputSourceSwitch uses hs.window.filter which can't capture kitty-quick-access focus events, use application.watcher instead
-- AppWatcher = hs.application.watcher.new(function(appName, eventType, appObj)
--   if eventType == hs.application.watcher.activated then
--     if appName == "kitty-quick-access" then
--       hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
--     end
--   end
-- end)
-- AppWatcher:start()

-- Other
hs.hotkey.bind({"alt"}, "w", function()
  hs.alert.show(hs.application.frontmostApplication())
  print(hs.application.frontmostApplication():name())
end)

-- https://github.com/dzirtusss/vifari
hs.loadSpoon("Vifari")
spoon.Vifari:start() -- this will add hooks. `:stop()` to remove hooks
