-- Full-screen confetti burst, a Raycast-free replacement for
-- `open raycast://extensions/raycast/raycast/confetti`.
--
-- Trigger it from anywhere with:  hs -c "Confetti()"
-- (needs `require("hs.ipc")` in init.lua for the `hs` CLI to reach us)

local PIECES = 120
local DURATION = 2.2
local FPS = 60
local GRAVITY = 1100 -- points per second squared
local DRAG = 0.99

local COLORS = {
    { red = 0.96, green = 0.26, blue = 0.35 },
    { red = 0.99, green = 0.73, blue = 0.20 },
    { red = 0.35, green = 0.78, blue = 0.45 },
    { red = 0.25, green = 0.55, blue = 0.96 },
    { red = 0.68, green = 0.40, blue = 0.92 },
    { red = 0.20, green = 0.80, blue = 0.82 },
}

-- Keeps canvases and timers alive for the length of the animation; without a
-- strong reference Lua would collect them mid-flight and the burst would stall.
local running = {}

local function newPiece(frame)
    return {
        x = frame.w * (0.1 + math.random() * 0.8),
        y = frame.h * (0.45 + math.random() * 0.2),
        vx = (math.random() - 0.5) * 1400,
        vy = -(600 + math.random() * 900),
        w = 5 + math.random() * 7,
        h = 8 + math.random() * 8,
        angle = math.random() * 360,
        spin = (math.random() - 0.5) * 1440,
    }
end

function Confetti(screen)
    local frame = (screen or hs.screen.mainScreen()):fullFrame()
    local canvas = hs.canvas.new(frame)
    canvas:level(hs.canvas.windowLevels.screenSaver)
    canvas:behaviorAsLabels({ "canJoinAllSpaces", "stationary", "transient" })
    canvas:clickActivating(false)

    local pieces = {}
    for i = 1, PIECES do
        pieces[i] = newPiece(frame)
        canvas[i] = {
            type = "rectangle",
            action = "fill",
            fillColor = COLORS[math.random(#COLORS)],
            roundedRectRadii = { xRadius = 2, yRadius = 2 },
            frame = { x = pieces[i].x, y = pieces[i].y, w = pieces[i].w, h = pieces[i].h },
        }
    end
    canvas:show()

    local dt = 1 / FPS
    local elapsed = 0
    local timer
    timer = hs.timer.doEvery(dt, function()
        elapsed = elapsed + dt
        for i, p in ipairs(pieces) do
            p.vx = p.vx * DRAG
            p.vy = p.vy * DRAG + GRAVITY * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.angle = p.angle + p.spin * dt
            -- Squashing the width fakes a tumbling piece of paper without
            -- building a rotation matrix per element.
            canvas[i].frame = {
                x = p.x,
                y = p.y,
                w = math.max(1, p.w * math.abs(math.cos(math.rad(p.angle)))),
                h = p.h,
            }
        end
        if elapsed >= DURATION then
            timer:stop()
            canvas:delete(0.4)
            running[timer] = nil
        end
    end)
    running[timer] = canvas
end

return Confetti
