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
    ["Cursor"] = "ABC",
    ["Typing Mind"] = "Squirrel - Simplified",
})
spoon.InputSourceSwitch:start()

-- Other
hs.hotkey.bind({"alt"}, "w", function()
  hs.alert.show(hs.application.frontmostApplication())
  print(hs.application.frontmostApplication():name())
end)

-- https://github.com/dzirtusss/vifari
hs.loadSpoon("Vifari")
spoon.Vifari:start() -- this will add hooks. `:stop()` to remove hooks
