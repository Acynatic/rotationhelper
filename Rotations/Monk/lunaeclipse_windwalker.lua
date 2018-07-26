local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Core = addon.Core.General;
local Objects = addon.Core.Objects;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_monk_windwalker";

-- CD Rotation
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.cd+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
		ArcaneTorrent = function()
			return Player.Chi.Deficit() >= 1
			and Player.Energy.TimeToMax() >= 0.5;
		end,

		TouchOfDeath = {
			-- actions.cd+=/touch_of_death,if=!artifact.gale_burst.enabled&!equipped.hidden_masters_forbidden_touch
			Use = function()
				return not Artifact.GaleBurst.Trait.Enabled()
				   and not Legendary.HiddenMastersForbiddenTouch.Equipped()
			end,

			-- actions.cd+=/touch_of_death,cycle_targets=1,max_cycle_targets=2,if=artifact.gale_burst.enabled&((talent.serenity.enabled&cooldown.serenity.remains<=1)|chi>=2)&(cooldown.strike_of_the_windlord.remains<8|cooldown.fists_of_fury.remains<=4)&cooldown.rising_sun_kick.remains<7&!prev_gcd.1.touch_of_death
			GaleBurst = function()
				return Artifact.GaleBurst.Trait.Enabled()
				   and ((Talent.Serenity.Enabled() and Talent.Serenity.Cooldown.Remains() <= 1) or Player.Chi() >= 2)
				   and (Artifact.StrikeOfTheWindlord.Cooldown.Remains() < 8 or Spell.FistsOfFury.Cooldown.Remains() <= 4)
				   and Spell.RisingSunKick.Cooldown.Remains() < 7
				   and not Player.PrevGCD(1, Spell.TouchOfDeath);
			end,

			-- actions.cd+=/touch_of_death,cycle_targets=1,max_cycle_targets=2,if=!artifact.gale_burst.enabled&equipped.hidden_masters_forbidden_touch&!prev_gcd.1.touch_of_death
			HiddenMastersForbiddenTouch = function()
				return not Artifact.GaleBurst.Trait.Enabled()
				   and Legendary.HiddenMastersForbiddenTouch.Equipped()
				   and not Player.PrevGCD(1, Spell.TouchOfDeath);
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- actions.cd=invoke_xuen_the_white_tiger
		action.EvaluateAction(Talent.InvokeXuen, true);
		-- actions.cd+=/blood_fury
		action.EvaluateAction(Racial.BloodFury, true);
		-- actions.cd+=/berserking
		action.EvaluateAction(Racial.Berserking, true);
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);
		action.EvaluateCycleAction(Spell.TouchOfDeath, self.Requirements.TouchOfDeath.HiddenMastersForbiddenTouch, nil, 2);
		action.EvaluateAction(Spell.TouchOfDeath, self.Requirements.TouchOfDeath.Use);
		action.EvaluateCycleAction(Spell.TouchOfDeath, self.Requirements.TouchOfDeath.GaleBurst, nil, 2);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Cooldowns = Cooldowns("Cooldowns");

