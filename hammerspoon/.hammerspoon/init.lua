hs.hotkey.bind({"alt"}, "w", function()
  hs.alert.show("Hello World!")
  hs.alert.show(hs.application.frontmostApplication())
  print('...')
  print(hs.application.frontmostApplication())
end)

-- Internal function used to get enabled input sources
local function isLayout(layoutName)
    local layouts = hs.keycodes.layouts()
    for key, value in pairs(layouts) do
        if (value == layoutName) then
            return true
        end
    end

    return false
end

local function isMethod(methodName)
    local methods = hs.keycodes.methods()
    for key, value in pairs(methods) do
        if (value == methodName) then
            return true
        end
    end

    return false
end

local function setAppInputSource(appName, sourceName, event)
    event = event or hs.window.filter.windowFocused

    hs.window.filter.new(appName):subscribe(event, function()
        local r = true
        print('changed')

        if (isLayout(sourceName)) then
            r = hs.keycodes.setLayout(sourceName)
        elseif isMethod(sourceName) then
            r = hs.keycodes.setMethod(sourceName)
        else
            hs.alert.show(string.format('sourceName: %s is not layout or method', sourceName))
        end

        if (not r) then
            hs.alert.show(string.format('set %s to %s failure', appName, sourceName))
        end
        end)
end

function start()
    applicationsMap = {
    ["kitty"] = "ABC"
  }
    for k,v in pairs(applicationsMap) do
        setAppInputSource(k, v)
    end
end


start()
