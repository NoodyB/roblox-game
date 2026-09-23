--!strict
-- Minimal synchronous signal for decoupling modules (server services, client controllers).
-- Handlers run in order of connection; errors in one handler do not stop the others.

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _handlers: { any } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	local entry = { fn = handler, connected = true }
	table.insert(self._handlers, entry)
	local connection = { Connected = true } :: any
	function connection.Disconnect(conn)
		if not entry.connected then
			return
		end
		entry.connected = false
		conn.Connected = false
		local index = table.find(self._handlers, entry)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end

function Signal.Once(self: Signal, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	-- iterate over a snapshot so handlers may disconnect during dispatch
	local snapshot = table.clone(self._handlers)
	for _, entry in snapshot do
		if entry.connected then
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				warn("[Signal] handler error: " .. tostring(err))
			end
		end
	end
end

function Signal.DisconnectAll(self: Signal)
	for _, entry in self._handlers do
		entry.connected = false
	end
	table.clear(self._handlers)
end

return Signal
