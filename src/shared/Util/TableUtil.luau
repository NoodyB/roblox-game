--!strict
-- Small table helpers.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return (copy :: any) :: T
end

-- Fill in keys missing from `target` using `template` (recursively). Existing values are kept.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, templateValue in template do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.deepCopy(templateValue)
		elseif type(templateValue) == "table" and type(current) == "table" then
			-- Only recurse into dictionaries that act as records (non-empty templates).
			if next(templateValue) ~= nil then
				TableUtil.reconcile(current, templateValue)
			end
		end
	end
	return target
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.shallowEqual(a: { [any]: any }, b: { [any]: any }): boolean
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

return TableUtil
