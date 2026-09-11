--!strict
--[[
	AFTERFALL — Client bootstrap

	The mirror image of the server bootstrap, for the player's own machine.

	Controllers handle input, camera, UI, animation and effects -- everything
	the player sees and feels. They never decide game outcomes. A controller may
	ask the server "I want to attack", and it may play the swing animation
	immediately so the game feels responsive, but whether the hit actually
	landed and for how much damage is the server's decision alone.

	Same two-pass startup as the server, for the same reason.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local CombatConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatConfig"))

--[[
	On the client, requiring Net waits for the server's remote tree rather than
	creating it. Doing it here means a controller can assume the remotes exist
	by the time it starts.
]]
local Net = require(Shared:WaitForChild("Net"))

--[[
	Controllers start in this exact order, top to bottom. A controller may only
	depend on controllers listed ABOVE it.

	Empty for now -- Phase A is data, timing and networking only. The first
	entry will be "InputController".
]]
local STARTUP_ORDER: { string } = {}

export type Controller = {
	Init: ((Controller) -> ())?,
	Start: ((Controller) -> ())?,
}

local controllersFolder = script:WaitForChild("Controllers", 10)
assert(
	controllersFolder,
	"[AFTERFALL] Client/Controllers folder is missing. Is Rojo connected in Studio?"
)

local loaded: { [string]: Controller } = {}

-- Pass 1: load and initialise.
for _, name in STARTUP_ORDER do
	local module = controllersFolder:FindFirstChild(name)
	assert(
		module and module:IsA("ModuleScript"),
		`[AFTERFALL] STARTUP_ORDER lists "{name}" but Client/Controllers/{name} does not exist.`
	)

	local controller = require(module) :: Controller
	loaded[name] = controller

	-- Bound to a local first: calling controller:Init() directly does not narrow
	-- the optional type away, which strict mode correctly rejects.
	local init = controller.Init
	if init then
		init(controller)
	end
end

-- Pass 2: start running, each in its own thread so a yield cannot stall the
-- rest of the client's startup.
for _, name in STARTUP_ORDER do
	local controller = loaded[name]
	local start = controller.Start
	if start then
		task.spawn(start, controller)
	end
end

local remoteCategories = 0
for _ in Net do
	remoteCategories += 1
end

print(
	`[AFTERFALL] Client online — {Constants.GAME_NAME}: {Constants.CHAPTER_TITLE}`
		.. ` | {CombatConfig.TICK_RATE}Hz fixed timestep`
		.. ` | {remoteCategories} remote categories received`
		.. ` | {#STARTUP_ORDER} controller(s) started`
)
