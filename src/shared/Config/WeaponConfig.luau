--!strict
--[[
	WeaponConfig — weapon types, mastery keys and weapon data

	A weapon is DATA. The combat engine reads this file; it contains no code
	that knows the word "Longsword". Adding the Greatsword later means adding an
	entry here and a moveset in MoveConfig, and touching no engine code at all.
]]

local Types = require(script.Parent.Parent.Types)

--[[
	The eight weapon types the game will ship with. Two jobs:

		1. The keys of the mastery table in every player's save.
		2. The set a weapon's WeaponType must belong to.

	!! ONLY "Longsword" AND "SwordAndShield" ARE CONFIRMED. !!

	The other six are placeholders chosen to cover the usual archetypes, and are
	expected to change. That is safe: mastery is stored in the save as a map
	keyed by these strings, so renaming one before launch is a data migration of
	a single key, not a schema change. Confirm the real list when the weapon
	roster is decided.
]]
local WEAPON_TYPES = {
	Longsword = "Longsword", -- confirmed: the first weapon
	SwordAndShield = "SwordAndShield", -- confirmed: referenced as the defensive identity
	Greatsword = "Greatsword", -- placeholder
	Dagger = "Dagger", -- placeholder
	Spear = "Spear", -- placeholder
	Bow = "Bow", -- placeholder
	Staff = "Staff", -- placeholder
	Gauntlets = "Gauntlets", -- placeholder
}

--[[
	Rarity exists here only so items can carry it. The full rarity ecosystem
	(Common through Ancient) is not this slice's job.
]]
local RARITY = {
	Common = "Common",
	Uncommon = "Uncommon",
}

local WEAPONS: { [string]: Types.WeaponData } = {
	--[[
		The starting weapon. WeaponBase 10 is chosen so that MoveConfig's damage
		numbers read as literal damage at level 1: base 10 x the move's
		multiplier x 1.0 attribute scale x 1.0 Novice mastery.
	]]
	Longsword_Common = {
		Id = "Longsword_Common",
		DisplayName = "Longsword",
		WeaponType = WEAPON_TYPES.Longsword,
		Rarity = RARITY.Common,
		WeaponBase = 10,
		--[[
			Which attribute scales this weapon's damage. Data, not a rule baked
			into the engine -- a Dexterity-scaling longsword variant is a
			one-word change here.
		]]
		ScalingStat = "Strength",
		Moveset = "Longsword_Novice",
	},

	--[[
		The wolf's drop, and the only equippable reward in this slice.

		Its WeaponBase is 12 against the starting weapon's 10 specifically so
		that equipping it produces a visible, immediately legible change: every
		damage number goes up by a fifth. "Observe the stat change" is a
		success condition of the slice, and it cannot be observed if the reward
		is a sidegrade.
	]]
	Longsword_Wolffang = {
		Id = "Longsword_Wolffang",
		DisplayName = "Wolffang Longsword",
		WeaponType = WEAPON_TYPES.Longsword,
		Rarity = RARITY.Uncommon,
		WeaponBase = 12,
		ScalingStat = "Strength",
		Moveset = "Longsword_Novice",
	},
}

local WeaponConfig = {
	WEAPON_TYPES = WEAPON_TYPES,
	RARITY = RARITY,
	WEAPONS = WEAPONS,

	-- What a brand new character starts holding.
	STARTING_WEAPON = "Longsword_Common",
}

--[[
	Returns a weapon by id, or errors naming the offender.

	Loud on failure by design: a typo'd weapon id that returned nil would
	surface later as a mysterious zero-damage attack, which is far harder to
	trace than a crash at the point of the mistake.
]]
function WeaponConfig.get(weaponId: string): Types.WeaponData
	local weapon = WEAPONS[weaponId]
	if not weapon then
		error(`WeaponConfig: no weapon with id "{weaponId}"`, 2)
	end
	return weapon
end

for _, weapon in WEAPONS do
	table.freeze(weapon)
end
table.freeze(WEAPON_TYPES)
table.freeze(RARITY)
table.freeze(WEAPONS)
table.freeze(WeaponConfig)

return WeaponConfig
