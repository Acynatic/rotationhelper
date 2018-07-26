local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Objects
local Pet = addon.Units.Pet;
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Spell, Talent, Aura, Azerite, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_hunter_beastmastery";

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Azortharion and SimCraft",
		GuideLink = "http://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-guide",
		WoWVersion = 80000,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raid"] = "1323011",
	};

	-- Table to hold requirements to use spells for defensive reasons.
	self.Defensives = {
		AspectOfTheTurtle = function()
			return Player.DamagePredicted(4) >= 40;
		end,

		Exhilaration = function()
			return Player.Health.Percent() < 70
			   and Player.DamagePredicted(5) >= 25;
		end,

		FeignDeath = function()
			return Player.Health.Percent() < 25
			   and Player.DamagePredicted(5) >= 25;
		end,

		MendPet = function()
			return not Pet.Buff(Aura.MendPet).Up()
			   and Pet.Health.Percent() < 80;
		end,
	};

	-- Table to hold requirements to use spells for interrupts.
	self.Interrupts = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		WarStomp = function()
			return Target.InRange(5);
		end,
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions+=/ancestral_call,if=cooldown.bestial_wrath.remains>30
		AncestralCall = function()
			return Spell.BestialWrath.Cooldown.Remains() > 30;
		end,

		BarbedShot = {
			-- actions+=/barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max
			Frenzy = function()
				return Pet.Buff(Aura.Frenzy).Up()
				   and Pet.Buff(Aura.Frenzy).Remains() <= Player.GCD();
			end,

			-- actions+=/barbed_shot,if=pet.cat.buff.frenzy.down&charges_fractional>1.4|full_recharge_time<gcd.max|target.time_to_die<9
			Use = function()
				return Pet.Buff(Aura.Frenzy).Down()
				   and Spell.BarbedShot.Charges.Fractional() > 1.4
				    or Spell.BarbedShot.Charges.FullRechargeTime() < Player.GCD()
				    or Target.TimeToDie() < 9;
			end,
		},

		-- actions+=/berserking,if=cooldown.bestial_wrath.remains>30
		Berserking = function()
			return Spell.BestialWrath.Cooldown.Remains() > 30;
		end,

		-- actions+=/bestial_wrath,if=!buff.bestial_wrath.up
		BestialWrath = function()
			return not Player.Buff(Aura.BestialWrath).Up();
		end,

		-- actions+=/blood_fury,if=cooldown.bestial_wrath.remains>30
		BloodFury = function()
			return Spell.BestialWrath.Cooldown.Remains() > 30;
		end,

		-- Not specified by SimCraft but ensure that pet is not already out before suggesting
		-- actions.precombat+=/summon_pet
		CallPet = function()
			return not Pet.IsActive();
		end,

		-- actions+=/cobra_shot,if=(active_enemies<2|cooldown.kill_command.remains>focus.time_to_max)&(buff.bestial_wrath.up&active_enemies>1|cooldown.kill_command.remains>1+gcd&cooldown.bestial_wrath.remains>focus.time_to_max|focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost)
		CobraShot = function(numEnemies)
			return (numEnemies < 2 or Spell.KillCommand.Cooldown.Remains() > Player.Focus.TimeToMax())
			   and (Player.Buff(Aura.BestialWrath).Up() and numEnemies > 1 or Spell.KillCommand.Cooldown.Remains() > 1 + Player.GCD() and Spell.BestialWrath.Cooldown.Remains() > Player.Focus.TimeToMax() or Player.Focus() - Spell.CobraShot.Cost() + Player.Focus.Regen() * (Spell.KillCommand.Cooldown.Remains() - 1) > Spell.KillCommand.Cost());
		end,

		-- actions+=/fireblood,if=cooldown.bestial_wrath.remains>30
		Fireblood = function()
			return Spell.BestialWrath.Cooldown.Remains() > 30;
		end,

		-- SimCraft doesn't specify it, but kill command can only be used if you have an active pet, so add check for active pet
		-- actions+=/kill_command
		KillCommand = function()
			return Pet.IsActive();
		end,

		MultiShot = {
			-- Not specified by SimCraft but this is for Beast Cleave so add a check to make sure we can actually Beast Cleave
			-- actions+=/multishot,if=spell_targets>2&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
			AOE = function(numEnemies)
				return Spell.BeastCleave.IsKnown()
				   and numEnemies > 2
				   and (Pet.Buff(Aura.BeastCleave).Remains() < Player.GCD() or Pet.Buff(Aura.BeastCleave).Down());
			end,

			-- Not specified by SimCraft but this is for Beast Cleave so add a check to make sure we can actually Beast Cleave
			-- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
			Use = function(numEnemies)
				return Spell.BeastCleave.IsKnown()
				   and numEnemies > 1
				   and (Pet.Buff(Aura.BeastCleave).Remains() < Player.GCD() or Pet.Buff(Aura.BeastCleave).Down());
			end,
		},

		-- actions+=/potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up
		ProlongedPower = function()
			return Player.Buff(Aura.BestialWrath).Up()
			   and Player.Buff(Aura.AspectOfTheWild).Up();
		end,

		RevivePet = function()
			return Pet.IsActive()
			   and Pet.IsDeadOrGhost();
		end,

		-- actions+=/stampede,if=buff.bestial_wrath.up|cooldown.bestial_wrath.remains<gcd|target.time_to_die<15
		Stampede = function()
			return Player.Buff(Aura.BestialWrath).Up()
			    or Spell.BestialWrath.Cooldown.Remains() < Player.GCD()
			    or Target.TimeToDie() < 15;
		end,
	};

	Objects.FinalizeRequirements(self.Defensives, self.Interrupts, self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable(...)
		Racial, Spell, Talent, Aura, Azerite = ...;

		Item = {};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117, "OPT_POTION"),
		};

		Objects.FinalizeActions(Racial, Spell, Talent, Aura, Azerite, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.AncestralCall, Racial.Berserking, Racial.BloodFury, Racial.Fireblood, Racial.LightsJudgment);
		config.AOEOptions(options, Talent.Barrage, Talent.ChimaeraShot, Spell.MultiShot);
		config.CooldownOptions(options, Talent.AMurderOfCrows, Spell.AspectOfTheWild, Spell.BestialWrath, Talent.DireBeast, Talent.SpittingCobra, Talent.Stampede);
		config.DefensiveOptions(options, Spell.AspectOfTheTurtle, Spell.Exhilaration, Spell.FeignDeath);
		config.PetOptions(options, Spell.CallPet, Spell.MendPet, Spell.RevivePet);
	end

	-- Function for destroying action objects such as spells, buffs, debuffs and items, called when the rotation is no longer the active rotation.
	function self.Disable()
		local coreTables = addon.Core.Tables;

		coreTables.WipeTables(Racial, Spell, Talent, Aura, Azerite, Item, Consumable);
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
		-- The abilities here should be listed from highest damage required to suggest to lowest,
		-- Specific damage types before all damage types.

		-- Heal pet if its losing health
		action.EvaluateDefensiveAction(Spell.MendPet, self.Defensives.MendPet);

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.AspectOfTheTurtle, self.Defensives.AspectOfTheTurtle);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.Exhilaration, self.Defensives.Exhilaration);

		-- Feign Death if no other defensives are available
		action.EvaluateDefensiveAction(Spell.FeignDeath, self.Defensives.FeignDeath);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.CounterShot, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Interrupts.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Talent.Intimidation, true);
			action.EvaluateInterruptAction(Racial.QuakingPalm, true);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Interrupts.WarStomp);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		action.EvaluateAction(Spell.CallPet, self.Requirements.CallPet);
		-- This is not specified in SimCraft but if the pet is active and dead, then we need to use revive pet not call pet.
		action.EvaluateAction(Spell.RevivePet, self.Requirements.RevivePet);
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- actions.precombat+=/aspect_of_the_wild
		action.EvaluateAction(Spell.AspectOfTheWild, true);
		-- These are not part of SimCraft but are part of performing an opener and can be used to initate combat.
		action.EvaluateAction(Talent.AMurderOfCrows, true);
		action.EvaluateAction(Spell.BestialWrath, true);
		action.EvaluateAction(Spell.KillCommand, true);
		action.EvaluateAction(Spell.BarbedShot, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury);
		action.EvaluateAction(Racial.AncestralCall, self.Requirements.AncestralCall);
		action.EvaluateAction(Racial.Fireblood, self.Requirements.Fireblood);
		-- actions+=/lights_judgment
		action.EvaluateAction(Racial.LightsJudgment, true);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Spell.BarbedShot, self.Requirements.BarbedShot.Frenzy);
		-- actions+=/a_murder_of_crows
		action.EvaluateAction(Talent.AMurderOfCrows, true);
		-- actions+=/spitting_cobra
		action.EvaluateAction(Talent.SpittingCobra, true);
		action.EvaluateAction(Talent.Stampede, self.Requirements.Stampede);
		-- actions+=/aspect_of_the_wild
		action.EvaluateAction(Spell.AspectOfTheWild, true);
		action.EvaluateAction(Spell.BestialWrath, self.BestialWrath);
		action.EvaluateAction(Spell.MultiShot, self.Requirements.MultiShot.AOE, Enemies.GetEnemies(Spell.MultiShot));
		-- actions+=/chimaera_shot
		action.EvaluateAction(Talent.ChimaeraShot, true);
		action.EvaluateAction(Spell.KillCommand, self.Requirements.KillCommand);
		-- actions+=/dire_beast
		action.EvaluateAction(Talent.DireBeast, true);
		action.EvaluateAction(Spell.BarbedShot, self.Requirements.BarbedShot.Use);
		-- actions+=/barrage
		action.EvaluateAction(Talent.Barrage, true);
		action.EvaluateAction(Spell.MultiShot, self.Requirements.MultiShot.Use, Enemies.GetEnemies(Spell.MultiShot));
		action.EvaluateAction(Spell.CobraShot, self.Requirements.CobraShot);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Beast Mastery Hunter", addonTable.Enum.SpecID.HUNTER_BEASTMASTERY);