--!strict
--[[
	EnemyConfig — enemy data

	READ THIS BEFORE ADDING A SECOND ENEMY.

	This file holds the wolf's NUMBERS. The wolf's BEHAVIOUR is a single
	hand-written file on the server and is deliberately not generalised: no base
	enemy class, no shared AI state machine, no enemy framework.

	That is a decision, not an oversight. Building the framework first feels
	like good engineering and is exactly wrong here. A shared state machine
	forces every enemy toward the same rhythm, and combat averaged toward a
	common shape is how a game ends up with damage sponges without anyone ever
	deciding to make them.

	When a second enemy exists and the two can be compared, whatever genuinely
	repeats between them gets extracted -- and not one line before.

	All frame counts are at a fixed 60Hz.
]]

local Types = require(script.Parent.Parent.Types)

local WOLF_ATTACKS: { [string]: Types.EnemyAttackData } = {
	--[[
		The close-range answer. A 12-frame tell is the project's floor for
		readability: 200ms is enough to react to once the animation is known,
		and the wolf's whole job is teaching the player that tells are real.
	]]
	SnapBite = {
		Id = "SnapBite",
		DisplayName = "Snap Bite",
		TellFrames = 12,
		Active = 4,
		Recovery = 16,
		Damage = 10,
	},

	--[[
		The committed attack, and the one worth learning to dodge.

		A 26-frame crouch is a long, unmistakable telegraph -- nearly half a
		second of the wolf visibly gathering itself. 34 frames of recovery on
		a whiff is the punish window that makes dodging it worth doing: read
		the crouch, step through it, and get a free chain.

		Missing it costs 18, nearly a fifth of the player's health.
	]]
	LungeBite = {
		Id = "LungeBite",
		DisplayName = "Lunge Bite",
		TellFrames = 26,
		Active = 5,
		Recovery = 34,
		Damage = 18,
		TravelDistance = 12,
	},
}

local WOLF = {
	Id = "Wolf",
	DisplayName = "Wolf",

	-- Vitals ----------------------------------------------------------------
	Health = 60,
	--[[
		40 poise against a light chain dealing 8 + 8 + 10 + 22 = 48. Finishing
		the chain staggers; stopping short does not. The chain finisher is the
		reward for committing.
	]]
	Poise = 40,
	-- No armour, so damage numbers read literally during a playtest.
	Mitigation = 0,

	--[[
		The weak point hook exists and is empty. The wolf has none.

		Present so the system is exercised end to end by later enemies --
		Gravemaw's mouth interior, the Frostbound Colossus seals -- without a
		later retrofit.
	]]
	WeakPoints = {} :: { Types.WeakPointSpec },

	-- Movement --------------------------------------------------------------
	-- Faster than the player's walk (14) and slower than their sprint (22):
	-- the wolf can close on a walking player but cannot run one down.
	MoveSpeed = 20,
	AggroRange = 35,

	Attacks = WOLF_ATTACKS,

	-- Behaviour -------------------------------------------------------------
	AI = {
		--[[
			THE ANTI-CHEAP-SHOT RULE. Applies to every enemy in this project.

			On entering attack range the wolf cannot attack for 20 frames. That
			third of a second is the difference between "I was outplayed" and
			"that was unfair" -- an enemy that attacks the instant it arrives
			gives the player nothing to react to.

			The timer starts on entering range and resets on re-entry.
		]]
		AntiCheapShotFrames = 20,

		-- Lunge covers the mid-range gap; snap answers at close quarters. The
		-- 6-8 stud band between them is deliberately empty: inside it the wolf
		-- has to reposition, which reads as hesitation and gives the player a
		-- beat to act.
		LungeRangeMin = 8,
		LungeRangeMax = 16,
		SnapRangeMax = 6,

		-- Circling: disengage, orbit, re-commit. This cadence is the main dial
		-- controlling fight difficulty, because it decides how often the wolf
		-- gets to attack at all.
		CircleRadius = 8,
		CircleMinFrames = 40,
		CircleMaxFrames = 80,

		--[[
			The wolf never attacks from behind without a visible reposition
			first. Being hit by something that was never shown to you is the
			purest form of "the game cheated".
		]]
		RequireVisibleReposition = true,
		RepositionFrames = 24,

		-- Flees at 15% health toward the nearest other wolf. With a lone wolf
		-- there is nowhere to run to, so it flees from the player instead.
		FleeHealthFraction = 0.15,
		FleeSpeedMultiplier = 1.15,
	},

	-- Rewards ---------------------------------------------------------------
	Rewards = {
		XP = 25,
		Gold = { Min = 5, Max = 12 },
		--[[
			One guaranteed drop, and it is equippable on purpose.

			"Equip the loot and observe the stat change" is a success condition
			of this slice, and it cannot be observed if the reward is a
			sidegrade or a crafting material. The Wolffang Longsword's base 12
			against the starting weapon's 10 makes every damage number visibly
			rise.
		]]
		Drops = {
			{ ItemId = "Longsword_Wolffang", Chance = 1.0, Min = 1, Max = 1 },
		},
	},
}

local ENEMIES = {
	Wolf = WOLF,
}

local EnemyConfig = {
	ENEMIES = ENEMIES,
}

-- Loud on a bad id, for the same reason as WeaponConfig.get.
function EnemyConfig.get(enemyId: string)
	local enemy = ENEMIES[enemyId]
	if not enemy then
		error(`EnemyConfig: no enemy with id "{enemyId}"`, 2)
	end
	return enemy
end

for _, attack in WOLF_ATTACKS do
	table.freeze(attack)
end
table.freeze(WOLF_ATTACKS)
table.freeze(WOLF.AI)
table.freeze(WOLF.Rewards.Gold)
for _, drop in WOLF.Rewards.Drops do
	table.freeze(drop)
end
table.freeze(WOLF.Rewards.Drops)
table.freeze(WOLF.Rewards)
table.freeze(WOLF.WeakPoints)
table.freeze(WOLF)
table.freeze(ENEMIES)
table.freeze(EnemyConfig)

return EnemyConfig
