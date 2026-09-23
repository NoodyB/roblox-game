--!strict
-- Compact binary encoding for debris updates sent to every client.
-- Delta format: u16 count, then count * (u8 zoneId, u16 cellIndex, u8 amount) = 4 bytes per change.

local NetCodec = {}

local ENTRY_SIZE = 4
local MAX_ENTRIES = 65535

-- dirty: { [zoneId]: { [cellIndex]: true } }, read: (zoneId, cellIndex) -> amount
function NetCodec.encodeDirty(dirty: { [number]: { [number]: boolean } }, read: (number, number) -> number): buffer?
	local count = 0
	for _, cells in dirty do
		for _ in cells do
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	count = math.min(count, MAX_ENTRIES)
	local out = buffer.create(2 + count * ENTRY_SIZE)
	buffer.writeu16(out, 0, count)
	local offset = 2
	local written = 0
	for zoneId, cells in dirty do
		for index in cells do
			if written >= count then
				break
			end
			buffer.writeu8(out, offset, zoneId)
			buffer.writeu16(out, offset + 1, index)
			buffer.writeu8(out, offset + 3, read(zoneId, index))
			offset += ENTRY_SIZE
			written += 1
		end
	end
	return out
end

function NetCodec.decodeDeltas(data: buffer, apply: (zoneId: number, cellIndex: number, amount: number) -> ())
	if buffer.len(data) < 2 then
		return
	end
	local count = buffer.readu16(data, 0)
	if buffer.len(data) < 2 + count * ENTRY_SIZE then
		return
	end
	local offset = 2
	for _ = 1, count do
		apply(buffer.readu8(data, offset), buffer.readu16(data, offset + 1), buffer.readu8(data, offset + 3))
		offset += ENTRY_SIZE
	end
end

return NetCodec
