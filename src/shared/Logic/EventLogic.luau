--!strict
-- Which seasonal event (if any) is active at a given unix time, plus event helpers.

local Shared = script.Parent.Parent
local Events = require(Shared.Config.Events)
local Critters = require(Shared.Config.Critters)

local EventLogic = {}

function EventLogic.active(now: number): Events.Event?
	for _, event in Events do
		if now >= event.start and now < event.finish then
			return event
		end
	end
	return nil
end

function EventLogic.secondsLeft(event: Events.Event, now: number): number
	return math.max(0, event.finish - now)
end

-- Event critters for an event id, in drop-weight order.
function EventLogic.critters(eventId: string): { Critters.Critter }
	local list = {}
	for _, critter in Critters.List do
		if critter.event == eventId then
			table.insert(list, critter)
		end
	end
	return list
end

-- Overall odds of each event critter given that a find happens during the event.
function EventLogic.odds(event: Events.Event): { { critter: Critters.Critter, chance: number } }
	local list = EventLogic.critters(event.id)
	local total = 0
	for _, critter in list do
		total += critter.weight
	end
	local result = {}
	for _, critter in list do
		table.insert(result, { critter = critter, chance = event.critterShare * critter.weight / math.max(total, 1) })
	end
	return result
end

return EventLogic
