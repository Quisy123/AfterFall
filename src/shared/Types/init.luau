--!strict
--[[
	Types

	Shared type definitions. Types declared here are visible to the server and
	the client, which means both sides describe the same data the same way and
	the type checker can catch mismatches before the game is ever run.

	Usage:
		local Types = require(ReplicatedStorage.Shared.Types)
		local function award(result: Types.Result<number>) ... end

	Game-content types (WeaponData, AttackData, EnemyData, ...) will be added
	here as the systems that need them are built. Adding speculative types for
	systems that do not exist yet only creates work when the real requirements
	turn out to be different.
]]

--[[
	Result describes an operation that is expected to fail sometimes, such as
	loading save data from a DataStore.

	It exists so that failure has to be handled at the call site rather than
	being reported by returning nil, which is easy to ignore by accident. That
	matters most in DataService: silently treating a failed load as "new
	player" is how games erase real progress.
]]
export type Result<T> = { ok: true, value: T } | { ok: false, error: string }

-- Type-only module: nothing to export at runtime.
return table.freeze({})
