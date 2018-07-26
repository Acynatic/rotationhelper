local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

local Objects = addon.Core.Objects;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_demonhunter_vengeance";

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Greensprîng and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-guide",
		WoWVersion = 70305,
		ImportantNotes = "This rotation provides suggestions for doing damage, and offering some very basic defensive suggestions.\n\nThis rotation SHOULD NOT be used for group content as it offers no actual tanking suggestions, such as managing threat or dealing with mechanics.\n\nThis rotation is really only suitable for open world content.",
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raid Tanking"] = "1222330",
		["Mythic+ Tanking"] = "1222130",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		-- actions+=/demonic_infusion,if=cooldown.demon_spikes.charges=0&pain.deficit>60
		DemonicInfusion = function()
			return Spell.DemonSpikes.Charges() == 0
			   and Player.Pain.Deficit() > 60;
		end,

		-- actions+=/demon_spikes,if=charges=2|buff.demon_spikes.down&!dot.fiery_brand.ticking&buff.metamorphosis.down
		DemonSpikes = function()
			return Spell.DemonSpikes.Charges() == 2
				or Player.Buff(Buff.DemonSpikes).Down()
			   and not Target.Debuff(Debuff.FieryBrand).Up()
			   and Player.Buff(Buff.Metamorphosis).Down();
		end,

		-- No way to really do debuff.casting.up, so we will trigger this when a unit is casting
		-- and uninterruptible spell as these are usually magic damage abilities.
		-- actions+=/empower_wards,if=debuff.casting.up
		EmpowerWards = function()
			return Target.Casting()
			   and not Target.Casting.IsInterruptible();
		end,

		-- actions+=/felblade,if=pain<=70
		Felblade = function()
			return Player.Pain() <= 70;
		end,

		-- actions+=/fel_devastation,if=incoming_damage_5s>health.max*0.70
		FelDevastation = function()
			return Player.DamagePredicted(5) >= 70;
		end,

		-- actions+=/fiery_brand,if=buff.demon_spikes.down&buff.metamorphosis.down
		FieryBrand = function()
			return Player.Buff(Buff.DemonSpikes).Down()
			   and Player.Buff(Buff.Metamorphosis).Down();
		end,

		-- actions+=/fracture,if=pain>=80&soul_fragments<4&incoming_damage_4s<=health.max*0.20
		Fracture = function()
			return Player.Pain() >= 80
			   and Player.Buff(Buff.SoulFragments).Stack() < 4
			   and Player.DamagePredicted(4) <= 20;
		end,

		-- actions+=/immolation_aura,if=pain<=80
		ImmolationAura = function()
			return Player.Pain() <= 80;
		end,


		InfernalStrike = {
			-- Don't do the In flight/travel time stuff as there is no way to calculate this as it targets the ground not a unit.
			-- actions+=/infernal_strike,if=!sigil_placed&!in_flight&remains-travel_time-delay<0.3*duration&(!artifact.fiery_demise.enabled|(max_charges-charges_fractional)*recharge_time<cooldown.fiery_brand.remains+5)&(cooldown.sigil_of_flame.remains>7|charges=2)
			Use = function()
				return Spell.SigilOfFlame.TimeSinceLastUsed() > 10
				   and (not Artifact.FieryDemise.Trait.Enabled() or Spell.InfernalStrike.Charges.FullRechargeTime() < Spell.FieryBrand.Cooldown.Remains() + 5)
				   and (Spell.SigilOfFlame.Cooldown.Remains() > 7 or Spell.InfernalStrike.Charges() == 2);
			end,

			-- Don't do the In flight/travel time stuff as there is no way to calculate this as it targets the ground not a unit.
			-- actions+=/infernal_strike,if=!sigil_placed&!in_flight&remains-travel_time-delay<0.3*duration&artifact.fiery_demise.enabled&dot.fiery_brand.ticking
			FieryDemise = function()
				return Spell.SigilOfFlame.TimeSinceLastUsed() > 10
				   and Artifact.FieryDemise.Trait.Enabled()
				   and Target.Debuff(Debuff.FieryBrand).Up();
			end,
		},

		-- actions+=/metamorphosis,if=buff.demon_spikes.down&!dot.fiery_brand.ticking&buff.metamorphosis.down&incoming_damage_5s>health.max*0.70
		Metamorphosis = function()
			return Player.Buff(Buff.DemonSpikes).Down()
			   and not Target.Debuff(Debuff.FieryBrand).Up()
			   and Player.Buff(Buff.Metamorphosis).Down()
			   and Player.DamagePredicted(5) >= 70;
		end,

		-- actions+=/sigil_of_flame,if=remains-delay<=0.3*duration
		SigilOfFlame = function()
			return Target.Debuff(Debuff.SigilOfFlame).Refreshable();
		end,

		SigilOfSilence = function()
			return Target.InRange(8);
		end,

		-- actions+=/soul_carver,if=dot.fiery_brand.ticking
		SoulCarver = function()
			return Target.Debuff(Debuff.FieryBrand).Up();
		end,

		SoulCleave = {
			-- actions+=/soul_cleave,if=pain>=80
			Use = function()
				return Player.Pain() >= 80;
			end,

			-- actions+=/soul_cleave,if=incoming_damage_5s>=health.max*0.70
			Damage = function()
				return Player.DamagePredicted(5) >= 70;
			end,

			-- actions+=/soul_cleave,if=soul_fragments=5
			SoulFragments = function()
				return Player.Buff(Buff.SoulFragments).Stack() == 5;
			end,
		},

		-- actions+=/spirit_bomb,if=soul_fragments=5|debuff.frailty.down
		SpiritBomb = function()
			return Player.Buff(Buff.SoulFragments).Stack() == 5
			   and Player.Buff(Debuff.Frailty).Down();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		-- Spells
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(202719),
			Shadowmeld = Objects.newSpell(58984),
		};

		Artifact = {
			-- Abilities
			SoulCarver = Objects.newSpell(207407),
			-- Traits
			FieryDemise = Objects.newSpell(212817),
		};

		Spell = {
			-- Abilities
			ChaosBlades = Objects.newSpell(211796),
			ImmolationAura = Objects.newSpell(178740),
			InfernalStrike = Objects.newSpell(189110),
			Metamorphosis = Objects.newSpell(187827),
			Sever = Objects.newSpell(235964),
			Shear = Objects.newSpell(203782),
			SigilOfFlame = Objects.newSpell(204596),
			SoulCleave = Objects.newSpell(228477),
			ThrowGlaive = Objects.newSpell(204157),
			-- Crowd Control
			ConsumeMagic = Objects.newSpell(183752),
			Imprison = Objects.newSpell(217832),
			SigilOfMisery = Objects.newSpell(207684),
			SigilOfSilence = Objects.newSpell(202137),
			-- Defensive
			CharredWarblades = Objects.newSpell(213011),
			DemonSpikes = Objects.newSpell(203720),
			EmpowerWards = Objects.newSpell(218256),
			FieryBrand = Objects.newSpell(204021),
			-- Utility
			Glide = Objects.newSpell(131347),
			SpectralSight = Objects.newSpell(188501),
			Torment = Objects.newSpell(185245),
		};

		Talent = {
			-- Active Talents
			DemonicInfusion = Objects.newSpell(236189),
			Felblade = Objects.newSpell(232893),
			FelDevastation = Objects.newSpell(212084),
			FelEruption = Objects.newSpell(211881),
			Fracture = Objects.newSpell(209795),
			SigilOfChains = Objects.newSpell(202138),
			SoulBarrier = Objects.newSpell(227225),
			SpiritBomb = Objects.newSpell(247454),
			-- Passive Talents
			AbyssalStrike = Objects.newSpell(207550),
			AgonizingFlames = Objects.newSpell(207548),
			BladeTurning = Objects.newSpell(247254),
			BurningAlive = Objects.newSpell(207739),
			ConcentratedSigils = Objects.newSpell(207666),
			Fallout = Objects.newSpell(227174),
			FeastOfSouls = Objects.newSpell(207697),
			FeedTheDemon = Objects.newSpell(218612),
			FlameCrash = Objects.newSpell(227322),
			LastResort = Objects.newSpell(209258),
			QuickenedSigils = Objects.newSpell(209281),
			RazorSpikes = Objects.newSpell(209400),
			SoulRending = Objects.newSpell(217996),
		};

		Buff = {
			-- Buffs
			DemonSpikes = Objects.newSpell(203819),
			FeastOfSouls = Objects.newSpell(207693),
			Gluttony = Objects.newSpell(227330),
			IllidansGrasp = Objects.newSpell(208618),
			Metamorphosis = Spell.Metamorphosis,
			Nemesis = Objects.newSpell(208579),
			NetherBond = Objects.newSpell(207811),
			Painbringer = Objects.newSpell(212988),
			RainOfChaos = Objects.newSpell(232538),
			SiphonedPower = Objects.newSpell(218561),
			SoulFragments = Objects.newSpell(203981),
		};

		Debuff = {
			-- Debuffs
			DemonicTrample = Objects.newSpell(213491),
			FieryBrand = Objects.newSpell(207771),
			FieryDemise = Objects.newSpell(212818),
			Frailty = Objects.newSpell(247456),
			Imprison = Objects.newSpell(221527),
			Intimidated = Objects.newSpell(206891),
			RazorSpikes = Objects.newSpell(210003),
			SigilOfChains = Objects.newSpell(204843),
			SigilOfFlame = Objects.newSpell(204598),
			SigilOfMisery = Objects.newSpell(207685),
			SigilOfSilence = Objects.newSpell(204490),
		};

		Legendary = {};

		Item = {};

		Consumable = {
			-- Potions
			UnbendingPotion = Objects.newItem(127845),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Shadowmeld);
		config.AOEOptions(options, Talent.FelDevastation, Spell.ImmolationAura, Spell.InfernalStrike, Spell.SigilOfFlame, Spell.SoulCleave, Talent.SpiritBomb, Spell.ThrowGlaive);
		config.CooldownOptions(options, Talent.FelEruption, Talent.Felblade, Talent.Fracture, Spell.Metamorphosis, Artifact.SoulCarver);
		config.DefensiveOptions(options, Talent.DemonicInfusion, Spell.CharredWarblades, Spell.DemonSpikes, Spell.EmpowerWards, Spell.FieryBrand, Talent.SoulBarrier);
		config.UtilityOptions(options, Spell.Imprison, Talent.SigilOfChains, Spell.SigilOfMisery, Spell.SpectralSight, Spell.Torment);
	end

	-- Function for destroying action objects such as spells, buffs, debuffs and items, called when the rotation is no longer the active rotation.
	function self.Disable()
		Racial = nil;
		Artifact = nil;
		Spell = nil;
		Talent = nil;
		Buff = nil;
		Debuff = nil;
		Legendary = nil;
		Item = nil;
		Consumable = nil;
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
		-- The abilities here should be listed from highest damage required to suggest to lowest,
		-- Specific damage types before all damage types.

		-- This is a tanking spec rotation so Defensive actions are listed in the main rotations.
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.ConsumeMagic, true);
		action.EvaluateInterruptAction(Spell.SigilOfSilence, self.Requirements.SigilOfSilence);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Talent.FelEruption, true);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.UnbendingPotion, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Talent.DemonicInfusion, self.Requirements.DemonicInfusion);
		action.EvaluateAction(Spell.FieryBrand, self.Requirements.FieryBrand);
		action.EvaluateAction(Spell.DemonSpikes, self.Requirements.DemonSpikes);
		action.EvaluateAction(Spell.EmpowerWards, self.Requirements.EmpowerWards);
		action.EvaluateAction(Spell.InfernalStrike, self.Requirements.InfernalStrike.FieryDemise);
		action.EvaluateAction(Spell.InfernalStrike, self.Requirements.InfernalStrike.Use);
		action.EvaluateAction(Talent.SpiritBomb, self.Requirements.SpiritBomb);
		action.EvaluateAction(Artifact.SoulCarver, self.Requirements.SoulCarver);
		action.EvaluateAction(Spell.ImmolationAura, self.Requirements.ImmolationAura);
		action.EvaluateAction(Talent.Felblade, self.Requirements.Felblade);
		-- actions+=/soul_barrier
		action.EvaluateAction(Talent.SoulBarrier, true);
		action.EvaluateAction(Spell.SoulCleave, self.Requirements.SoulCleave.SoulFragments);
		action.EvaluateAction(Spell.Metamorphosis, self.Requirements.Metamorphosis);
		action.EvaluateAction(Talent.FelDevastation, self.Requirements.FelDevastation);
		action.EvaluateAction(Spell.SoulCleave, self.Requirements.SoulCleave.Damage);
		-- actions+=/fel_eruption
		action.EvaluateAction(Talent.FelEruption, true);
		action.EvaluateAction(Spell.SigilOfFlame, self.Requirements.SigilOfFlame);
		action.EvaluateAction(Talent.Fracture, self.Requirements.Fracture);
		action.EvaluateAction(Spell.SoulCleave, self.Requirements.SoulCleave.Use);
		-- actions+=/sever
		action.EvaluateAction(Spell.Sever, true);
		-- actions+=/shear
		action.EvaluateAction(Spell.Shear, true);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Vengeance Demon Hunter", addonTable.Enum.SpecID.DEMONHUNTER_VENGEANCE);