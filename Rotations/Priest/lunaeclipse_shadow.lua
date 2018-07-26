local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

local math = math;

--- Localize Vars
local Core = addon.Core.General;
local Objects = addon.Core.Objects;

-- Function for converting booleans returns to numbers
local val = Core.ToNumber;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_priest_shadow";

local function Variables(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Function to set variables that change in combat.
	function self.Rotation()
		-- actions.check=variable,op=set,name=actors_fight_time_mod,value=0
		self.actors_fight_time_mod = 0;

		-- if=time+target.time_to_die>450&time+target.time_to_die<600
		if Target.TimeToDie() > 450 and Target.TimeToDie() < 600 then
			-- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10)
			self.actors_fight_time_mod = ((-(450) + (Core.CombatTime() + Target.TimeToDie())) / 10);
		end

		-- if=time+target.time_to_die<=450
		if Target.TimeToDie() <= 450 then
			-- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5)
			self.actors_fight_time_mod = ((450 - (Core.CombatTime() + Target.TimeToDie())) / 5);
		end

		if self.s2msetup_time then
			-- actions.check+=/variable,op=set,name=s2mcheck,value=variable.s2msetup_time-(variable.actors_fight_time_mod*nonexecute_actors_pct)
			self.s2mcheck = self.s2msetup_time - (self.actors_fight_time_mod * 1);

			-- actions.check+=/variable,op=min,name=s2mcheck,value=180
			self.s2mcheck = math.min(self.s2mcheck, 180);
		end
	end

	-- actions+=/call_action_list,name=check,if=talent.surrender_to_madness.enabled&!buff.surrender_to_madness.up
	function self.Use()
		return Talent.SurrenderToMadness.Enabled()
		   and not Player.Buff(Buff.SurrenderToMadness).Up();
	end

	return self;
end

-- Create a variable so we can call the functions to set rotation variables.
local Variables = Variables("Variables");

-- Standard Rotation.
local function Main(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		MindBlast = {
			-- actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
			Use = function(numEnemies)
				return numEnemies <= 4
				   and not Talent.LegacyOfTheVoid.Enabled()
					or (Player.Insanity() <= 96 or (Player.Insanity() <= 95.2 and Talent.FortressOfTheMind.Enabled()));
			end,

			-- actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
			LegacyOfTheVoid = function(numEnemies)
				return numEnemies <= 4
				   and Talent.LegacyOfTheVoid.Enabled()
				   and (Player.Insanity() <= 81 or (Player.Insanity() <= 75.2 and Talent.FortressOfTheMind.Enabled()));
			end,
		},

		-- actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
		ShadowCrash = function()
			return Talent.ShadowCrash.Enabled();
		end,

		ShadowWordDeath = {
			-- actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)|(equipped.zeks_exterminatus&buff.zeks_exterminatus.react)
			Use = function(numEnemies)
				return (numEnemies <= 4 or (Talent.ReaperOfSouls.Enabled() and numEnemies <= 2))
				   and Spell.ShadowWordDeath.Charges() == 2
				   and Player.Insanity() <= (85 - 15 * val(Talent.ReaperOfSouls.Enabled()))
					or (Legendary.ZeksExterminatus.Equipped() and Player.Buff(Buff.ZeksExterminatus).React());
			end,

			-- actions.main+=/shadow_word_death,if=equipped.zeks_exterminatus&equipped.mangazas_madness&buff.zeks_exterminatus.react
			ZeksExterminatus = function()
				return Legendary.ZeksExterminatus.Equipped()
				   and Legendary.MangazasMadness.Equipped()
				   and Player.Buff(Buff.ZeksExterminatus).React();
			end,
		},

		ShadowWordPain = {
			-- actions.main+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
			Use = function(numEnemies, Target)
				return numEnemies > 1
				   and not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and (Variables.dot_swp_dpgcd * Target.TimeToDie() / (Player.GCD() * (118 + Variables.sear_dpgcd * (numEnemies - 1)))) > 1;
			end,

			-- actions.main+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd.max,moving=1,cycle_targets=1
			Misery = function(numEnemies, Target)
				return Talent.Misery.Enabled()
				   and Target.Debuff(Debuff.ShadowWordPain).Remains() < Player.GCD()
				   and Player.IsMoving();
			end,

			-- SimCraft specifies a manual time for refreshing the spell, we will use the calculated Pandemic using the Refreshable property.
			-- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd
			Refresh = function()
				return not Talent.Misery.Enabled()
				   and Target.Debuff(Debuff.ShadowWordPain).Refreshable();
			end,

			-- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
			Talents = function(numEnemies, Target)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and Target.TimeToDie() > 10
				   and (numEnemies < 5 and (Talent.AuspiciousSpirit.Enabled() or Talent.ShadowyInsight.Enabled()));
			end,
		},

		-- actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=75-10*talent.legacy_of_the_void.enabled)
		ShadowWordVoid = function()
			return Talent.ShadowWordVoid.Enabled()
			   and Player.Insanity() <= 75 - 10 * val(Talent.LegacyOfTheVoid.Enabled());
		end,

		-- actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
		SurrenderToMadness = function()
			return Talent.SurrenderToMadness.Enabled()
			   and Target.TimeToDie() <= Variables.s2mcheck;
		end,

		VampiricTouch = {
			-- actions.main+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
			Use = function(numEnemies, Target)
				return numEnemies > 1
				   and not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.VampiricTouch).Up()
				   and (Variables.dot_vt_dpgcd * Target.TimeToDie() / (Player.GCD() * (156 + Variables.sear_dpgcd * (numEnemies - 1)))) > 1;
			end,

			-- actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
			Misery = function(numEnemies, Target)
				return Talent.Misery.Enabled()
				   and (Target.Debuff(Debuff.VampiricTouch).Remains() < 3 * Player.GCD() or Target.Debuff(Debuff.ShadowWordPain).Remains() < 3 * Player.GCD());
			end,

			-- SimCraft specifies a manual time for refreshing the spell, we will use the calculated Pandemic using the Refreshable property.
			-- actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
			Refresh = function()
				return not Talent.Misery.Enabled()
				   and Target.Debuff(Debuff.VampiricTouch).Refreshable();
			end,
		},

		-- actions.main+=/void_eruption,if=(talent.mindbender.enabled&cooldown.mindbender.remains<(variable.erupt_eval+gcd.max*4%3))|!talent.mindbender.enabled|set_bonus.tier20_4pc
		VoidEruption = function()
			return (Talent.Mindbender.Enabled() and Talent.Mindbender.Cooldown.Remains() < (Variables.erupt_eval + Player.GCD() * 4 / 3))
				or addonTable.Tier20_4PC;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.SurrenderToMadness, self.Requirements.SurrenderToMadness);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.ZeksExterminatus);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Misery);
		action.EvaluateCycleAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Misery);
		action.EvaluateAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Refresh);
		action.EvaluateAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Refresh);
		action.EvaluateAction(Spell.VoidEruption, self.Requirements.VoidEruption);
		action.EvaluateAction(Talent.ShadowCrash, self.Requirements.ShadowCrash);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.Use);
		action.EvaluateAction(Spell.MindBlast, self.Requirements.MindBlast.LegacyOfTheVoid);
		action.EvaluateAction(Spell.MindBlast, self.Requirements.MindBlast.Use);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Talents);
		action.EvaluateCycleAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Use);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Use);
		action.EvaluateAction(Talent.ShadowWordVoid, self.Requirements.ShadowWordVoid);
		-- actions.main+=/mind_flay,interrupt=1,chain=1
		action.EvaluateInterruptCondition(Spell.MindFlay, true, true);
		-- actions.main+=/shadow_word_pain
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Main = Main("Main");

