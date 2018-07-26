local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Core = addon.Core.General;
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Objects
local Pet = addon.Units.Pet;
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_mage_frost";

-- AOE Rotation
local function AOE(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.aoe+=/flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt)
		Flurry = function()
			return Player.PrevGCD(1, Artifact.Ebonbolt)
				or Player.Buff(Buff.BrainFreeze).React()
			   and (Player.PrevGCD(1, Talent.GlacialSpike) or Player.PrevGCD(1, Spell.Frostbolt));
		end,

		-- actions.aoe=frostbolt,if=prev_off_gcd.water_jet
		Frostbolt = function()
			return Pet.PrevOffGCD(1, Spell.WaterJet);
		end,

		-- actions.aoe+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&buff.fingers_of_frost.react
		FrostBomb = function()
			return Target.Debuff(Debuff.FrostBomb).Remains() < Spell.IceLance.TravelTime()
			   and Player.Buff(Buff.FingersOfFrost).React();
		end,

		-- actions.aoe+=/ice_lance,if=buff.fingers_of_frost.react
		IceLance = function()
			return Player.Buff(Buff.FingersOfFrost).React();
		end,

		-- actions.aoe+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<3&!buff.brain_freeze.react
		WaterJet = function()
			return Player.PrevGCD(1, Spell.Frostbolt)
			   and Player.Buff(Buff.FingersOfFrost).Stack() < 3
			   and not Player.Buff(Buff.BrainFreeze).React();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Frostbolt, self.Requirements.Frostbolt);
		-- # Make sure Frozen Orb is used before Blizzard if both are available. This is a small gain with Freezing Rain and on par without.
		-- actions.aoe+=/frozen_orb
		action.EvaluateAction(Spell.FrozenOrb, true);
		-- actions.aoe+=/blizzard
		action.EvaluateAction(Spell.Blizzard, true);
		-- actions.aoe+=/comet_storm
		action.EvaluateAction(Talent.CometStorm, true);
		-- actions.aoe+=/ice_nova
		action.EvaluateAction(Talent.IceNova, true);
		action.EvaluateAction(Spell.WaterJet, self.Requirements.WaterJet);
		action.EvaluateAction(Spell.Flurry, self.Requirements.Flurry);
		action.EvaluateAction(Talent.FrostBomb, self.Requirements.FrostBomb);
		action.EvaluateAction(Spell.IceLance, self.Requirements.IceLance);
		-- actions.aoe+=/ebonbolt
		action.EvaluateAction(Artifact.Ebonbolt, true);
		-- actions.aoe+=/glacial_spike
		action.EvaluateAction(Talent.GlacialSpike, true);
		-- actions.aoe+=/frostbolt
		action.EvaluateAction(Spell.Frostbolt, true);
		-- actions.aoe+=/cone_of_cold
		action.EvaluateAction(Spell.ConeOfCold, true);
		-- actions.aoe+=/ice_lance
		action.EvaluateAction(Spell.IceLance, true);
	end

	-- actions+=/call_action_list,name=aoe,if=active_enemies>=3
	function self.Use(numEnemies)
		return numEnemies >= 3;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local AOE = AOE("AOE");

-- Cooldowns Rotation
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.cooldowns+=/potion,if=cooldown.icy_veins.remains<1|target.time_to_die<70
		ProlongedPower = function()
			return Spell.IcyVeins.Cooldown.Remains() < 1
				or Target.TimeToDie() < 70;
		end,

		-- # Rune of Power is used when going into Icy Veins and while Icy Veins are up. Outside of Icy Veins, use Rune of Power when about to cap on charges or the target is about to die.
		-- actions.cooldowns=rune_of_power,if=cooldown.icy_veins.remains<cast_time|charges_fractional>1.9&cooldown.icy_veins.remains>10|buff.icy_veins.up|target.time_to_die+5<charges_fractional*10
		RuneOfPower = function()
			return Spell.IcyVeins.Cooldown.Remains() < Talent.RuneOfPower.CastTime()
				or Talent.RuneOfPower.Charges.Fractional() > 1.9
			   and Spell.IcyVeins.Cooldown.Remains() > 10
				or Player.Buff(Buff.IcyVeins).Up()
				or Target.TimeToDie() + 5 < Talent.RuneOfPower.Charges.Fractional() * 10;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.RuneOfPower, self.Requirements.RuneOfPower);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		-- actions.cooldowns+=/icy_veins
		action.EvaluateAction(Spell.IcyVeins, true);
		-- actions.cooldowns+=/mirror_image
		action.EvaluateAction(Talent.MirrorImage, true);
		-- actions.cooldowns+=/blood_fury
		action.EvaluateAction(Racial.BloodFury, true);
		-- actions.cooldowns+=/berserking
		action.EvaluateAction(Racial.Berserking, true);
		-- actions.cooldowns+=/arcane_torrent
		action.EvaluateAction(Racial.ArcaneTorrent, true);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Cooldowns = Cooldowns("Cooldowns");

