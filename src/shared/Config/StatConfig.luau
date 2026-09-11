--!strict
--[[
	StatConfig — character stats, attributes and the damage formula

	THE DAMAGE FORMULA, in the order it is applied:

		Base       = WeaponBase x MoveMultiplier
		Scaled     = Base x AttributeScale x MasteryTier
		Critical   = Scaled x (CRIT_DAMAGE_MULTIPLIER if the hit crits)
		Mitigated  = Critical x (1 - ArmourMitigation)   <- skipped on weak points
		Final      = Mitigated x (1 - BlockAbsorption)

	Two decisions inside that are worth understanding:

	ARMOUR AND BLOCK ARE SEPARATE LAYERS.
	Armour mitigation caps at MITIGATION_CAP. Block is applied afterwards as its
	own multiplier and does NOT feed that cap. If block fed the same cap, a
	heavily-armoured player would gain almost nothing from raising their guard,
	and a defensive weapon like Sword & Shield would have no structural identity
	to build on. Block is paid for in stamina, so it earns its own layer.

	WEAK POINTS SKIP MITIGATION ENTIRELY.
	A weak point hit multiplies by 1.0 in place of the mitigation term rather
	than reducing mitigation. This is what stops heavily-armoured late-game
	enemies from making precision pointless. Deterministic, never a roll.
]]

local StatConfig = {
	-- Level 1 baseline ------------------------------------------------------
	BASE = {
		Health = 120,
		Stamina = 100,
		Vigor = 10,
		Strength = 10,
		Dexterity = 10,
	},

	-- Attribute scaling -----------------------------------------------------
	--[[
		AttributeScale = 1 + (RelevantStat - BASELINE) x PER_POINT

		At the baseline of 10 this is exactly 1.0, so a level 1 character deals
		precisely the damage printed in MoveConfig. That makes the frame data
		readable as real numbers during a playtest instead of needing mental
		arithmetic.

		Which attribute is "relevant" is declared per weapon, in
		WeaponConfig.ScalingStat.
	]]
	ATTRIBUTE_BASELINE = 10,
	ATTRIBUTE_SCALE_PER_POINT = 0.02,

	-- Critical hits ---------------------------------------------------------
	--[[
		A random roll, driven by Dexterity. Heavy attacks do NOT auto-crit:
		if they did, Strength builds would get Dexterity's payoff for free and
		the two build paths would collapse into one.

		Chance = (Dexterity - BASELINE) x CRIT_CHANCE_PER_DEXTERITY, capped.
		At Dexterity 10 the chance is zero, so crits are something a build opts
		into rather than ambient noise.

		The cap is reached at Dexterity 34.
	]]
	CRIT_CHANCE_PER_DEXTERITY = 0.015,
	CRIT_CHANCE_CAP = 0.35,
	CRIT_DAMAGE_MULTIPLIER = 1.5,

	-- Mitigation ------------------------------------------------------------
	--[[
		Ceiling on armour-derived damage reduction, so stacking defence can
		never approach immunity. Block is NOT subject to this -- see the header.
	]]
	MITIGATION_CAP = 0.60,

	-- Stamina ---------------------------------------------------------------
	STAMINA_REGEN_PER_SECOND = 18,
	--[[
		Regeneration is suspended for this many frames after ANY stamina spend.

		This delay is what stops attack-spam from being free: the cost of a
		combo is not only the stamina it uses but the regeneration it postpones.
	]]
	STAMINA_REGEN_DELAY_FRAMES = 30,

	-- Movement --------------------------------------------------------------
	WALK_SPEED = 14,
	SPRINT_SPEED = 22,

	-- Mastery ---------------------------------------------------------------
	--[[
		Mastery multiplies damage by tier. Only Novice exists in this slice --
		this is the hook the progression system will later drive, not a
		progression system in itself.

		Later tiers are deliberately absent rather than written as 1.0
		placeholders: a missing key fails loudly, whereas a placeholder silently
		ships wrong balance.
	]]
	MASTERY_TIER_MULTIPLIER = {
		Novice = 1.00,
	},

	-- Progression -----------------------------------------------------------
	-- Deliberately minimal. The real level 1-50 curve is not this slice's job.
	STARTING_LEVEL = 1,
	XP_FOR_LEVEL_2 = 100,
}

table.freeze(StatConfig.BASE)
table.freeze(StatConfig.MASTERY_TIER_MULTIPLIER)
table.freeze(StatConfig)

return StatConfig
