--!strict
-- Watches frame rate. If the game runs below ~28 FPS for a sustained window while Low Graphics is
-- off, it switches Low Graphics on (fewer debris parts) and tells the player how to undo it.
-- Runs at most once per session so it never fights the player's choice.

local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.ClientState)

local PerformanceGuard = {}

local WINDOW = 20 -- seconds of sampling
local LOW_FPS = 28
local WARMUP = 15 -- ignore the first seconds after joining (loading hitches)

local acted = false
local lowGraphics = false

-- Pure decision helper (unit-tested): average FPS from frame count and elapsed time.
function PerformanceGuard.shouldReduce(frames: number, seconds: number, alreadyLow: boolean): boolean
	if alreadyLow or seconds <= 0 then
		return false
	end
	return frames / seconds < LOW_FPS
end

function PerformanceGuard:Init()
	ClientState.Changed:Connect(function(state)
		lowGraphics = state.settings and state.settings.lowGraphics == true
	end)
end

function PerformanceGuard:Start()
	task.spawn(function()
		task.wait(WARMUP)
		while not acted do
			local frames = 0
			local connection = RunService.RenderStepped:Connect(function()
				frames += 1
			end)
			local started = os.clock()
			task.wait(WINDOW)
			connection:Disconnect()
			local elapsed = os.clock() - started
			if PerformanceGuard.shouldReduce(frames, elapsed, lowGraphics) then
				acted = true
				ClientState.request("SaveSettings", { lowGraphics = true }, true)
				ClientState.Notify:Fire("info", "Switched to Low Graphics for smoother play (change it in ⚙️ Settings)")
			elseif lowGraphics then
				acted = true -- player already chose low graphics; nothing to do
			end
		end
	end)
end

return PerformanceGuard
