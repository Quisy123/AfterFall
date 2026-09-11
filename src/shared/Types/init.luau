--!strict
--[[
	Types

	Shared type definitions, visible to server and client alike, so both sides
	describe the same data the same way and the type checker catches mismatches
	before the game is ever run.

	Usage:
		local Types = require(ReplicatedStorage.Shared.Types)
		local function apply(hit: Types.DamageResult) ... end
]]

--[[
	Result describes an operation that is expected to fail sometimes, such as
	loading save data from a DataStore.

	Failure has to be handled at the call site rather than reported by returning
	nil, which is easy to ignore by accident. That matters most in DataService:
	silently treating a failed load as "new player" is how games erase real
	progress.
]]
export type Result<T> = { ok: true, value: T } | { ok: false, error: string }

-- =========================================================================
-- COMBAT
-- =========================================================================

export type MoveKind = "Light" | "Heavy" | "Dodge"

--[[
	Hit quality drives both feedback and hitstop. It is derived from the
	outcome of a hit, never chosen by the caller.

	Normal    an ordinary connect
	Critical  a Dexterity crit roll, OR a weak point hit -- one tier for both,
	          so the player reads "I hurt it properly" without having to work
	          out which of the two fired
	Stagger   this hit crossed the target's poise threshold
	Finisher  this hit killed the target
]]
export type HitQuality = "Normal" | "Critical" | "Stagger" | "Finisher"

export type HitboxSpec = {
	Shape: string,
	Range: number,
	AngleDegrees: number,
	Height: number,
}

--[[
	One move's frame data. Attacks carry Startup/Active/Recovery; dodges carry
	TotalFrames and an invulnerability window instead. Both live in this one
	type so a moveset can hold them together.
]]
export type MoveData = {
	Id: string,
	DisplayName: string,
	Kind: MoveKind,
	StaminaCost: number,

	-- Attacks only.
	Startup: number?,
	Active: number?,
	Recovery: number?,
	DamageMultiplier: number?,
	PoiseDamage: number?,
	HitstopFrames: number?,
	Hitbox: HitboxSpec?,
	CancelIntoDodgeFromRecoveryFrame: number?,

	-- Dodges only.
	TotalFrames: number?,
	InvulnerableFromFrame: number?,
	InvulnerableToFrame: number?,
	Distance: number?,
}

export type MovesetData = {
	Id: string,
	LightChain: { string },
	Heavy: string,
	Dodge: string,
}

export type WeaponData = {
	Id: string,
	DisplayName: string,
	WeaponType: string,
	Rarity: string,
	WeaponBase: number,
	ScalingStat: string,
	Moveset: string,
}

--[[
	Everything the damage formula needs, gathered in one place.

	Passed as a plain table of numbers with no Roblox types anywhere, so the
	damage calculation stays a pure function that the test suite can run tens of
	thousands of times outside Roblox.
]]
export type DamageParams = {
	WeaponBase: number,
	MoveMultiplier: number,
	AttributeScale: number,
	MasteryMultiplier: number,
	-- Armour mitigation, already clamped to StatConfig.MITIGATION_CAP.
	Mitigation: number,
	-- Block absorption, or 0 when the guard is not up. Its own layer -- it does
	-- not feed the mitigation cap.
	BlockAbsorption: number,
	IsCritical: boolean,
	-- Weak point hits skip the mitigation term entirely.
	IsWeakPoint: boolean,
}

export type DamageResult = {
	Damage: number,
	Quality: HitQuality,
	HitstopFrames: number,
	PoiseDamage: number,
	Staggered: boolean,
	Killed: boolean,
}

-- =========================================================================
-- ENEMIES
-- =========================================================================

export type EnemyAttackData = {
	Id: string,
	DisplayName: string,
	TellFrames: number,
	Active: number,
	Recovery: number,
	Damage: number,
	TravelDistance: number?,
}

--[[
	A point on an enemy that ignores mitigation when struck. The hook exists
	now; no enemy in this slice defines one.
]]
export type WeakPointSpec = {
	Id: string,
	AttachmentName: string,
	Radius: number,
}

-- =========================================================================
-- SAVE DATA
-- =========================================================================
--[[
	The save schema is shaped for the whole of Chapter 1 but populated only as
	far as this slice needs. Fields present and empty are deliberate: adding a
	key to a table that already exists is free, whereas introducing a whole new
	branch later means a migration.

	Every change to this shape must bump Constants.DATA_VERSION and add a
	migration step. Old saves are migrated forward, never discarded.
]]

export type PlayerAttributes = {
	Vigor: number,
	Strength: number,
	Dexterity: number,
}

export type MasteryEntry = {
	Tier: string,
	XP: number,
}

export type PlayerSettings = {
	--[[
		Shift lock is a player choice, off by default, and is NEVER engaged or
		disengaged automatically by any game system. Persisted here so the
		choice survives a rejoin.
	]]
	ShiftLock: boolean,
	AimMode: "Assisted" | "LockOn" | "FreeAim",
}

export type PlayerData = {
	DataVersion: number,

	Identity: {
		CharacterName: string,
	},

	Progression: {
		Level: number,
		XP: number,
		Attributes: PlayerAttributes,
		UnspentAttributePoints: number,
		Renown: number,
		Titles: { string },
	},

	-- Keyed by WeaponConfig.WEAPON_TYPES. All eight present from character
	-- creation, so mastery never has to be back-filled.
	Mastery: { [string]: MasteryEntry },

	Equipment: {
		Weapon: string?,
		Armor: string?,
		Accessories: { string },
	},

	-- Item id -> quantity.
	Inventory: { [string]: number },

	Economy: {
		Gold: number,
		Aether: number,
		GuildTokens: number,
	},

	-- Shaped and empty: these systems are outside this slice.
	Quests: {
		Completed: { string },
		Active: { [string]: any },
	},

	Guilds: {
		[string]: {
			Rank: number,
			Reputation: number,
		},
	},

	Settings: PlayerSettings,
}

-- Type-only module: nothing to export at runtime.
return table.freeze({})
