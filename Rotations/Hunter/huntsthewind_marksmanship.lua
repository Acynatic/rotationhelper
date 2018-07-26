local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Objects = addon.Core.Objects;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Spell, Talent, Aura, Azerite, Item, Consumable;

local nameAPL = "huntsthewind_hunter_marksmanship";

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "HuntsTheWind",
		ScriptCredits = "LunaEclipse",
		GuideAuthor = "Azortharion and SimCraft",
		GuideLink = "http://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-guide",
		WoWVersion = 80000,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raid"] = "3123012",
		["Mythic+"] = "1322032",
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
		AimedShot = {
			-- actions+=/aimed_shot,if=buff.precise_shots.down&buff.double_tap.down&(active_enemies>2&buff.trick_shots.up|active_enemies<3&full_recharge_time<cast_time+gcd)
			NoPreciseShots = function(numEnemies)
				return Player.Buff(Aura.PreciseShots).Down()
				   and Player.Buff(Aura.DoubleTap).Down()
				   and (numEnemies > 2 and Player.Buff(Aura.TrickShots).Up() or numEnemies < 3 and Spell.AimedShot.Charges.FullRechargeTime() < Spell.AimedShot.CastTime() + Player.GCD());
			end,

			-- actions+=/aimed_shot,if=buff.precise_shots.down&(focus>70|buff.steady_focus.down)
			Use = function(numEnemies)
				return Player.Buff(Aura.PreciseShots).Down()
				   and (Player.Focus() > 70 or Player.Buff(Aura.SteadyFocus).Down());
			end,
		},

		-- actions+=/ancestral_call,if=cooldown.trueshot.remains>30
		AncestralCall = function()
			return Spell.Trueshot.Cooldown.Remains() > 30;
		end,

		ArcaneShot = {
			-- actions+=/arcane_shot,if=active_enemies<3&buff.precise_shots.up&cooldown.aimed_shot.full_recharge_time<gcd*buff.precise_shots.stack+action.aimed_shot.cast_time
			PreciseShots = function(numEnemies)
				return numEnemies < 3
					and Player.Buff(Aura.PreciseShots).Up()
					and Spell.AimedShot.Charges.FullRechargeTime() < Player.GCD() * Player.Buff(Aura.PreciseShots).Stack() + Spell.AimedShot.CastTime();
			end,

			-- actions+=/arcane_shot,if=active_enemies<3&(focus>70|buff.steady_focus.down&(focus>60|buff.precise_shots.up))
			Use = function(numEnemies)
				return numEnemies < 3
				   and (Player.Focus() > 70 or Player.Buff(Aura.SteadyFocus).Down() and (Player.Focus() or Player.Buff(Aura.PreciseShots).Up()));
			end,
		},

		-- actions+=/barrage,if=active_enemies>1
		Barrage = function(numEnemies)
			return numEnemies > 1;
		end,

		-- actions+=/berserking,if=cooldown.trueshot.remains>30
		Berserking = function()
			return Spell.Trueshot.Cooldown.Remains() > 30;
		end,

		-- actions+=/blood_fury,if=cooldown.trueshot.remains>30
		BloodFury = function()
			return Spell.Trueshot.Cooldown.Remains() > 30;
		end,

		-- actions+=/double_tap,if=cooldown.rapid_fire.remains<gcd
		DoubleTap = function()
			return Spell.RapidFire.Cooldown.Remains() < Player.GCD();
		end,

		-- actions+=/explosive_shot,if=active_enemies>1
		ExplosiveShot = function(numEnemies)
			return numEnemies > 1;
		end,

		-- actions+=/fireblood,if=cooldown.trueshot.remains>30
		Fireblood = function()
			return Spell.Trueshot.Cooldown.Remains() > 30;
		end,

		-- actions+=/hunters_mark,if=debuff.hunters_mark.down
		HuntersMark = function()
			return Target.Debuff(Aura.HuntersMark).Down();
		end,

		MultiShot = {
			-- actions+=/multishot,if=active_enemies>2&buff.trick_shots.down
			NoTrickShots = function(numEnemies)
				return numEnemies > 2
				   and Player.Buff(Aura.TrickShots).Down();
			end,

			-- actions+=/multishot,if=active_enemies>2&buff.precise_shots.up&cooldown.aimed_shot.full_recharge_time<gcd*buff.precise_shots.stack+action.aimed_shot.cast_time
			PreciseShots = function(numEnemies)
				return numEnemies > 2
				   and Player.Buff(Aura.PreciseShots).Up()
				   and Spell.AimedShot.Charges.FullRechargeTime() < Player.GCD() * Player.Buff(Aura.PreciseShots).Stack() + Spell.AimedShot.CastTime();
			end,

			-- actions+=/multishot,if=active_enemies>2&(focus>90|buff.precise_shots.up&(focus>70|buff.steady_focus.down&focus>45))
			Use = function(numEnemies)
				return numEnemies > 2
				   and (Player.Focus() > 90 or Player.Buff(Aura.PreciseShots).Up() and (Player.Focus() > 70 or Player.Buff(Aura.SteadyFocus).Down() and Player.Focus() > 45));
			end,
		},

		-- actions+=/potion,if=(buff.trueshot.react&buff.bloodlust.react)|((consumable.prolonged_power&target.time_to_die<62)|target.time_to_die<31)
		ProlongedPower = function()
			return (Player.Buff(Aura.Trueshot).React() and Player.HasBloodlust())
			    or ((Player.Buff(Aura.ProlongedPower) and Target.TimeToDie() < 62) or Target.TimeToDie() < 31);
		end,

		-- actions+=/rapid_fire,if=active_enemies<3|buff.trick_shots.up
		RapidFire = function(numEnemies)
			return numEnemies < 3
			    or Player.Buff(Aura.TrickShots).Up();
		end,

		-- actions+=/serpent_sting,if=refreshable
		SerpentSting = function()
			return Target.Debuff(Aura.SerpentSting).Refreshable();
		end,

		-- actions+=/trueshot,if=cooldown.aimed_shot.charges<1
		Trueshot = function()
			return Spell.AimedShot.Charges() < 1;
		end,
	};

	-- Add meta-table to the requirements table, to enable better debugging and case insensitivity.
	Objects.FinalizeRequirements(self.Defensives, self.Interrupts, self.Requirements);

	-- Function for setting up action objects such as spells, buffs,
	-- debuffs, and items, called when the rotation becomes the active
	-- rotation.
	function self.Enable(...)
		Racial, Spell, Talent, Aura, Azerite = ...;

		Aura.ProlongedPower = Objects.newSpell(229206);

		Item = {};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117, "OPT_POTION"),
		};

		-- Add meta-table to the various object tables, to enable better debugging and case insensitivity.
		Objects.FinalizeActions(Racial, Spell, Talent, Aura, Azerite, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.AncestralCall, Racial.Berserking, Racial.BloodFury, Racial.Fireblood, Racial.LightsJudgment);
		config.AOEOptions(options, Talent.Barrage, Talent.ExplosiveShot, Spell.MultiShot);
		config.CooldownOptions(options, Talent.AMurderOfCrows, Talent.DoubleTap, Talent.HuntersMark, Talent.PiercingShot, Talent.SerpentSting, Spell.Trueshot);
		config.DefensiveOptions(options, Spell.AspectOfTheTurtle, Spell.Exhilaration, Spell.FeignDeath);
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
			action.EvaluateInterruptAction(Racial.QuakingPalm, true);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Interrupts.WarStomp);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		-- SimCraft doesn't specify it, but we only want to use Hunter's Mark if its not already active, so use normal requirements.
		-- actions.precombat+=/hunters_mark
		action.EvaluateAction(Talent.HuntersMark, self.Requirements.HuntersMark);
		-- SimCraft doesn't specify it, but we only want to use Hunter's Mark if its not already active, so use normal requirements.
		-- actions.precombat+=/double_tap,precast_time=5
		action.EvaluateAction(Talent.DoubleTap, self.Requirements.DoubleTap);
		-- The addon can't determine number of enemies outside combat, so just do Aimed Shot without a check.
		-- actions.precombat+=/aimed_shot,if=active_enemies<3
		-- actions.precombat+=/explosive_shot,if=active_enemies>2
		action.EvaluateAction(Spell.AimedShot, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Talent.HuntersMark, self.Requirements.HuntersMark);
		action.EvaluateAction(Talent.DoubleTap, self.Requirements.DoubleTap);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury);
		action.EvaluateAction(Racial.AncestralCall, self.Requirements.AncestralCall);
		action.EvaluateAction(Racial.Fireblood, self.Requirements.Fireblood);
		-- actions+=/lights_judgment
		action.EvaluateAction(Racial.LightsJudgment, true);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Spell.Trueshot, self.Requirements.Trueshot);
		action.EvaluateAction(Talent.Barrage, self.Requirements.Barrage);
		action.EvaluateAction(Talent.ExplosiveShot, self.Requirements.ExplosiveShot);
		action.EvaluateAction(Spell.MultiShot, self.Requirements.MultiShot.PreciseShots);
		action.EvaluateAction(Spell.ArcaneShot, self.Requirements.ArcaneShot.PreciseShots);
		action.EvaluateAction(Spell.AimedShot, self.Requirements.AimedShot.NoPreciseShots);
		action.EvaluateAction(Spell.RapidFire, self.Requirements.RapidFire);
		-- actions+=/explosive_shot
		action.EvaluateAction(Talent.ExplosiveShot, true);
		-- actions+=/barrage
		action.EvaluateAction(Talent.Barrage, true);
		-- actions+=/piercing_shot
		action.EvaluateAction(Talent.PiercingShot, true);
		-- actions+=/a_murder_of_crows
		action.EvaluateAction(Talent.AMurderOfCrows, true);
		action.EvaluateAction(Spell.MultiShot, self.Requirements.MultiShot.NoTrickShots);
		action.EvaluateAction(Spell.AimedShot, self.Requirements.AimedShot.Use);
		action.EvaluateAction(Spell.MultiShot, self.Requirements.MultiShot.Use);
		action.EvaluateAction(Spell.ArcaneShot, self.Requirements.ArcaneShot.Use);
		action.EvaluateAction(Talent.SerpentSting, self.Requirements.SerpentSting);
		-- actions+=/steady_shot
		action.EvaluateAction(Spell.SteadyShot, true);
	end

	return self;
end

local APL = APL(nameAPL, "HuntsTheWind: Marksmanship Hunter", addonTable.Enum.SpecID.HUNTER_MARKSMANSHIP);