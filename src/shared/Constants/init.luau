--!strict
--[[
	Constants

	Values that more than one system has to agree on.

	The rule: if a number appears in two different files, it belongs here
	instead. That is what stops "magic numbers scattered everywhere" from
	slowly making the game impossible to re-balance.

	This is NOT a dumping ground for every tunable in the game. Per-weapon and
	per-enemy numbers live in their own definition files under
	Shared/Definitions, so that adding content never means editing this file.
]]

local Constants = {
	-- Identity -------------------------------------------------------------
	GAME_NAME = "AFTERFALL",
	CHAPTER_TITLE = "AWAKENING",

	-- Save data ------------------------------------------------------------
	-- Bumped by one whenever the shape of saved PlayerData changes. DataService
	-- uses this to migrate old saves forward instead of throwing them away.
	-- Never reuse or lower a version number.
	DATA_VERSION = 1,

	-- Session --------------------------------------------------------------
	-- Design target is ~12 players, hard ceiling 15. Systems that scale with
	-- player count should read this rather than assuming a number.
	MAX_PLAYERS = 15,
}

-- Frozen so a typo like `Constants.MAX_PLAYERS = 3` fails loudly at the moment
-- it happens, instead of silently corrupting behaviour somewhere else later.
table.freeze(Constants)

return Constants
