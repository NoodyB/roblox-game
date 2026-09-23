--!strict
-- A zone's debris field: a grid of cells, each holding 0..cellMax units, stored in a compact buffer.
-- The server owns the authoritative grid; clients keep a mirror updated from replicated deltas.

local DebrisGrid = {}
DebrisGrid.__index = DebrisGrid

export type Config = {
	cols: number,
	rows: number,
	cellSize: number,
	originX: number,
	originZ: number,
	cellMax: number,
	mask: { [number]: boolean }?,
	reachPadding: number?,
}

export type DebrisGrid = typeof(setmetatable(
	{} :: {
		cols: number,
		rows: number,
		cellSize: number,
		originX: number,
		originZ: number,
		cellMax: number,
		mask: { [number]: boolean },
		reachPadding: number,
		cells: buffer,
		activeCells: number,
		capacity: number,
		remaining: number,
	},
	DebrisGrid
))

function DebrisGrid.new(config: Config): DebrisGrid
	local mask = config.mask or {}
	local count = config.cols * config.rows
	local active = 0
	for i = 0, count - 1 do
		if not mask[i] then
			active += 1
		end
	end
	local self = setmetatable({
		cols = config.cols,
		rows = config.rows,
		cellSize = config.cellSize,
		originX = config.originX,
		originZ = config.originZ,
		cellMax = config.cellMax,
		mask = mask,
		reachPadding = config.reachPadding or 0,
		cells = buffer.create(count),
		activeCells = active,
		capacity = active * config.cellMax,
		remaining = 0,
	}, DebrisGrid)
	return self
end

function DebrisGrid.cellCount(self: DebrisGrid): number
	return self.cols * self.rows
end

function DebrisGrid.fill(self: DebrisGrid, amount: number?)
	local value = math.clamp(amount or self.cellMax, 0, self.cellMax)
	local total = 0
	for i = 0, self:cellCount() - 1 do
		if self.mask[i] then
			buffer.writeu8(self.cells, i, 0)
		else
			buffer.writeu8(self.cells, i, value)
			total += value
		end
	end
	self.remaining = total
end

function DebrisGrid.get(self: DebrisGrid, index: number): number
	return buffer.readu8(self.cells, index)
end

function DebrisGrid.set(self: DebrisGrid, index: number, amount: number)
	if self.mask[index] then
		return
	end
	local clamped = math.clamp(math.floor(amount), 0, self.cellMax)
	local old = buffer.readu8(self.cells, index)
	buffer.writeu8(self.cells, index, clamped)
	self.remaining += clamped - old
end

function DebrisGrid.cellCenter(self: DebrisGrid, index: number): (number, number)
	local col = index % self.cols
	local row = index // self.cols
	return self.originX + (col + 0.5) * self.cellSize, self.originZ + (row + 0.5) * self.cellSize
end

function DebrisGrid.indexAt(self: DebrisGrid, x: number, z: number): number?
	local col = math.floor((x - self.originX) / self.cellSize)
	local row = math.floor((z - self.originZ) / self.cellSize)
	if col < 0 or row < 0 or col >= self.cols or row >= self.rows then
		return nil
	end
	return row * self.cols + col
end

-- Removes up to `power` units from every cell within `radius` of (x, z), never exceeding `maxUnits`
-- in total. Indices of changed cells are appended to `changed` if provided. Returns units removed.
function DebrisGrid.collect(
	self: DebrisGrid,
	x: number,
	z: number,
	radius: number,
	power: number,
	maxUnits: number,
	changed: { number }?
): number
	if maxUnits <= 0 or power <= 0 or self.remaining <= 0 then
		return 0
	end
	local reach = radius + self.reachPadding
	local reach2 = reach * reach
	local size = self.cellSize
	local colMin = math.max(0, math.floor((x - reach - self.originX) / size))
	local colMax = math.min(self.cols - 1, math.floor((x + reach - self.originX) / size))
	local rowMin = math.max(0, math.floor((z - reach - self.originZ) / size))
	local rowMax = math.min(self.rows - 1, math.floor((z + reach - self.originZ) / size))
	if colMin > colMax or rowMin > rowMax then
		return 0
	end

	local taken = 0
	local cells = self.cells
	for row = rowMin, rowMax do
		local cz = self.originZ + (row + 0.5) * size - z
		local cz2 = cz * cz
		if cz2 <= reach2 then
			for col = colMin, colMax do
				local cx = self.originX + (col + 0.5) * size - x
				if cx * cx + cz2 <= reach2 then
					local index = row * self.cols + col
					local amount = buffer.readu8(cells, index)
					if amount > 0 then
						local take = math.min(amount, power, maxUnits - taken)
						buffer.writeu8(cells, index, amount - take)
						taken += take
						if changed then
							table.insert(changed, index)
						end
						if taken >= maxUnits then
							self.remaining -= taken
							return taken
						end
					end
				end
			end
		end
	end
	self.remaining -= taken
	return taken
end

function DebrisGrid.cleanFraction(self: DebrisGrid): number
	if self.capacity <= 0 then
		return 1
	end
	return 1 - self.remaining / self.capacity
end

function DebrisGrid.snapshot(self: DebrisGrid): buffer
	local copy = buffer.create(buffer.len(self.cells))
	buffer.copy(copy, 0, self.cells, 0)
	return copy
end

function DebrisGrid.load(self: DebrisGrid, source: buffer)
	local len = math.min(buffer.len(source), buffer.len(self.cells))
	buffer.copy(self.cells, 0, source, 0, len)
	local total = 0
	for i = 0, self:cellCount() - 1 do
		if self.mask[i] then
			buffer.writeu8(self.cells, i, 0)
		else
			total += buffer.readu8(self.cells, i)
		end
	end
	self.remaining = total
end

return DebrisGrid
