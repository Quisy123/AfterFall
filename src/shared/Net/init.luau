--!strict
--[[
	Net — every client/server message in the game

	THE ONLY PLACE IN THE PROJECT WHERE A REMOTE MAY BE CREATED.

	Remotes scattered through a codebase are how Roblox games get exploited:
	nobody can hold the full list in their head, so nobody notices the one that
	forgot to validate its input. One file means the entire attack surface fits
	on a single screen and can actually be reviewed.

	DIRECTION IS PART OF THE DECLARATION

	Every remote below is marked ClientToServer or ServerToClient, and that
	marking is enforced at runtime, not just documented. A client that fires a
	ServerToClient remote is refused. This closes a whole family of exploits
	where an attacker fires the event the server uses to ANNOUNCE a result --
	"you gained 500 gold", "the wolf died" -- and other clients believe it.

	WHAT THE CLIENT MAY SAY

	Nothing below reports an outcome. The client asks: "I pressed attack",
	"I pressed dodge", "I am holding block". Whether any of that happened, and
	what it did, is the server's decision alone. There is deliberately no
	remote for dealing damage, awarding XP, granting an item or clearing spawn
	protection, because there must never be one.

	USAGE

		local Net = require(ReplicatedStorage.Shared.Net)

		-- client
		Net.Combat.RequestAttack:FireServer("Light")

		-- server
		Net.Combat.RequestAttack.OnServerEvent:Connect(function(player, kind) ... end)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local REMOTES_FOLDER_NAME = "Remotes"
-- Generous: covers a slow first join, but still fails loudly rather than
-- hanging forever if the server never created the remote.
local CLIENT_WAIT_SECONDS = 20

type Direction = "ClientToServer" | "ServerToClient"

type ManifestEntry = {
	Name: string,
	Direction: Direction,
	-- Not decoration: if a remote cannot be described in one line it is
	-- probably doing two jobs and should be two remotes.
	Purpose: string,
}

--[[
	A remote the client may fire. The wrapper exposes FireServer and
	OnServerEvent and nothing else.
]]
export type ClientToServerRemote = {
	Instance: RemoteEvent,
	Direction: Direction,
	FireServer: (self: any, ...any) -> (),
	OnServerEvent: RBXScriptSignal,
}

--[[
	A remote only the server may fire. The wrapper exposes FireClient,
	FireAllClients and OnClientEvent and nothing else.
]]
export type ServerToClientRemote = {
	Instance: RemoteEvent,
	Direction: Direction,
	FireClient: (self: any, player: Player, ...any) -> (),
	FireAllClients: (self: any, ...any) -> (),
	OnClientEvent: RBXScriptSignal,
}

export type Remote = ClientToServerRemote | ServerToClientRemote

--[[
	The manifest. Adding a remote means adding a line here and nowhere else.

	Each entry declares its name, its permitted direction, and its purpose.
]]
local MANIFEST: { [string]: { ManifestEntry } } = {
	Combat = {
		{
			Name = "RequestAttack",
			Direction = "ClientToServer",
			Purpose = "Player pressed light or heavy attack",
		},
		{
			Name = "RequestDodge",
			Direction = "ClientToServer",
			Purpose = "Player pressed dodge, with their facing direction",
		},
		{
			Name = "SetBlock",
			Direction = "ClientToServer",
			Purpose = "Player started or stopped holding block",
		},
		{
			Name = "CombatEvent",
			Direction = "ServerToClient",
			Purpose = "Authoritative result: hits, staggers, state changes",
		},
	},

	Player = {
		{
			Name = "StateSnapshot",
			Direction = "ServerToClient",
			Purpose = "Authoritative health, stamina, poise, spawn protection",
		},
	},

	Progression = {
		{
			Name = "ProgressionChanged",
			Direction = "ServerToClient",
			Purpose = "XP gained or level changed",
		},
	},

	Inventory = {
		{
			Name = "RequestEquip",
			Direction = "ClientToServer",
			Purpose = "Player asked to equip an item they believe they own",
		},
		{
			Name = "InventoryChanged",
			Direction = "ServerToClient",
			Purpose = "Authoritative inventory and equipment state",
		},
	},

	Settings = {
		{
			Name = "SetSetting",
			Direction = "ClientToServer",
			Purpose = "Player changed a setting, e.g. shift lock toggle",
		},
	},
}

export type RemoteDirection = Direction

local Net = {}

--[[
	Builds the remote tree on the server, or waits for it on the client.

	Runs once, at require time. That is deliberate: making callers remember to
	initialise Net before using it would be one more ordering rule to get wrong,
	and the client's WaitForChild already handles arriving before the server has
	finished building.
]]
local function buildOrWait(): Folder
	if IS_SERVER then
		local existing = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
		if existing then
			return existing :: Folder
		end

		local folder = Instance.new("Folder")
		folder.Name = REMOTES_FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	local folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, CLIENT_WAIT_SECONDS)
	assert(folder, `[AFTERFALL] Net: ReplicatedStorage.{REMOTES_FOLDER_NAME} never appeared.`)
	return folder :: Folder
end

local remotesRoot = buildOrWait()

--[[
	Wraps a RemoteEvent so its declared direction is enforced.

	The wrapper exposes only the calls that are legal for this side, so a
	mistake -- a client trying to fire a server-to-client remote -- is a hard
	error at the call site rather than a silently accepted message.
]]
local function wrapRemote(remote: RemoteEvent, direction: Direction, path: string): Remote
	if direction == "ClientToServer" then
		local clientToServer: ClientToServerRemote = {
			Instance = remote,
			Direction = direction,

			FireServer = function(_self, ...)
				assert(not IS_SERVER, `[AFTERFALL] Net.{path}: FireServer called on the server.`)
				remote:FireServer(...)
			end,

			OnServerEvent = remote.OnServerEvent,
		}
		return table.freeze(clientToServer)
	end

	local serverToClient: ServerToClientRemote = {
		Instance = remote,
		Direction = direction,

		FireClient = function(_self, player: Player, ...)
			assert(IS_SERVER, `[AFTERFALL] Net.{path}: FireClient called on a client.`)
			remote:FireClient(player, ...)
		end,

		FireAllClients = function(_self, ...)
			assert(IS_SERVER, `[AFTERFALL] Net.{path}: FireAllClients called on a client.`)
			remote:FireAllClients(...)
		end,

		OnClientEvent = remote.OnClientEvent,
	}
	return table.freeze(serverToClient)
end

for categoryName, entries in MANIFEST do
	local categoryFolder: Instance

	if IS_SERVER then
		local folder = Instance.new("Folder")
		folder.Name = categoryName
		folder.Parent = remotesRoot
		categoryFolder = folder
	else
		local folder = remotesRoot:WaitForChild(categoryName, CLIENT_WAIT_SECONDS)
		assert(folder, `[AFTERFALL] Net: remote category "{categoryName}" never appeared.`)
		categoryFolder = folder
	end

	local category: { [string]: Remote } = {}

	for _, entry in entries do
		-- Separate statements with explicit annotations: multiple assignment
		-- loses the literal union type and widens Direction to plain string.
		local remoteName: string = entry.Name
		local direction: Direction = entry.Direction
		local remote: RemoteEvent

		if IS_SERVER then
			local created = Instance.new("RemoteEvent")
			created.Name = remoteName
			created.Parent = categoryFolder
			remote = created
		else
			local found = categoryFolder:WaitForChild(remoteName, CLIENT_WAIT_SECONDS)
			assert(found, `[AFTERFALL] Net: remote "{categoryName}.{remoteName}" never appeared.`)
			remote = found :: RemoteEvent
		end

		category[remoteName] = wrapRemote(remote, direction, `{categoryName}.{remoteName}`)
	end

	Net[categoryName] = table.freeze(category)
end

table.freeze(Net)

return Net
