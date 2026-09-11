--!strict
--[[
	MoveConfig — frame data

	THE SINGLE MOST TUNING-SENSITIVE FILE IN THE PROJECT. Everything about how
	combat feels is decided by these numbers, and all of them are expected to
	change after playtest.

	HOW A MOVE RUNS

		STARTUP  ->  ACTIVE  ->  RECOVERY
		(wind up)    (can hit)   (committed, vulnerable)

	Every duration is in FRAMES at a fixed 60Hz, never seconds. The fixed
	timestep (Shared/Util/FrameClock) guarantees frame 3 is frame 3 on a 30fps
	phone and a 144fps PC alike.

	DAMAGE

	DamageMultiplier is expressed against the weapon's base, not as a flat
	number, so the same moveset scales with every longsword in the game. With
	the Common Longsword (WeaponBase 10) at level 1 the multipliers produce
	exactly the damage in the design table:

		M1-1  1.2 x 10 = 12      M1-4      2.0 x 10 = 20
		M1-2  1.2 x 10 = 12      Crescent  2.8 x 10 = 28
		M1-3  1.4 x 10 = 14

	CANCELS

	CancelIntoDodgeFromRecoveryFrame is counted from the first frame of
	RECOVERY, not from the start of the move. Six frames into an M1's recovery
	the player may dodge out of it.

	That one number is most of what separates a beginner from an expert with
	this weapon: committing to a swing is safe to escape from, but only after a
	real window of vulnerability.
]]

local Types = require(script.Parent.Parent.Types)

local MOVE_KIND = {
	Light = "Light",
	Heavy = "Heavy",
	Dodge = "Dodge",
}

--[[
	Hitbox shapes are resolved by spatial query, never by .Touched -- touch
	events are unreliable at speed and trivially spoofed from the client.

	!! RANGE AND ANGLE ARE ENGINEERING ESTIMATES, NOT DESIGN-SPECIFIED. !!
	The design table specifies timing, damage, poise and stamina; reach was not
	given. These are first guesses sized to the animation each move implies -- a
	thrust is long and narrow, a crescent sweep is short and wide. Expect to
	retune them first, because reach is the property players feel most directly
	and complain about most specifically.
]]
local MOVES: { [string]: Types.MoveData } = {
	-- Light chain -----------------------------------------------------------
	LS_M1_1 = {
		Id = "LS_M1_1",
		DisplayName = "Diagonal Slash",
		Kind = MOVE_KIND.Light,
		Startup = 9,
		Active = 4,
		Recovery = 14,
		DamageMultiplier = 1.2,
		PoiseDamage = 8,
		StaminaCost = 8,
		HitstopFrames = 4,
		Hitbox = { Shape = "Arc", Range = 7, AngleDegrees = 100, Height = 6 },
		CancelIntoDodgeFromRecoveryFrame = 6,
	},

	LS_M1_2 = {
		Id = "LS_M1_2",
		DisplayName = "Reverse Slash",
		Kind = MOVE_KIND.Light,
		-- One frame faster to start than M1-1: the blade is already in motion
		-- coming out of the first swing.
		Startup = 8,
		Active = 4,
		Recovery = 14,
		DamageMultiplier = 1.2,
		PoiseDamage = 8,
		StaminaCost = 8,
		HitstopFrames = 4,
		Hitbox = { Shape = "Arc", Range = 7, AngleDegrees = 100, Height = 6 },
		CancelIntoDodgeFromRecoveryFrame = 6,
	},

	LS_M1_3 = {
		Id = "LS_M1_3",
		DisplayName = "Thrust",
		Kind = MOVE_KIND.Light,
		Startup = 10,
		Active = 5,
		Recovery = 16,
		DamageMultiplier = 1.4,
		PoiseDamage = 10,
		StaminaCost = 8,
		HitstopFrames = 4,
		-- Longest reach, narrowest arc: a thrust should reward lining the
		-- target up and punish swinging it at a crowd.
		Hitbox = { Shape = "Arc", Range = 9, AngleDegrees = 35, Height = 5 },
		CancelIntoDodgeFromRecoveryFrame = 6,
	},

	LS_M1_4 = {
		Id = "LS_M1_4",
		DisplayName = "Heavy Arc",
		Kind = MOVE_KIND.Heavy,
		Startup = 14,
		Active = 6,
		Recovery = 26,
		DamageMultiplier = 2.0,
		--[[
			22 poise is the number that makes the chain sing. A full four-hit
			chain deals 8 + 8 + 10 + 22 = 48 poise into the wolf's 40, so
			finishing the chain staggers it and starting over does not. The
			chain finisher is the payoff for committing to the whole thing.
		]]
		PoiseDamage = 22,
		StaminaCost = 14,
		HitstopFrames = 7,
		Hitbox = { Shape = "Arc", Range = 8, AngleDegrees = 140, Height = 7 },
		CancelIntoDodgeFromRecoveryFrame = 6,
	},

	-- Heavy -----------------------------------------------------------------
	LS_CRESCENT_BREAK = {
		Id = "LS_CRESCENT_BREAK",
		DisplayName = "Crescent Break",
		Kind = MOVE_KIND.Heavy,
		--[[
			A 22-frame startup is a long, readable commitment -- over a third of
			a second of telegraph. That is the point: it should be punishable on
			reaction, and land like a decision rather than a reflex.

			NOTE ON POISE: 34 does NOT stagger a full-poise wolf (40). It brings
			the wolf to 85% of its threshold, so any follow-up hit staggers.
			Crescent Break SETS UP a stagger rather than delivering one. That may
			well be intended -- but it is worth knowing, because the heaviest
			attack in the weapon not breaking the starter enemy on its own is
			surprising until you have read this comment.
		]]
		Startup = 22,
		Active = 7,
		Recovery = 32,
		DamageMultiplier = 2.8,
		PoiseDamage = 34,
		StaminaCost = 20,
		HitstopFrames = 7,
		Hitbox = { Shape = "Arc", Range = 9, AngleDegrees = 160, Height = 7 },
		CancelIntoDodgeFromRecoveryFrame = 6,
	},

	-- Dodge -----------------------------------------------------------------
	--[[
		Flowing Step.

		20 frames total with invulnerability on frames 3 through 11 inclusive
		(9 frames, 150ms). The 2-frame lead-in is what stops the dodge from
		being a panic button: it has to be started before the hit, not during
		it.

		Frames 12-20 are recovery with no protection, which is what makes dodge
		spam punishable rather than free.
	]]
	LS_DODGE = {
		Id = "LS_DODGE",
		DisplayName = "Flowing Step",
		Kind = MOVE_KIND.Dodge,
		TotalFrames = 20,
		InvulnerableFromFrame = 3,
		InvulnerableToFrame = 11,
		StaminaCost = 20,
		Distance = 14,
	},
}