-- Serenity Rotation
local function Serenity(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		BlackoutKick = {
			-- actions.serenity+=/blackout_kick,cycle_targets=1,if=!prev_gcd.1.blackout_kick
			Use = function()
				return not Player.PrevGCD(1, Spell.BlackoutKick);
			end,

			-- actions.serenity+=/blackout_kick,cycle_targets=1,if=(!prev_gcd.1.blackout_kick)&(prev_gcd.1.strike_of_the_windlord|prev_gcd.1.fists_of_fury)&active_enemies<2
			Cooldowns = function(numEnemies)
				return not Player.PrevGCD(1, Spell.BlackoutKick)
				   and (Player.PrevGCD(1, Artifact.StrikeOfTheWindlord) or Player.PrevGCD(1, Spell.FistsOfFury))
				   and numEnemies < 2;
			end,
		},

		FistsOfFury = {
			-- actions.serenity+=/fists_of_fury,if=((!equipped.drinking_horn_cover|buff.bloodlust.up|buff.serenity.remains<1)&(cooldown.rising_sun_kick.remains>1|active_enemies>1)),interrupt=1
			Use = function(numEnemies)
				return (not Legendary.DrinkingHornCover.Equipped() or Player.HasBloodlust() or Player.Buff(Buff.Serenity).Remains() < 1)
				   and (Spell.RisingSunKick.Cooldown.Remains() > 1 or numEnemies > 1);
			end,

			-- actions.serenity+=/fists_of_fury,if=((equipped.drinking_horn_cover&buff.pressure_point.remains<=2&set_bonus.tier20_4pc)&(cooldown.rising_sun_kick.remains>1|active_enemies>1)),interrupt=1
			DrinkingHornCover = function(numEnemies)
				return (Legendary.DrinkingHornCover.Equipped() and Player.Buff(Buff.PressurePoint).Remains() <= 2 and addonTable.Tier20_4PC)
				   and (Spell.RisingSunKick.Cooldown.Remains() > 1 or numEnemies > 1);
			end,

			-- interrupt=1
			Interrupt = function()
				return true;
			end,
		},

		RisingSunKick = {
			-- actions.serenity+=/rising_sun_kick,cycle_targets=1,if=active_enemies>=3
			Use = function(numEnemies)
				return numEnemies >= 3;
			end,

			-- actions.serenity+=/rising_sun_kick,cycle_targets=1,if=active_enemies<3
			Cleave = function(numEnemies)
				return numEnemies < 3;
			end,
		},

		RushingJadeWind = {
			-- actions.serenity+=/rushing_jade_wind,if=!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down&active_enemies>1
			Use = function(numEnemies)
				return not Player.PrevGCD(1, Talent.RushingJadeWind)
				   and Player.Buff(Buff.RushingJadeWind).Down()
				   and numEnemies > 1;
			end,

			-- actions.serenity+=/rushing_jade_wind,if=!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down&buff.serenity.remains>=4
			Serenity = function()
				return not Player.PrevGCD(1, Talent.RushingJadeWind)
				   and Player.Buff(Buff.RushingJadeWind).Down()
				   and Player.Buff(Buff.Serenity).Remains() >= 4;
			end,
		},

		SpinningCraneKick = {
			-- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick
			Use = function()
				return not Player.PrevGCD(1, Spell.SpinningCraneKick);
			end,

			-- actions.serenity+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
			AOE = function(numEnemies)
				return numEnemies >= 3
				   and not Player.PrevGCD(1, Spell.SpinningCraneKick);
			end,
		},

		-- actions.serenity=tiger_palm,cycle_targets=1,if=!prev_gcd.1.tiger_palm&energy=energy.max&chi<1&!buff.serenity.up
		TigerPalm = function()
			return not Player.PrevGCD(1, Spell.TigerPalm)
			   and Player.Energy() == Player.Energy.Max()
			   and Player.Chi() < 1
			   and not Player.Buff(Buff.Serenity).Up();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateCycleAction(Spell.TigerPalm, self.Requirements.TigerPalm);

		-- actions.serenity+=/call_action_list,name=cd
		action.CallActionList(Cooldowns);

		-- actions.serenity+=/serenity
		action.EvaluateAction(Talent.Serenity, true);
		action.EvaluateCycleAction(Spell.RisingSunKick, self.Requirements.RisingSunKick.Cleave);
		-- actions.serenity+=/strike_of_the_windlord
		action.EvaluateAction(Artifact.StrikeOfTheWindlord, true);
		action.EvaluateCycleAction(Spell.BlackoutKick, self.Requirements.BlackoutKick.Cooldowns);
		action.EvaluateInterruptCondition(Spell.FistsOfFury, self.Requirements.FistsOfFury.DrinkingHornCover, self.Requirements.FistsOfFury.Interrupt);
		action.EvaluateInterruptCondition(Spell.FistsOfFury, self.Requirements.FistsOfFury.Use, self.Requirements.FistsOfFury.Interrupt);
		action.EvaluateAction(Spell.SpinningCraneKick, self.Requirements.SpinningCraneKick.AOE);
		action.EvaluateAction(Talent.RushingJadeWind, self.Requirements.RushingJadeWind.Serenity);
		action.EvaluateCycleAction(Spell.RisingSunKick, self.Requirements.RisingSunKick.Use);
		action.EvaluateAction(Talent.RushingJadeWind, self.Requirements.RushingJadeWind.Use);
		action.EvaluateAction(Spell.SpinningCraneKick, self.Requirements.SpinningCraneKick.Use);
		action.EvaluateCycleAction(Spell.BlackoutKick, self.Requirements.BlackoutKick.Use);
	end

	-- actions+=/call_action_list,name=serenity,if=(talent.serenity.enabled&cooldown.serenity.remains<=0)|buff.serenity.up
	function self.Use()
		return (Talent.Serenity.Enabled() and Talent.Serenity.Cooldown.Remains() <= 0)
			or Player.Buff(Buff.Serenity).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Serenity = Serenity("Serenity");

-- Standard Rotation
local function Standard(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.st+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
		ArcaneTorrent = function()
			return Player.Chi.Deficit() >= 1
			   and Player.Energy.TimeToMax() >= 0.5;
		end,

		BlackoutKick = {
			-- actions.st+=/blackout_kick,cycle_targets=1,if=(chi>1|buff.bok_proc.up|(talent.energizing_elixir.enabled&cooldown.energizing_elixir.remains<cooldown.fists_of_fury.remains))&((cooldown.rising_sun_kick.remains>1&(!artifact.strike_of_the_windlord.enabled|cooldown.strike_of_the_windlord.remains>1)|chi>2)&(cooldown.fists_of_fury.remains>1|chi>3)|prev_gcd.1.tiger_palm)&!prev_gcd.1.blackout_kick
			Use = function()
				return (Player.Chi() > 1 or Player.Buff(Buff.BlackoutKick).Up() or (Talent.EnergizingElixir.Enabled() and Talent.EnergizingElixir.Cooldown.Remains() < Spell.FistsOfFury.Cooldown.Remains()))
				   and ((Spell.RisingSunKick.Cooldown.Remains() > 1 and (not Artifact.StrikeOfTheWindlord.Enabled() or Artifact.StrikeOfTheWindlord.Cooldown.Remains() > 1) or Player.Chi() > 2) and (Spell.FistsOfFury.Cooldown.Remains() > 1 or Player.Chi() > 3) or Player.PrevGCD(1, Spell.TigerPalm))
				   and not Player.PrevGCD(1, Spell.BlackoutKick);
			end,

			-- actions.st+=/blackout_kick,cycle_targets=1,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&(!set_bonus.tier19_2pc|talent.serenity.enabled|buff.bok_proc.up)
			Tier21 = function()
				return not Player.PrevGCD(1, Spell.BlackoutKick)
				   and Player.Chi.Deficit() >= 1
				   and addonTable.Tier21_4PC
				   and (not addonTable.Tier19_2PC or Talent.Serenity.Enabled() or Player.Buff(Buff.BlackoutKick).Up());
			end,
		},

		-- actions.st+=/chi_burst,if=energy.time_to_max>1
		ChiBurst = function()
			return Player.Energy.TimeToMax() > 1;
		end,

		-- actions.st+=/chi_wave,if=energy.time_to_max>1
		ChiWave = function()
			return Player.Energy.TimeToMax() > 1;
		end,

		CracklingJadeLightning = {
			-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
			Use = function()
				return Legendary.TheEmperorsCapacitor.Equipped()
				   and Player.Buff(Buff.TheEmperorsCapacitor).Stack() >= 19
				   and Player.Energy.TimeToMax() > 3;
			end,

			-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
			Serenity = function()
				return Legendary.TheEmperorsCapacitor.Equipped()
				   and Player.Buff(Buff.TheEmperorsCapacitor).Stack() >= 14
				   and Talent.Serenity.Cooldown.Remains() < 13
				   and Talent.Serenity.Enabled()
				   and Player.Energy.TimeToMax() > 3;
			end,
		},

		-- actions.st+=/energizing_elixir,if=chi<=1&(cooldown.rising_sun_kick.remains=0|(artifact.strike_of_the_windlord.enabled&cooldown.strike_of_the_windlord.remains=0)|energy<50)
		EnergizingElixir = function()
			return Player.Chi() <= 1
			   and (Spell.RisingSunKick.Cooldown.Up() or (Artifact.StrikeOfTheWindlord.Enabled() and Artifact.StrikeOfTheWindlord.Cooldown.Up()) or Player.Energy() < 50);
		end,

		FistsOfFury = {
			-- actions.st+=/fists_of_fury,if=!talent.serenity.enabled&energy.time_to_max>2
			Use = function()
				return not Talent.Serenity.Enabled()
				   and Player.Energy.TimeToMax() > 2;
			end,

			-- actions.st+=/fists_of_fury,if=talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.serenity.remains>=15|cooldown.serenity.remains<=4)&energy.time_to_max>2
			DrinkingHornCover = function()
				return Talent.Serenity.Enabled()
				   and Legendary.DrinkingHornCover.Equipped()
				   and (Talent.Serenity.Cooldown.Remains() >= 15 or Talent.Serenity.Cooldown.Remains() <= 4)
				   and Player.Energy.TimeToMax() > 2;
			end,

			-- actions.st+=/fists_of_fury,if=talent.serenity.enabled&!equipped.drinking_horn_cover&cooldown.serenity.remains>=5&energy.time_to_max>2
			NoDrinkingHornCover = function()
				return Talent.Serenity.Enabled()
				   and not Legendary.DrinkingHornCover.Equipped()
				   and Talent.Serenity.Cooldown.Remains() >= 5
				   and Player.Energy.TimeToMax() > 2;
			end,
		},

		RisingSunKick = {
			-- actions.st+=/rising_sun_kick,cycle_targets=1,if=!talent.serenity.enabled|cooldown.serenity.remains>=5
			Use = function()
				return not Talent.Serenity.Enabled()
					or Talent.Serenity.Cooldown.Remains() >= 5;
			end,

			-- actions.st+=/rising_sun_kick,cycle_targets=1,if=((chi>=3&energy>=40)|chi>=5)&(!talent.serenity.enabled|cooldown.serenity.remains>=6)
			MaxResources = function()
				return ((Player.Chi() >= 3 and Player.Energy() >= 40) or Player.Chi() >= 5)
				   and (not Talent.Serenity.Enabled() or Talent.Serenity.Cooldown.Remains() >= 6);
			end,
		},

		-- actions.st+=/rushing_jade_wind,if=chi.max-chi>1&!prev_gcd.1.rushing_jade_wind
		RushingJadeWind = function()
			return Player.Chi.Deficit() > 1
			   and not Player.PrevGCD(1, Talent.RushingJadeWind);
		end,

		SpinningCraneKick = {
			-- actions.st+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
			Use = function(numEnemies)
				return numEnemies >= 3
				   and not Player.PrevGCD(1, Spell.SpinningCraneKick);
			end,

			-- actions.st+=/spinning_crane_kick,if=(active_enemies>=3|(buff.bok_proc.up&chi.max-chi>=0))&!prev_gcd.1.spinning_crane_kick&set_bonus.tier21_4pc
			Tier21 = function(numEnemies)
				return (numEnemies >= 3 or (Player.Buff(Buff.BlackoutKick).Up() and Player.Chi.Deficit() >= 0))
				   and not Player.PrevGCD(1, Spell.SpinningCraneKick)
				   and addonTable.Tier21_4PC;
			end,
		},

		-- actions.st+=/strike_of_the_windlord,if=!talent.serenity.enabled|cooldown.serenity.remains>=10
		StrikeOfTheWindlord = function()
			return not Talent.Serenity.Enabled()
				or Talent.Serenity.Cooldown.Remains() >= 10;
		end,

		TigerPalm = {
			-- actions.st+=/tiger_palm,cycle_targets=1,if=!prev_gcd.1.tiger_palm&(chi.max-chi>=2|energy.time_to_max<1)
			Use = function()
				return not Player.PrevGCD(1, Spell.TigerPalm)
				   and (Player.Chi.Deficit() >= 2 or Player.Energy.TimeToMax() < 1);
			end,

			-- actions.st+=/tiger_palm,cycle_targets=1,if=!prev_gcd.1.tiger_palm&energy.time_to_max<=0.5&chi.max-chi>=2
			MaxEnergy = function()
				return not Player.PrevGCD(1, Spell.TigerPalm)
				   and Player.Energy.TimeToMax() <= 0.5
				   and Player.Chi.Deficit() >= 2;
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- actions.st=call_action_list,name=cd
		action.CallActionList(Cooldowns);

		action.EvaluateAction(Talent.EnergizingElixir, self.Requirements.EnergizingElixir);
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);
		action.EvaluateCycleAction(Spell.TigerPalm, self.Requirements.TigerPalm.MaxEnergy);
		action.EvaluateAction(Artifact.StrikeOfTheWindlord, self.Requirements.StrikeOfTheWindlord);
		action.EvaluateCycleAction(Spell.RisingSunKick, self.Requirements.RisingSunKick.MaxResources);
		action.EvaluateAction(Spell.FistsOfFury, self.Requirements.FistsOfFury.NoDrinkingHornCover);
		action.EvaluateAction(Spell.FistsOfFury, self.Requirements.FistsOfFury.DrinkingHornCover);
		action.EvaluateAction(Spell.FistsOfFury, self.Requirements.FistsOfFury.Use);
		action.EvaluateCycleAction(Spell.RisingSunKick, self.Requirements.RisingSunKick.Use);
		-- actions.st+=/whirling_dragon_punch
		action.EvaluateAction(Talent.WhirlingDragonPunch, true);
		action.EvaluateCycleAction(Spell.BlackoutKick, self.Requirements.BlackoutKick.Tier21);
		action.EvaluateAction(Spell.SpinningCraneKick, self.Requirements.SpinningCraneKick.Tier21);
		action.EvaluateAction(Spell.CracklingJadeLightning, self.Requirements.CracklingJadeLightning.Use);
		action.EvaluateAction(Spell.CracklingJadeLightning, self.Requirements.CracklingJadeLightning.Serenity);
		action.EvaluateAction(Spell.SpinningCraneKick, self.Requirements.SpinningCraneKick.Use);
		action.EvaluateAction(Talent.RushingJadeWind, self.Requirements.RushingJadeWind);
		action.EvaluateCycleAction(Spell.BlackoutKick, self.Requirements.BlackoutKick.Use);
		action.EvaluateAction(Talent.ChiWave, self.Requirements.ChiWave);
		action.EvaluateAction(Talent.ChiBurst, self.Requirements.ChiBurst);
		action.EvaluateCycleAction(Spell.TigerPalm, self.Requirements.TigerPalm.Use);
		-- actions.st+=/chi_wave
		action.EvaluateAction(Talent.ChiWave, true);
		-- actions.st+=/chi_burst
		action.EvaluateAction(Talent.ChiBurst, true);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Standard = Standard("Standard");

-- Serenity Opener Rotation
local function StormEarthFire(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.sef+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
		ArcaneTorrent = function()
			return Player.Chi.Deficit() >= 1
			   and Player.Energy.TimeToMax() >= 0.5;
		end,

		-- actions.sef+=/storm_earth_and_fire,if=!buff.storm_earth_and_fire.up
		StormEarthAndFire = function()
			return not Player.Buff(Buff.StormEarthAndFire).Up();
		end,

		-- actions.sef=tiger_palm,cycle_targets=1,if=!prev_gcd.1.tiger_palm&energy=energy.max&chi<1
		TigerPalm = function()
			return not Player.PrevGCD(1, Spell.TigerPalm)
			   and Player.Energy() == Player.Energy.Max()
			   and Player.Chi() < 1;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateCycleAction(Spell.TigerPalm, self.Requirements.TigerPalm);
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- actions.sef+=/call_action_list,name=cd
		action.CallActionList(Cooldowns);

		action.EvaluateAction(Spell.StormEarthAndFire, self.Requirements.StormEarthAndFire);

		-- actions.sef+=/call_action_list,name=st
		action.CallActionList(Standard);
	end

	-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&(buff.storm_earth_and_fire.up|cooldown.storm_earth_and_fire.charges=2)
	-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.strike_of_the_windlord.remains<=18&cooldown.fists_of_fury.remains<=12&chi>=3&cooldown.rising_sun_kick.remains<=1|target.time_to_die<=25|cooldown.touch_of_death.remains>112)&cooldown.storm_earth_and_fire.charges=1
	-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&!equipped.drinking_horn_cover&(cooldown.strike_of_the_windlord.remains<=14&cooldown.fists_of_fury.remains<=6&chi>=3&cooldown.rising_sun_kick.remains<=1|target.time_to_die<=15|cooldown.touch_of_death.remains>112)&cooldown.storm_earth_and_fire.charges=1
	function self.Use()
		return (not Talent.Serenity.Enabled() and (Player.Buff(Buff.StormEarthAndFire).Up() or Spell.StormEarthAndFire.Charges() == 2))
			or (not Talent.Serenity.Enabled() and Legendary.DrinkingHornCover.Equipped() and (Artifact.StrikeOfTheWindlord.Cooldown.Remains() <= 18 and Spell.FistsOfFury.Cooldown.Remains() <= 12 and Player.Chi() >= 3 and Spell.RisingSunKick.Cooldown.Remains() <= 1 or Target.TimeToDie() <= 25 or Spell.TouchOfDeath.Cooldown.Remains() > 112) and Spell.StormEarthAndFire.Charges() == 1)
			or (not Talent.Serenity.Enabled() and not Legendary.DrinkingHornCover.Equipped() and (Artifact.StrikeOfTheWindlord.Cooldown.Remains() <= 14 and Spell.FistsOfFury.Cooldown.Remains() <= 6 and Player.Chi() >= 3 and Spell.RisingSunKick.Cooldown.Remains() <= 1 or Target.TimeToDie() <= 15 or Spell.TouchOfDeath.Cooldown.Remains() > 112) and Spell.StormEarthAndFire.Charges() == 1)
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local StormEarthFire = StormEarthFire("StormEartthFire");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = addonTable.MONK_WINDWALKER,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Babylonius and SimCraft",
		GuideLink = "http://www.icy-veins.com/wow/windwalker-monk-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Single Target"] = "3010032",
		["AOE"] = "1010012",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		DampenHarm = function()
			return Player.PhysicalDamagePredicted(5) >= 25;
		end,

		DiffuseMagic = function()
			return Player.MagicDamagePredicted(3) >= 30;
		end,

		HealingElixir = function()
			return Player.DamagePredicted(3) >= 15
			   and Player.Health.Percent() <= 85;
		end,

		LegSweep = function()
			return Target.InRange(5);
		end,

		-- trinket.proc.agility.react can't be done without long lists of hard coded trinket data, so just skip trinket.proc conditions.
		-- actions+=/potion,if=buff.serenity.up|buff.storm_earth_and_fire.up|(!talent.serenity.enabled&trinket.proc.agility.react)|buff.bloodlust.react|target.time_to_die<=60
		ProlongedPower = function()
			return Player.Buff(Buff.Serenity).Up()
				or Player.Buff(Buff.StormEarthAndFire).Up()
				or not Talent.Serenity.Enabled()
				or Player.HasBloodlust()
				or Target.TimeToDie() <= 60;
		end,

		-- actions+=/touch_of_death,if=target.time_to_die<=9
		TouchOfDeath = function()
			return Target.TimeToDie() <= 9;
		end,

		TouchOfKarma = function()
			return Player.DamagePredicted(5) >= 25;
		end,

		WarStomp = function()
			return Target.InRange(5);
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		-- Spells
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(129597),
			Berserking = Objects.newSpell(26297),
			BloodFury = Objects.newSpell(33697),
			GiftoftheNaaru = Objects.newSpell(59547),
			QuakingPalm = Objects.newSpell(107079),
			Shadowmeld = Objects.newSpell(58984),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Abilities
			StrikeOfTheWindlord = Objects.newSpell(205320),
			-- Traits
			GaleBurst = Objects.newSpell(195399),
		};

		Spell = {
			-- Abilities
			BlackoutKick = Objects.newSpell(100784),
			CracklingJadeLightning = Objects.newSpell(117952),
			FistsOfFury = Objects.newSpell(113656),
			FlyingSerpentKick = Objects.newSpell(101545),
			FlyingSerpentKickLand = Objects.newSpell(115057),
			RisingSunKick = Objects.newSpell(107428),
			SpinningCraneKick = Objects.newSpell(101546),
			StormEarthAndFire = Objects.newSpell(137639),
			TigerPalm = Objects.newSpell(100780),
			TouchOfDeath = Objects.newSpell(115080),
			-- Defensive
			TouchOfKarma = Objects.newSpell(122470),
			-- Utility
			Detox = Objects.newSpell(218164),
			Disable = Objects.newSpell(116095),
			Effuse = Objects.newSpell(116694),
			Paralysis = Objects.newSpell(115078),
			SpearHandStrike = Objects.newSpell(116705),
		};

		Talent = {
			-- Talents
			ChiBurst = Objects.newSpell(123986),
			ChiWave = Objects.newSpell(115098),
			DampenHarm = Objects.newSpell(122278),
			DiffuseMagic = Objects.newSpell(122783),
			EnergizingElixir = Objects.newSpell(115288),
			HealingElixir = Objects.newSpell(122281),
			HitCombo = Objects.newSpell(196741),
			InvokeXuen = Objects.newSpell(123904),
			LegSweep = Objects.newSpell(119381),
			PowerStrikes = Objects.newSpell(121817),
			RushingJadeWind = Objects.newSpell(116847),
			Serenity = Objects.newSpell(152173),
			TigersLust = Objects.newSpell(116841),
			WhirlingDragonPunch = Objects.newSpell(152175),
		};

		Buff = {
			-- Buffs
			BlackoutKick = Objects.newSpell(116768),
			PressurePoint = Objects.newSpell(247255),
			RushingJadeWind = Talent.RushingJadeWind,
			Serenity = Talent.Serenity,
			StormEarthAndFire = Objects.newSpell(137639),
			-- Legendaries
			TheEmperorsCapacitor = Objects.newSpell(235054),
		};

		-- Items
		Legendary = {
			-- Legendaries
			DrinkingHornCover = Objects.newItem(137097),
			HiddenMastersForbiddenTouch = Objects.newItem(137057),
			KatsuosEclipse = Objects.newItem(137029),
			TheEmperorsCapacitor = Objects.newItem(144239),
		};

		Item = {};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.BloodFury, Racial.GiftOfTheNaaru, Racial.Shadowmeld);
		config.AOEOptions(options, Spell.FistsOfFury, Talent.RushingJadeWind, Spell.SpinningCraneKick, Talent.ChiBurst);
		config.CooldownOptions(options, Talent.ChiWave, Talent.EnergizingElixir, Talent.InvokeXuen, Talent.Serenity, Spell.StormEarthAndFire, Artifact.StrikeOfTheWindlord, Spell.TouchOfDeath,
									 Talent.WhirlingDragonPunch);
		config.DefensiveOptions(options, Talent.DampenHarm, Talent.DiffuseMagic, Talent.HealingElixir, Spell.TouchOfKarma);
	end

	-- Function for destroying action objects such as spells, buffs, debuffs and items, called when the rotation is no longer the active rotation.
	function self.Disable()
		Racial = nil;
		Artifact = nil;
		Spell = nil;
		Talent = nil;
		Buff = nil;
		Legendary = nil;
		Item = nil;
		Consumable = nil;
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
		-- The abilities here should be listed from highest damage required to suggest to lowest,
		-- Specific damage types before all damage types.

		-- Redirect damage back to target
		action.EvaluateDefensiveAction(Spell.TouchOfKarma, self.Requirements.TouchOfKarma);

		-- Protects against magical damage
		action.EvaluateDefensiveAction(Talent.DiffuseMagic, self.Requirements.DiffuseMagic);

		-- Protects against physical damage
		action.EvaluateDefensiveAction(Talent.DampenHarm, self.Requirements.DampenHarm);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Talent.HealingElixir, self.Requirements.HealingElixir);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.SpearHandStrike, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Racial.QuakingPalm, true);
			action.EvaluateInterruptAction(Talent.LegSweep, self.Requirements.LegSweep);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
		end

		-- Crowd Control
		action.EvaluateInterruptAction(Spell.Paralysis, true);
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- actions.precombat+=/chi_burst
		action.EvaluateAction(Talent.ChiBurst, true);
		-- actions.precombat+=/chi_wave
		action.EvaluateAction(Talent.ChiWave, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Spell.TouchOfDeath, self.Requirements.TouchOfDeath);

		action.CallActionList(Serenity);
		action.CallActionList(StormEarthFire);
		-- actions+=/call_action_list,name=st
		action.CallActionList(Standard);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Windwalker Monk", addonTable.Enum.SpecID.MONK_WINDWALKER);