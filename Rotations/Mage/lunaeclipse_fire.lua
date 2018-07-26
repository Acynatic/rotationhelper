local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Core = addon.Core.General;
local Objects = addon.Core.Objects;

-- Function for converting booleans returns to numbers
local val = Core.ToNumber;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_mage_fire";

-- ActiveTalents Rotation
local function ActiveTalents(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.active_talents=blast_wave,if=(buff.combustion.down)|(buff.combustion.up&action.fire_blast.charges<1&action.phoenixs_flames.charges<1)
		BlastWave = function()
			return Player.Buff(Buff.Combustion).Down()
				or (Player.Buff(Buff.Combustion).Up() and Spell.FireBlast.Charges() < 1 and Artifact.PhoenixsFlames.Charges() < 1);
		end,

		-- actions.active_talents+=/cinderstorm,if=cooldown.combustion.remains<cast_time&(buff.rune_of_power.up|!talent.rune_of_power.enabled)|cooldown.combustion.remains>10*spell_haste&!buff.combustion.up
		Cinderstorm = function()
			local spell_haste = 1 / (1 + (Player.HastePercent() / 100));

			return Spell.Combustion.Cooldown.Remains() < Talent.Cinderstorm.CastTime()
			   and (Player.Buff(Buff.RuneOfPower).Up() or not Talent.RuneOfPower.Enabled())
				or Spell.Combustion.Cooldown.Remains() > 10 * spell_haste
			   and not Player.Buff(Buff.Combustion).Up();
		end,

		-- actions.active_talents+=/dragons_breath,if=equipped.darcklis_dragonfire_diadem|(talent.alexstraszas_fury.enabled&!buff.hot_streak.react)
		DragonsBreath = function()
			return Legendary.DarcklisDragonfireDiadem.Equipped()
				or (Talent.AlexstraszasFury.Enabled() and not Player.Buff(Buff.HotStreak).React());
		end,

		-- actions.active_talents+=/living_bomb,if=active_enemies>1&buff.combustion.down
		LivingBomb = function(numEnemies)
			return numEnemies > 1
			   and Player.Buff(Buff.Combustion).Down();
		end,

		-- actions.active_talents+=/meteor,if=cooldown.combustion.remains>40|(cooldown.combustion.remains>target.time_to_die)|buff.rune_of_power.up|firestarter.active
		Meteor = function()
			return Spell.Combustion.Cooldown.Remains() > 40
				or Spell.Combustion.Cooldown.Remains() > Target.TimeToDie()
				or Player.Buff(Buff.RuneOfPower).Up()
				or (Talent.Firestarter.Enabled() and Target.Health.Percent() > 90);
		end,
	};

	-- Add meta-table to the requirements table, to enable better debugging and case insensitivity.
	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.BlastWave, self.Requirements.BlastWave);
		action.EvaluateAction(Talent.Meteor, self.Requirements.Meteor);
		action.EvaluateAction(Talent.Cinderstorm, self.Requirements.Cinderstorm);
		action.EvaluateAction(Spell.DragonsBreath, self.Requirements.DragonsBreath);
		action.EvaluateAction(Talent.LivingBomb, self.Requirements.LivingBomb);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local ActiveTalents = ActiveTalents("ActiveTalents");

