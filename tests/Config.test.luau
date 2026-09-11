--!strict
--[[
	Config tests

	Verifies the data in Shared/Config against the numbers in the design spec.

	A mistyped config value is the most dangerous kind of bug in a data-driven
	game: nothing crashes, nothing errors, the game simply plays wrong and
	everyone spends a week arguing about feel. These checks turn that into a
	failing test.

	Run via tests/run.sh.
]]

local CombatConfig = require("../src/shared/Config/CombatConfig")
local StatConfig = require("../src/shared/Config/StatConfig")
local WeaponConfig = require("../src/shared/Config/WeaponConfig")
local MoveConfig = require("../src/shared/Config/MoveConfig")
local EnemyConfig = require("../src/shared/Config/EnemyConfig")

local failures = 0
local checks = 0

local function check(name: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print(`  PASS  {name}`)
	else
		failures += 1
		print(`  FAIL  {name}{if detail then "  --  " .. detail else ""}`)
	end
end

local function equal(name: string, actual: any, expected: any)
	check(name, actual == expected, `got {tostring(actual)}, expected {tostring(expected)}`)
end

print("\n=== Config ===\n")

-- 1. Longsword damage at level 1 must match the design table exactly.
--
-- A level 1 character has attribute scale 1.0 and Novice mastery 1.0, so
-- damage is simply WeaponBase x DamageMultiplier. These are the numbers that
-- will appear on screen during a playtest.
do
	local base = WeaponConfig.get("Longsword_Common").WeaponBase
	equal("Common Longsword WeaponBase is 10", base, 10)

	local expectedDamage = {
		LS_M1_1 = 12,
		LS_M1_2 = 12,
		LS_M1_3 = 14,
		LS_M1_4 = 20,
		LS_CRESCENT_BREAK = 28,
	}

	for moveId, expected in expectedDamage do
		local move = MoveConfig.get(moveId)
		local damage = base * (move.DamageMultiplier :: number)
		check(
			`{moveId} deals {expected} at level 1`,
			math.abs(damage - expected) < 0.0001,
			`got {damage}`
		)
	end
end

-- 2. Frame data, straight from the design table.
do
	local expectedFrames = {
		-- moveId            startup active recovery poise stamina
		{ "LS_M1_1", 9, 4, 14, 8, 8 },
		{ "LS_M1_2", 8, 4, 14, 8, 8 },
		{ "LS_M1_3", 10, 5, 16, 10, 8 },
		{ "LS_M1_4", 14, 6, 26, 22, 14 },
		{ "LS_CRESCENT_BREAK", 22, 7, 32, 34, 20 },
	}

	for _, row in expectedFrames do
		local moveId = row[1] :: string
		local move = MoveConfig.get(moveId)
		local ok = move.Startup == row[2]
			and move.Active == row[3]
			and move.Recovery == row[4]
			and move.PoiseDamage == row[5]
			and move.StaminaCost == row[6]
		check(
			`{moveId} frame data matches the design table`,
			ok,
			`{move.Startup}/{move.Active}/{move.Recovery} poise {move.PoiseDamage} stam {move.StaminaCost}`
		)
	end
end

-- 3. Hitstop: light attacks 4 frames, heavy attacks 7.
do
	for _, moveId in { "LS_M1_1", "LS_M1_2", "LS_M1_3" } do
		equal(`{moveId} has 4-frame hitstop (light)`, MoveConfig.get(moveId).HitstopFrames, 4)
	end
	for _, moveId in { "LS_M1_4", "LS_CRESCENT_BREAK" } do
		equal(`{moveId} has 7-frame hitstop (heavy)`, MoveConfig.get(moveId).HitstopFrames, 7)
	end

	-- The tier floors must line up with the per-move values, or a critical on
	-- a light attack would feel lighter than a plain heavy.
	equal("Normal tier hitstop matches light attacks", CombatConfig.HITSTOP_FRAMES.Normal, 4)
	equal("Critical tier hitstop matches heavy attacks", CombatConfig.HITSTOP_FRAMES.Critical, 7)
	check(
		"stagger hitstop exceeds critical",
		CombatConfig.HITSTOP_FRAMES.Stagger > CombatConfig.HITSTOP_FRAMES.Critical
	)
	check(
		"finisher hitstop exceeds stagger",
		CombatConfig.HITSTOP_FRAMES.Finisher > CombatConfig.HITSTOP_FRAMES.Stagger
	)
end

-- 4. Dodge: 20 frames, invulnerable on 3 through 11.
do
	local dodge = MoveConfig.get("LS_DODGE")
	equal("dodge lasts 20 frames", dodge.TotalFrames, 20)
	equal("i-frames begin on frame 3", dodge.InvulnerableFromFrame, 3)
	equal("i-frames end on frame 11", dodge.InvulnerableToFrame, 11)
	equal("dodge costs 20 stamina", dodge.StaminaCost, 20)

	local iframes = (dodge.InvulnerableToFrame :: number) - (dodge.InvulnerableFromFrame :: number) + 1
	equal("that is a 9-frame invulnerability window", iframes, 9)

	-- Vulnerable frames on both sides are what stop dodge from being a panic
	-- button and what make dodge spam punishable.
	check("dodge has vulnerable startup", (dodge.InvulnerableFromFrame :: number) > 1)
	check(
		"dodge has vulnerable recovery",
		(dodge.TotalFrames :: number) > (dodge.InvulnerableToFrame :: number)
	)
end

-- 5. THE KEY BALANCE RELATIONSHIP.
--
-- A full light chain must stagger the wolf, and stopping short must not. This
-- is what makes committing to the whole chain the correct play, and it is the
-- single most important number relationship in the slice.
do
	local moveset = MoveConfig.getMoveset("Longsword_Novice")
	local wolf = EnemyConfig.get("Wolf")

	local runningPoise = 0
	local poiseAfter: { number } = {}
	for _, moveId in moveset.LightChain do
		runningPoise += MoveConfig.get(moveId).PoiseDamage :: number
		table.insert(poiseAfter, runningPoise)
	end

	equal("full light chain deals 48 poise", runningPoise, 48)
	equal("wolf poise threshold is 40", wolf.Poise, 40)

	check(
		"the full chain staggers the wolf",
		poiseAfter[4] >= wolf.Poise,
		`{poiseAfter[4]} vs {wolf.Poise}`
	)
	check(
		"three hits do NOT stagger the wolf",
		poiseAfter[3] < wolf.Poise,
		`{poiseAfter[3]} vs {wolf.Poise}`
	)

	--[[
		Crescent Break does NOT stagger a full-poise wolf on its own: 34 against
		a threshold of 40.

		This is asserted deliberately rather than treated as a bug, because it
		is a real and slightly counter-intuitive property of the design numbers.
		The heaviest, most committed attack in the weapon sets a stagger up
		instead of delivering it -- any follow-up hit then breaks the wolf.

		If a future retune makes Crescent stagger outright, this test fails and
		forces the change to be deliberate rather than accidental.
	]]
	local crescentPoise = MoveConfig.get("LS_CRESCENT_BREAK").PoiseDamage :: number
	check(
		"Crescent Break alone does not stagger a full-poise wolf",
		crescentPoise < wolf.Poise,
		`{crescentPoise} vs {wolf.Poise}`
	)
	check(
		"but it leaves the wolf one hit from staggering",
		crescentPoise + 8 >= wolf.Poise,
		`{crescentPoise} + a light hit vs {wolf.Poise}`
	)
	check(
		"Crescent Break carries the most poise damage of any single move",
		crescentPoise > (MoveConfig.get("LS_M1_4").PoiseDamage :: number)
	)
end

-- 6. Chain damage against wolf health.
do
	local wolf = EnemyConfig.get("Wolf")
	local base = WeaponConfig.get("Longsword_Common").WeaponBase
	local moveset = MoveConfig.getMoveset("Longsword_Novice")

	local chainDamage = 0
	local chainStamina = 0
	for _, moveId in moveset.LightChain do
		local move = MoveConfig.get(moveId)
		chainDamage += base * (move.DamageMultiplier :: number)
		chainStamina += move.StaminaCost
	end

	equal("full chain deals 58 damage", chainDamage, 58)
	equal("full chain costs 38 stamina", chainStamina, 38)

	-- Deliberately just short of a kill: the wolf survives one perfect chain
	-- and the player must commit to a second exchange.
	check(
		"one full chain does NOT kill the wolf",
		chainDamage < wolf.Health,
		`{chainDamage} vs {wolf.Health} HP`
	)
	check(
		"the player can afford a full chain from full stamina",
		chainStamina < StatConfig.BASE.Stamina,
		`{chainStamina} of {StatConfig.BASE.Stamina}`
	)
end

-- 7. The wolf's own numbers.
do
	local wolf = EnemyConfig.get("Wolf")
	equal("wolf has 60 health", wolf.Health, 60)
	equal("wolf moves at 20 studs/s", wolf.MoveSpeed, 20)
	equal("wolf aggros at 35 studs", wolf.AggroRange, 35)
	equal("anti-cheap-shot delay is 20 frames", wolf.AI.AntiCheapShotFrames, 20)
	equal("wolf flees at 15% health", wolf.AI.FleeHealthFraction, 0.15)

	equal("snap bite tell is 12 frames", wolf.Attacks.SnapBite.TellFrames, 12)
	equal("snap bite deals 10", wolf.Attacks.SnapBite.Damage, 10)
	equal("lunge tell is 26 frames", wolf.Attacks.LungeBite.TellFrames, 26)
	equal("lunge deals 18", wolf.Attacks.LungeBite.Damage, 18)
	equal("lunge recovery is 34 frames", wolf.Attacks.LungeBite.Recovery, 34)

	-- Every tell must clear the 12-frame readability floor, or the attack is
	-- not something a player can react to.
	for attackId, attack in wolf.Attacks do
		check(`{attackId} tell is at least 12 frames`, attack.TellFrames >= 12, `{attack.TellFrames}`)
	end

	-- The wolf must be able to close on a walking player but never run down a
	-- sprinting one, or disengaging would be impossible.
	check("wolf outruns a walking player", wolf.MoveSpeed > StatConfig.WALK_SPEED)
	check("a sprinting player outruns the wolf", StatConfig.SPRINT_SPEED > wolf.MoveSpeed)

	-- The weak point hook exists and the wolf has none.
	equal("wolf has no weak points in this slice", #wolf.WeakPoints, 0)
end

-- 8. Survivability: how many hits the player can take.
do
	local wolf = EnemyConfig.get("Wolf")
	local health = StatConfig.BASE.Health
	local lungesToKill = math.ceil(health / wolf.Attacks.LungeBite.Damage)
	local snapsToKill = math.ceil(health / wolf.Attacks.SnapBite.Damage)

	equal("player has 120 health", health, 120)
	equal("7 lunges kill the player", lungesToKill, 7)
	equal("12 snaps kill the player", snapsToKill, 12)

	-- A single mistake must never be lethal, and the fight must not be endless.
	check("no single wolf attack removes more than a quarter of health",
		wolf.Attacks.LungeBite.Damage < health / 4)
end

-- 9. The damage formula's constants.
do
	equal("attribute baseline is 10", StatConfig.ATTRIBUTE_BASELINE, 10)
	equal("attribute scaling is 2% per point", StatConfig.ATTRIBUTE_SCALE_PER_POINT, 0.02)
	equal("Novice mastery multiplier is exactly 1.0", StatConfig.MASTERY_TIER_MULTIPLIER.Novice, 1.00)
	equal("armour mitigation caps at 60%", StatConfig.MITIGATION_CAP, 0.60)

	-- A level 1 character must scale to exactly 1.0, so the design table's
	-- damage numbers are literally what appears on screen.
	local scale = 1 + (StatConfig.BASE.Strength - StatConfig.ATTRIBUTE_BASELINE)
		* StatConfig.ATTRIBUTE_SCALE_PER_POINT
	equal("level 1 attribute scale is exactly 1.0", scale, 1.0)

	-- Crit: driven by Dexterity, zero at baseline, capped at 35%.
	local function critChance(dexterity: number): number
		local raw = (dexterity - StatConfig.ATTRIBUTE_BASELINE) * StatConfig.CRIT_CHANCE_PER_DEXTERITY
		return math.clamp(raw, 0, StatConfig.CRIT_CHANCE_CAP)
	end

	equal("crit chance at Dexterity 10 is zero", critChance(10), 0)
	equal("crit chance at Dexterity 20 is 15%", critChance(20), 0.15)
	equal("crit chance is capped at 35%", critChance(100), 0.35)
	equal("crit multiplier is 1.5x", StatConfig.CRIT_DAMAGE_MULTIPLIER, 1.5)

	-- Find where the cap actually bites, so a later rebalance cannot move it
	-- without someone noticing.
	local capAt = 0
	for dexterity = 10, 200 do
		if critChance(dexterity) >= StatConfig.CRIT_CHANCE_CAP then
			capAt = dexterity
			break
		end
	end
	equal("crit cap is reached at Dexterity 34", capAt, 34)
end

-- 10. Block and mitigation are separate layers.
--
-- The whole point of the decision: armour must still be worth something while
-- blocking. If block fed the mitigation cap, these two would be equal.
do
	equal("block absorbs 60%", CombatConfig.BLOCK_ABSORPTION, 0.60)
	equal("guard break leaves the player helpless for 45 frames",
		CombatConfig.GUARD_BREAK_HELPLESS_FRAMES, 45)
	equal("block takes 4 frames to raise", CombatConfig.BLOCK_RAISE_FRAMES, 4)

	local incoming = 100
	local cappedArmour = StatConfig.MITIGATION_CAP

	local blockOnly = incoming * (1 - CombatConfig.BLOCK_ABSORPTION)
	local armourThenBlock = incoming * (1 - cappedArmour) * (1 - CombatConfig.BLOCK_ABSORPTION)

	equal("block alone reduces 100 damage to 40", blockOnly, 40)
	equal("capped armour then block reduces 100 damage to 16", armourThenBlock, 16)
	check(
		"armour still matters while blocking (the layers are separate)",
		armourThenBlock < blockOnly,
		`{armourThenBlock} vs {blockOnly}`
	)

	-- Stamina cost of blocking a lunge, on the "absorbed" basis.
	local wolf = EnemyConfig.get("Wolf")
	local lunge = wolf.Attacks.LungeBite.Damage
	local absorbed = lunge * CombatConfig.BLOCK_ABSORPTION
	local staminaCost = absorbed * CombatConfig.BLOCK_STAMINA_PER_DAMAGE_BLOCKED
	check(
		`blocking a lunge costs {string.format("%.2f", staminaCost)} stamina`,
		staminaCost > 0 and staminaCost < StatConfig.BASE.Stamina
	)
	equal("block stamina basis is the absorbed portion", CombatConfig.BLOCK_STAMINA_BASIS, "Absorbed")
end

-- 11. Timing constants convert correctly between seconds and frames.
do
	local rate = CombatConfig.TICK_RATE
	equal("tick rate is 60", rate, 60)
	equal("seconds per frame is 1/60", CombatConfig.SECONDS_PER_FRAME, 1 / 60)
	equal("spawn protection is 8 seconds", CombatConfig.SPAWN_PROTECTION_FRAMES / rate, 8)
	equal("poise regen delay is 1.5 seconds", CombatConfig.POISE_REGEN_DELAY_FRAMES / rate, 1.5)
	equal("stamina regen delay is 0.5 seconds", StatConfig.STAMINA_REGEN_DELAY_FRAMES / rate, 0.5)
	equal("rewind cap is 100ms", CombatConfig.REWIND_MAX_MS, 100)
	equal("rewind cap is 6 frames", CombatConfig.REWIND_MAX_FRAMES, 6)
	check(
		"the rewind cap in frames matches the cap in milliseconds",
		math.abs(CombatConfig.REWIND_MAX_FRAMES / rate * 1000 - CombatConfig.REWIND_MAX_MS) < 1.7,
		`{CombatConfig.REWIND_MAX_FRAMES} frames vs {CombatConfig.REWIND_MAX_MS}ms`
	)

	-- The rewind window must be shorter than the i-frame window, or a client
	-- could claim a dodge that covers more than it actually did.
	local dodge = MoveConfig.get("LS_DODGE")
	local iframes = (dodge.InvulnerableToFrame :: number) - (dodge.InvulnerableFromFrame :: number) + 1
	check(
		"rewind window is shorter than the i-frame window",
		CombatConfig.REWIND_MAX_FRAMES < iframes,
		`{CombatConfig.REWIND_MAX_FRAMES} vs {iframes}`
	)
end

-- 12. The loot reward must be a visible upgrade, or "observe the stat change"
-- cannot be observed.
do
	local starting = WeaponConfig.get(WeaponConfig.STARTING_WEAPON)
	local wolf = EnemyConfig.get("Wolf")
	local dropId = wolf.Rewards.Drops[1].ItemId
	local drop = WeaponConfig.get(dropId)

	equal("the wolf's drop is the Wolffang Longsword", dropId, "Longsword_Wolffang")
	equal("the drop is guaranteed", wolf.Rewards.Drops[1].Chance, 1.0)
	check(
		"the drop is a straight upgrade on the starting weapon",
		drop.WeaponBase > starting.WeaponBase,
		`{drop.WeaponBase} vs {starting.WeaponBase}`
	)

	-- Percentage terms: the change has to be big enough to see without a
	-- spreadsheet.
	local increase = (drop.WeaponBase - starting.WeaponBase) / starting.WeaponBase
	check(
		`equipping it raises damage by {math.floor(increase * 100)}%`,
		increase >= 0.10,
		`{increase}`
	)

	-- Both weapons share a moveset, so the change is pure numbers -- exactly
	-- what makes the difference legible in a playtest.
	equal("both longswords share the Novice moveset", drop.Moveset, starting.Moveset)
end

-- 13. The mastery table covers all eight weapon types.
do
	local count = 0
	for _ in WeaponConfig.WEAPON_TYPES do
		count += 1
	end
	equal("there are eight weapon types", count, 8)

	-- Every weapon's type must be one of them, or its mastery would have
	-- nowhere to be recorded.
	for weaponId, weapon in WeaponConfig.WEAPONS do
		check(
			`{weaponId} has a known weapon type`,
			WeaponConfig.WEAPON_TYPES[weapon.WeaponType] ~= nil,
			weapon.WeaponType
		)
	end
end

print(`\n{checks - failures}/{checks} checks passed\n`)
if failures > 0 then
	error(`{failures} config check(s) failed`, 0)
end
