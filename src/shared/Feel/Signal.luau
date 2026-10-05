--!strict
-- Minimal synchronous signal. Pure (no Roblox services) so shared/sim code can use it under Lune.
-- Handlers run in Connect order on the firing thread; a handler that errors stops the Fire.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Handler = { fn: (...any) -> (), conn: any }

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { Handler } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local handlers: { Handler } = self._handlers
	local conn = { Connected = true } :: any
	local entry: Handler = { fn = fn, conn = conn }
	function conn.Disconnect(c: any)
		if not c.Connected then
			return
		end
		c.Connected = false
		local i = table.find(handlers, entry)
		if i then
			table.remove(handlers, i)
		end
	end
	table.insert(handlers, entry)
	return conn :: Connection
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local conn: Connection
	conn = Signal.Connect(self, function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire(self: any, ...: any)
	local snapshot = table.clone(self._handlers) :: { Handler }
	for _, entry in snapshot do
		if entry.conn.Connected then
			entry.fn(...)
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, entry in self._handlers do
		entry.conn.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