-- Combustion Rotation
local function Combustion(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.combustion_phase+=/dragons_breath,if=!buff.hot_streak.react&action.fire_blast.charges<1&action.phoenixs_flames.charges<1
		DragonsBreath = function()
			return not Player.Buff(Buff.HotStreak).React()
			   and Spell.FireBlast.Charges() < 1
			   and Artifact.PhoenixsFlames.Charges() < 1;
		end,

		-- actions.combustion_phase+=/fire_blast,if=buff.heating_up.react
		FireBlast = function()
			return Player.Buff(Buff.HeatingUp).React();
		end,

		-- actions.combustion_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2|active_enemies>4)&buff.hot_streak.react
		Flamestrike = function(numEnemies)
			return (Talent.FlamePatch.Enabled() and numEnemies > 2 or numEnemies > 4)
			   and Player.Buff(Buff.HotStreak).React();
		end,

		Pyroblast = {
			-- actions.combustion_phase+=/pyroblast,if=buff.hot_streak.react
			Use = function()
				return Player.Buff(Buff.HotStreak).React();
			end,

			-- actions.combustion_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&buff.combustion.remains>execute_time
			KaelthasUltimateAbility = function()
				return Player.Buff(Buff.KaelthasUltimateAbility).React()
				   and Player.Buff(Buff.Combustion).Remains() > Spell.Pyroblast.ExecuteTime();
			end,
		},

		-- actions.combustion_phase=rune_of_power,if=buff.combustion.down
		RuneOfPower = function()
			return Player.Buff(Buff.Combustion).Down();
		end,

		Scorch = {
			-- actions.combustion_phase+=/scorch,if=buff.combustion.remains>cast_time
			Use = function()
				return Player.Buff(Buff.Combustion).Remains() > Spell.Scorch.CastTime();
			end,

			-- actions.combustion_phase+=/scorch,if=target.health.pct<=30&equipped.koralon_burning_touch
			KoralonBurningTouch = function()
				return Target.Health.Percent() <= 30
				   and Legendary.KoralonBurningTouch.Equipped();
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.RuneOfPower, self.Requirements.RuneOfPower);

		-- actions.combustion_phase+=/call_action_list,name=active_talents
		action.CallActionList(ActiveTalents);

		-- actions.combustion_phase+=/combustion
		action.EvaluateAction(Spell.Combustion, true);
		-- actions.combustion_phase+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- actions.combustion_phase+=/blood_fury
		action.EvaluateAction(Racial.BloodFury, true);
		-- actions.combustion_phase+=/berserking
		action.EvaluateAction(Racial.Berserking, true);
		-- actions.combustion_phase+=/arcane_torrent
		action.EvaluateAction(Racial.ArcaneTorrent, true);
		action.EvaluateAction(Spell.Flamestrike, self.Requirements.Flamestrike);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.KaelthasUltimateAbility);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.Use);
		action.EvaluateAction(Spell.FireBlast, self.Requirements.FireBlast);
		-- actions.combustion_phase+=/phoenixs_flames
		action.EvaluateAction(Artifact.PhoenixsFlames, true);
		action.EvaluateAction(Spell.Scorch, self.Requirements.Scorch.Use);
		action.EvaluateAction(Spell.DragonsBreath, self.Requirements.DragonsBreath);
		action.EvaluateAction(Spell.Scorch, self.Requirements.Scorch.KoralonBurningTouch);
	end

	-- actions+=/call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
	function self.Use(numEnemies)
		return Spell.Combustion.Cooldown.Remains() <= Talent.RuneOfPower.CastTime() + (val(not Talent.Kindling.Enabled()) * Player.GCD())
		   and (not (Talent.Firestarter.Enabled() and Target.Health.Percent() > 90) or numEnemies >= 4 or numEnemies >= 2 and Talent.FlamePatch.Enabled())
			or Player.Buff(Buff.Combustion).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Combustion = Combustion("Combustion");

