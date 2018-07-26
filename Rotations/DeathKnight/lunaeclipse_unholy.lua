local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;
local UndeadSummons = addonTable.UndeadSummons;

-- Objects
local Pet = addon.Units.Pet;
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_deathknight_unholy";

-- Creature IDs for Undead Tracker
local Undead = {
	Apocalypse = 999999, -- Fake creatureID to seperate Army of the Dead Ghouls from Apocalypse Ghouls
	ArmyOfTheDead = 24207,
	DarkArbiter = 100876,
	Gargoyle = 27829,
	ShamblingHorror = 97055,
	Skulker = 99541,
};

-- AOE Rotation
local function AOE(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(death_and_decay.ticking|defile.ticking)
		ClawingShadows = function(numEnemies)
			return numEnemies >= 2
			   and Player.Buff(Buff.DeathAndDecay).Up();
		end,

		-- actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
		DeathAndDecay = function(numEnemies)
			return numEnemies >= 2;
		end,

		Epidemic = {
			-- actions.aoe+=/epidemic,if=spell_targets.epidemic>2
			Use = function(numEnemies)
				return numEnemies > 2;
			end,

			-- actions.aoe+=/epidemic,if=spell_targets.epidemic>4
			AOE = function(numEnemies)
				return numEnemies > 4;
			end,
		},

		-- actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(death_and_decay.ticking|defile.ticking)
		ScourgeStrike = function(numEnemies)
			 return numEnemies >= 2
			   and Player.Buff(Buff.DeathAndDecay).Up();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.DeathAndDecay, self.Requirements.DeathAndDecay, Enemies.GetEnemies(8));
		action.EvaluateAction(Talent.Epidemic, self.Requirements.Epidemic.AOE);
		action.EvaluateAction(Spell.ScourgeStrike, self.Requirements.ScourgeStrike);
		action.EvaluateAction(Talent.ClawingShadows, self.Requirements.ClawingShadows);
		action.EvaluateAction(Talent.Epidemic, self.Requirements.Epidemic.Use);
	end

	function self.Use(numEnemies)
		-- actions.generic+=/call_action_list,name=aoe,if=active_enemies>=2
		return numEnemies >= 2;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local AOE = AOE("AOE");

-- Cold Heart Rotation
local function ColdHeart(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ChainsOfIce = {
			-- actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack=20&buff.unholy_strength.react
			Use = function()
				return Player.Buff(Buff.ColdHeart).Stack() == 20
				   and Player.Buff(Buff.UnholyStrength).React();
			end,

			-- actions.cold_heart+=/chains_of_ice,if=buff.master_of_ghouls.remains<gcd&buff.master_of_ghouls.up&buff.cold_heart.stack>17
			MasterOfGhouls = function()
				return Player.Buff(Buff.MasterOfGhouls).Remains() < Player.GCD()
				   and Player.Buff(Buff.MasterOfGhouls).Up()
				   and Player.Buff(Buff.ColdHeart).Stack() > 17;
			end,

			-- actions.cold_heart=chains_of_ice,if=buff.unholy_strength.remains<gcd&buff.unholy_strength.react&buff.cold_heart.stack>16
			UnholyStrength = function()
				return Player.Buff(Buff.UnholyStrength).Remains() < Player.GCD()
				   and Player.Buff(Buff.UnholyStrength).React()
				   and Player.Buff(Buff.ColdHeart).Stack() > 16;
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.UnholyStrength);
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.MasterOfGhouls);
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.Use);
	end

	-- actions.cooldowns=call_action_list,name=cold_heart,if=equipped.cold_heart&buff.cold_heart.stack>10&!debuff.soul_reaper.up
	function self.Use()
		return Legendary.ColdHeart.Equipped()
		   and Player.Buff(Buff.ColdHeart).Stack() > 10
		   and not Target.Debuff(Debuff.SoulReaper).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local ColdHeart = ColdHeart("ColdHeart");

