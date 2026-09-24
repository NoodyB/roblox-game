--!strict
-- Sound effects and music. Sounds are preloaded once and played with slight pitch variation.
-- Respects the player's settings; collect sounds are throttled so they never become noise.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Audio = {}

local sounds: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local sfxEnabled = true
local music: Sound? = nil
local random = Random.new()

local THROTTLE = { Collect = 0.07 }

function Audio:Init()
	local folder = Instance.new("Folder")
	folder.Name = "SweepSounds"
	folder.Parent = SoundService
	for name, def in Sounds do
		if def.id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = def.id
			sound.Volume = def.volume
			sound.Parent = folder
			sounds[name] = sound
		end
	end
	music = sounds.Music
	if music then
		music.Looped = true
	end
end

function Audio.play(name: string)
	if not sfxEnabled then
		return
	end
	local sound = sounds[name]
	local def = (Sounds :: any)[name]
	if not sound or not def then
		return
	end
	local now = os.clock()
	local throttle = THROTTLE[name]
	if throttle and now - (lastPlayed[name] or 0) < throttle then
		return
	end
	lastPlayed[name] = now
	sound.PlaybackSpeed = random:NextNumber(def.pitchMin, def.pitchMax)
	sound.TimePosition = 0
	sound:Play()
end

function Audio.applySettings(settings: { [string]: any }?)
	if not settings then
		return
	end
	sfxEnabled = settings.sfx ~= false
	if music then
		if settings.music ~= false then
			if not music.IsPlaying then
				music:Play()
			end
		else
			music:Stop()
		end
	end
end

return Audio