-- RuneOfPower Rotation
local function RuneOfPower(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.rop_phase+=/dragons_breath,if=active_enemies>2
		DragonsBreath = function(numEnemies)
			return numEnemies > 2;
		end,

		FireBlast = {
			-- actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
			Use = function()
				return not Player.PrevOffGCD(1, Spell.FireBlast)
				   and not (Talent.Firestarter.Enabled() and Target.Health.Percent() > 90);
			end,

			-- actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.react&firestarter.active&charges_fractional>1.7
			Firestarter = function()
				return not Player.PrevOffGCD(1, Spell.FireBlast)
				   and Player.Buff(Buff.HeatingUp).React()
				   and (Talent.Firestarter.Enabled() and Target.Health.Percent() > 90)
				   and Spell.FireBlast.Charges.Fractional() > 1.7;
			end,
		},

		Flamestrike = {
			-- actions.rop_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
			Use = function(numEnemies)
				return (Talent.FlamePatch.Enabled() and numEnemies > 2)
					or numEnemies > 5;
			end,

			-- actions.rop_phase+=/flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.react
			HotStreak = function(numEnemies)
				return ((Talent.FlamePatch.Enabled() and numEnemies > 1) or numEnemies > 3)
				   and Player.Buff(Buff.HotStreak).React();
			end,
		},

		PhoenixsFlames = {
			-- actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames
			Use = function()
				return not Player.PrevGCD(1, Artifact.PhoenixsFlames);
			end,

			-- actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames&charges_fractional>2.7&firestarter.active
			FireStarter = function()
				return not Player.PrevGCD(1, Artifact.PhoenixsFlames)
				   and Artifact.PhoenixsFlames.Charges.Fractional() > 2.7
				   and (Talent.Firestarter.Enabled() and Target.Health.Percent() > 90);
			end,
		},

		Pyroblast = {
			-- actions.rop_phase+=/pyroblast,if=buff.hot_streak.react
			HotStreak = function()
				return Player.Buff(Buff.HotStreak).React();
			end,

			-- actions.rop_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains&buff.rune_of_power.remains>cast_time
			KaelthasUltimateAbility = function()
				return Player.Buff(Buff.KaelthasUltimateAbility).React()
				   and Spell.Pyroblast.ExecuteTime() < Player.Buff(Buff.KaelthasUltimateAbility).Remains()
				   and Player.Buff(Buff.RuneOfPower).Remains() > Spell.Pyroblast.CastTime();
			end,
		},

		-- actions.rop_phase+=/scorch,if=target.health.pct<=30&equipped.koralon_burning_touch
		Scorch = function()
			return Target.Health.Percent() <= 30
			   and Legendary.KoralonBurningTouch.Equipped();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.RuneOfPower, true);
		action.EvaluateAction(Spell.Flamestrike, self.Requirements.Flamestrike.HotStreak);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.HotStreak);

		-- actions.rop_phase+=/call_action_list,name=active_talents
		action.CallActionList(ActiveTalents);

		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.KaelthasUltimateAbility);
		action.EvaluateAction(Spell.FireBlast, self.Requirements.FireBlast.Firestarter);
		action.EvaluateAction(Artifact.PhoenixsFlames, self.Requirements.PhoenixsFlames.Firestarter);
		action.EvaluateAction(Spell.FireBlast, self.Requirements.FireBlast.Use);
		action.EvaluateAction(Artifact.PhoenixsFlames, self.Requirements.PhoenixsFlames.Use);
		action.EvaluateAction(Spell.Scorch, self.Requirements.Scorch);
		action.EvaluateAction(Spell.DragonsBreath, self.Requirements.DragonsBreath);
		action.EvaluateAction(Spell.Flamestrike, self.Requirements.Flamestrike.Use);
		-- actions.rop_phase+=/fireball
		action.EvaluateAction(Spell.Fireball, true);
	end

	-- actions+=/call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
	function self.Use()
		return Player.Buff(Buff.RuneOfPower).Up()
		   and Player.Buff(Buff.Combustion).Down();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local RuneOfPower = RuneOfPower("RuneOfPower");

