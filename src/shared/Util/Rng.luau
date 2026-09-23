--!strict
-- Deterministic pseudo random generator (xorshift32) that behaves identically on server, client and
-- in offline tests. Used for world layout and daily quest selection so every machine agrees.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

local MOD = 2 ^ 32

function Rng.new(seed: number): Rng
	local s = math.floor(math.abs(seed)) % MOD
	if s == 0 then
		s = 0x9E3779B9
	end
	local self = setmetatable({ state = s }, Rng)
	-- warm up so similar seeds diverge
	for _ = 1, 4 do
		self:nextInt()
	end
	return self
end

function Rng.nextInt(self: Rng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- float in [0, 1)
function Rng.next(self: Rng): number
	return self:nextInt() / MOD
end

-- float in [min, max)
function Rng.range(self: Rng, min: number, max: number): number
	return min + (max - min) * self:next()
end

-- integer in [min, max]
function Rng.int(self: Rng, min: number, max: number): number
	return min + math.floor(self:next() * (max - min + 1))
end

function Rng.pick<T>(self: Rng, list: { T }): T
	return list[self:int(1, #list)]
end

function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Stable 32-bit hash of a string, for seeding.
function Rng.hashString(text: string): number
	-- djb2 (kept below 2^53 so it is exact in doubles on every platform)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % MOD
	end
	return h
end

return Rng