-- Movement Rotation
local function Movement(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.movement+=/ice_floes,if=buff.ice_floes.down&!buff.fingers_of_frost.react
		IceFloes = function()
			return Player.Buff(Buff.IceFloes).Down()
			   and not Player.Buff(Buff.FingersOfFrost).React();
		end,
	};

	-- Add meta-table to the requirements table, to enable better debugging and case insensitivity.
	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- Can't do raid movement events, so we are just going to skip this
		-- actions.movement=blink,if=movement.distance>10
		action.EvaluateAction(Talent.IceFloes, self.Requirements.IceFloes);
	end

	-- actions+=/call_action_list,name=movement,moving=1
	function self.Use()
		return Player.IsMoving();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Movement = Movement("Movement");

-- Single Target Rotation
local function SingleTarget(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Blizzard = {
			-- # Against low number of targets, Blizzard is used as a filler. Zann'esu buffed Blizzard is used only at 5 stacks.
			-- actions.single+=/blizzard,if=active_enemies>1|buff.zannesu_journey.stack=5&buff.zannesu_journey.remains>cast_time
			Use = function (numEnemies)
				return numEnemies > 1
					or Player.Buff(Buff.ZannesuJourney).Stack() == 5
				   and Player.Buff(Buff.ZannesuJourney).Remains() > Spell.Blizzard.CastTime();
			end,

			-- # Freezing Rain Blizzard. While the normal Blizzard action is usually enough, right after Frozen Orb the actor will be getting a lot of FoFs, which might delay Blizzard to the point where we miss out on Freezing Rain. Therefore, if we are not at a risk of overcapping on FoF, use Blizzard before using Ice Lance.
			-- actions.single+=/blizzard,if=cast_time=0&active_enemies>1&buff.fingers_of_frost.react<3
			FreezingRain = function(numEnemies)
				return Spell.Blizzard.CastTime() == 0
				   and numEnemies > 1
				   and Player.Buff(Buff.FingersOfFrost).Remains() < 3;
			end,

			-- # While on the move, use instant Blizzard if available.
			-- actions.single+=/blizzard
			Moving = function()
				return Player.IsMoving()
				   and Spell.Blizzard.CastTime() == 0;
			end,
		},

		-- # Winter's Chill from Flurry can apply to the spell cast right before (provided the travel time is long enough). This can be exploited to a great effect with Ebonbolt, Glacial Spike (which deal a lot of damage by themselves) and Frostbolt (as a guaranteed way to proc Frozen Veins and Chain Reaction). When using Glacial Spike, it is worth saving a Brain Freeze proc when Glacial Spike is right around the corner (i.e. with 5 Icicles). However, when the actor also has T20 2pc, Glacial Spike is delayed to fit into Frozen Mass, so we do not want to sit on a Brain Freeze proc for too long in that case.
		-- actions.single+=/flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<=4|cooldown.frozen_orb.remains<=10&set_bonus.tier20_2pc))
		Flurry = function()
			return Player.PrevGCD(1, Artifact.Ebonbolt)
				or Player.Buff(Buff.BrainFreeze).React()
			   and (Player.PrevGCD(1, Talent.GlacialSpike) or Player.PrevGCD(1, Spell.Frostbolt) and (not Talent.GlacialSpike.Enabled() or Player.Buff(Buff.Icicles).Stack() <= 4 or Spell.FrozenOrb.Cooldown.Remains() <= 10 and addonTable.Tier20_2PC));
		end,

		-- # While Frozen Mass is active, we want to fish for Brain Freeze for the next Glacial Spike. Stop when Frozen Mass is about to run out and we wouldn't be able to cast Glacial Spike in time.
		-- actions.single+=/frostbolt,if=buff.frozen_mass.remains>execute_time+action.glacial_spike.execute_time+action.glacial_spike.travel_time&!buff.brain_freeze.react&talent.glacial_spike.enabled
		Frostbolt = {
			Use = function()
				return Player.Buff(Buff.FrozenMass).Remains() > Spell.Frostbolt.ExecuteTime() + Talent.GlacialSpike.ExecuteTime() + Talent.GlacialSpike.TravelTime()
				   and not Player.Buff(Buff.BrainFreeze).React()
				   and Talent.GlacialSpike.Enabled();
			end,

			-- actions.single+=/frostbolt,if=prev_off_gcd.water_jet
			WaterJet = function()
				return Pet.PrevOffGCD(1, Spell.WaterJet);
			end,
		},

		-- actions.single+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&buff.fingers_of_frost.react
		FrostBomb = function()
			return Target.Debuff(Debuff.FrostBomb).Remains() < Spell.IceLance.TravelTime()
			   and Player.Buff(Buff.FingersOfFrost).React();
		end,

		-- # With T20 2pc, Frozen Orb should be used as soon as it comes off CD.
		-- actions.single+=/frozen_orb,if=set_bonus.tier20_2pc&buff.fingers_of_frost.react<3
		FrozenOrb = function()
			return addonTable.Tier20_2PC
			   and Player.Buff(Buff.FingersOfFrost).Remains() < 3;
		end,

		-- # Glacial Spike is generally used as it is available, unless we have T20 2pc. In that case, Glacial Spike is delayed when Frozen Mass is happening soon (in less than 10 s).
		-- actions.single+=/glacial_spike,if=cooldown.frozen_orb.remains>10|!set_bonus.tier20_2pc
		GlacialSpike = function()
			return Spell.FrozenOrb.Cooldown.Remains() > 10
				or not addonTable.Tier20_2PC;
		end,

		-- actions.single+=/ice_lance,if=buff.fingers_of_frost.react
		IceLance = function()
			return Player.Buff(Buff.FingersOfFrost).React();
		end,

		-- # In some circumstances, it is possible for both Ice Lance and Ice Nova to benefit from a single Winter's Chill.
		-- actions.single=ice_nova,if=debuff.winters_chill.up
		IceNova = function()
			return Target.Debuff(Debuff.WintersChill).Up();
		end,

		-- actions.single+=/ray_of_frost,if=buff.icy_veins.up|cooldown.icy_veins.remains>action.ray_of_frost.cooldown&buff.rune_of_power.down
		RayOfFrost = function()
			return Player.Buff(Buff.IcyVeins).Up()
				or Spell.IcyVeins.Cooldown.Remains() > Talent.RayOfFrost.Cooldown.Base()
			   and Player.Buff(Buff.RuneOfPower).Down();
		end,

		-- # Basic Water Jet combo. Since Water Jet can only be used if the actor is not casting, we use it right after Frostbolt is executed. At the default distance, Frostbolt travels slightly over 1 s, giving Water Jet enough time to apply the DoT (Water Jet's cast time is 1 s, with haste scaling). The APL then forces another Frostbolt to guarantee getting both FoFs from the Water Jet. This works for most haste values (roughly from 0% to 160%). When changing the default distance, great care must be taken otherwise this action won't produce two FoFs.
		-- actions.single+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<3&!buff.brain_freeze.react
		WaterJet = function()
			return Player.PrevGCD(1, Spell.Frostbolt)
			   and Player.Buff(Buff.FingersOfFrost).Stack() < 3
			   and not Player.Buff(Buff.BrainFreeze).React();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.IceNova, self.Requirements.IceNova);
		action.EvaluateAction(Spell.Frostbolt, self.Requirements.Frostbolt.WaterJet);
		action.EvaluateAction(Spell.WaterJet, self.Requirements.WaterJet);
		action.EvaluateAction(Talent.RayOfFrost, self.Requirements.RayOfFrost);
		action.EvaluateAction(Spell.Flurry, self.Requirements.Flurry);
		action.EvaluateAction(Spell.FrozenOrb, self.Requirements.FrozenOrb);
		action.EvaluateAction(Spell.Blizzard, self.Requirements.Blizzard.FreezingRain);
		action.EvaluateAction(Talent.FrostBomb, self.Requirements.FrostBomb);
		action.EvaluateAction(Spell.IceLance, self.Requirements.IceLance);
		-- actions.single+=/ebonbolt
		action.EvaluateAction(Artifact.Ebonbolt, true);
		-- actions.single+=/frozen_orb
		action.EvaluateAction(Spell.FrozenOrb, true);
		-- actions.single+=/ice_nova
		action.EvaluateAction(Talent.IceNova, true);
		-- actions.single+=/comet_storm
		action.EvaluateAction(Talent.CometStorm, true);
		action.EvaluateAction(Spell.Blizzard, self.Requirements.Blizzard.Use);
		action.EvaluateAction(Spell.Frostbolt, self.Requirements.Frostbolt.Use);
		action.EvaluateAction(Talent.GlacialSpike, self.Requirements.GlacialSpike);
		-- actions.single+=/frostbolt
		action.EvaluateAction(Spell.Frostbolt, true);
		action.EvaluateAction(Spell.Blizzard, self.Requirements.Blizzard.Moving);
		-- # Otherwise just use Ice Lance to do at least some damage.
		-- actions.single+=/ice_lance
		action.EvaluateAction(Spell.IceLance, true);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local SingleTarget = SingleTarget("SingleTarget");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Kuni and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/frost-mage-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Single Target"] = "2133021",
		["Cleave / AOE"] = "2133031",
		["Solo"] = "2133035",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		IceBarrier = function()
			return not Player.Buff(Buff.IceBarrier).Up()
			   and Player.DamagePredicted(5) >= 15;
		end,

		IceBlock = function()
			return Player.DamagePredicted(3) >= 50;
		end,

		-- # Free Ice Lance after Flurry. This action has rather high priority to ensure that we don't cast Rune of Power, Ray of Frost, etc. after Flurry and break up the combo. If FoF was already active, we do not lose anything by delaying the Ice Lance.
		-- actions+=/ice_lance,if=!buff.fingers_of_frost.react&prev_gcd.1.flurry
		IceLance = function()
			return not Player.Buff(Buff.FingersOfFrost).React()
			   and Player.PrevGCD(1, Spell.Flurry);
		end,

		-- # Time Warp is used right at the start. If the actor has Shard of the Exodar, try to synchronize the second Time Warp with Icy Veins. If the target is about to die, use Time Warp regardless.
		-- Remove the parts about lusting on start of combat, and change it to Shard of Exodar only, lust should only be used when called for by the raid leader.
		-- actions+=/time_warp,if=buff.bloodlust.down&(buff.exhaustion.down|equipped.shard_of_the_exodar)&(cooldown.icy_veins.remains<1|target.time_to_die<50)
		TimeWarp = function()
			return not Player.HasBloodlust()
			   and Legendary.ShardOfTheExodar.Equipped()
			   and (Spell.IcyVeins.Cooldown.Remains() < 1 or Target.TimeToDie() < 50);
		end,

		-- Not specified in simcraft, but we want to make sure we only suggest summoning pet if its not already active.
		-- actions.precombat+=/water_elemental
		WaterElemental = function()
			return not Pet.IsActive();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		-- Spells
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(28730),
			Berserking = Objects.newSpell(26297),
			BloodFury = Objects.newSpell(33702),
			GiftOfTheNaaru = Objects.newSpell(59548),
			QuakingPalm = Objects.newSpell(107079),
			Shadowmeld = Objects.newSpell(58984),
		};

		Artifact = {
			-- Abilities
			Ebonbolt = Objects.newSpell(214634),
			-- Traits
			IcyHand = Objects.newSpell(220817),
		};

		Spell = {
			-- Abilities
			Blizzard = Objects.newSpell(190356),
			ColdSnap = Objects.newSpell(235219),
			ConeOfCold = Objects.newSpell(120),
			Flurry = Objects.newSpell(44614),
			Frostbolt = Objects.newSpell(116),
			FrostNova = Objects.newSpell(122),
			FrozenOrb = Objects.newSpell(84714),
			IceLance = Objects.newSpell(30455),
			IcyVeins = Objects.newSpell(12472),
			-- Crowd Control
			CounterSpell = Objects.newSpell(2139),
			Polymorph = Objects.newSpell(118),
			-- Defensive
			IceBarrier = Objects.newSpell(11426),
			IceBlock = Objects.newSpell(45438),
			-- Pet
			Freeze = Objects.newSpell(33395),
			WaterJet = Objects.newSpell(135029),
			-- Utility
			Blink = Objects.newSpell(1953),
			Invisibility = Objects.newSpell(66),
			SpellSteal = Objects.newSpell(30449),
			TimeWarp = Objects.newSpell(80353),
			WaterElemental = Objects.newSpell(31687),
		};

		Talent = {
			-- Active Talents
			CometStorm = Objects.newSpell(153595),
			FrostBomb = Objects.newSpell(112948),
			GlacialSpike = Objects.newSpell(199786),
			IceFloes = Objects.newSpell(108839),
			IceNova = Objects.newSpell(157997),
			MirrorImage = Objects.newSpell(55342),
			RayOfFrost = Objects.newSpell(205021),
			RingOfFrost = Objects.newSpell(113724),
			RuneOfPower = Objects.newSpell(116011),
			Shimmer = Objects.newSpell(212653),
			-- Passive Talents
			ArcticGale = Objects.newSpell(205038),
			BoneChilling = Objects.newSpell(205027),
			FrigidWinds = Objects.newSpell(235224),
			FrozenTouch = Objects.newSpell(205030),
			GlacialInsulation = Objects.newSpell(235297),
			IceWard = Objects.newSpell(205036),
			IncantersFlow = Objects.newSpell(1463),
			LonelyWinter = Objects.newSpell(205024),
			SplittingIce = Objects.newSpell(56377),
			ThermalVoid = Objects.newSpell(155149),
			UnstableMagic = Objects.newSpell(157976),
		};

		Buff = {
			-- Buffs
			Blink = Spell.Blink,
			BoneChilling = Objects.newSpell(205027),
			BrainFreeze = Objects.newSpell(190447),
			FingersOfFrost = Objects.newSpell(112965),
			FrozenMass = Objects.newSpell(242253),
			IceBarrier = Spell.IceBarrier,
			IceBlock = Spell.IceBlock,
			IceFloes = Talent.IceFloes,
			IceNova = Talent.IceNova,
			Icicles = Objects.newSpell(76613),
			IcyVeins = Spell.IcyVeins,
			IncantersFlow = Talent.IncantersFlow,
			Invisibility = Spell.Invisibility,
			RuneOfPower = Talent.RuneOfPower,
			Shimmer = Talent.Shimmer,
			TimeWarp = Spell.TimeWarp,
			--Legendaries
			ZannesuJourney = Objects.newSpell(206397),
		};

		Debuff = {
			-- Debuffs
			ConeOfCold = Spell.ConeOfCold,
			Freeze = Spell.Freeze,
			FrostBomb = Talent.FrostBomb,
			FrostNova = Spell.FrostNova,
			GlacialSpike = Talent.GlacialSpike,
			Hypothermia = Objects.newSpell(41425),
			Polymorph = Spell.Polymorph,
			RayOfFrost = Talent.RayOfFrost,
			RingOfFrost = Talent.RingOfFrost,
			Shatter = Objects.newSpell(12982),
			WaterJet = Spell.WaterJet,
			WintersChill = Objects.newSpell(228358),
		};

		-- Items
		Legendary = {
		-- Legendaries
			LadyVashjsGrasp = Objects.newItem(132411),
			ShardOfTheExodar = Objects.newItem(132410),
		};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.BloodFury, Racial.GiftOfTheNaaru, Racial.Shadowmeld);
		config.AOEOptions(options, Spell.Blizzard, Talent.CometStorm, Spell.ConeOfCold, Talent.FrostBomb, Spell.FrozenOrb, Talent.IceNova);
		config.CooldownOptions(options, Spell.ColdSnap, Artifact.Ebonbolt, Talent.GlacialSpike, Talent.IceFloes, Spell.IcyVeins, Talent.MirrorImage, Talent.RayOfFrost, Talent.RuneOfPower);
		config.DefensiveOptions(options, Spell.IceBarrier, Spell.IceBlock);
		config.PetOptions(options, Spell.Freeze, Spell.WaterElemental, Spell.WaterJet);
		config.UtilityOptions(options, Spell.Blink, Spell.Invisibility, Spell.Polymorph, Talent.RingOfFrost, Talent.Shimmer, Spell.SpellSteal, Spell.TimeWarp);
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
		Consumable = nil;
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
		-- The abilities here should be listed from highest damage required to suggest to lowest,
		-- Specific damage types before all damage types.

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.IceBlock, self.Requirements.IceBlock);
		action.EvaluateDefensiveAction(Spell.IceBarrier, self.Requirements.IceBarrier);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.CounterSpell, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Racial.QuakingPalm, true);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		action.EvaluateAction(Spell.WaterElemental, self.Requirements.WaterElemental);
		-- actions.precombat+=/mirror_image
		action.EvaluateAction(Talent.MirrorImage, true);
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- actions.precombat+=/frostbolt
		action.EvaluateAction(Spell.Frostbolt, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Spell.IceLance, self.Requirements.IceLance);
		action.EvaluateAction(Spell.TimeWarp, self.Requirements.TimeWarp);

		action.CallActionList(Movement);
		-- actions+=/call_action_list,name=cooldowns
		action.CallActionList(Cooldowns);
		action.CallActionList(AOE);
		-- actions+=/call_action_list,name=single
		action.CallActionList(SingleTarget);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Frost Mage", addonTable.Enum.SpecID.MAGE_FROST);