-- Surrender to Madness Rotation
local function SurrenderMadness(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.s2m+=/berserking,if=buff.voidform.stack>=65
		Berserking = function()
			return Player.Buff(Buff.VoidForm).Stack() >= 65;
		end,

		-- actions.s2m+=/dispersion,if=current_insanity_drain*gcd.max>insanity&!buff.power_infusion.up|(buff.voidform.stack>76&cooldown.shadow_word_death.charges=0&current_insanity_drain*gcd.max>insanity)
		Dispersion = function()
			return Player.Insanity.Drain() * Player.GCD() > Player.Insanity()
			   and not Player.Buff(Buff.PowerInfusion).Up()
				or (Player.Buff(Buff.VoidForm).Stack() > 76 and Spell.ShadowWordDeath.Charges() == 0 and Player.Insanity.Drain() * Player.GCD() > Player.Insanity());
		end,

		-- actions.s2m+=/mindbender,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)
		Mindbender = function()
			return Spell.ShadowWordDeath.Charges() == 0
			   and Player.Buff(Buff.VoidForm).Stack() > (45 + 25 * val(addonTable.Tier20_4PC));
		end,

		MindBlast = {
			-- actions.s2m+=/mind_blast,if=active_enemies<=5
			Use = function(numEnemies)
				return numEnemies <= 5;
			end,

			-- Simcraft doesn't specify it, but just make sure we don't have any active charges, otherwise its usable immediately.
			-- actions.s2m+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=5
			Wait = function(numEnemies)
				return Spell.MindBlast.Cooldown.Remains() > 0
				   and Spell.MindBlast.Cooldown.Remains() < Player.GCD() * 0.28
				   and numEnemies <= 5;
			end,
		},

		MindFlay = {
			-- actions.s2m+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+60)<100&cooldown.shadow_word_death.charges>=1))
			Interrupt = function()
				return Player.Casting.Tick() >= 2
				   and (Spell.VoidBolt.IsUsable() or (Player.Insanity.Drain() * Player.GCD() > Player.Insanity() and (Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + 60) < 100 and Spell.ShadowWordDeath.Charges() >= 1));
			end,
		},

		-- actions.s2m+=/power_infusion,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)|target.time_to_die<=30
		PowerInfusion = function()
			return Spell.ShadowWordDeath.Charges() == 0
			   and Player.Buff(Buff.VoidForm).Stack() > (45 + 25 * val(addonTable.Tier20_4PC))
				or Target.TimeToDie() <= 30;
		end,

		-- actions.s2m+=/shadow_crash,if=talent.shadow_crash.enabled
		ShadowCrash = function()
			return Talent.ShadowCrash.Enabled();
		end,

		-- actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled&buff.voidform.stack>15
		Shadowfiend = function()
			return not Talent.Mindbender.Enabled()
			   and Player.Buff(Buff.VoidForm).Stack() > 15;
		end,

		ShadowWordDeath = {
			-- actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
			Use = function(numEnemies)
				return (numEnemies <= 4 or (Talent.ReaperOfSouls.Enabled() and numEnemies <= 2))
				   and Spell.ShadowWordDeath.Charges() == 2;
			end,

			Insanity = {
				-- actions.s2m+=/shadow_word_death,if=current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled)<100)
				Use = function()
					return Player.Insanity.Drain() * Player.GCD() > Player.Insanity()
					   and Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + (30 + 30 * val(Talent.ReaperOfSouls.Enabled())) < 100;
				end,

				-- actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled))<100
				Cleave = function(numEnemies)
					return (numEnemies <= 4 or (Talent.ReaperOfSouls.Enabled() and numEnemies <= 2))
					   and Player.Insanity.Drain() * Player.GCD() > Player.Insanity()
					   and Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + (30 + 30 * val(Talent.ReaperOfSouls.Enabled())) < 100;
				end,
			},
		},

		ShadowWordPain = {
			-- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
			Use = function(numEnemies, Target)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and Target.TimeToDie() > 10
				   and (numEnemies < 5 and Artifact.SphereOfInsanity.Trait.Enabled());
			end,

			-- actions.s2m+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
			Misery = function(numEnemies, Target)
				return Talent.Misery.Enabled()
				   and Target.Debuff(Debuff.ShadowWordPain).Remains() < Player.GCD()
				   and Player.IsMoving();
			end,

			-- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
			NotDying = function(numEnemies, Target)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and Target.TimeToDie() > 10
				   and (numEnemies < 5 and (Talent.AuspiciousSpirit.Enabled() or Talent.ShadowyInsight.Enabled()));
			end,

			-- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
			Talents = function(numEnemies)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and (numEnemies < 5 or Talent.AuspiciousSpirits.Enabled() or Talent.ShadowyInsight.Enabled() or Artifact.SphereOfInsanity.Trait.Enabled());
			end,
		},

		-- actions.s2m+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+50)<100
		ShadowWordVoid = function()
			return Talent.ShadowWordVoid.Enabled()
			   and (Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + 50) < 100;
		end,

		VampiricTouch = {
			-- actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
			Use = function(numEnemies, Target)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.VampiricTouch).Up()
				   and Target.TimeToDie() > 10
				   and (numEnemies < 4 or Talent.Sanlayn.Enabled() or (Talent.AuspiciousSpirits.Enabled() and Artifact.UnleashTheShadows.Trait.Enabled()));
			end,

			-- actions.s2m+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
			Misery = function(numEnemies, Target)
				return Talent.Misery.Enabled()
				   and (Target.Debuff(Debuff.VampiricTouch).Remains() < 3 * Player.GCD() or Target.Debuff(Debuff.ShadowWordPain).Remains() < 3 * Player.GCD());
			end,

			-- actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
			Talents = function(numEnemies)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.VampiricTouch).Up()
				   and (numEnemies < 4 or Talent.Sanlayn.Enabled() or (Talent.AuspiciousSpirits.Enabled() and Artifact.UnleashTheShadows.Trait.Enabled()));
			end,
		},

		VoidBolt = {
			-- actions.s2m+=/void_bolt,if=buff.insanity_drain_stacks.value<6&set_bonus.tier19_4pc
			Use = function()
				return Player.Insanity.DrainStacks() < 6
				   and addonTable.Tier19_4PC;
			end,

			-- Simcraft doesn't specify it, but just make sure we don't have any active charges, otherwise its usable immediately.
			-- actions.s2m+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
			Wait = function()
				return Spell.VoidBolt.Cooldown.Remains() > 0
				   and Spell.VoidBolt.Cooldown.Remains() < Player.GCD() * 0.28;
			end,
		},

		-- actions.s2m+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&!buff.power_infusion.up|buff.voidform.stack<5
		VoidTorrent = function()
			return Target.Debuff(Debuff.ShadowWordPain).Remains() > 5.5
			   and Target.Debuff(Debuff.VampiricTouch).Remains() > 5.5
			   and not Player.Buff(Buff.PowerInfusion).Up()
				or Player.Buff(Buff.VoidForm).Stack() < 5;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- actions.s2m=silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up,cycle_targets=1
		action.EvaluateAction(Spell.VoidBolt, self.Requirements.VoidBolt.use);
		-- actions.s2m+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up,cycle_targets=1
		action.EvaluateAction(Talent.ShadowCrash, self.Requirements.ShadowCrash);
		action.EvaluateAction(Talent.Mindbender, self.Requirements.Mindbender);
		action.EvaluateAction(Artifact.VoidTorrent, self.Requirements.VoidTorrent);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.Insanity.Use);
		action.EvaluateAction(Talent.PowerInfusion, self.Requirements.PowerInfusion);
		-- actions.s2m+=/void_bolt
		action.EvaluateAction(Spell.VoidBolt, true);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.Insanity.Cleave);
		action.EvaluateWaitCondition(Spell.VoidBolt, self.Requirements.VoidBolt.Wait);
		action.EvaluateAction(Spell.Dispersion, self.Requirements.Dispersion);
		action.EvaluateAction(Spell.MindBlast, self.Requirements.MindBlast.Use);
		action.EvaluateWaitCondition(Spell.MindBlast, self.Requirements.MindBlast.Wait);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.Use);
		action.EvaluateAction(Spell.Shadowfiend, self.Requirements.Shadowfiend);
		action.EvaluateAction(Talent.ShadowWordVoid, self.Requirements.ShadowWordVoid);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Misery);
		action.EvaluateCycleAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Misery);
		action.EvaluateAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Talents);
		action.EvaluateAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Talents);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.NotDying);
		action.EvaluateCycleAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Use);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Use);
		action.EvaluateInterruptCondition(Spell.MindFlay, true, self.Requirements.MindFlay.Interrupt);
	end

	-- actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
	function self.Use()
		return Player.Buff(Buff.VoidForm).Up()
		   and Player.Buff(Buff.SurrenderToMadness).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local SurrenderMadness = SurrenderMadness("SurrenderMadness");

