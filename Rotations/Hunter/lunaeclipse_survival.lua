local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Objects = addon.Core.Objects;

-- Objects
local Pet = addon.Units.Pet;
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Spell, Talent, Aura, Azerite, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_hunter_survival";

local Variables = {};

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		ScriptCredits = "HuntsTheWind",
		GuideAuthor = "Azortharion and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/survival-hunter-pve-dps-guide",
		WoWVersion = 80000,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Single Target"] = "1121021",
		["Sustained Cleave"] = "1221012",
		["High Burst"] = "1322012",
	};

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
		-- actions+=/ancestral_call,if=cooldown.coordinated_assault.remains>30
		AncestralCall = function()
			return Spell.CoordinatedAssault.Cooldown.Remains() > 30;
		end,

		-- actions+=/berserking,if=cooldown.coordinated_assault.remains>30
		Berserking = function()
			return Spell.CoordinatedAssault.Cooldown.Remains() > 30;
		end,

		-- actions+=/blood_fury,if=cooldown.coordinated_assault.remains>30
		BloodFury = function()
			return Spell.CoordinatedAssault.Cooldown.Remains() > 30;
		end,

		-- actions+=/butchery,if=(!talent.wildfire_infusion.enabled|full_recharge_time<gcd)&active_enemies>3|(dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3)
		Butchery = function(numEnemies)
			return (not Talent.WildfireInfusion.Enabled() or Talent.Butchery.Charges.FullRechargeTime() < Player.GCD())
			   and numEnemies > 3
			    or (Target.Debuff(Aura.ShrapnelBomb).Ticking() and Target.Debuff(Aura.InternalBleeding).Stack() < 3);
		end,

		-- Not specified in simcraft, but we want to make sure we only suggest summoning pet if its not already active.
		-- actions.precombat+=/summon_pet
		CallPet = function()
			return not Pet.IsActive();
		end,

		-- actions+=/carve,if=active_enemies>2&(active_enemies<6&active_enemies+gcd<cooldown.wildfire_bomb.remains|5+gcd<cooldown.wildfire_bomb.remains)
		Carve = function(numEnemies)
			return numEnemies > 2
			   and (numEnemies < 6 and numEnemies + Player.GCD() < Spell.WildfireBomb.Cooldown.Remains() or 5 + Player.GCD() < Spell.WildfireBomb.Cooldown.Remains());
		end,

		-- actions+=/chakrams,if=active_enemies>1
		Chakrams = function(numEnemies)
			return numEnemies > 1;
		end,

		-- actions+=/fireblood,if=cooldown.coordinated_assault.remains>30
		Fireblood = function()
			return Spell.CoordinatedAssault.Cooldown.Remains() > 30;
		end,

		-- actions+=/harpoon,if=talent.terms_of_engagement.enabled
		Harpoon = function()
			return Talent.TermsOfEngagement.Enabled();
		end,

		KillCommand = {
			-- We won't do target_if as that is part of multi-dot, that will be added later when EvaluateCycleAction is completed.
			-- actions+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3&active_enemies<2
			AOE = function(numEnemies)
				return Player.Focus() + Player.Focus.CastRegen(Spell.KillCommand) < Player.Focus.Max()
				   and Player.Buff(Aura.TipOfTheSpear).Stack() < 3
				   and numEnemies < 2;
			end,

			-- We won't do target_if as that is part of multi-dot, that will be added later when EvaluateCycleAction is completed.
			-- actions+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
			Use = function()
				return Player.Focus() + Player.Focus.CastRegen(Spell.KillCommand) < Player.Focus.Max()
				   and Player.Buff(Aura.TipOfTheSpear).Stack() < 3;
			end,
		},

		-- We won't do target_if as that is part of multi-dot, that will be added later when EvaluateCycleAction is completed.
		-- actions+=/mongoose_bite,target_if=min:dot.internal_bleeding.stack,if=buff.mongoose_fury.up|focus>60
		MongooseBite = function()
			return Player.Buff(Aura.MongooseFury).Up()
			    or Player.Focus() > 60;
		end,

		-- actions+=/potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)
		ProlongedPower = function()
			return Player.Buff(Aura.CoordinatedAssault).Up()
			   and (Player.Buff(Aura.Berserking).Up() or Player.Buff(Aura.BloodFury).Up() or not Player.Race("Troll") and not Player.Race("Orc"));
		end,

		SerpentSting = {
			-- actions+=/serpent_sting,if=(active_enemies<2&refreshable&(buff.mongoose_fury.down|(variable.can_gcd&!talent.vipers_venom.enabled)))|buff.vipers_venom.up
			Refreshable = function(numEnemies)
				return (numEnemies < 2 and Target.Debuff(Aura.SerpentSting).Refreshable() and (Player.Buff(Aura.MongooseFury).Down() or (Variables.can_gcd and not Talent.VipersVenom.Enabled())))
				    or Player.Buff(Aura.VipersVenom).Up();
			end,

			-- We won't do target_if as that is part of multi-dot, that will be added later when EvaluateCycleAction is completed.
			-- actions+=/serpent_sting,target_if=min:remains,if=refreshable&buff.mongoose_fury.down|buff.vipers_venom.up
			Use = function()
				return Target.Debuff(Aura.SerpentSting).Refreshable()
				   and Player.Buff(Aura.MongooseFury).Down()
				    or Player.Buff(Aura.VipersVenom).Up();
			end,
		},

		-- actions+=/wildfire_bomb,if=(focus+cast_regen<focus.max|active_enemies>1)&(dot.wildfire_bomb.refreshable&buff.mongoose_fury.down|full_recharge_time<gcd)
		WildfireBomb = function(numEnemies)
			return (Player.Focus() + Player.Focus.CastRegen(Spell.WildfireBomb) < Player.Focus.Max() or numEnemies > 1)
			   and (Target.Debuff(Aura.WildfireBomb).Refreshable() and Player.Buff(Aura.MongooseFury).Down() or Spell.WildfireBomb.Charges.FullRechargeTime() < Player.GCD());
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
		config.AOEOptions(options, Spell.Carve, Spell.WildfireBomb);
		config.CooldownOptions(options, Talent.AMurderOfCrows, Talent.Butchery, Talent.Chakrams, Spell.CoordinatedAssault, Spell.KillCommand, Talent.MongooseBite, Spell.SerpentSting, Talent.SteelTrap);
		config.DefensiveOptions(options, Spell.AspectOfTheTurtle, Spell.Exhilaration, Spell.FeignDeath);
		config.PetOptions(options, Spell.CallPet, Spell.MendPet, Spell.RevivePet);
		config.UtilityOptions(options, Spell.Harpoon);
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
		action.EvaluateInterruptAction(Spell.Muzzle, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Interrupts.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
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
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- actions.precombat+=/steel_trap
		action.EvaluateAction(Talent.SteelTrap, true);
		-- actions.precombat+=/harpoon
		action.EvaluateAction(Spell.Harpoon, true);
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
		-- actions+=/variable,name=can_gcd,value=!talent.mongoose_bite.enabled|buff.mongoose_fury.down|(buff.mongoose_fury.remains-(((buff.mongoose_fury.remains*focus.regen+focus)%action.mongoose_bite.cost)*gcd.max)>gcd.max)
		Variables.can_gcd = not Talent.MongooseBite.Enabled() or Player.Buff(Aura.MongooseFury).Down() or (Player.Buff(Aura.MongooseFury).Remains() - (((Player.Buff(Aura.MongooseFury).Remains() * Player.Focus.Regen() + Player.Focus()) / Talent.MongooseBite.Cost()) * Player.GCD()) > Player.GCD);
		-- actions+=/steel_trap
		action.EvaluateAction(Talent.SteelTrap, true);
		-- actions+=/a_murder_of_crows
		action.EvaluateAction(Talent.AMurderOfCrows, true);
		-- actions+=/coordinated_assault
		action.EvaluateAction(Spell.CoordinatedAssault, true);
		action.EvaluateAction(Talent.Chakrams, self.Requirements.Chakrams);
		action.EvaluateCycleAction(Spell.KillCommand, self.Requirements.KillCommand.AOE);
		action.EvaluateAction(Spell.WildfireBomb, self.Requirements.WildfireBomb);
		action.EvaluateCycleAction(Spell.KillCommand, self.Requirements.KillCommand.Use);
		action.EvaluateAction(Talent.Butchery, self.Requirements.Butchery);
		action.EvaluateAction(Spell.SerpentSting, self.Requirements.SerpentSting.Refreshable);
		action.EvaluateAction(Spell.Carve, self.Requirements.Carve);
		action.EvaluateAction(Spell.Harpoon, self.Requirements.Harpoon);
		-- actions+=/flanking_strike
		action.EvaluateAction(Talent.FlankingStrike, true);
		-- actions+=/chakrams
		action.EvaluateAction(Talent.Chakrams, true);
		action.EvaluateCycleAction(Spell.SerpentSting, self.Requirements.SerpentSting.Use);
		action.EvaluateCycleAction(Talent.MongooseBite, self.Requirements.MongooseBite);
		-- actions+=/butchery
		action.EvaluateAction(Talent.Butchery, true);
		-- We won't do target_if as that is part of multi-dot, that will be added later when EvaluateCycleAction is completed.
		-- actions+=/raptor_strike,target_if=min:dot.internal_bleeding.stack
		action.EvaluateAction(Spell.RaptorStrike, true);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Survival Hunter", addonTable.Enum.SpecID.HUNTER_SURVIVAL);