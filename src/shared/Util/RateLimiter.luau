--!strict
-- Token-bucket rate limiter keyed by an arbitrary key (usually a Player).
-- `clock` is injectable for tests; defaults to os.clock.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		rate: number,
		burst: number,
		buckets: { [any]: { tokens: number, last: number } },
		clock: () -> number,
	},
	RateLimiter
))

function RateLimiter.new(ratePerSecond: number, burst: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		rate = ratePerSecond,
		burst = burst,
		buckets = {},
		clock = clock or os.clock,
	}, RateLimiter)
end

function RateLimiter.check(self: RateLimiter, key: any, cost: number?): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.rate)
	bucket.last = now
	local price = cost or 1
	if bucket.tokens >= price then
		bucket.tokens -= price
		return true
	end
	return false
end

function RateLimiter.remove(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