-- Dark Transformation Rotation
local function DarkTransformation(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- Simcraft doesn't specify pet as active, but the spell needs a summoned pet
		DarkTransformation = {
			-- actions.dt+=/dark_transformation,if=!equipped.137075&rune.time_to_4>=gcd
			Use = function(...)
				return Pet.IsActive()
					and not Legendary.TaktheritrixsShoulderpads.Equipped()
					and Player.Runes.TimeToX(4) >= Player.GCD();
			end,

			DarkArbiter = {
				-- actions.dt+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
				Use = function()
					return Pet.IsActive()
						and Legendary.TaktheritrixsShoulderpads.Equipped()
						and Target.TimeToDie() < Talent.DarkArbiter.Cooldown.Remains() - 8;
				end,

				-- actions.dt+=/dark_transformation,if=equipped.137075&(talent.shadow_infusion.enabled|cooldown.dark_arbiter.remains>(52*1.333))&equipped.140806&cooldown.dark_arbiter.remains>(30*1.333)
				ConvergenceOfFates = function()
					return Pet.IsActive()
						and Legendary.TaktheritrixsShoulderpads.Equipped()
						and (Talent.ShadowInfusion.Enabled() or Talent.DarkArbiter.Cooldown.Remains() > (52 * 1.333))
						and Item.ConvergenceOfFates.Equipped()
						and Talent.DarkArbiter.Cooldown.Remains() > (30 * 1.333);
				end,

				-- actions.dt=dark_transformation,if=equipped.137075&talent.dark_arbiter.enabled&(talent.shadow_infusion.enabled|cooldown.dark_arbiter.remains>52)&cooldown.dark_arbiter.remains>30&!equipped.140806
				NoConvergenceOfFates = function()
					return Pet.IsActive()
						and Legendary.TaktheritrixsShoulderpads.Equipped()
						and Talent.DarkArbiter.Enabled()
						and (Talent.ShadowInfusion.Enabled() or Talent.DarkArbiter.Cooldown.Remains() > 52)
						and Talent.DarkArbiter.Cooldown.Remains() > 30
						and not Item.ConvergenceOfFates.Equipped();
				end,
			},

			SummonGargoyle = {
				-- actions.dt+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
				Use = function()
					return Pet.IsActive()
						and Legendary.TaktheritrixsShoulderpads.Equipped()
						and Target.TimeToDie() < Spell.SummonGargoyle.Cooldown.Remains() - 8;
				end,

				-- actions.dt+=/dark_transformation,if=equipped.137075&(talent.shadow_infusion.enabled|cooldown.summon_gargoyle.remains>55)&cooldown.summon_gargoyle.remains>35
				ShadowInfusion = function()
					return Pet.IsActive()
						and Legendary.TaktheritrixsShoulderpads.Equipped()
						and (Talent.ShadowInfusion.Enabled() or Spell.SummonGargoyle.Cooldown.Remains() > 55)
						and Spell.SummonGargoyle.Cooldown.Remains() > 35;
				end,
			},
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.DarkTransformation, self.Requirements.DarkTransformation.DarkArbiter.NoConvergenceOfFates);
		action.EvaluateAction(Spell.DarkTransformation, self.Requirements.DarkTransformation.DarkArbiter.ConvergenceOfFates);
		action.EvaluateAction(Spell.DarkTransformation, self.Requirements.DarkTransformation.DarkArbiter.Use);
		action.EvaluateAction(Spell.DarkTransformation, self.Requirements.DarkTransformation.SummonGargoyle.ShadowInfusion);
		action.EvaluateAction(Spell.DarkTransformation, self.Requirements.DarkTransformation.SummonGargoyle.Use);
		action.EvaluateAction(Spell.DarkTransformation, self.Requirements.DarkTransformation.Use);
	end

	-- actions.cooldowns+=/call_action_list,name=dt,if=cooldown.dark_transformation.ready
	function self.Use()
		return Spell.DarkTransformation.Cooldown.Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local DarkTransformation = DarkTransformation("DarkTransformation");

-- Cooldowns Rotation
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.cooldowns+=/apocalypse,if=debuff.festering_wound.stack>=6
		Apocalypse = function()
			return Target.Debuff(Debuff.FesteringWounds).Stack() >= 6;
		end,

		-- actions.cooldowns+=/dark_arbiter,if=(!equipped.137075|cooldown.dark_transformation.remains<2)&runic_power.deficit<30
		DarkArbiter = function()
			return (not Legendary.TaktheritrixsShoulderpads.Equipped() or Spell.DarkTransformation.Cooldown.Remains() < 2)
			   and Player.RunicPower.Deficit() < 30;
		end,

		-- actions.cooldowns+=/soul_reaper,if=(debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<=gcd)|(debuff.festering_wound.stack>=3&rune>=3&cooldown.apocalypse.remains>20)
		SoulReaper = function()
			return (Target.Debuff(Debuff.FesteringWounds).Stack() >= 6 and Artifact.Apocalypse.Cooldown.Remains() <= Player.GCD())
				or (Target.Debuff(Debuff.FesteringWounds).Stack() >= 3 and Player.Runes() >= 3 and Artifact.Apocalypse.Cooldown.Remains() > 20);
		end,

		-- actions.cooldowns+=/summon_gargoyle,if=(!equipped.137075|cooldown.dark_transformation.remains<10)&rune.time_to_4>=gcd
		SummonGargoyle = function()
			return (not Legendary.TaktheritrixsShoulderpads.Equipped() or Spell.DarkTransformation.Cooldown.Remains() < 10)
			   and Player.Runes.TimeToX(4) >= Player.GCD();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.CallActionList(ColdHeart);

		-- actions.cooldowns+=/army_of_the_dead
		action.EvaluateAction(Spell.ArmyOfTheDead, true);
		action.EvaluateAction(Artifact.Apocalypse, self.Requirements.Apocalypse);
		action.EvaluateAction(Talent.DarkArbiter, self.Requirements.DarkArbiter);
		action.EvaluateAction(Spell.SummonGargoyle, self.Requirements.SummonGargoyle);
		action.EvaluateAction(Talent.SoulReaper, self.Requirements.SoulReaper);

		action.CallActionList(DarkTransformation);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Cooldowns = Cooldowns("Cooldowns");

-- Generic Rotation
local function Generic(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ClawingShadows = {
			-- actions.generic+=/clawing_shadows,if=(buff.necrosis.up|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!equipped.132448)&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
			Use = function()
				return (Player.Buff(Buff.Necrosis).Up() or Player.Buff(Buff.UnholyStrength).React() or Player.Runes() >= 2)
					and Target.Debuff(Debuff.FesteringWounds).Stack() >= 1
					and (Target.Debuff(Debuff.FesteringWounds).Stack() >= 3 or not Legendary.InstructorsFourthLesson.Equipped())
					and (Spell.ArmyOfTheDead.Cooldown.Remains() > 5 or Player.Runes.TimeToX(4) < Player.GCD());
			end,

			-- actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.up
			SoulReaper = function()
				return Target.Debuff(Debuff.SoulReaper).Up()
				   and Target.Debuff(Debuff.FesteringWounds).Up();
			end,
		},

		DeathCoil = {
			-- actions.generic+=/death_coil,if=(talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10)|!talent.dark_arbiter.enabled
			Use = function()
				return (Talent.DarkArbiter.Enabled() and Talent.DarkArbiter.Cooldown.Remains() > 10)
					or not Talent.DarkArbiter.Enabled();
			end,

			-- actions.generic+=/death_coil,if=!buff.necrosis.up&buff.sudden_doom.react&((!talent.dark_arbiter.enabled&rune<=3)|cooldown.dark_arbiter.remains>5)
			SuddenDoom = function()
				return not Player.Buff(Buff.Necrosis).Up()
				   and Player.Buff(Buff.SuddenDoom).React()
				   and ((not Talent.DarkArbiter.Enabled() and Player.Runes() <= 3) or Talent.DarkArbiter.Cooldown.Remains() > 5);
			end,

			-- actions.generic+=/death_coil,if=runic_power.deficit<22&(talent.shadow_infusion.enabled|(!talent.dark_arbiter.enabled|cooldown.dark_arbiter.remains>5))
			RunicPower = function()
				return Player.RunicPower.Deficit() < 22
				   and (Talent.ShadowInfusion.Enabled() or (not Talent.DarkArbiter.Enabled() or Talent.DarkArbiter.Cooldown.Remains() > 5));
			end,
		},

		FesteringStrike = {
			-- actions.generic+=/festering_strike,if=(buff.blighted_rune_weapon.stack*2+debuff.festering_wound.stack)<=2|((buff.blighted_rune_weapon.stack*2+debuff.festering_wound.stack)<=4&talent.castigator.enabled)&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
			Use = function()
				return (Player.Buff(Buff.BlightedRuneWeapon).Stack() * 2 + Target.Debuff(Debuff.FesteringWounds).Stack()) <= 2 or ((Player.Buff(Buff.BlightedRuneWeapon).Stack() * 2 + Target.Debuff(Debuff.FesteringWounds).Stack()) <=4 and Talent.Castigator.Enabled())
				   and (Spell.ArmyOfTheDead.Cooldown.Remains() > 5 or Player.Runes.TimeToX(4) <= Player.GCD());
			end,

			-- actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
			Apocalypse = function()
				return Target.Debuff(Debuff.FesteringWounds).Stack() < 6
				   and Artifact.Apocalypse.Cooldown.Remains() <= 6;
			end,
		},

		ScourgeStrike = {
			-- actions.generic+=/scourge_strike,if=(buff.necrosis.up|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!(talent.castigator.enabled|equipped.132448))&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
			Use = function()
				return (Player.Buff(Buff.Necrosis).Up() or Player.Buff(Buff.UnholyStrength).React() or Player.Runes() >= 2)
				   and Target.Debuff(Debuff.FesteringWounds).Stack() >= 1
				   and (Target.Debuff(Debuff.FesteringWounds).Stack() >= 3 or not (Talent.Castigator.Enabled() or Legendary.InstructorsFourthLesson.Equipped()))
				   and (Spell.ArmyOfTheDead.Cooldown.Remains() > 5 or Player.Runes.TimeToX(4) < Player.GCD());
			end,

			-- actions.generic=scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.up
			SoulReaper = function()
				return Target.Debuff(Debuff.SoulReaper).Up()
				   and Target.Debuff(Debuff.FesteringWounds).Up();
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.ScourgeStrike, self.Requirements.ScourgeStrike.SoulReaper);
		action.EvaluateAction(Talent.ClawingShadows, self.Requirements.ClawingShadows.SoulReaper);
		action.EvaluateAction(Spell.DeathCoil, self.Requirements.DeathCoil.RunicPower);
		action.EvaluateAction(Spell.DeathCoil, self.Requirements.DeathCoil.SuddenDoom);
		action.EvaluateAction(Spell.FesteringStrike, self.Requirements.FesteringStrike.Apocalypse);
		-- actions.generic+=/defile
		action.EvaluateAction(Talent.Defile, true);

		action.CallActionList(AOE);

		action.EvaluateAction(Spell.FesteringStrike, self.Requirements.FesteringStrike.Use);
		action.EvaluateAction(Spell.ScourgeStrike, self.Requirements.ScourgeStrike.Use);
		action.EvaluateAction(Talent.ClawingShadows, self.Requirements.ClawingShadows.Use);
		action.EvaluateAction(Spell.DeathCoil, self.Requirements.DeathCoil.Use);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Generic = Generic("Generic");

-- Valkyr Rotation
local function Valkyr(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
		ClawingShadows = function()
			return Target.Debuff(Debuff.FesteringWounds).Up();
		end,

		FesteringStrike = {
			-- actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=4
			Use = function()
				 return Target.Debuff(Debuff.FesteringWounds).Stack() <= 4;
			end,

			-- actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<3
			Apocalypse = function()
				return Target.Debuff(Debuff.FesteringWounds).Stack() < 6
				   and Artifact.Apocalypse.Cooldown.Remains() < 3;
			end,
		},

		-- actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
		ScourgeStrike = function()
			return Target.Debuff(Debuff.FesteringWounds).Up();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- actions.valkyr=death_coil
		action.EvaluateAction(Spell.DeathCoil, true);
		action.EvaluateAction(Spell.FesteringStrike, self.Requirements.FesteringStrike.Apocalypse);

		action.CallActionList(AOE);

		action.EvaluateAction(Spell.FesteringStrike, self.Requirements.FesteringStrike.Use);
		action.EvaluateAction(Spell.ScourgeStrike, self.Requirements.ScourgeStrike);
		action.EvaluateAction(Talent.ClawingShadows, self.Requirements.ClawingShadows);
	end

	-- actions+=/run_action_list,name=valkyr,if=pet.valkyr_battlemaiden.active&talent.dark_arbiter.enabled
	function self.Use()
		return UndeadSummons.UndeadActive(Undead.DarkArbiter)
		   and Talent.DarkArbiter.Enabled();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Valkyr = Valkyr("Valkyr");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "JaceDK and SimCraft",
		GuideLink = "http://www.icy-veins.com/wow/unholy-death-knight-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raiding"] = "3211011",
		["Dungeon / Mythic+"] = "3331033",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = {
			-- actions+=/arcane_torrent,if=runic_power.deficit>20&(pet.valkyr_battlemaiden.active|!talent.dark_arbiter.enabled)
			Combat = function()
				return Player.RunicPower.Deficit() > 20
				   and (UndeadSummons.UndeadActive(Undead.DarkArbiter) or not Talent.DarkArbiter.Enabled());
			end,

			Interrupt = function()
				return Target.InRange(8);
			end,
		},

		AntiMagicShell = function()
			return Player.MagicDamagePredicted(3) >= 30;
		end,

		-- actions+=/berserking,if=pet.valkyr_battlemaiden.active|!talent.dark_arbiter.enabled
		Berserking = function()
			return UndeadSummons.UndeadActive(Undead.DarkArbiter)
				or not Talent.DarkArbiter.Enabled();
		end,

		-- actions+=/blighted_rune_weapon,if=debuff.festering_wound.stack<=4
		BlightedRuneWeapon = function()
			return Target.Debuff(Debuff.FesteringWounds).Stack() <= 4;
		end,

		-- actions+=/blood_fury,if=pet.valkyr_battlemaiden.active|!talent.dark_arbiter.enabled
		BloodFury = function()
			return UndeadSummons.UndeadActive(Undead.DarkArbiter)
				or not Talent.DarkArbiter.Enabled();
		end,

		CorpseShield = function()
			return Player.DamagePredicted(5) >= 50;
		end,

		DeathStrike = function()
			return Player.Buff(Buff.DarkSuccor).Up()
			   and Player.Health.Percent() < 90;
		end,

		-- actions+=/use_item,name=feloiled_infernal_machine,if=pet.valkyr_battlemaiden.active|!talent.dark_arbiter.enabled
		FelOiledInfernalMachine = function()
			return UndeadSummons.UndeadActive(Undead.DarkArbiter)
				or not Talent.DarkArbiter.Enabled();
		end,

		IceboundFortitude = function()
			return Player.DamagePredicted(4) >= 25;
		end,

		-- actions+=/outbreak,target_if=(dot.virulent_plague.tick_time_remains+tick_time<=dot.virulent_plague.remains)&dot.virulent_plague.remains<=gcd
		Outbreak = function()
			return Target.Debuff(Debuff.VirulentPlague).Remains() <= Player.GCD();
		end,

		-- actions+=/potion,if=buff.unholy_strength.react
		ProlongedPower = function()
			return Player.Buff(Buff.UnholyStrength).React();
		end,

		RaiseDead = function()
			-- Not specified in simcraft, but we want to make sure we only suggest summoning pet if its not already active.
			-- actions.precombat+=/raise_dead
			return not Pet.IsActive();
		end,

		-- actions+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
		RingOfCollapsingFutures = function()
			return (Player.Buff(Buff.Temptation).Stack() == 0 and Target.TimeToDie() > 60)
				or Target.TimeToDie() < 60;
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
			ArcaneTorrent = Objects.newSpell(50613),
			Berserking = Objects.newSpell(26297),
			BloodFury = Objects.newSpell(20572),
			GiftOfTheNaaru = Objects.newSpell(59547),
			Shadowmeld = Objects.newSpell(58984),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Abilities
			Apocalypse = Objects.newSpell(220143),
		};

		Spell = {
			-- Abilities
			ArmyOfTheDead = Objects.newSpell(42650),
			DarkTransformation = Objects.newSpell(63560),
			DeathAndDecay = Objects.newSpell(43265),
			DeathCoil = Objects.newSpell(47541),
			FesteringStrike = Objects.newSpell(85948),
			Outbreak = Objects.newSpell(77575),
			ScourgeStrike = Objects.newSpell(55090),
			SummonGargoyle = Objects.newSpell(49206),
			-- Crowd Control
			ChainsOfIce = Objects.newSpell(45524),
			ControlUndead = Objects.newSpell(111673),
			DeathGrip = Objects.newSpell(49576),
			MindFreeze = Objects.newSpell(47528),
			-- Defensive
			AntiMagicShell = Objects.newSpell(48707),
			DeathStrike = Objects.newSpell(49998),
			IceboundFortitude = Objects.newSpell(48792),
			-- Utility
			CorpseExplosion = Objects.newSpell(127344),
			DarkCommand = Objects.newSpell(56222),
			DeathGate = Objects.newSpell(50977),
			PathOfFrost = Objects.newSpell(3714),
			RaiseAlly = Objects.newSpell(61999),
			RaiseDead = Objects.newSpell(46584, false),
			WraithWalk = Objects.newSpell(212552),
		};

		Talent = {
			-- Active Talents
			Asphyxiate = Objects.newSpell(108194),
			BlightedRuneWeapon = Objects.newSpell(194918),
			ClawingShadows = Objects.newSpell(207311),
			CorpseShield = Objects.newSpell(207319),
			DarkArbiter = Objects.newSpell(207349),
			Defile = Objects.newSpell(152280),
			Epidemic = Objects.newSpell(207317),
			SoulReaper = Objects.newSpell(130736),
			-- Passive Talents
			AllWillServe = Objects.newSpell(194916),
			BurstingSores = Objects.newSpell(207264),
			Castigator = Objects.newSpell(207305),
			DebilitatingInfestation = Objects.newSpell(207316),
			EbonFever = Objects.newSpell(207269),
			InfectedClaws = Objects.newSpell(207272),
			LingeringApparition = Objects.newSpell(212763),
			Necrosis = Objects.newSpell(207346),
			PestilentPustules = Objects.newSpell(194917),
			ShadowInfusion = Objects.newSpell(198943),
			SludgeBelcher = Objects.newSpell(207313),
			SpellEater = Objects.newSpell(207321),
			UnholyFrenzy = Objects.newSpell(207289),
			-- Honor Talents
			NecroticStrike = Objects.newSpell(223829),
			Reanimation = Objects.newSpell(210128),
		};

		Buff = {
			-- Buffs
			AntiMagicShell = Spell.AntiMagicShell,
			ArmyOfTheDead = Spell.ArmyOfTheDead,
			BlightedRuneWeapon = Talent.BlightedRuneWeapon,
			CorpseShield = Talent.CorpseShield,
			DarkArbiter = Objects.newSpell(212412),
			DarkSuccor = Objects.newSpell(101568),
			DeathAndDecay = Objects.newSpell(188290),
			Defile = Objects.newSpell(218100),
			IceboundFortitude = Spell.IceboundFortitude,
			MasterOfGhouls = Objects.newSpell(246995),
			Necrosis = Objects.newSpell(216974),
			PathOfFrost = Spell.PathOfFrost,
			SuddenDoom = Objects.newSpell(81340),
			SummonGargoyle = Objects.newSpell(61777),
			Temptation = Objects.newSpell(234143),
			UnholyStrength = Objects.newSpell(53365),
			WraithWalk = Spell.WraithWalk,
			-- Pet Buffs
			DarkTransformation = Spell.DarkTransformation,
			-- Legendary Buffs
			ColdHeart = Objects.newSpell(235599),
			InstructorsFourthLesson = Objects.newSpell(208713),
		};

		Debuff = {
			-- Debuffs
			ChainsOfIce = Spell.ChainsOfIce,
			ControlUndead = Spell.ControlUndead,
			DarkCommand = Spell.DarkCommand,
			FesteringWounds = Objects.newSpell(194310),
			NecroticWound = Objects.newSpell(223929),
			SoulReaper = Talent.SoulReaper,
			VirulentPlague = Objects.newSpell(191587),
			VoidTouched = Objects.newSpell(97821),
		};

		-- Items
		Legendary = {
			-- Legendaries
			ColdHeart = Objects.newItem(151796),
			InstructorsFourthLesson = Objects.newItem(132448),
			KiljaedensBurningWish = Objects.newItem(144259),
			TaktheritrixsShoulderpads = Objects.newItem(137075),
		};

		Item = {
			-- Rings
			RingOfCollapsingFutures = Objects.newItem(142173),
			-- Trinkets
			FelOiledInfernalMachine = Objects.newItem(144482),
			ConvergenceOfFates = Objects.newItem(140806),
		};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.BloodFury, Racial.GiftOfTheNaaru, Racial.Shadowmeld);
		config.AOEOptions(options, Spell.DeathAndDecay, Talent.Defile, Talent.Epidemic);
		config.CooldownOptions(options, Artifact.Apocalypse, Spell.ArmyOfTheDead, Talent.BlightedRuneWeapon, Spell.ChainsOfIce, Item.ConvergenceOfFates, Talent.DarkArbiter, Spell.DarkTransformation,
									 Item.FelOiledInfernalMachine, Legendary.KiljaedensBurningWish, Talent.NecroticStrike, Talent.Reanimation, Item.RingOfCollapsingFutures, Spell.SummonGargoyle,
									 Talent.SoulReaper);
		config.DefensiveOptions(options, Spell.AntiMagicShell, Talent.CorpseShield, Spell.IceboundFortitude, Spell.DeathStrike);
		config.UtilityOptions(options, Spell.ControlUndead, Spell.DeathGrip, Spell.RaiseAlly);
		config.SpecialOptions(options, "UNHOLY_DEATHKNIGHT_HIDDENSKIN|Track spawn for Unholy DK Hidden Artifact Skin.")
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

		-- Protects against magic damage
		action.EvaluateDefensiveAction(Spell.AntiMagicShell, self.Requirements.AntiMagicShell);

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Talent.CorpseShield, self.Requirements.CorpseShield);
		action.EvaluateDefensiveAction(Spell.IceboundFortitude, self.Requirements.IceboundFortitude);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.DeathStrike, self.Requirements.DeathStrike);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.MindFreeze, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent.Interrupt);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Talent.Asphyxiate, true);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		action.EvaluateAction(Spell.RaiseDead, self.Requirements.RaiseDead);
		-- actions.precombat+=/army_of_the_dead
		action.EvaluateAction(Spell.ArmyOfTheDead, true);
		-- actions.precombat+=/blighted_rune_weapon
		action.EvaluateAction(Talent.BlightedRuneWeapon, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent.Combat);
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Item.FelOiledInfernalMachine, self.Requirements.FelOiledInfernalMachine);
		action.EvaluateAction(Item.RingOfCollapsingFutures, self.Requirements.RingOfCollapsingFutures);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Talent.BlightedRuneWeapon, self.Requirements.BlightedRuneWeapon);
		action.EvaluateAction(Spell.Outbreak, self.Requirements.Outbreak);

		-- actions+=/call_action_list,name=cooldowns
		action.CallActionList(Cooldowns);

		-- actions+=/run_action_list,name=valkyr,if=pet.valkyr_battlemaiden.active&talent.dark_arbiter.enabled
		action.RunActionList(Valkyr);

		-- actions+=/call_action_list,name=generic
		action.CallActionList(Generic);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Unholy Death Knight", addonTable.Enum.SpecID.DEATHKNIGHT_UNHOLY);