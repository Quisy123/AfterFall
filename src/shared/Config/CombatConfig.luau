--!strict
--[[
	CombatConfig — global combat rules and timing

	Values here apply to combat as a whole. Anything belonging to one weapon,
	one move or one enemy lives in WeaponConfig, MoveConfig or EnemyConfig.

	EVERY NUMBER IN THIS FILE IS A TUNING KNOB. Behaviour code must read from
	here and never hard-code a value, so that a retune after playtest is an edit
	to this file rather than a hunt through the codebase.

	Durations are in FRAMES at a fixed 60Hz, not seconds, because combat is
	simulated on a fixed timestep (see Shared/Util/FrameClock). Where a design
	value was given in seconds, the frame count and the conversion are both
	written down.
]]

local TICK_RATE = 60

local CombatConfig = {
	-- Simulation ------------------------------------------------------------
	TICK_RATE = TICK_RATE,
	SECONDS_PER_FRAME = 1 / TICK_RATE,

	--[[
		Most simulation frames one Heartbeat may run to catch up after a stall.

		8 frames is ~133ms of catch-up: enough to ride out an ordinary hitch
		without the simulation visibly slowing, small enough that a serious
		stall drops time instead of trying to replay a backlog it cannot finish.
	]]
	MAX_CATCHUP_FRAMES = 8,

	-- Chaining and cancels --------------------------------------------------
	--[[
		How long after a move's active frames end the next move in the chain may
		be buffered. Runs through recovery and past its end.
	]]
	CHAIN_WINDOW_FRAMES = 18,

	-- Hitstop ---------------------------------------------------------------
	--[[
		Hitstop is the brief freeze on impact that makes a hit feel like it
		connected with something solid.

		On a fixed timestep it is implemented as NOT ADVANCING the move clock of
		the entities involved for N frames. It is part of the authoritative
		simulation, not a client-side flourish -- if the client froze and the
		server did not, every timing after the hit would disagree.

		The value used is the LARGER of the move's own hitstop (MoveConfig) and
		the tier minimum below. So a light attack that rolls a critical gets the
		critical's 7 frames, and a heavy that does not crit still gets its 7.
	]]
	HITSTOP_FRAMES = {
		Normal = 4,
		Critical = 7,
		Stagger = 12,
		Finisher = 20,
	},

	-- Poise -----------------------------------------------------------------
	--[[
		Poise damage accumulates. On reaching the entity's threshold the entity
		staggers and its accumulated poise damage resets to zero.
	]]
	POISE_REGEN_PER_SECOND = 12,
	-- 1.5 seconds x 60. Regen is suspended until this many frames have passed
	-- since the last poise damage taken.
	POISE_REGEN_DELAY_FRAMES = 90,

	-- Blocking --------------------------------------------------------------
	--[[
		Block is a paid defence, not a passive one: it costs stamina in
		proportion to what it stops, and running out breaks the guard.
	]]
	BLOCK_RAISE_FRAMES = 4,
	--[[
		Fraction of incoming damage absorbed once the guard is up.

		Applied as its own multiplicative layer AFTER armour mitigation, and it
		does not feed the armour mitigation cap. See StatConfig.MITIGATION_CAP
		for why the two are kept separate.
	]]
	BLOCK_ABSORPTION = 0.60,
	--[[
		Stamina drained per point of damage ABSORBED (not per point incoming).

		A 10-damage bite against a raised guard absorbs 6 and costs 4.2 stamina.
		If this should instead be 70% of the incoming damage, change only this
		line and BLOCK_STAMINA_BASIS below.
	]]
	BLOCK_STAMINA_PER_DAMAGE_BLOCKED = 0.70,
	-- "Absorbed" = the damage prevented. "Incoming" = the damage before block.
	BLOCK_STAMINA_BASIS = "Absorbed" :: "Absorbed" | "Incoming",
	-- Guard breaking at zero stamina leaves the defender helpless this long.
	GUARD_BREAK_HELPLESS_FRAMES = 45,

	-- Lag compensation ------------------------------------------------------
	--[[
		Without compensation, a player on 100ms ping gets hit through dodges they
		watched themselves complete. That reads as the game cheating, which the
		core design rule forbids.

		So the server accepts the client's claimed action time and resolves
		against a rewound world state -- but only within a hard bound.

		STRICT LIMITS, both deliberate:

		1. HARD CAP. A claim older than this resolves in the server's present
		   with no rewind at all. Uncapped rewind lets players appear to
		   teleport, which becomes unacceptable once PvP exists.

		2. I-FRAMES AND HIT REGISTRATION ONLY. Health, stamina, poise, loot and
		   spawn protection ALWAYS resolve in the server's present. Rewinding
		   those would let a client retroactively rewrite state it does not own.
	]]
	REWIND_MAX_MS = 100,
	-- 100ms at 60Hz = 6 frames.
	REWIND_MAX_FRAMES = 6,

	-- Spawn protection ------------------------------------------------------
	--[[
		Full invulnerability on respawn. Breaks the instant the player attacks,
		never on a timer alone.

		Server-authoritative without exception. A client-side flag here would be
		an invulnerability toggle handed directly to an exploiter.
	]]
	-- 8 seconds x 60.
	SPAWN_PROTECTION_FRAMES = 480,

	-- Targeting -------------------------------------------------------------
	--[[
		Assisted aim nudges an attack toward a valid target within this cone.
		Computed identically on client and server from the same inputs, so
		prediction and authority agree without an extra network message.
	]]
	AIM_ASSIST_MAX_DEGREES = 15,
	AIM_ASSIST_MAX_RANGE = 20,
}

table.freeze(CombatConfig.HITSTOP_FRAMES)
table.freeze(CombatConfig)

return CombatConfig