--[[
	A moveset names the chain order. The engine walks this list; it does not
	know what a "Longsword" is.
]]
local MOVESETS: { [string]: Types.MovesetData } = {
	Longsword_Novice = {
		Id = "Longsword_Novice",
		LightChain = { "LS_M1_1", "LS_M1_2", "LS_M1_3", "LS_M1_4" },
		Heavy = "LS_CRESCENT_BREAK",
		Dodge = "LS_DODGE",
	},
}

local MoveConfig = {
	MOVE_KIND = MOVE_KIND,
	MOVES = MOVES,
	MOVESETS = MOVESETS,
}

-- Loud on a bad id, for the same reason as WeaponConfig.get.
function MoveConfig.get(moveId: string): Types.MoveData
	local move = MOVES[moveId]
	if not move then
		error(`MoveConfig: no move with id "{moveId}"`, 2)
	end
	return move
end

--[[
	Total frames a move occupies, hitstop aside. Dodge carries its length
	directly; attacks are the sum of their three phases.
]]
function MoveConfig.totalFrames(moveId: string): number
	local move = MoveConfig.get(moveId)
	if move.TotalFrames then
		return move.TotalFrames
	end
	return (move.Startup or 0) + (move.Active or 0) + (move.Recovery or 0)
end

function MoveConfig.getMoveset(movesetId: string): Types.MovesetData
	local moveset = MOVESETS[movesetId]
	if not moveset then
		error(`MoveConfig: no moveset with id "{movesetId}"`, 2)
	end
	return moveset
end

for _, move in MOVES do
	if move.Hitbox then
		table.freeze(move.Hitbox)
	end
	table.freeze(move)
end
for _, moveset in MOVESETS do
	table.freeze(moveset.LightChain)
	table.freeze(moveset)
end
table.freeze(MOVE_KIND)
table.freeze(MOVES)
table.freeze(MOVESETS)

table.freeze(MoveConfig)

return MoveConfig