-- Void Form Rotation
local function VoidForm(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.value<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
		Berserking = function()
			return Player.Buff(Buff.VoidForm).Stack() >= 10
			   and Player.Insanity.DrainStacks() <= 20
			   and (not Talent.SurrenderToMadness.Enabled() or (Talent.SurrenderToMadness.Enabled() and Target.TimeToDie() > Variables.s2mcheck - Player.Insanity.DrainStacks() + 60));
		end,

		-- There is no way in game to do calculations based on raid events such as movement and add spawning, so those parts are just removed from the equation
		-- actions.vf+=/mindbender,if=buff.insanity_drain_stacks.value>=(variable.cd_time+(variable.haste_eval*!set_bonus.tier20_4pc)-(3*set_bonus.tier20_4pc*(raid_event.movement.in<15)*((active_enemies-(raid_event.adds.count*(raid_event.adds.remains>0)))=1))+(5-3*set_bonus.tier20_4pc)*buff.bloodlust.up+2*talent.fortress_of_the_mind.enabled*set_bonus.tier20_4pc)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-buff.insanity_drain_stacks.value))
		Mindbender = function()
			return Player.Insanity.DrainStacks() >= (Variables.cd_time + (Variables.haste_eval * val(addonTable.Tier20_4PC)) + (5 - 3 * val(addonTable.Tier20_4PC)) * val(Player.HasBloodlust()) + 2 * val(Talent.FortressOfTheMind.Enabled()) * val(addonTable.Tier20_4PC))
			   and (not Talent.SurrenderToMadness.Enabled() or (Talent.SurrenderToMadness.Enabled() and Target.TimeToDie() > Variables.s2mcheck - Player.Insanity.DrainStacks()));
		end,

		MindBlast = {
			-- actions.vf+=/mind_blast,if=active_enemies<=4
			Use = function(numEnemies)
				return numEnemies <= 4;
			end,

			-- Simcraft doesn't specify it, but just make sure we don't have any active charges, otherwise its usable immediately.
			-- actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
			Wait = function(numEnemies)
				return Spell.MindBlast.Cooldown.Remains() > 0
				   and Spell.MindBlast.Cooldown.Remains() < Player.GCD() * 0.28
				   and numEnemies <= 4;
			end,
		},

		MindFlay = {
			-- actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
			Interrupt = function()
				return Player.Casting.Tick() >= 2
				   and (Spell.VoidBolt.IsUsable() or (Player.Insanity.Drain() * Player.GCD() > Player.Insanity() and (Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + 30) < 100 and Spell.ShadowWordDeath.Charges() >= 1));
			end,
		},

		-- actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.value>=(variable.cd_time+5*buff.bloodlust.up*(1+1*set_bonus.tier20_4pc))&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+61))
		PowerInfusion = function()
			return Player.Insanity.DrainStacks() >= (Variables.cd_time + 5 * val(Player.HasBloodlust()) * (1 + 1 + val(addonTable.Tier20_4PC)))
			   and (not Talent.SurrenderToMadness.Enabled() or (Talent.SurrenderToMadness.Enabled() and Target.TimeToDie() > Variables.s2mcheck - Player.Insanity.DrainStacks() + 61));
		end,

		-- actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
		ShadowCrash = function()
			return Talent.ShadowCrash.Enabled();
		end,

		-- actions.vf+=/shadowfiend,if=!talent.mindbender.enabled&buff.voidform.stack>15
		Shadowfiend = function()
			return not Talent.Mindbender.Enabled()
			   and Player.Buff(Buff.VoidForm).Stack() > 15;
		end,

		ShadowWordDeath = {
			-- actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2|(equipped.zeks_exterminatus&buff.zeks_exterminatus.react)
			Use = function(numEnemies)
				return (numEnemies <= 4 or (Talent.ReaperOfSouls.Enabled() and numEnemies <= 2))
				   and Spell.ShadowWordDeath.Charges() == 2
					or (Legendary.ZeksExterminatus.Equipped() and Player.Buff(Buff.ZeksExterminatus).React());
			end,

			-- actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
			Insanity = function(numEnemies)
				return (numEnemies <= 4 or (Talent.ReaperOfSouls.Enabled() and numEnemies <= 2))
				   and Player.Insanity.Drain() * Player.GCD() > Player.Insanity()
				   and (Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + (15 + 15 * val(Talent.ReaperOfSouls.Enabled()))) < 100;
			end,

			-- actions.vf+=/shadow_word_death,if=equipped.zeks_exterminatus&equipped.mangazas_madness&buff.zeks_exterminatus.react
			ZeksExterminatus = function()
				return Legendary.ZeksExterminatus.Equipped()
					and Legendary.MangazasMadness.Equipped()
					and Player.Buff(Buff.ZeksExterminatus).React();
			end,
		},

		ShadowWordPain = {
			-- actions.vf+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
			Use = function(numEnemies, Target)
				return numEnemies > 1
				   and not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and ((1 + 0.02 * Player.Buff(Buff.VoidForm).Stack()) * Variables.dot_swp_dpgcd * Target.TimeToDie() / (Player.GCD() * (118 + Variables.sear_dpgcd * (numEnemies - 1)))) > 1;
			end,

			-- actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
			Misery = function(numEnemies, Target)
				return Talent.Misery.Enabled()
				   and Target.Debuff(Debuff.ShadowWordPain).Remains() < Player.GCD()
				   and Player.IsMoving();
			end,

			-- actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
			Talents = function(numEnemies)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.ShadowWordPain).Up()
				   and (numEnemies < 5 or Talent.AuspiciousSpirit.Enabled() or Talent.ShadowyInsight.Enabled() or Artifact.SphereOfInsanity.Trait.Enabled());
			end,
		},

		-- actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
		ShadowWordVoid = function()
			return Talent.ShadowWordVoid.Enabled()
			   and (Player.Insanity() - (Player.Insanity.Drain() * Player.GCD()) + 25) < 100;
		end,

		-- actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.value)
		SurrenderToMadness = function()
			return Talent.SurrenderToMadness.Enabled()
			   and Player.Insanity() >= 25
			   and (Spell.VoidBolt.Cooldown.Up() or Artifact.VoidTorrent.Cooldown.Up() or Spell.ShadowWordDeath.Charges() >= 1 or Player.Buff(Buff.ShadowyInsight).Up())
			   and Target.TimeToDie <= Variables.s2mcheck - Player.Insanity.DrainStacks();
		end,

		VampiricTouch = {
			-- actions.vf+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
			Use = function(numEnemies, Target)
				return numEnemies > 1
				   and not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.VampiricTouch).Up()
				   and ((1 + 0.02 * Player.Buff(Buff.VoidForm).Stack()) * Variables.dot_vt_dpgcd * Target.TimeToDie() / (Player.GCD() * (156 + Variables.sear_dpgcd * (numEnemies - 1)))) > 1;
			end,

			-- actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max)&target.time_to_die>5*gcd.max,cycle_targets=1
			Misery = function(numEnemies, Target)
				return Talent.Misery.Enabled()
				   and (Target.Debuff(Debuff.VampiricTouch).Remains() < 3 * Player.GCD() or Target.Debuff(Debuff.ShadowWordPain).Remains() < 3 * Player.GCD())
				   and Target.TimeToDie() > 5 * Player.GCD();
			end,

			-- actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
			Talents = function(numEnemies)
				return not Talent.Misery.Enabled()
				   and not Target.Debuff(Debuff.VampiricTouch).Up()
				   and (numEnemies < 4 or Talent.Sanlayn.Enabled() or (Talent.AuspiciousSpirit.Enabled() and Artifact.UnleashTheShadows.Trait.Enabled()));
			end,
		},

		VoidBolt = {
			-- Simcraft doesn't specify it, but just make sure we don't have any active charges, otherwise its usable immediately.
			-- actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
			Wait = function()
				return Spell.VoidBolt.Cooldown.Remains() > 0
				   and Spell.VoidBolt.Cooldown.Remains() < Player.GCD() * 0.28;
			end,
		},

		-- actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
		VoidTorrent = function()
			return Target.Debuff(Debuff.ShadowWordPain).Remains() > 5.5
			   and Target.Debuff(Debuff.VampiricTouch).Remains() > 5.5
			   and (not Talent.SurrenderToMadness.Enabled() or (Talent.SurrenderToMadness.Enabled() and Target.TimeToDie() > Variables.s2mcheck - Player.Insanity.DrainStacks() + 60));
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.SurrenderToMadness, self.Requirements.SurrenderToMadness);
		-- actions.vf+=/silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
		-- actions.vf+=/void_bolt
		action.EvaluateAction(Spell.VoidBolt, true);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.ZeksExterminatus);
		-- actions.vf+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
		action.EvaluateAction(Talent.ShadowCrash, self.Requirements.ShadowCrash);
		action.EvaluateAction(Artifact.VoidTorrent, self.Requirements.VoidTorrent);
		action.EvaluateAction(Talent.Mindbender, self.Requirements.Mindbender);
		action.EvaluateAction(Talent.PowerInfusion, self.Requirements.PowerInfusion);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.Insanity);
		action.EvaluateWaitCondition(Spell.VoidBolt, self.Requirements.VoidBolt.Wait);
		action.EvaluateAction(Spell.MindBlast, self.Requirements.MindBlast.Use);
		action.EvaluateWaitCondition(Spell.MindBlast, self.Requirements.MindBlast.Wait);
		action.EvaluateAction(Spell.ShadowWordDeath, self.Requirements.ShadowWordDeath.Use);
		action.EvaluateAction(Spell.Shadowfiend, self.Requirements.Shadowfiend);
		action.EvaluateAction(Talent.ShadowWordVoid, self.Requirements.ShadowWordVoid);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Misery);
		action.EvaluateCycleAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Misery);
		action.EvaluateAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Talents);
		action.EvaluateAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Talents);
		action.EvaluateCycleAction(Spell.VampiricTouch, self.Requirements.VampiricTouch.Use);
		action.EvaluateCycleAction(Spell.ShadowWordPain, self.Requirements.ShadowWordPain.Use);
		action.EvaluateInterruptCondition(Spell.MindFlay, true, self.Requirements.MindFlay.Interrupt);
		-- actions.vf+=/shadow_word_pain
		action.EvaluateAction(Spell.ShadowWordPain, true);
	end

	-- actions+=/run_action_list,name=vf,if=buff.voidform.up
	function self.Use()
		return Player.Buff(Buff.VoidForm).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local VoidForm = VoidForm("VoidForm");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "HowToPriest and SimCraft",
		GuideLink = "https://howtopriest.com/viewtopic.php?f=19&t=8402",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Auspicious Spirits"] = "1001231",
		["Surrender to Madness"] = "1002233",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		Dispersion = function()
			return Player.DamagePredicted(3) >= 30;
		end,

		Fade = function()
			return Player.DamagePredicted(3) >= 15
		end,

		PowerWordShield = function()
			return not Player.Buff(Buff.PowerWordShield).Up()
			   and Player.DamagePredicted(5) >= 15;
		end,

		-- actions=potion,if=buff.bloodlust.react|target.time_to_die<=80|(target.health.pct<35&cooldown.power_infusion.remains<30)
		ProlongedPower = function()
			return Player.HasBloodlust()
				or Target.TimeToDie() <= 80
				or (Target.Health.Percent() < 35 and Talent.PowerInfusion.Cooldown.Remains() < 30);
		end,

		-- actions.precombat+=/shadowform,if=!buff.shadowform.up
		Shadowform = function()
			return not Player.Buff(Buff.Shadowform).Up();
		end,

		ShadowMend = function()
			return Player.Health.Percent() < 60;
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
			ArcaneTorrent = Objects.newSpell(232633),
			Berserking = Objects.newSpell(26297),
			GiftOfTheNaaru = Objects.newSpell(59547),
			QuakingPalm = Objects.newSpell(107079),
			Shadowmeld = Objects.newSpell(58984),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Abilities
			VoidTorrent = Objects.newSpell(205065),
			-- Traits
			MassHysteria = Objects.newSpell(194378),
			SphereOfInsanity = Objects.newSpell(194179),
			UnleashTheShadows = Objects.newSpell(194093),
			FiendingDark = Objects.newSpell(238065),
			LashOfInsanity = Objects.newSpell(238137),
			ToThePain = Objects.newSpell(193644),
			TouchOfDarkness = Objects.newSpell(194007),
			VoidCorruption = Objects.newSpell(194016),
		};

		Spell = {
			-- Abilities
			MindBlast = Objects.newSpell(8092),
			MindFlay = Objects.newSpell(15407),
			VoidEruption = Objects.newSpell(228260),
			VoidBolt = Objects.newSpell(205448),
			ShadowWordDeath = Objects.newSpell(32379),
			ShadowWordPain = Objects.newSpell(589),
			VampiricTouch = Objects.newSpell(34914),
			Shadowfiend = Objects.newSpell(34433),
			Shadowform = Objects.newSpell(232698),
			-- Defensive
			Dispersion = Objects.newSpell(47585),
			Fade = Objects.newSpell(586),
			PowerWordShield = Objects.newSpell(17),
			ShadowMend = Objects.newSpell(186263),
			-- Utility
			Silence = Objects.newSpell(15487),
			VampiricEmbrace = Objects.newSpell(15286),
		};

		Talent = {
			-- Talents
			TwistOfFate = Objects.newSpell(109142),
			FortressOfTheMind = Objects.newSpell(193195),
			ShadowWordVoid = Objects.newSpell(205351),
			LingeringInsanity = Objects.newSpell(199849),
			ReaperOfSouls = Objects.newSpell(199853),
			VoidRay = Objects.newSpell(205371),
			Sanlayn = Objects.newSpell(199855),
			AuspiciousSpirit = Objects.newSpell(155271),
			ShadowyInsight = Objects.newSpell(162452),
			PowerInfusion = Objects.newSpell(10060),
			Misery = Objects.newSpell(238558),
			Mindbender = Objects.newSpell(200174),
			LegacyOfTheVoid = Objects.newSpell(193225),
			ShadowCrash = Objects.newSpell(205385),
			SurrenderToMadness = Objects.newSpell(193223),
		};

		Buff = {
			-- Buffs
			PowerInfusion = Talent.PowerInfusion,
			PowerWordShield = Spell.PowerWordShield,
			Shadowform = Spell.Shadowform,
			ShadowyInsight = Talent.ShadowyInsight,
			SurrenderToMadness = Talent.SurrenderToMadness,
			VoidForm = Objects.newSpell(194249),
			-- Legendaries
			ZeksExterminatus = Objects.newSpell(236546),
		};

		Debuff = {
			-- Debuffs
			ShadowWordPain = Spell.ShadowWordPain,
			VampiricTouch = Spell.VampiricTouch,
		};

		-- Items
		Legendary = {
			-- Legendaries
			MotherShahrazsSeduction = Objects.newItem(132437),
			MangazasMadness = Objects.newItem(132864),
			ZeksExterminatus = Objects.newItem(137100),
		};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.GiftOfTheNaaru, Racial.Shadowmeld);
		config.AOEOptions(options, Talent.ShadowCrash);
		config.BuffOptions(options, Buff.Shadowform);
		config.CooldownOptions(options, Spell.Dispersion, Talent.Mindbender, Talent.PowerInfusion, Talent.ShadowWordVoid, Spell.Shadowfiend, Talent.SurrenderToMadness,
									 Spell.VoidEruption, Artifact.VoidTorrent);
		config.DefensiveOptions(options, "OPT_DISPERSION_DEFENSIVE|Dispersion (Defensive)", Spell.Fade, Spell.PowerWordShield, Spell.ShadowMend);
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
		action.EvaluateDefensiveAction(Spell.Dispersion, self.Requirements.Dispersion, "OPT_DISPERSION_DEFENSIVE");
		action.EvaluateDefensiveAction(Spell.Fade, self.Requirements.Fade);
		action.EvaluateDefensiveAction(Spell.PowerWordShield, self.Requirements.PowerWordShield);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.ShadowMend, self.Requirements.ShadowMend);
	end

	-- Function for displaying interrupts when Target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.Silence, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Racial.QuakingPalm, true);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for setting any pre-combat variables, is always called even if you don't have a target.
	function self.PrecombatVariables()
		-- actions.precombat+=/variable,name=haste_eval,op=set,value=(raw_haste_pct-0.3)*(10+10*equipped.mangazas_madness+5*talent.fortress_of_the_mind.enabled)
		Variables.haste_eval = (Player.HastePercent() - 0.3) * (10 + 10 * val(Legendary.MangazasMadness.Equipped()) + 5 * val(Talent.FortressOfTheMind.Enabled()));
		-- actions.precombat+=/variable,name=haste_eval,op=max,value=0
		Variables.haste_eval = math.max(Variables.haste_eval, 0);
		-- actions.precombat+=/variable,name=erupt_eval,op=set,value=26+1*talent.fortress_of_the_mind.enabled-4*talent.Sanlayn.enabled-3*talent.Shadowy_insight.enabled+variable.haste_eval*1.5
		Variables.erupt_eval = 26 + 1 * val(Talent.FortressOfTheMind.Enabled()) - 4 * val(Talent.Sanlayn.Enabled()) - 3 * val(Talent.ShadowyInsight.Enabled()) + Variables.haste_eval * 1.5;
		-- actions.precombat+=/variable,name=cd_time,op=set,value=(12+(2-2*talent.mindbender.enabled*set_bonus.tier20_4pc)*set_bonus.tier19_2pc+(1-3*talent.mindbender.enabled*set_bonus.tier20_4pc)*equipped.mangazas_madness+(6+5*talent.mindbender.enabled)*set_bonus.tier20_4pc+2*artifact.lash_of_insanity.rank)
		Variables.cd_time = (12 + (2 - 2 * val(Talent.Mindbender.Enabled()) * val(addonTable.Tier20_4PC)) * val(addonTable.Tier19_2PC) + (1 - 3 * val(Talent.Mindbender.Enabled()) * val(addonTable.Tier20_4PC)) * val(Legendary.MangazasMadness.Equipped()) + (6 + 5 * val(Talent.Mindbender.Enabled())) * val(addonTable.Tier20_4PC) + 2 * Artifact.LashOfInsanity.Trait.Rank());
		-- actions.precombat+=/variable,name=dot_swp_dpgcd,op=set,value=36.5*1.2*(1+0.06*artifact.to_the_pain.rank)*(1+0.2+stat.mastery_rating%16000)*0.75
		Variables.dot_swp_dpgcd = 36.5 * 1.2 * (1 + 0.06 * Artifact.ToThePain.Trait.Rank()) * (1 + 0.2 + Player.MasteryRating() / 16000) * 0.75;
		-- actions.precombat+=/variable,name=dot_vt_dpgcd,op=set,value=68*1.2*(1+0.2*talent.sanlayn.enabled)*(1+0.05*artifact.touch_of_darkness.rank)*(1+0.2+stat.mastery_rating%16000)*0.5
		Variables.dot_vt_dpgcd = 68 * 1.2 * (1 + 0.2 * val(Talent.Sanlayn.Enabled())) * (1 + 0.05 * Artifact.TouchOfDarkness.Trait.Rank()) * (1 + 0.2 + Player.MasteryRating() / 16000) * 0.5;
		-- actions.precombat+=/variable,name=sear_dpgcd,op=set,value=120*1.2*(1+0.05*artifact.void_corruption.rank)
		Variables.sear_dpgcd = 120 * 1.2 * (1 + 0.05 * Artifact.VoidCorruption.Trait.Rank());

		-- if=talent.surrender_to_madness.enabled
		if Talent.SurrenderToMadness.Enabled() then
			-- actions.precombat+=/variable,name=s2msetup_time,op=set,value=(0.8*(83+(20+20*talent.fortress_of_the_mind.enabled)*set_bonus.tier20_4pc-(5*talent.sanlayn.enabled)+((33-13*set_bonus.tier20_4pc)*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*equipped.mangazas_madness+(raw_haste_pct*10*(1+0.7*set_bonus.tier20_4pc))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled))))
			Variables.s2msetup_time = (0.8 * (83 + (20 + 20 * val(Talent.FortressOfTheMind.Enabled())) * val(addonTable.Tier20_4PC) - (5 * val(Talent.Sanlayn.Enabled())) + ((33 - 13 * val(addonTable.Tier20_4PC)) * val(Talent.ReaperOfSouls.Enabled())) + val(addonTable.Tier19_2PC) * 4 + 8 * val(Legendary.MangazasMadness.Equipped()) + (Player.HastePercent() * 10 * (1 + 0.7 * val(addonTable.Tier20_4PC))) * (2 + (0.8 * val(addonTable.Tier19_2PC)) + (1 * val(Talent.ReaperOfSouls.Enabled())) + (2 * Artifact.MassHysteria.Trait.Rank()) - (1 * val(Talent.Sanlayn.Enabled())))));
		end
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		action.EvaluateAction(Spell.Shadowform, self.Requirements.Shadowform);
		-- actions.precombat+=/mind_blast
		action.EvaluateAction(Spell.MindBlast, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);

		action.CallActionList(Variables);
		action.RunActionList(SurrenderMadness);
		action.RunActionList(VoidForm);
		-- actions+=/run_action_list,name=main
		action.RunActionList(Main);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Shadow Priest", addonTable.Enum.SpecID.PRIEST_SHADOW);