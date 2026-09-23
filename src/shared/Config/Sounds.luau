--!strict
-- Sound effects. The rbxasset:// entries ship with every Roblox client, so they need no uploads.
-- To upgrade audio: pick licensed sounds from the Creator Store (or upload your own), paste the
-- rbxassetid:// ids here and test in Studio. An empty string disables that sound.
-- Music is intentionally empty until a licensed track is chosen (see docs/.../Assets & Audio.md).

local Sounds = {
	Collect = { id = "rbxasset://sounds/clickfast.wav", volume = 0.25, pitchMin = 1.1, pitchMax = 1.5 },
	Sell = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitchMin = 1.0, pitchMax = 1.0 },
	Purchase = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitchMin = 1.3, pitchMax = 1.3 },
	Error = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.2, pitchMin = 1.6, pitchMax = 1.6 },
	Click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.4, pitchMin = 0.9, pitchMax = 0.9 },
	CritterFound = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitchMin = 1.6, pitchMax = 1.6 },
	ZoneClear = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitchMin = 0.8, pitchMax = 0.8 },
	Whoosh = { id = "rbxasset://sounds/swoosh.wav", volume = 0.4, pitchMin = 0.9, pitchMax = 1.1 },
	Music = { id = "", volume = 0.25, pitchMin = 1, pitchMax = 1 },
}

return Sounds
