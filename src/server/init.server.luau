--!strict
--[[
	AFTERFALL — Server bootstrap

	This is the only script on the server that runs by itself. Everything else
	is a module that this script starts, in an order defined here.

	Why startup order is written down explicitly:

	If services were allowed to reach out and grab each other whenever they
	felt like it, you eventually get a loop -- CombatService needs
	ProgressionService, which needs InventoryService, which needs
	CombatService -- and the game fails to start for reasons that are very hard
	to trace. Listing the order in one place makes that loop impossible to
	create by accident: a service may only depend on services listed ABOVE it.

	Startup runs in two passes:

		Init   -- set up internal state. No talking to other services yet.
		Start  -- begin running. Every service now exists, so this is the point
		          at which it is safe to use another one.

	The two passes are what let two services use each other without either one
	needing to load first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local CombatConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatConfig"))

--[[
	Requiring Net here is what builds the remote tree in ReplicatedStorage --
	remotes are created at require time, and on the server this is the first
	require. Doing it in the bootstrap means the tree exists before any service
	or client tries to use it.
]]
local Net = require(Shared:WaitForChild("Net"))

--[[
	Services start in this exact order, top to bottom.

	Empty for now -- Phase A is data, timing and networking only. The first
	entry will be "DataService", followed by "PlayerService".
]]
local STARTUP_ORDER: { string } = {}

export type Service = {
	Init: ((Service) -> ())?,
	Start: ((Service) -> ())?,
}

local servicesFolder = script:WaitForChild("Services", 10)
assert(
	servicesFolder,
	"[AFTERFALL] Server/Services folder is missing. Is Rojo connected in Studio?"
)

local loaded: { [string]: Service } = {}

-- Pass 1: load and initialise.
for _, name in STARTUP_ORDER do
	local module = servicesFolder:FindFirstChild(name)
	assert(
		module and module:IsA("ModuleScript"),
		`[AFTERFALL] STARTUP_ORDER lists "{name}" but Server/Services/{name} does not exist.`
	)

	local service = require(module) :: Service
	loaded[name] = service

	-- Bound to a local first: calling service:Init() directly does not narrow
	-- the optional type away, which strict mode correctly rejects.
	local init = service.Init
	if init then
		init(service)
	end
end

-- Pass 2: start running.
--
-- Each Start runs in its own thread so that one service that yields (waiting on
-- a DataStore, for example) cannot stall the rest of the server's startup.
for _, name in STARTUP_ORDER do
	local service = loaded[name]
	local start = service.Start
	if start then
		task.spawn(start, service)
	end
end

-- Counted rather than hard-coded, so this line cannot drift out of date as
-- remotes are added.
local remoteCategories = 0
for _ in Net do
	remoteCategories += 1
end

print(
	`[AFTERFALL] Server online — {Constants.GAME_NAME}: {Constants.CHAPTER_TITLE}`
		.. ` | save format v{Constants.DATA_VERSION}`
		.. ` | {CombatConfig.TICK_RATE}Hz fixed timestep`
		.. ` | {remoteCategories} remote categories`
		.. ` | {#STARTUP_ORDER} service(s) started`
)
