--!strict
--[[
	Client player settings. Pure (no services), local only for now.

		local Settings = require(path.to.Settings)
		Settings.Get("screenShake")              --> 0.7
		Settings.Set("screenShake", 0.3)
		Settings.ApplyPreset("Competitive")
		Settings.Changed:Connect(function(key, value, old) ... end)
		Settings.Observe("rumble", function(value) ... end) -- fires now and on every change

	The module is a ready-made shared store. `Settings.new()` makes an isolated store (tests).

	Persistence seam: call `Settings.SetPersistence({ load = fn, save = fn })` once at startup.
	`load()` returns a partial values table (or nil) that is validated and merged over the
	defaults; `save(values)` is called after every change. A future DataStore-backed adapter
	(through a RemoteFunction to the server) plugs in here without changing any caller.
]]

local Config = require("./Config")

export type Values = Config.Values
export type Persistence = {
	load: () -> { [string]: any }?,
	save: (values: { [string]: any }) -> (),
}

type Listener = (key: string, value: any, old: any) -> ()
export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
export type ChangedSignal = { Connect: (self: ChangedSignal, fn: Listener) -> Connection }

export type Store = {
	Changed: ChangedSignal,
	Get: (key: string) -> any,
	GetAll: () -> Values,
	Set: (key: string, value: any) -> boolean,
	ApplyPreset: (name: string) -> (),
	Reset: () -> (),
	Observe: (key: string, fn: (value: any) -> ()) -> Connection,
	SetPersistence: (adapter: Persistence?) -> (),
	Validate: (key: string, value: any) -> (boolean, any),
	Defaults: Values,
	Presets: { [string]: { [string]: any } },
}

local function validate(key: string, value: any): (boolean, any)
	local rule = Config.Rules[key]
	if not rule then
		return false, nil
	end
	if rule.kind == "number" then
		if type(value) ~= "number" or value ~= value then
			return false, nil
		end
		return true, math.clamp(value, rule.min or -math.huge, rule.max or math.huge)
	elseif rule.kind == "boolean" then
		return type(value) == "boolean", value
	elseif rule.kind == "enum" then
		return table.find(rule.values or {}, value) ~= nil, value
	end
	return false, nil
end

local function newStore(): Store
	local values: { [string]: any } = table.clone(Config.Defaults :: any)
	local listeners: { { fn: Listener, conn: any } } = {}
	local persistence: Persistence? = nil

	local Changed = {} :: any
	function Changed.Connect(_self: any, fn: Listener): Connection
		local conn = { Connected = true } :: any
		local entry = { fn = fn, conn = conn }
		function conn.Disconnect(c: any)
			c.Connected = false
			local i = table.find(listeners, entry)
			if i then
				table.remove(listeners, i)
			end
		end
		table.insert(listeners, entry)
		return conn
	end

	local function fire(key: string, value: any, old: any)
		for _, entry in table.clone(listeners) do
			if entry.conn.Connected then
				entry.fn(key, value, old)
			end
		end
	end

	local function save()
		if persistence then
			local ok, err = pcall(persistence.save, table.clone(values))
			if not ok then
				warn(`[Settings] save failed: {err}`)
			end
		end
	end

	-- Sets without saving; returns true if the value changed.
	local function setRaw(key: string, value: any): boolean
		local ok, clean = validate(key, value)
		if not ok then
			error(`[Settings] invalid value for "{key}": {tostring(value)}`, 3)
		end
		local old = values[key]
		if old == clean then
			return false
		end
		values[key] = clean
		fire(key, clean, old)
		return true
	end

	local store = {} :: Store
	store.Changed = Changed :: ChangedSignal
	store.Defaults = Config.Defaults
	store.Presets = Config.Presets
	store.Validate = validate

	function store.Get(key: string): any
		assert(Config.Rules[key], `[Settings] unknown setting "{key}"`)
		return values[key]
	end

	function store.GetAll(): Values
		return table.clone(values) :: any
	end

	function store.Set(key: string, value: any): boolean
		local changed = setRaw(key, value)
		if changed then
			save()
		end
		return changed
	end

	function store.ApplyPreset(name: string)
		local preset = Config.Presets[name]
		assert(preset, `[Settings] unknown preset "{name}"`)
		local changed = false
		for key, value in preset do
			changed = setRaw(key, value) or changed
		end
		if changed then
			save()
		end
	end

	function store.Reset()
		local changed = false
		for key, value in Config.Defaults :: any do
			changed = setRaw(key, value) or changed
		end
		if changed then
			save()
		end
	end

	function store.Observe(key: string, fn: (value: any) -> ()): Connection
		fn(store.Get(key))
		return Changed:Connect(function(k, v)
			if k == key then
				fn(v)
			end
		end)
	end

	function store.SetPersistence(adapter: Persistence?)
		persistence = adapter
		if not adapter then
			return
		end
		local ok, loaded = pcall(adapter.load)
		if not ok then
			warn(`[Settings] load failed: {loaded}`)
			return
		end
		if type(loaded) == "table" then
			for key, value in loaded do
				local valid, clean = validate(key, value)
				if valid then
					setRaw(key, clean)
				end
			end
		end
	end

	return store
end

local Settings = newStore() :: Store & { new: () -> Store }
Settings.new = newStore

return Settings