-- Standard Rotation
local function Standard(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		FireBlast = {
			-- actions.standard_rotation+=/fire_blast,if=!talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
			Use = function()
				local spell_haste = 1 / (1 + (Player.HastePercent() / 100));

				return not Talent.Kindling.Enabled()
				   and Player.Buff(Buff.HeatingUp).React()
				   and (not Talent.RuneOfPower.Enabled() or Spell.FireBlast.Charges.Fractional() > 1.4 or Spell.Combustion.Cooldown.Remains() < 40)
				   and (3 - Spell.FireBlast.Charges.Fractional()) * (12 * spell_haste) < Spell.Combustion.Cooldown.Remains() + 3
					or Target.TimeToDie() < 4;
			end,

			-- actions.standard_rotation+=/fire_blast,if=talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
			Kindling = function()
				local spell_haste = 1 / (1 + (Player.HastePercent() / 100));

				return Talent.Kindling.Enabled()
				   and Player.Buff(Buff.HeatingUp).React()
				   and (not Talent.RuneOfPower.Enabled() or Spell.FireBlast.Charges.Fractional() > 1.5 or Spell.Combustion.Cooldown.Remains() < 40)
				   and (3 - Spell.FireBlast.Charges.Fractional()) * (18 * spell_haste) < Spell.Combustion.Cooldown.Remains() + 3
					or Target.TimeToDie() < 4;
			end,
		},

		Flamestrike = {
			-- actions.standard_rotation+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>3)|active_enemies>5
			Use = function(numEnemies)
				return (Talent.FlamePatch.Enabled() and numEnemies > 3)
					or numEnemies > 5;
			end,

			-- actions.standard_rotation=flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.react
			HotStreak = function(numEnemies)
				return ((Talent.FlamePatch.Enabled() and numEnemies > 1) or numEnemies > 3)
				   and Player.Buff(Buff.HotStreak).React();
			end,
		},

		PhoenixsFlames = {
			-- actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
			Use = function()
				return Artifact.PhoenixsFlames.Charges.Fractional() > 2.5
				   and Spell.Combustion.Cooldown.Remains() > 23;
			end,

			-- actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
			Combustion = function()
				return (Player.Buff(Buff.Combustion).Up() or Player.Buff(Buff.RuneOfPower).Up())
				   and (4 - Artifact.PhoenixsFlames.Charges.Fractional()) * 30 < Spell.Combustion.Cooldown.Remains() + 5;
			end,

			-- actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.7&active_enemies>2
			MaxCharges = function(numEnemies)
				return Artifact.PhoenixsFlames.Charges.Fractional() > 2.7
				   and numEnemies > 2;
			end,

			-- actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&artifact.phoenix_reborn.enabled&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die<10
			PhoenixReborn = function()
				return (Player.Buff(Buff.Combustion).Up() or Player.Buff(Buff.RuneOfPower).Up() or Player.Buff(Buff.IncantersFlow).Stack() > 3 or Talent.MirrorImage.Enabled())
				   and Artifact.PhoenixReborn.Trait.Enabled()
				   and (4 - Artifact.PhoenixsFlames.Charges.Fractional()) * 13 < Spell.Combustion.Cooldown.Remains() + 5
					or Target.TimeToDie() < 10;
			end,
		},

		Pyroblast = {
			-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&firestarter.active&!talent.rune_of_power.enabled
			Firestarter = function()
				return Player.Buff(Buff.HotStreak).React()
				   and (Talent.Firestarter.Enabled() and Target.Health.Percent() > 90)
				   and not Talent.RuneOfPower.Enabled();
			end,

			-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&(!prev_gcd.1.pyroblast|action.pyroblast.in_flight)
			HotStreak = function()
				return Player.Buff(Buff.HotStreak).React()
				   and (not Player.PrevGCD(1, Spell.Pyroblast) or Spell.Pyroblast.IsInFlight());
			end,

			-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
			HotStreakExpiring = function()
				return Player.Buff(Buff.HotStreak).React()
				   and Player.Buff(Buff.HotStreak).Remains() < Spell.Fireball.ExecuteTime();
			end,

			-- actions.standard_rotation+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
			KaelthasUltimateAbility = function()
				return Player.Buff(Buff.KaelthasUltimateAbility).React()
				   and Spell.Pyroblast.ExecuteTime() < Player.Buff(Buff.KaelthasUltimateAbility).Remains();
			end,

			-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&target.health.pct<=30&equipped.koralon_burning_touch
			KoralonBurningTouch = function()
				return Player.Buff(Buff.HotStreak).React()
				   and Target.Health.Percent() <= 30
				   and Legendary.KoralonBurningTouch.Equipped();
			end,
		},

		-- actions.standard_rotation+=/scorch,if=target.health.pct<=30&equipped.koralon_burning_touch
		Scorch = function()
			return Target.Health.Percent() <= 30
			   and Legendary.KoralonBurningTouch.Equipped();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Flamestrike, self.Requirements.Flamestrike.HotStreak);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.HotStreakExpiring);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.Firestarter);
		action.EvaluateAction(Artifact.PhoenixsFlames, self.Requirements.PhoenixsFlames.MaxCharges);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.HotStreak);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.KoralonBurningTouch);
		action.EvaluateAction(Spell.Pyroblast, self.Requirements.Pyroblast.KaelthasUltimateAbility);

		-- actions.standard_rotation+=/call_action_list,name=active_talents
		action.CallActionList(ActiveTalents);

		action.EvaluateAction(Spell.FireBlast, self.Requirements.FireBlast.Use);
		action.EvaluateAction(Spell.FireBlast, self.Requirements.FireBlast.Kindling);
		action.EvaluateAction(Artifact.PhoenixsFlames, self.Requirements.PhoenixsFlames.PhoenixReborn);
		action.EvaluateAction(Artifact.PhoenixsFlames, self.Requirements.PhoenixsFlames.Combustion);
		action.EvaluateAction(Artifact.PhoenixsFlames, self.Requirements.PhoenixsFlames.Use);
		action.EvaluateAction(Spell.Flamestrike, self.Requirements.Flamestrike.Use);
		action.EvaluateAction(Spell.Scorch, self.Requirements.Scorch);
		-- actions.standard_rotation+=/fireball
		action.EvaluateAction(Spell.Fireball, true);
		-- actions.standard_rotation+=/scorch
		action.EvaluateAction(Spell.Scorch, true);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Standard = Standard("Standard");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Rinoa and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/fire-mage-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Tier 21 - 4 Piece"] = "1022121",
		["Standard"] = "3032123",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		BlazingBarrier = function()
			return not Player.Buff(Buff.BlazingBarrier).Up()
			   and Player.DamagePredicted(5) >= 15;
		end,

		IceBlock = function()
			return Player.DamagePredicted(3) >= 50;
		end,

		-- actions+=/mirror_image,if=buff.combustion.down
		MirrorImage = function()
			return Player.Buff(Buff.Combustion).Down();
		end,

		RuneOfPower = {
			-- # Standard Talent RoP Logic.
			-- actions+=/rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
			Use = function()
				return ((Talent.Firestarter.Enabled() and Target.Health.Percent() > 90) and Talent.RuneOfPower.Charges() == 2)
					or (Spell.Combustion.Cooldown.Remains() > 40 and Player.Buff(Buff.Combustion).Down() and not Talent.Kindling.Enabled())
					or Target.TimeToDie() < 11
					or (Talent.Kindling.Enabled() and (Talent.RuneOfPower.Charges.Fractional() > 1.8 or Core.CombatTime() < 40) and Spell.Combustion.Cooldown.Remains() > 40);
			end,

			-- # RoP use while using Legendary Items.
			-- actions+=/rune_of_power,if=(buff.kaelthas_ultimate_ability.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))|(buff.erupting_infernal_core.up&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))
			Legendaries = function()
				return (Player.Buff(Buff.KaelthasUltimateAbility).React() and (Spell.Combustion.Cooldown.Remains() > 40 or Talent.RuneOfPower.Charges() > 1))
					or (Player.Buff(Buff.EruptingInfernalCore).Up() and (Spell.Combustion.Cooldown.Remains() > 40 or Talent.RuneOfPower.Charges() > 1));
			end,
		},

		-- Don't do the time warp on fight start as calling for time warp is a raid leaders responsibility, only suggest with Shard of Exodar or when solo
		-- actions+=/time_warp,if=(time=0&buff.bloodlust.down)|(buff.bloodlust.down&equipped.shard_of_the_exodar&(cooldown.combustion.remains<1|target.time_to_die<50))
		TimeWarp = function()
			return (Player.IsSolo() or (Player.IsSated() and Legendary.ShardOfTheExodar.Equipped()))
			   and (Spell.Combustion.Cooldown.Remains() < 1 or Target.TimeToDie() < 50);
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
			PhoenixsFlames = Objects.newSpell(194466),
			-- Traits
			PhoenixReborn = Objects.newSpell(215773),
		};

		Spell = {
			-- Abilities
			Combustion = Objects.newSpell(190319),
			DragonsBreath = Objects.newSpell(31661),
			Fireball = Objects.newSpell(133),
			FireBlast = Objects.newSpell(108853),
			Flamestrike = Objects.newSpell(2120),
			Pyroblast = Objects.newSpell(11366),
			Scorch = Objects.newSpell(2948),
			-- Crowd Control
			Counterspell = Objects.newSpell(2139),
			FrostNova = Objects.newSpell(122),
			Polymorph = Objects.newSpell(118),
			-- Defensive
			BlazingBarrier = Objects.newSpell(235313),
			IceBlock = Objects.newSpell(45438),
			-- Utility
			Blink = Objects.newSpell(1953),
			Invisibility = Objects.newSpell(66),
			SlowFall = Objects.newSpell(130),
			Spellsteal = Objects.newSpell(30449),
			TimeWarp = Objects.newSpell(80353),
		};

		Talent = {
			-- Active Talents
			BlastWave = Objects.newSpell(157981),
			Cinderstorm = Objects.newSpell(198929),
			LivingBomb = Objects.newSpell(44457),
			Meteor = Objects.newSpell(153561),
			MirrorImage = Objects.newSpell(55342),
			RingOfFrost = Objects.newSpell(113724),
			RuneOfPower = Objects.newSpell(116011),
			Shimmer = Objects.newSpell(212653),
			-- Passive Talents
			AlexstraszasFury = Objects.newSpell(235870),
			BlazingSoul = Objects.newSpell(235365),
			Conflagration = Objects.newSpell(205023),
			ControlledBurn = Objects.newSpell(205033),
			Firestarter = Objects.newSpell(205026),
			FlameOn = Objects.newSpell(205029),
			FlamePatch = Objects.newSpell(205037),
			FreneticSpeed = Objects.newSpell(236058),
			IceWard = Objects.newSpell(205036),
			IncantersFlow = Objects.newSpell(1463),
			Kindling = Objects.newSpell(155148),
			Pyromaniac = Objects.newSpell(205020),
			UnstableMagic = Objects.newSpell(157976),
		};

		Buff = {
			-- Buffs
			Berserking = Racial.Berserking,
			BlazingBarrier = Spell.BlazingBarrier,
			BloodFury = Racial.BloodFury,
			CauterizingBlink = Objects.newSpell(194316),
			Combustion = Spell.Combustion,
			EnhancedPyrotechnics = Objects.newSpell(157644),
			EruptingInfernalCore = Objects.newSpell(248147),
			FreneticSpeed = Objects.newSpell(236060),
			GiftOfTheNaaru = Racial.GiftOfTheNaaru,
			HeatingUp = Objects.newSpell(48107),
			HotStreak = Objects.newSpell(48108),
			IceBlock = Spell.IceBlock,
			IncantersFlow = Talent.IncantersFlow,
			Invisibility = Spell.Invisibility,
			RuneOfPower = Objects.newSpell(116014),
			ScorchedEarth = Objects.newSpell(227482),
			Shadowmeld = Racial.Shadowmeld,
			SlowFall = Spell.SlowFall,
			WarmthOfThePhoenix = Objects.newSpell(240671),
			-- Legendaries
			KaelthasUltimateAbility = Objects.newSpell(209455),
		};

		Debuff = {
			-- Debuffs
			BlastFurnace = Objects.newSpell(194522),
			BlastWave = Talent.BlastWave,
			Conflagration = Objects.newSpell(226757),
			DragonsBreath = Spell.DragonsBreath,
			Flamestrike = Spell.Flamestrike,
			FrostNova = Spell.FrostNova,
			Hypothermia = Objects.newSpell(41425),
			LivingBomb = Objects.newSpell(217694),
			Meteor = Objects.newSpell(155158),
			Polymorph = Spell.Polymorph,
			QuakingPalm = Racial.QuakingPalm,
			RingOfFrost = Objects.newSpell(82691),
		};

		-- Items
		Legendary = {
			-- Legendaries
			DarcklisDragonfireDiadem = Objects.newItem(132863),
			KoralonBurningTouch = Objects.newItem(132454),
			ShardOfTheExodar = Objects.newItem(132410),
		};

		Item = {};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.BloodFury, Racial.GiftOfTheNaaru, Racial.Shadowmeld);
		config.AOEOptions(options, Talent.BlastWave, Spell.DragonsBreath, Spell.Flamestrike, Talent.LivingBomb, Talent.Meteor);
		config.CooldownOptions(options, Talent.Cinderstorm, Spell.Combustion, Spell.FireBlast, Talent.MirrorImage, Artifact.PhoenixsFlames, Talent.RuneOfPower);
		config.DefensiveOptions(options, Spell.BlazingBarrier, Spell.IceBlock);
		config.UtilityOptions(options, Spell.Blink, Spell.FrostNova, Spell.Invisibility, Spell.Polymorph, Talent.RingOfFrost, Talent.Shimmer, Spell.SlowFall, Spell.Spellsteal, Spell.TimeWarp);
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

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.IceBlock, self.Requirements.IceBlock);
		action.EvaluateDefensiveAction(Spell.BlazingBarrier, self.Requirements.BlazingBarrier);
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
		-- actions.precombat+=/mirror_image
		action.EvaluateAction(Talent.MirrorImage, true);
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- actions.precombat+=/pyroblast
		action.EvaluateAction(Spell.Pyroblast, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Spell.TimeWarp, self.Requirements.TimeWarp);
		action.EvaluateAction(Talent.MirrorImage, self.Requirements.MirrorImage);
		action.EvaluateAction(Talent.RuneOfPower, self.Requirements.RuneOfPower.Use);
		action.EvaluateAction(Talent.RuneOfPower, self.Requirements.RuneOfPower.Legendaries);

		action.CallActionList(Combustion);
		action.CallActionList(RuneOfPower);
		-- actions+=/call_action_list,name=standard_rotation
		action.CallActionList(Standard);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Fire Mage", addonTable.Enum.SpecID.MAGE_FIRE);