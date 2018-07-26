local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

local Core = addon.Core.General;
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_warrior_arms";

-- AOE Rotation
local function AOE(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.aoe+=/bladestorm,if=buff.battle_cry.up&!talent.ravager.enabled
		Bladestorm = function()
			return Player.Buff(Buff.BattleCry).Up()
			   and not Talent.Ravager.Enabled();
		end,

		-- actions.aoe+=/cleave,if=spell_targets.whirlwind>=5
		Cleave = function(numEnemies)
			return numEnemies >= 5;
		end,

		ColossusSmash = {
			-- actions.aoe+=/colossus_smash,if=buff.shattered_defenses.down
			Use = function()
				return Player.Buff(Buff.ShatteredDefenses).Down();
			end,

			-- actions.aoe+=/colossus_smash,cycle_targets=1,if=debuff.colossus_smash.down&spell_targets.whirlwind<=10
			Cycle = function(numEnemies, Target)
				return Target.Debuff(Debuff.ColossusSmash).Down()
				   and numEnemies <= 10;
			end,

			-- actions.aoe+=/colossus_smash,if=buff.in_for_the_kill.down&talent.in_for_the_kill.enabled
			InForTheKill = function()
				return Player.Buff(Buff.InForTheKill).Down()
				   and Talent.InForTheKill.Enabled();
			end,
		},

		-- actions.aoe+=/execute,if=buff.stone_heart.react
		Execute = function()
			return Player.Buff(Buff.StoneHeart).React();
		end,

		-- actions.aoe+=/mortal_strike,if=buff.shattered_defenses.up|buff.executioners_precision.down
		MortalStrike = function()
			return Player.Buff(Buff.ShatteredDefenses).Up()
				or Player.Buff(Buff.ExecutionersPrecision).Down();
		end,

		-- actions.aoe+=/ravager,if=talent.ravager.enabled&cooldown.battle_cry.remains<=gcd&debuff.colossus_smash.remains>6
		Ravager = function()
			return Talent.Ravager.Enabled()
			   and Spell.BattleCry.Cooldown.Remains() <= Player.GCD()
			   and Target.Debuff(Debuff.ColossusSmash).Remains() > 6;
		end,

		-- actions.aoe+=/rend,cycle_targets=1,if=remains<=duration*0.3&spell_targets.whirlwind<=3
		Rend = function(numEnemies, Target)
			return Target.Debuff(Debuff.Rend).Refreshable()
			   and numEnemies <= 3;
		end,

		-- actions.aoe=warbreaker,if=(cooldown.bladestorm.up|cooldown.bladestorm.remains<=gcd)&(cooldown.battle_cry.up|cooldown.battle_cry.remains<=gcd)
		Warbreaker = function()
			return (Spell.Bladestorm.Cooldown.Up() or Spell.Bladestorm.Cooldown.Remains() <= Player.GCD())
			   and (Spell.BattleCry.Cooldown.Up() or Spell.BattleCry.Cooldown.Remains() <= Player.GCD());
		end,

		Whirlwind = {
			-- actions.aoe+=/whirlwind,if=spell_targets.whirlwind>=7
			Use = function(numEnemies)
				return numEnemies >= 7;
			end,

			-- actions.aoe+=/whirlwind,if=spell_targets.whirlwind>=5&buff.cleave.up
			Cleave = function(numEnemies)
				return numEnemies >= 5
				   and Player.Buff(Buff.Cleave).Up();
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Artifact.Warbreaker, self.Requirements.Warbreaker);
		action.EvaluateAction(Spell.Bladestorm, self.Requirements.Bladestorm);
		action.EvaluateAction(Talent.Ravager, self.Requirements.Ravager);
		action.EvaluateAction(Spell.ColossusSmash, self.Requirements.ColossusSmash.InForTheKill);
		action.EvaluateCycleAction(Spell.ColossusSmash, self.Requirements.ColossusSmash.Cycle, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.Cleave, self.Requirements.Cleave, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.Whirlwind, self.Requirements.Whirlwind.Cleave, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.Whirlwind, self.Requirements.Whirlwind.Use, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.ColossusSmash, self.Requirements.ColossusSmash.Use);
		action.EvaluateAction(Spell.Execute, self.Requirements.Execute);
		action.EvaluateAction(Spell.MortalStrike, self.Requirements.MortalStrike);
		action.EvaluateCycleAction(Talent.Rend, self.Requirements.Rend, Enemies.GetEnemies(8));
		-- actions.aoe+=/cleave
		action.EvaluateAction(Spell.Cleave, true);
		-- actions.aoe+=/whirlwind
		action.EvaluateAction(Spell.Whirlwind, true);


	end

	-- actions+=/run_action_list,name=aoe,if=spell_targets.whirlwind>=4
	function self.Use(numEnemies)
		return numEnemies >= 4;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local AOE = AOE("AOE");

-- Cleave Rotation
local function Cleave(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.cleave=bladestorm,if=buff.battle_cry.up&!talent.ravager.enabled
		Bladestorm = function()
			return Player.Buff(Buff.BattleCry).Up()
			   and not Talent.Ravager.Enabled();
		end,

		-- actions.cleave+=/colossus_smash,cycle_targets=1,if=debuff.colossus_smash.down
		ColossusSmash = function(numEnemies, Target)
			return Target.Debuff(Debuff.ColossusSmash).Down();
		end,

		-- actions.cleave+=/focused_rage,if=rage.deficit<35&buff.focused_rage.stack<3
		FocusedRage = function()
			return Player.Rage.Deficit() < 35
			   and Player.Buff(Buff.FocusedRage).Stack() < 3;
		end,

		-- actions.cleave+=/ravager,if=talent.ravager.enabled&cooldown.battle_cry.remains<=gcd&debuff.colossus_smash.remains>6
		Ravager = function()
			return Talent.Ravager.Enabled()
			   and Spell.BattleCry.Cooldown.Remains() <= Player.GCD()
			   and Target.Debuff(Debuff.ColossusSmash).Remains() > 6;
		end,

		-- actions.cleave+=/rend,cycle_targets=1,if=remains<=duration*0.3
		Rend = function(numEnemies, Target)
			return Target.Debuff(Debuff.Rend).Refreshable();
		end,

		-- Can't do raid events so just skip these.
		-- actions.cleave+=/warbreaker,if=raid_event.adds.in>90&buff.shattered_defenses.down
		Warbreaker = function()
			return Player.Buff(Buff.ShatteredDefenses).Down();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Bladestorm, self.Requirements.Bladestorm);
		action.EvaluateAction(Talent.Ravager, self.Requirements.Ravager);
		action.EvaluateCycleAction(Spell.ColossusSmash, self.Requirements.ColossusSmash);
		action.EvaluateAction(Artifact.Warbreaker, self.Requirements.Warbreaker);
		action.EvaluateAction(Talent.FocusedRage, self.Requirements.FocusedRage);
		action.EvaluateCycleAction(Talent.Rend, self.Requirements.Rend);
		-- actions.cleave+=/mortal_strike
		action.EvaluateAction(Spell.MortalStrike, true);
		-- actions.cleave+=/execute
		action.EvaluateAction(Spell.Execute, true);
		-- actions.cleave+=/cleave
		action.EvaluateAction(Spell.Cleave, true);
		-- actions.cleave+=/whirlwind
		action.EvaluateAction(Spell.Whirlwind, true);
	end

	-- actions+=/run_action_list,name=cleave,if=spell_targets.whirlwind>=2
	function self.Use(numEnemies)
		return numEnemies >= 2;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Cleave = Cleave("Cleave");

-- Execute Rotation
local function Execute(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Bladestorm = {
			-- Can't do raid events so just skip these.
			-- actions.execute+=/bladestorm,interrupt=1,if=(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)&!set_bonus.tier20_4pc
			Use = function(numEnemies)
				return numEnemies > Core.DesiredTargets()
				   and not addonTable.Tier20_4PC;
			end,

			-- actions.execute=bladestorm,if=buff.battle_cry.up&(set_bonus.tier20_4pc|equipped.the_great_storms_eye)
			Tier20 = function()
				return Player.Buff(Buff.BattleCry).Up()
				   and (addonTable.Tier20_4PC or Legendary.TheGreatStormsEye.Equipped());
			end,
		},

		-- actions.execute+=/colossus_smash,if=buff.shattered_defenses.down&(buff.battle_cry.down|(buff.executioners_precision.stack=2&(cooldown.battle_cry.remains<1|buff.battle_cry.up)))
		ColossusSmash = function()
			return Player.Buff(Buff.ShatteredDefenses).Down()
			   and (Player.Buff(Buff.BattleCry).Down() or (Player.Buff(Buff.ExecutionersPrecision).Stack() == 2 and (Spell.BattleCry.Cooldown.Remains() < 1 or Player.Buff(Buff.BattleCry).Up())));
		end,

		-- actions.execute+=/execute,if=buff.shattered_defenses.down|rage>=40|talent.dauntless.enabled&rage>=36
		Execute = function()
			return Player.Buff(Buff.ShatteredDefenses).Down()
				or Player.Rage() >= 40
				or Talent.Dauntless.Enabled()
			   and Player.Rage() >= 36;
		end,

		-- actions.execute+=/focused_rage,if=rage.deficit<35&buff.focused_rage.stack<3
		FocusedRage = function()
			return Player.Rage.Deficit() < 35
			   and Player.Buff(Buff.FocusedRage).Stack() < 3;
		end,

		-- actions.execute+=/mortal_strike,if=buff.executioners_precision.stack=2&buff.shattered_defenses.up
		MortalStrike = function()
			return Player.Buff(Buff.ExecutionersPrecision).Stack() == 2
			   and Player.Buff(Buff.ShatteredDefenses).Up();
		end,

		-- actions.execute+=/overpower,if=rage<40
		Overpower = function()
			return Player.Rage() < 40;
		end,

		-- actions.execute+=/ravager,if=cooldown.battle_cry.remains<=gcd&debuff.colossus_smash.remains>6
		Ravager = function()
			return Spell.BattleCry.Cooldown.Remains() <= Player.GCD()
			   and Target.Debuff(Debuff.ColossusSmash).Remains() > 6;
		end,

		-- actions.execute+=/rend,if=remains<5&cooldown.battle_cry.remains<2&(cooldown.bladestorm.remains<2|!set_bonus.tier20_4pc)
		Rend = function()
			return Target.Debuff(Debuff.Rend).Remains() < 5
			   and Spell.BattleCry.Cooldown.Remains() < 2
			   and (Spell.Bladestorm.Cooldown.Remains() < 2 or not addonTable.Tier20_4PC);
		end,

		-- Can't do raid events so just skip these.
		-- actions.execute+=/warbreaker,if=(raid_event.adds.in>90|!raid_event.adds.exists)&cooldown.mortal_strike.remains<=gcd.remains&buff.shattered_defenses.down&buff.executioners_precision.stack=2
		Warbreaker = function()
			return Spell.MortalStrike.Cooldown.Remains() <= Player.GCD.Remains()
			   and Player.Buff(Buff.ShatteredDefenses).Down()
			   and Player.Buff(Buff.ExecutionersPrecision).Stack() == 2;
		end,

		-- actions.execute+=/whirlwind,if=talent.fervor_of_battle.enabled&buff.weighted_blade.stack=3&debuff.colossus_smash.up&buff.battle_cry.down
		Whirlwind = function()
			return Talent.FervorOfBattle.Enabled()
			   and Player.Buff(Buff.WeightedBlade).Stack() == 3
			   and Target.Debuff(Debuff.ColossusSmash).Up()
			   and Player.Buff(Buff.BattleCry).Down();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Bladestorm, self.Requirements.Bladestorm.Tier20);
		action.EvaluateAction(Spell.ColossusSmash, self.Requirements.ColossusSmash);
		action.EvaluateAction(Artifact.Warbreaker, self.Requirements.Warbreaker);
		action.EvaluateAction(Talent.FocusedRage, self.Requirements.FocusedRage);
		action.EvaluateAction(Talent.Rend, self.Requirements.Rend);
		action.EvaluateAction(Talent.Ravager, self.Requirements.Ravager);
		action.EvaluateAction(Spell.MortalStrike, self.Requirements.MortalStrike);
		action.EvaluateAction(Spell.Whirlwind, self.Requirements.Whirlwind);
		action.EvaluateAction(Talent.Overpower, self.Requirements.Overpower);
		action.EvaluateAction(Spell.Execute, self.Requirements.Execute);
		action.EvaluateInterruptCondition(Spell.Bladestorm, self.Requirements.Bladestorm.Use, true, Enemies.GetEnemies(8));
	end

	-- actions+=/run_action_list,name=execute,target_if=target.health.pct<=20&spell_targets.whirlwind<5
	function self.Use(numEnemies)
		return Target.Health.Percent() <= 20
		   and numEnemies < 5;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Execute = Execute("Execute");

-- SingleTarget Rotation
local function SingleTarget(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Bladestorm = {
			-- We can't do raid events, so just skip these.
			-- actions.single+=/bladestorm,if=(raid_event.adds.in>90|!raid_event.adds.exists)&!set_bonus.tier20_4pc
			Use = function()
				return not addonTable.Tier20_4PC;
			end,

			-- actions.single=bladestorm,if=buff.battle_cry.up&(set_bonus.tier20_4pc|equipped.the_great_storms_eye)
			Tier20 = function()
				return Player.Buff(Buff.BattleCry).Up()
				   and (addonTable.Tier20_4PC or Legendary.TheGreatStormsEye.Equipped());
			end,
		},

		-- actions.single+=/cleave,if=talent.fervor_of_battle.enabled&buff.cleave.down&!equipped.archavons_heavy_hand
		Cleave = function()
			return Talent.FervorOfBattle.Enabled()
			   and Player.Buff(Buff.Cleave).Down()
			   and not Legendary.ArchavonsHeavyHand.Equipped();
		end,

		-- actions.single+=/colossus_smash,if=buff.shattered_defenses.down
		ColossusSmash = function()
			return Player.Buff(Buff.ShatteredDefenses).Down();
		end,

		-- actions.single+=/execute,if=buff.stone_heart.react
		Execute = function()
			return Player.Buff(Buff.StoneHeart).React();
		end,

		-- actions.single+=/focused_rage,if=!buff.battle_cry_deadly_calm.up&buff.focused_rage.stack<3&!cooldown.colossus_smash.up&(rage>=130|debuff.colossus_smash.down|talent.anger_management.enabled&cooldown.battle_cry.remains<=8)
		FocusedRage = function()
			return not(Talent.DeadlyCalm.Enabled() and Player.Buff(Buff.BattleCry).Up())
			   and Player.Buff(Buff.FocusedRage).Stack() < 3
			   and not Spell.ColossusSmash.Cooldown.Up()
			   and (Player.Rage() >= 130 or Target.Debuff(Debuff.ColossusSmash).Down() or Talent.AngerManagement.Enabled() and Spell.BattleCry.Cooldown.Remains() <= 8);
		end,

		-- actions.single+=/mortal_strike,if=buff.shattered_defenses.up|buff.executioners_precision.down
		MortalStrike = function()
			return Player.Buff(Buff.ShatteredDefenses).Up()
				or Player.Buff(Buff.ExecutionersPrecision).Down();
		end,

		-- actions.single+=/overpower,if=buff.battle_cry.down
		Overpower = function()
			return Player.Buff(Buff.BattleCry).Down();
		end,

		-- actions.single+=/ravager,if=cooldown.battle_cry.remains<=gcd&debuff.colossus_smash.remains>6
		Ravager = function()
			return Spell.BattleCry.Cooldown.Remains() <= Player.GCD()
			   and Target.Debuff(Debuff.ColossusSmash).Remains() > 6;
		end,

		Rend = {
			-- actions.single+=/rend,if=remains<=gcd.max|remains<5&cooldown.battle_cry.remains<2&(cooldown.bladestorm.remains<2|!set_bonus.tier20_4pc)
			Use = function()
				return Target.Debuff(Debuff.Rend).Remains() <= Player.GCD()
					or Target.Debuff(Debuff.Rend).Remains() < 5
				   and Spell.BattleCry.Cooldown.Remains() < 2
				   and (Spell.Bladestorm.Cooldown.Remains() < 2 or not addonTable.Tier20_4PC);
			end,

			-- actions.single+=/rend,if=remains<=duration*0.3
			Refresh = function()
				return Target.Debuff(Debuff.Rend).Refreshable();
			end,
		},

		-- actions.single+=/slam,if=spell_targets.whirlwind=1&!talent.fervor_of_battle.enabled&(rage>=52|!talent.rend.enabled|!talent.ravager.enabled)
		Slam = function(numEnemies)
			return numEnemies == 1
			   and not Talent.FervorOfBattle.Enabled()
			   and (Player.Rage() >= 52 or not Talent.Rend.Enabled() or not Talent.Ravager.Enabled());
		end,

		-- We can't do raid events so just ignore these
		-- actions.single+=/warbreaker,if=(raid_event.adds.in>90|!raid_event.adds.exists)&((talent.fervor_of_battle.enabled&debuff.colossus_smash.remains<gcd)|!talent.fervor_of_battle.enabled&((buff.stone_heart.up|cooldown.mortal_strike.remains<=gcd.remains)&buff.shattered_defenses.down))
		Warbreaker = function()
			return (Talent.FervorOfBattle.Enabled() and Target.Debuff(Debuff.ColossusSmash).Remains() < Player.GCD())
				or not Talent.FervorOfBattle.Enabled()
			   and ((Player.Buff(Buff.StoneHeart).Up() or Spell.MortalStrike.Cooldown.Remains() <= Player.GCD.Remains()) and Player.Buff(Buff.ShatteredDefenses).Down());
		end,

		-- actions.single+=/whirlwind,if=spell_targets.whirlwind>1|talent.fervor_of_battle.enabled
		Whirlwind = function(numEnemies)
			return numEnemies > 1
				or Talent.FervorOfBattle.Enabled();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Bladestorm, self.Requirements.BladeStorm.Tier20);
		action.EvaluateAction(Spell.ColossusSmash, self.Requirements.ColossusSmash);
		action.EvaluateAction(Artifact.Warbreaker, self.Requirements.Warbreaker);
		action.EvaluateAction(Talent.FocusedRage, self.Requirements.FocusedRage);
		action.EvaluateAction(Talent.Rend, self.Requirements.Rend.Use);
		action.EvaluateAction(Talent.Ravager, self.Requirements.Ravager);
		action.EvaluateAction(Spell.Execute, self.Requirements.Execute);
		action.EvaluateAction(Talent.Overpower, self.Requirements.Overpower);
		action.EvaluateAction(Spell.MortalStrike, self.Requirements.MortalStrike);
		action.EvaluateAction(Talent.Rend, self.Requirements.Rend.Refresh);
		action.EvaluateAction(Spell.Cleave, self.Requirements.Cleave);
		action.EvaluateAction(Spell.Whirlwind, self.Requirements.Whirlwind, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.Slam, self.Requirements.Slam, Enemies.GetEnemies(8));
		-- actions.single+=/overpower
		action.EvaluateAction(Talent.Overpower, true);
		action.EvaluateAction(Spell.Bladestorm, self.Requirements.Bladestorm.Use);
	end

	-- actions+=/run_action_list,name=single,if=target.health.pct>20
	function self.Use()
		return Target.Health.Percent() > 20;
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
		GuideAuthor = "Archimtiros and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/arms-warrior-pve-dps-guide",
		WoWVersion = 703025
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Dungeons / Raiding"] = "1010122",
		["World Quests"] = "3010122",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = {
			-- actions+=/arcane_torrent,if=buff.battle_cry_deadly_calm.down&rage.deficit>40&cooldown.battle_cry.remains
			Use = function()
				return (not Talent.DeadlyCalm.Enabled() or Player.Buff(Buff.BattleCry).Down())
				   and Player.Rage.Deficit() > 40
				   and not Spell.BattleCry.Cooldown.Up();
			end,

			Interrupt = function()
				return Target.InRange(8);
			end,
		},

		-- actions+=/avatar,if=gcd.remains<0.25&(buff.battle_cry.up|cooldown.battle_cry.remains<15)|target.time_to_die<=20
		Avatar = function()
			return Player.GCD.Remains() < 0.25
			   and (Player.Buff(Buff.BattleCry).Up() or Spell.BattleCry.Cooldown.Remains() < 15)
				or Target.TimeToDie() <= 20;
		end,

		-- Do not do the check for not on global cooldown as this would massively restrict suggestion.
		-- actions+=/battle_cry,if=((target.time_to_die>=70|set_bonus.tier20_4pc)&((gcd.remains<=0.5&prev_gcd.1.ravager)|!talent.ravager.enabled&!gcd.remains&target.debuff.colossus_smash.remains>=5&(!cooldown.bladestorm.remains|!set_bonus.tier20_4pc)&(!talent.rend.enabled|dot.rend.remains>4)))|buff.executioners_precision.stack=2&buff.shattered_defenses.up&!gcd.remains&!set_bonus.tier20_4pc
		BattleCry = function()
			return ((Target.TimeToDie() >= 70 or addonTable.Tier20_4PC) and ((Player.GCD.Remains() <= 0.5 and Player.PrevGCD(1, Talent.Ravager)) or not Talent.Ravager.Enabled() and Target.Debuff(Debuff.ColossusSmash).Remains() >= 5 and (Spell.Bladestorm.Cooldown.Up() or not addonTable.Tier20_4PC) and (not Talent.Rend.Enabled() or Target.Debuff(Debuff.Rend).Remains() > 4)))
				or Player.Buff(Buff.ExecutionersPrecision).Stack() == 2
			   and Player.Buff(Buff.ShatteredDefenses).Up()
			   and not addonTable.Tier20_4PC;
		end,

		-- actions+=/berserking,if=buff.battle_cry.up|target.time_to_die<=11
		Berserking = function()
			return Player.Buff(Buff.BattleCry).Up()
				or Target.TimeToDie() <= 11;
		end,

		-- actions+=/blood_fury,if=buff.battle_cry.up|target.time_to_die<=16
		BloodFury = function()
			return Player.Buff(Buff.BattleCry).Up()
				or Target.TimeToDie() <= 16;
		end,

		CommandingShout = function()
			return Player.DamagePredicted(5) >= 50;
		end,

		DieByTheSword = {
			All = function()
				return Player.DamagePredicted(4) >= 30;
			end,

			Physical = function()
				return Player.PhysicalDamagePredicted(8) >= 30;
			end,
		},

		-- actions+=/potion,name=old_war,if=(!talent.avatar.enabled|buff.avatar.up)&buff.battle_cry.up&debuff.colossus_smash.up|target.time_to_die<=26
		OldWar = function()
			return (not Talent.Avatar.Enabled() or Player.Buff(Buff.Avatar).Up())
			   and Player.Buff(Buff.BattleCry).Up()
			   and Target.Debuff(Debuff.ColossusSmash).Up()
				or Target.TimeToDie() <= 26;
		end,

		VictoryRush = function()
			return Player.Buff(Buff.VictoryRush).Up()
			   and Player.Health.Percent() <= 70;
		end,

		WarStomp = function()
			return Target.InRange(5);
		end,
	};

	-- Add meta-table to the requirements table, to enable better debugging and case insensitivity.
	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(69179),
			Berserking = Objects.newSpell(26297),
			BloodFury = Objects.newSpell(33697),
			GiftOfTheNaaru = Objects.newSpell(59547),
			QuakingPalm = Objects.newSpell(107079),
			Shadowmeld = Objects.newSpell(58984),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Abilities
			Warbreaker = Objects.newSpell(209577),
		};

		Spell = {
			-- Abilities
			BattleCry = Objects.newSpell(1719),
			BerserkerRage = Objects.newSpell(18499),
			Bladestorm = Objects.newSpell(227847),
			Cleave = Objects.newSpell(845),
			ColossusSmash = Objects.newSpell(167105),
			CommandingShout = Objects.newSpell(97462),
			Execute = Objects.newSpell(163201),
			MortalStrike = Objects.newSpell(12294),
			Slam = Objects.newSpell(1464),
			VictoryRush = Objects.newSpell(34428),
			Whirlwind = Objects.newSpell(1680),
			-- Crowd Control
			Hamstring = Objects.newSpell(1715),
			IntimidatingShout = Objects.newSpell(5246),
			Pummel = Objects.newSpell(6552),
			-- Defensive
			DieByTheSword = Objects.newSpell(118038),
			-- Utility
			Charge = Objects.newSpell(100),
			HeroicLeap = Objects.newSpell(6544),
			HeroicThrow = Objects.newSpell(57755),
			Taunt = Objects.newSpell(355),
		};

		Talent = {
			-- Active Talents
			Avatar = Objects.newSpell(107574),
			DefensiveStance = Objects.newSpell(197690),
			FocusedRage = Objects.newSpell(207982),
			Overpower = Objects.newSpell(7384),
			Ravager = Objects.newSpell(152277),
			Rend = Objects.newSpell(772),
			Shockwave = Objects.newSpell(46968),
			StormBolt = Objects.newSpell(107570),
			-- Passive Talents
			AngerManagement = Objects.newSpell(152278),
			BoundingStride = Objects.newSpell(202163),
			Dauntless = Objects.newSpell(202297),
			DeadlyCalm = Objects.newSpell(227266),
			DoubleTime = Objects.newSpell(103827),
			FervorOfBattle = Objects.newSpell(202316),
			InForTheKill = Objects.newSpell(248621),
			MortalCombo = Objects.newSpell(202593),
			OpportunityStrikes = Objects.newSpell(203179),
			SecondWind = Objects.newSpell(29838),
			SweepingStrikes = Objects.newSpell(202161),
			TitanicMight = Objects.newSpell(202612),
			Trauma = Objects.newSpell(215538),
		};

		Buff = {
			-- Buffs
			Avatar = Talent.Avatar,
			BattleCry = Spell.BattleCry,
			BerserkerRage = Spell.BerserkerRage,
			Bladestorm = Spell.Bladestorm,
			BoundingStride = Talent.BoundingStride,
			Cleave = Objects.newSpell(188923),
			CommandingShout = Spell.CommandingShout,
			DefensiveStance = Talent.DefensiveStance,
			DieByTheSword = Spell.DieByTheSword,
			ExecutionersPrecision = Objects.newSpell(242188),
			FocusedRage = Talent.FocusedRage,
			InForTheKill = Objects.newSpell(248622),
			Overpower = Objects.newSpell(24407),
			PreciseStrikes = Objects.newSpell(248195),
			Ravager = Talent.Ravager,
			SecondWind = Objects.newSpell(202149),
			ShatteredDefenses = Objects.newSpell(248625),
			Tactician = Objects.newSpell(199854),
			VictoryRush = Objects.newSpell(210057),
			WeightedBlade = Objects.newSpell(253383),
			-- Legendary
			StoneHeart = Objects.newSpell(225947),
		};

		Debuff = {
			-- Debuffs
			ColossusSmash = Objects.newSpell(208086),
			DeepWounds = Objects.newSpell(115767),
			Hamstring = Spell.Hamstring,
			IntimidatingShout = Spell.IntimidatingShout,
			Rend = Talent.Rend,
			Shockwave = Talent.Shockwave,
			Stormbolt = Talent.Stormbolt,
			Taunt = Spell.Taunt,
			Trauma = Objects.newSpell(215537),
		};

		Legendary = {
			ArchavonsHeavyHand = Objects.newItem(137060),
			TheGreatStormsEye = Objects.newItem(151823),
		};

		Item = {};

		Consumable = {
			-- Potions
			OldWar = Objects.newItem(127844),
		};

		-- Add meta-table to the various object tables, to enable better debugging and case insensitivity.
		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.BloodFury, Racial.GiftOfTheNaaru, Racial.Shadowmeld);
		config.AOEOptions(options, Spell.Bladestorm, Artifact.Warbreaker, Spell.Whirlwind);
		config.CooldownOptions(options, Talent.Avatar, Spell.BattleCry, Spell.BerserkerRage, Spell.CommandingShout, Talent.FocusedRage, Talent.Overpower,
									 Talent.Ravager, Talent.Rend, Talent.Shockwave, Talent.StormBolt, Spell.VictoryRush);
		config.DefensiveOptions(options, Talent.DefensiveStance, Spell.DieByTheSword);
		config.UtilityOptions(options, Spell.Charge, Spell.Hamstring, Spell.HeroicLeap, Spell.HeroicThrow, Spell.IntimidatingShout, Spell.Taunt);
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

		-- Buff to increase health.
		action.EvaluateDefensiveAction(Spell.CommandingShout, self.Requirements.CommandingShout);

		-- Protects against physical damage
		action.EvaluateDefensiveAction(Spell.DieByTheSword, self.Requirements.DieByTheSword.Physical);

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.DieByTheSword, self.Requirements.DieByTheSword.All);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.VictoryRush, self.Requirements.VictoryRush);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.Pummel, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent.Interrupt);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Talent.StormBolt, true);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion,name=old_war
		action.EvaluateAction(Consumable.OldWar, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		-- actions=charge
		action.EvaluateAction(Spell.Charge, true);
		action.EvaluateAction(Consumable.OldWar, self.Requirements.OldWar);
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent.Use);
		action.EvaluateAction(Talent.Avatar, self.Requirements.Avatar);
		action.EvaluateAction(Spell.BattleCry, self.Requirements.BattleCry);

		action.RunActionList(Execute, Enemies.GetEnemies(8));
		action.RunActionList(AOE, Enemies.GetEnemies(8));
		action.RunActionList(Cleave, Enemies.GetEnemies(8));
		action.RunActionList(SingleTarget);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Arms Warrior", addonTable.Enum.SpecID.WARRIOR_ARMS);