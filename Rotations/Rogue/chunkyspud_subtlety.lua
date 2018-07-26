local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Core = addon.Core.General
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;
local Settings = addon.Core.Settings;

-- Function for converting booleans returns to numbers
local val = Core.ToNumber;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

local nameAPL = "chunkyspud_rogue_subtlety";

-- Variables
local function Variables(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Function to set variables that are set outside of combat.
	function self.Precombat()
		self.ssw_refund_offset = 0

		if Target.NPCID() == 101002 or Target.NPCID() == 114537 then
			self.ssw_refund_offset = 2
		end
		-- actions.precombat+=/variable,name=ssw_refund,value=equipped.shadow_satyrs_walk*(6+ssw_refund_offset)
		self.ssw_refund = val(Legendary.ShadowSatyrsWalk.Equipped()) * (6 + self.ssw_refund_offset)
		-- actions.precombat+=/variable,name=stealth_threshold,value=(65+talent.vigor.enabled*35+talent.master_of_shadows.enabled*10+variable.ssw_refund)
		self.stealth_threshold = 65 + (val(Talent.Vigor.Enabled()) * 35) + (val(Talent.MasterOfShadows.Enabled()) * 10) + self.ssw_refund
		-- actions.precombat+=/variable,name=shd_fractional,value=1.725+0.725*talent.enveloping_shadows.enabled
		self.shd_fractional = 1.725 + (0.725 * val(Talent.EnvelopingShadows.Enabled()))
	end

	-- Function to set variables that change in combat.
	function self.Rotation(action)
		-- actions=variable,name=dsh_dfa,value=talent.death_from_above.enabled&talent.dark_shadow.enabled&spell_targets.death_from_above<4
		self.dsh_dfa = Talent.DeathFromAbove.Enabled() and Talent.DarkShadow.Enabled() and Enemies.GetEnemies() < 4

		self.cp_max_spend = 5

		if Talent.DeeperStratagem.Enabled() then
			self.cp_max_spend = 6
		end
	end

	return self
end

-- Create a variable so we can call the functions to set rotation variables.
local Variables = Variables("Variables");

-- Finishers
local function Finisher(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Nightblade = {
			One = function(numEnemies, ...)
				-- actions.finish=nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&(mantle_duration=0|remains<=mantle_duration)&((refreshable&(!finality|buff.finality_nightblade.up|variable.dsh_dfa))|remains<tick_time*2)&(spell_targets.shuriken_storm<4&!variable.dsh_dfa|!buff.symbols_of_death.up)
				return (not Talent.DarkShadow.Enabled() or not Player.Buff(Buff.ShadowDance).Up())
					and Target.TimeToDie() - Target.Debuff(Debuff.Nightblade).Remains() > 6
					and (Player.Buff(Buff.MasterAssassin).Duration() == 0 or Target.Debuff(Debuff.Nightblade).Remains() <= Player.Buff(Buff.MasterAssassin).Duration())
					and ((Target.Debuff(Debuff.Nightblade).Refreshable() and (not Artifact.Finality.Trait.Enabled() or Player.Buff(Buff.FinalityNightblade).Up() or Variables.dsh_dfa))
					or Target.Debuff(Debuff.Nightblade).Remains() < 4)
					and (numEnemies < 4 and not Variables.dsh_dfa or not Player.Buff(Buff.SymbolsOfDeath).Up())
			end,
			Two = function(numEnemies, Target)
				-- actions.finish+=/nightblade,cycle_targets=1,if=(!talent.death_from_above.enabled|set_bonus.tier19_2pc)&(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>12&mantle_duration=0&((refreshable&(!finality|buff.finality_nightblade.up|variable.dsh_dfa))|remains<tick_time*2)&(spell_targets.shuriken_storm<4&!variable.dsh_dfa|!buff.symbols_of_death.up)
				return (not Talent.DeathFromAbove.Enabled() or addonTable.Tier19_2PC)
					and (not Talent.DarkShadow.Enabled() or not Player.Buff(Buff.ShadowDance).Up())
					and Target.TimeToDie() - Target.Debuff(Debuff.Nightblade).Remains() > 12
					and (Player.Buff(Buff.MasterAssassin).Duration() == 0 or Target.Debuff(Debuff.Nightblade).Remains() <= Player.Buff(Buff.MasterAssassin).Duration())
					and ((Target.Debuff(Debuff.Nightblade).Refreshable() and (not Artifact.Finality.Trait.Enabled() or Player.Buff(Buff.FinalityNightblade).Up() or Variables.dsh_dfa))
					or Target.Debuff(Debuff.Nightblade).Remains() < 4)
					and (numEnemies < 4 and not Variables.dsh_dfa or not Player.Buff(Buff.SymbolsOfDeath).Up())
			end,
			Three = function(...)
				-- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5+(combo_points=6)&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
				return Target.Debuff(Debuff.Nightblade).Remains() < Spell.SymbolsOfDeath.Cooldown.Remains() + 10
					and Spell.SymbolsOfDeath.Cooldown.Remains() <= 5 + (val(Player.ComboPoints() == 6)) and val(Target.TimeToDie()) - val(Target.Debuff(Debuff.Nightblade).Remains()) > val(Spell.SymbolsOfDeath.Cooldown.Remains()) + 5
			end,
		},
		DeathFromAbove = function(numEnemies, ...)
			-- actions.finish+=/death_from_above,if=!talent.dark_shadow.enabled|(!buff.shadow_dance.up|spell_targets>=4)&(buff.symbols_of_death.up|cooldown.symbols_of_death.remains>=10+set_bonus.tier20_4pc*5)&buff.the_first_of_the_dead.remains<1&(buff.finality_eviscerate.up|spell_targets.shuriken_storm<4)
			return not Talent.DarkShadow.Enabled()
				or (not Player.Buff(Buff.ShadowDance).Up() or numEnemies >= 4)
				and (Player.Buff(Buff.SymbolsOfDeath).Up() or Spell.SymbolsOfDeath.Cooldown.Remains() >= 10 + val(addonTable.Tier20_4PC) * 5) and Player.Buff(Buff.FirstOfTheDead).Remains() < 1
				and (Player.Buff(Buff.FinalityEviscerate).Up() or numEnemies <= 4)
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Nightblade, self.Requirements.Nightblade.One)
		action.EvaluateCycleAction(Spell.Nightblade, self.Requirements.Nightblade.Two)
		action.EvaluateAction(Spell.Nightblade, self.Requirements.Nightblade.Three)
		action.EvaluateAction(Talent.DeathFromAbove, self.Requirements.DeathFromAbove)
		action.EvaluateAction(Spell.Eviscerate, true)
	end

	return self
end

local Finisher = Finisher("Finisher")

-- Stealthed Rotation
local function Stealthed(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ShadowStrike = function(...)
			--actions.stealthed=shadowstrike,if=buff.stealth.up
			return Player.IsStealthed()
		end,
		Finisher = {
			One = function(numEnemies, ...)
				--actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5+(talent.deeper_stratagem.enabled&buff.vanish.up)&(spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
				return Player.ComboPoints() >= 5 + (val(Talent.DeeperStratagem.Enabled()) and val(Player.Buff(Buff.Vanish).Up()))
					and (numEnemies >= 3 + val(Legendary.ShadowSatyrsWalk.Equipped()) or (Player.Buff(Buff.MasterAssassin).Duration() <= 1.3
					and Player.Buff(Buff.MasterAssassin).Duration() - Player.GCD.Remains() >= 0.3))
			end,
			Two = function(...)
				--actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5+(talent.deeper_stratagem.enabled&buff.vanish.up)&combo_points.deficit<3+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
				return Player.ComboPoints() >= 5 + (val(Talent.DeeperStratagem.Enabled())
					and val(Player.Buff(Buff.Vanish).Up()))
					and Player.ComboPoints.Deficit() < 3 + val(Player.Buff(Buff.ShadowBlades).Up()) - val(Legendary.MantleOfTheMasterAssassin.Equipped())
			end,
		},
		ShurikenStorm = function(numEnemies, ...)
			--actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=2+equipped.insignia_of_ravenholdt&spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1&buff.the_dreadlords_deceit.stack>=29))
			return Player.Buff(Buff.Shadowmeld).Down()
				and ((Player.ComboPoints.Deficit() >= 2 + val(Legendary.InsigniaOfRavenholdt.Equipped())
				and numEnemies >= 3 + val(Legendary.ShadowSatyrsWalk.Equipped())) or (Player.ComboPoints.Deficit() >= 1
				and Player.Buff(Buff.DreadlordsDeceit).Stack() >= 29))
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.ShadowStrike, self.Requirements.ShadowStrike)
		action.CallActionList(Finisher, self.Requirements.Finisher.One)
		action.EvaluateAction(Spell.ShurikenStorm, self.Requirements.ShurikenStorm)
		action.CallActionList(Finisher, self.Requirements.Finisher.Two)
		action.EvaluateAction(Spell.ShadowStrike, true)
	end

	function self.Use()
		-- actions+=/run_action_list,name=stealthed,if=stealthed.all
		return Player.IsStealthed()
	end

	return self
end

local Stealthed = Stealthed("Stealthed")

-- Builders
local function Builder(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ShurikenStorm = function(numEnemies, ...)
			-- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2+buff.the_first_of_the_dead.up
			return numEnemies >= 2 + val(Player.Buff(Buff.FirstOfTheDead).Up())
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.ShurikenStorm, self.Requirements.ShurikenStorm)
		action.EvaluateAction(Talent.Gloomblade, true)
		action.EvaluateAction(Spell.Backstab, true)
	end

	function self.Use()
		-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
		return Player.Energy.Deficit() <= Variables.stealth_threshold
	end

	return self
end

-- Create a variable so we can call the rotations functions.
local Builder = Builder("Builder")

-- Cooldowns
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function(...)
			-- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
			return Settings.GetCharacterValue("ScriptOptions", "OPT_ARCANE_TORRENT_INTERRUPT") == 0
				and Player.IsStealthed()
				and Player.Energy.Deficit() > 70
		end,
		BadgeOfConquest = function(...)
			-- actions.cds+=/use_item,name=fierce_combatants_badge_of_conquest,if=(buff.shadow_blades.up&stealthed.rogue)|target.time_to_die<20
			return (Player.Buff(Buff.ShadowBlades).Up()
				and Player.IsStealthed())
				or Target.TimeToDie() < 20
		end,
		Berserking = function(...)
			-- actions.cds+=/berserking,if=stealthed.rogue
			return Player.IsStealthed()
		end,
		BloodFury = function(...)
			-- actions.cds+=/blood_fury,if=stealthed.rogue
			return Player.IsStealthed()
		end,
		GoremawsBite = function(...)
			-- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=variable.shd_fractional&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
			return not Player.IsStealthed()
				and Spell.ShadowDance.Charges.Fractional() <= Variables.shd_fractional
				and ((Player.ComboPoints.Deficit() >= 4 - val(Core.CombatTime() < 10) * 2 and Player.Energy.Deficit() > 50 + val(Talent.Vigor.Enabled()) * 25 - val(Core.CombatTime() >= 10) * 15)
				or (Player.ComboPoints.Deficit() >= 1 and Target.TimeToDie() < 8))
		end,
		MarkedForDeath = {
			One = function(...)
				-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
				return Target.TimeToDie() < Player.ComboPoints.Deficit()
			end,
			Two = function(...)
				-- actions.cds+=/marked_for_death,if=raid_event.adds.in>40&!stealthed.all&combo_points.deficit>=cp_max_spend
				return not Player.IsStealthed()
					and Player.ComboPoints.Deficit() >= Variables.cp_max_spend
			end,
		},
		ProlongedPower = function(...)
			-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
			return Player.HasBloodlust() or Target.TimeToDie() <= 60
				or (Player.Buff(Buff.Vanish).Up()
				and (Player.Buff(Buff.ShadowBlades).Up() or Spell.ShadowBlades.Cooldown.Remains() <= 30))
		end,
		ShadowBlades = function(...)
			-- actions.cds+=/shadow_blades,if=(time>10&combo_points.deficit>=2+stealthed.all-equipped.mantle_of_the_master_assassin)|(time<10&(!talent.marked_for_death.enabled|combo_points.deficit>=3|dot.nightblade.ticking))
			return (Core.CombatTime() > 10 and Player.ComboPoints.Deficit() >= 2 + val(Player.IsStealthed()) - val(Legendary.MantleOfTheMasterAssassin.Equipped()))
				or (Core.CombatTime() < 10 and (not Talent.MarkedForDeath.Enabled() or Player.ComboPoints.Deficit() >= 3 or Target.Debuff(Debuff.Nightblade).Up()))
		end,
		ShadowDance = {
			One = function(...)
				-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=4+talent.subterfuge.enabled
				return not Player.Buff(Buff.ShadowDance).Up()
					and Target.TimeToDie() <= 4 + val(Talent.Subterfuge.Enabled())
			end,
			Two = function(...)
				-- actions+=/shadow_dance,if=talent.dark_shadow.enabled&(!stealthed.all|buff.subterfuge.up)&buff.death_from_above.up&buff.death_from_above.remains<=0.15
				return Talent.DarkShadow.Enabled()
					and (not Player.IsStealthed() or Player.Buff(Buff.Subterfuge).Up())
					and Player.Buff(Buff.DeathFromAbove).Up() and Player.Buff(Buff.DeathFromAbove).Remains() <= 0.15
			end,
		},
		SymbolsOfDeath = {
			One = function(...)
				-- actions.cds+=/symbols_of_death,if=!talent.death_from_above.enabled&((time>10&energy.deficit>=40-stealthed.all*30)|(time<10&dot.nightblade.ticking))
				return not Talent.DeathFromAbove.Enabled()
					and ((Core.CombatTime() > 10 and Player.Energy.Deficit() >= 40 - val(Player.IsStealthed()) * 30)
					or Core.CombatTime() < 10 and Target.Debuff(Debuff.Nightblade).Up())
			end,
			Two = function(...)
				-- actions.cds+=/symbols_of_death,if=(talent.death_from_above.enabled&cooldown.death_from_above.remains<=3&(dot.nightblade.remains>=cooldown.death_from_above.remains+3|target.time_to_die-dot.nightblade.remains<=6)&(time>=3|set_bonus.tier20_4pc|equipped.the_first_of_the_dead))|target.time_to_die-remains<=10
				return (Talent.DeathFromAbove.Enabled() and Talent.DeathFromAbove.Cooldown.Remains() <= 3
					and (Target.Debuff(Debuff.Nightblade).Remains() >= Talent.DeathFromAbove.Cooldown.Remains() + 3
					or Target.TimeToDie() - Target.Debuff(Debuff.Nightblade).Remains() <= 6)
					and (Core.CombatTime() >= 3 or addonTable.Tier20_4PC or Legendary.FirstOfTheDead.Equipped()))
					or Target.TimeToDie() <= 10
			end,
		},
		Vanish = function(...)
			-- actions.cds+=/vanish,if=energy>=55-talent.shadow_focus.enabled*10&variable.dsh_dfa&(!equipped.mantle_of_the_master_assassin|buff.symbols_of_death.up)&cooldown.shadow_dance.charges_fractional<=variable.shd_fractional&!buff.shadow_dance.up&!buff.stealth.up&mantle_duration=0&(dot.nightblade.remains>=cooldown.death_from_above.remains+6|target.time_to_die-dot.nightblade.remains<=6)&cooldown.death_from_above.remains<=1|target.time_to_die<=7
			return Player.Energy() >= 55 - val(Talent.ShadowFocus.Enabled()) * 10
				and Variables.dsh_dfa
				and (not Legendary.MantleOfTheMasterAssassin.Equipped or Player.Buff(Buff.SymbolsOfDeath).Up())
				and Spell.ShadowDance.Charges.Fractional() <= Variables.shd_fractional
				and not Player.Buff(Buff.ShadowDance).Up() and not Player.Buff(Buff.Stealth).Up() and Player.Buff(Buff.MasterAssassin).Duration() == 0
				and (Target.Debuff(Debuff.Nightblade).Remains() >= Talent.DeathFromAbove.Cooldown.Remains() + 6 or Target.TimeToDie() - val(Target.Debuff(Debuff.Nightblade).Remains()) <= 6)
				and Talent.DeathFromAbove.Cooldown.Remains() <= 1 or Target.TimeToDie() <= 7
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.ShadowDance, self.Requirements.ShadowDance.Two)
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower)
		action.EvaluateAction(Item.BadgeOfConquestA, self.Requirements.BadgeOfConquest)
		action.EvaluateAction(Item.BadgeOfConquestH, self.Requirements.BadgeOfConquest)
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury)
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking)
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent)
		action.EvaluateAction(Spell.SymbolsOfDeath, self.Requirements.SymbolsOfDeath.One)
		action.EvaluateAction(Spell.SymbolsOfDeath, self.Requirements.SymbolsOfDeath.Two)
		action.EvaluateAction(Talent.MarkedForDeath, self.Requirements.MarkedForDeath.One)
		action.EvaluateAction(Talent.MarkedForDeath, self.Requirements.MarkedForDeath.Two)
		action.EvaluateAction(Spell.ShadowBlades, self.Requirements.ShadowBlades)
		action.EvaluateAction(Artifact.GoremawsBite, self.Requirements.GoremawsBite)
		action.EvaluateAction(Spell.Vanish, self.Requirements.Vanish)
		action.EvaluateAction(Spell.ShadowDance, self.Requirements.ShadowDance.One)
	end

	return self
end

local Cooldowns = Cooldowns("Cooldowns")

-- Stealthed Cooldowns
local function StealthCDS(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Vanish = function(...)
			--actions.stealth_cds=vanish,if=!variable.dsh_dfa&mantle_duration=0&cooldown.shadow_dance.charges_fractional<variable.shd_fractional+(equipped.mantle_of_the_master_assassin&time<30)*0.3&(!equipped.mantle_of_the_master_assassin|buff.symbols_of_death.up)
			return not Variables.dsh_dfa
				and Player.Buff(Buff.MasterAssassin).Duration() == 0
				and Spell.ShadowDance.Charges.Fractional() < Variables.shd_fractional + val(Legendary.MantleOfTheMasterAssassin.Equipped() and Core.CombatTime() < 30) * 0.3
				and (not Legendary.MantleOfTheMasterAssassin.Equipped() or Player.Buff(Buff.SymbolsOfDeath).Up())
		end,
		ShadowDance = {
			One = function(...)
				--actions.stealth_cds+=/shadow_dance,if=charges_fractional>=variable.shd_fractional|target.time_to_die<cooldown.symbols_of_death.remains
				return Spell.ShadowDance.Charges.Fractional() >= Variables.shd_fractional
					or Target.TimeToDie() < Spell.SymbolsOfDeath.Cooldown.Remains()
			end,
			Two = function(numEnemies, ...)
				--actions.stealth_cds+=/shadow_dance,if=!variable.dsh_dfa&combo_points.deficit>=2+talent.subterfuge.enabled*2&(buff.symbols_of_death.remains>=1.2+gcd.remains|cooldown.symbols_of_death.remains>=12+(talent.dark_shadow.enabled&set_bonus.tier20_4pc)*3-(!talent.dark_shadow.enabled&set_bonus.tier20_4pc)*4|mantle_duration>0)&(spell_targets.shuriken_storm>=4|!buff.the_first_of_the_dead.up)
				return not Variables.dsh_dfa
					and Player.ComboPoints.Deficit() >= 2 + val(Talent.Subterfuge.Enabled()) * 2
					and (Player.Buff(Buff.SymbolsOfDeath).Remains() >= 1.2 + Player.GCD.Remains() or Spell.SymbolsOfDeath.Cooldown.Remains() >= 12 + val(Talent.DarkShadow.Enabled() and addonTable.Tier20_4PC) * 3 - val(not Talent.DarkShadow.Enabled() and addonTable.Tier20_4PC) * 4 or Player.Buff(Buff.MasterAssassin).Duration() > 0)
					and (numEnemies >= 4 or not Player.Buff(Buff.FirstOfTheDead).Up())
			end,
		},
		--actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
		Shadowmeld = function(...)
			--actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10+variable.ssw_refund
			return Player.Energy() >= 40
				and Player.Energy.Deficit() >= 10 + Variables.ssw_refund
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Vanish, self.Requirements.Vanish)
		action.EvaluateAction(Spell.ShadowDance, self.Requirements.ShadowDance.One)
		-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
		action.EvaluateAction(Racial.Shadowmeld, self.Requirements.Shadowmeld)
		action.EvaluateAction(Spell.ShadowDance, self.Requirements.ShadowDance.Two)
	end

	return self
end

local StealthCDS = StealthCDS("StealthCDS")

-- Stealth Action List Starter
local function StealthALS(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Energy = function(...)
			-- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold-25*(!cooldown.goremaws_bite.up&!buff.feeding_frenzy.up)&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=variable.shd_fractional|energy.deficit>=10)
			return Player.Energy.Deficit() <= Variables.stealth_threshold - 25 * val(not Artifact.GoremawsBite.Cooldown.Up() and not Player.Buff(Buff.FeedingFrenzy).Up())
				and (not Legendary.ShadowSatyrsWalk.Equipped() or Spell.ShadowDance.Charges.Fractional() >= Variables.shd_fractional or Player.Energy.Deficit() >= 10)
		end,
		MantleOfTheMasterAssassin = function(...)
			-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=mantle_duration>2.3
			return Player.Buff(Buff.MasterAssassin).Duration() > 2.3
		end,
		ShurikenStorm = function(numEnemies, ...)
			-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=4
			return numEnemies >= 4
		end,
		Shadowmeld = function(...)
			-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
			return (Racial.Shadowmeld.Cooldown.Up()
				and not Spell.Vanish.Cooldown.Up()
				and Spell.ShadowDance.Charges() <= 1)
		end,
		TimeToDie = function(...)
			-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)
			return Target.TimeToDie() < 12 * val(Spell.ShadowDance.Charges.Fractional()) * (1 + val(Legendary.ShadowSatyrsWalk.Equipped()) * 0.5)
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.CallActionList(StealthCDS, self.Requirements.Energy)
		action.CallActionList(StealthCDS, self.Requirements.MantleOfTheMasterAssassin)
		action.CallActionList(StealthCDS, self.Requirements.ShurikenStorm)
		action.CallActionList(StealthCDS, self.Requirements.Shadowmeld)
		action.CallActionList(StealthCDS, self.Requirements.TimeToDie)
	end

	return self
end

local StealthALS = StealthALS("StealthALS")

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Gray_Hound and SimCraft",
		GuideLink = "http://www.wowhead.com/subtlety-rogue-guide",
		WoWVersion = 70300,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raid"] = "2310013",
		["Solo / World Quests"] = "2110012",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function(...)
			return Target.InRange(8);
		end,
		CheapShot = function(...)
			return Target.IsStunnable()
				and Player.IsStealthed()
				and Target.InRange(5)
		end,
		Finisher = {
			One = function(numEnemies, ...)
				-- actions+=/call_action_list,name=finish,if=combo_points>=5+3*(buff.the_first_of_the_dead.up&talent.anticipation.enabled)+(talent.deeper_stratagem.enabled&!buff.shadow_blades.up&(mantle_duration=0|set_bonus.tier20_4pc)&(!buff.the_first_of_the_dead.up|variable.dsh_dfa))
				-- |(combo_points>=4&combo_points.deficit<=2&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)|(target.time_to_die<=1&combo_points>=3)
				return Player.ComboPoints() >= 5 + 3 * val(Player.Buff(Buff.FirstOfTheDead).Up() and Talent.Anticipation.Enabled()) + val(Talent.DeeperStratagem.Enabled() and not Player.Buff(Buff.ShadowBlades).Up() and (Player.Buff(Buff.MasterAssassin).Duration() or addonTable.Tier20_4PC) and (not Player.Buff(Buff.FirstOfTheDead).Up() or Variables.dsh_dfa))
					or (Player.ComboPoints() >= 4 and Player.ComboPoints.Deficit() <= 2 and numEnemies >= 3 and numEnemies <= 4)
					or (Target.TimeToDie() <= 1 and Player.ComboPoints() >= 3)
			end,
			Two = function(numEnemies, ...)
				-- actions+=/call_action_list,name=finish,if=variable.dsh_dfa&cooldown.symbols_of_death.remains<=1&combo_points>=2&equipped.the_first_of_the_dead&spell_targets.shuriken_storm<2
				return Variables.dsh_dfa
					and Spell.SymbolsOfDeath.Cooldown.Remains() <= 1
					and Player.ComboPoints() >= 2
					and Legendary.FirstOfTheDead.Equipped()
					and numEnemies < 2
			end,
		},
		KidneyShot = function(...)
			return Target.IsStunnable()
				and Target.InRange(5)
		end,
		Nightblade = function(...)
			-- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
			return Target.TimeToDie() > 6
				and Target.Debuff(Debuff.Nightblade).Remains() < Player.GCD()
				and Player.ComboPoints() >= 4 - val(Core.CombatTime() < 10) * 2
		end,
		ProlongedPower = function(...)
			-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
			return Player.HasBloodlust()
				or Target.TimeToDie() <= 60
				or (Player.Buff(Buff.Vanish).Up() and (Player.Buff(Buff.ShadowBlades).Up() or Spell.ShadowBlades.Cooldown.Remains() <= 30))
		end,
		Stealth = function(...)
			-- actions.precombat+=/stealth
			return not Player.Buff(Buff.Stealth).Up()
		end,
		ShadowDance = function(...)
			-- actions+=/shadow_dance,if=talent.dark_shadow.enabled&(!stealthed.all|buff.subterfuge.up)&buff.death_from_above.up&buff.death_from_above.remains<=0.15
			return Talent.DarkShadow.Enabled() and (not Player.IsStealthed() or Player.Buff(Buff.Subterfuge).Up()) and Player.Buff(Buff.DeathFromAbove).Up() and Player.Buff(Buff.DeathFromAbove).Remains() > 0
		end,
		ShurikenToss = function (...)
			-- Shuriken Toss when out of range
			return Target.InRange.Min() >= 10 and not Player.IsStealthed() and not Player.Buff(Buff.Sprint).Up()
				and Player.Energy.Deficit() < 20 and (Player.ComboPoints.Deficit() >= 1 or Player.Energy.TimeToMax() <= 1.2)
		end,
		StealthALS = {
			One = function(...)
				-- actions+=/call_action_list,name=stealth_als,if=talent.dark_shadow.enabled&combo_points.deficit>=2+buff.shadow_blades.up&(dot.nightblade.remains>4+talent.subterfuge.enabled|cooldown.shadow_dance.charges_fractional>=1.9&(!equipped.denial_of_the_halfgiants|time>10))
				return (Talent.DarkShadow.Enabled()
					and Player.ComboPoints.Deficit() >= 2 + val(Player.Buff(Buff.ShadowBlades).Up())
					and (Target.Debuff(Debuff.Nightblade).Remains() > 4 + val(Talent.Subterfuge.Enabled())) or Spell.ShadowDance.Charges.Fractional() >= 1.9
					and (not Legendary.DenialOfTheHalfgiants.Equipped() or Core.CombatTime() >= 10))
			end,
			Two = function(...)
				-- actions+=/call_action_list,name=stealth_als,if=!talent.dark_shadow.enabled&(combo_points.deficit>=2+buff.shadow_blades.up|cooldown.shadow_dance.charges_fractional>=1.9+talent.enveloping_shadows.enabled)
				return (not Talent.DarkShadow.Enabled() and (Player.ComboPoints.Deficit() >= 2 + val(Player.Buff(Buff.ShadowBlades).Up())
					or Spell.ShadowDance.Charges.Fractional() >= 1.9 + val(Talent.EnvelopingShadows.Enabled())))
			end,
		},
		WarStomp = function(...)
			return Target.IsStunnable()
				and Target.InRange(5);
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
			BloodFury = Objects.newSpell(20572),
			GiftOfTheNaaru = Objects.newSpell(59547),
			QuakingPalm = Objects.newSpell(107079),
			Shadowmeld = Objects.newSpell(58984),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Abilities
			GoremawsBite = Objects.newSpell(209782),
			-- Traits
			Finality = Objects.newSpell(197406)
		}

		Spell = {
			-- Abilities
			Backstab = Objects.newSpell(53),
			CheapShot = Objects.newSpell(1833),
			Eviscerate = Objects.newSpell(196819),
			KidneyShot = Objects.newSpell(408),
			Nightblade = Objects.newSpell(195452),
			ShadowBlades = Objects.newSpell(121471),
			ShadowDance = Objects.newSpell(185313),
			ShadowStrike = Objects.newSpell(185438),
			ShurikenStorm = Objects.newSpell(197835),
			ShurikenToss = Objects.newSpell(114014),
			Stealth = Objects.newSpell(1784),
			SymbolsOfDeath = Objects.newSpell(212283),
			Vanish = Objects.newSpell(1856),

			-- Defensive
			CloakOfShadows = Objects.newSpell(31224),
			Evasion = Objects.newSpell(5277),
			Feint = Objects.newSpell(1966),
			-- Utility
			CrimsonVial = Objects.newSpell(185311),
			Kick = Objects.newSpell(1766),
		}

		Talent = {
			-- Talents
			Gloomblade = Objects.newSpell(200758),
			Subterfuge = Objects.newSpell(108208),
			ShadowFocus = Objects.newSpell(108209),
			DeeperStratagem = Objects.newSpell(193531),
			Anticipation = Objects.newSpell(114015),
			Vigor = Objects.newSpell(14983),
			DarkShadow = Objects.newSpell(245687),
			EnvelopingShadows = Objects.newSpell(238104),
			MasterOfShadows = Objects.newSpell(196976),
			MarkedForDeath = Objects.newSpell(137619),
			DeathFromAbove = Objects.newSpell(152150),
		}

		Buff = {
			-- Buffs
			DeathFromAbove = Talent.DeathFromAbove,
			FeedingFrenzy = Objects.newSpell(242705),
			FinalityEviscerate = Objects.newSpell(197496),
			FinalityNightblade = Objects.newSpell(197498),
			ShadowBlades = Spell.ShadowBlades,
			ShadowDance = Objects.newSpell(185422),
			Shadowmeld = Racial.Shadowmeld,
			Sprint = Objects.newSpell(2983),
			Stealth = Spell.Stealth,
			StealthSub = Objects.newSpell(115191),
			Subterfuge = Objects.newSpell(115192),
			SymbolsOfDeath = Spell.SymbolsOfDeath,
			Vanish = Objects.newSpell(11327),
			VanishSub = Objects.newSpell(115193),
			-- Legendaries
			MasterAssassin = Objects.newSpell(235022),
			FirstOfTheDead = Objects.newSpell(248110),
			DreadlordsDeceit = Objects.newSpell(228224),
		}

		Debuff = {
			-- Debuffs
			Nightblade = Objects.newSpell(195452),
		}

		-- Items
		Legendary = {
			-- Legendaries
			ShadowSatyrsWalk = Objects.newItem(137032),
			MantleOfTheMasterAssassin = Objects.newItem(144236),
			FirstOfTheDead = Objects.newItem(151818),
			InsigniaOfRavenholdt = Objects.newItem(137049),
			DenialOfTheHalfgiants = Objects.newItem(137100),
		}

		Item = {
			BadgeOfConquestA = Objects.newItem(149702),
			BadgeOfConquestH = Objects.newItem(149703),
		}

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		}

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.AOEOptions(options, Spell.ShurikenStorm);
		config.BuffOptions(options, Buff.Stealth);
		config.CooldownOptions(options, Spell.ShadowBlades, Spell.SymbolsOfDeath, Spell.Vanish, Artifact.GoremawsBite, Item.BadgeOfConquestA, Item.BadgeOfConquestH);
		config.DefensiveOptions(options, Spell.CloakOfShadows, Spell.Evasion, Spell.Feint);
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
	end

	-- Function for displaying interrupts when Target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.Kick, true);
		action.EvaluateInterruptAction(Spell.CheapShot, self.Requirements.CheapShot)
		action.EvaluateInterruptAction(Spell.KidneyShot, self.Requirements.KidneyShot)
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);
		action.EvaluateInterruptAction(Racial.QuakingPalm, true);
		action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for setting any pre-combat variables, is always called even if you don't have a target.
	function self.PrecombatVariables()
		Variables.Precombat();
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion,name=prolonged_power
		action.EvaluateAction(Consumable.ProlongedPower, true);
		action.EvaluateAction(Spell.Stealth, self.Requirements.Stealth);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.CallActionList(Variables)
		-- # This let us to use Shadow Dance right before the 2nd part of DfA lands. Only with Dark Shadow.
		-- actions+=/shadow_dance,if=talent.dark_shadow.enabled&(!stealthed.all|buff.subterfuge.up)&buff.death_from_above.up&buff.death_from_above.remains<=0.15
		action.EvaluateAction(Spell.ShadowDance, self.Requirements.ShadowDance)
		-- # This is triggered only with DfA talent since we check shadow_dance even while the gcd is ongoing, it's purely for simulation performance.
		-- actions+=/wait,sec=0.1,if=buff.shadow_dance.up&gcd.remains>0
		action.EvaluateAction(Spell.ShurikenToss, self.Requirements.ShurikenToss)
		-- actions+=/call_action_list,name=cds
		action.CallActionList(Cooldowns)
		-- # Fully switch to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
		-- actions+=/run_action_list,name=stealthed,if=stealthed.all
		action.RunActionList(Stealthed)
		-- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
		action.EvaluateAction(Spell.Nightblade, self.Requirements.Nightblade)
		-- actions+=/call_action_list,name=stealth_als,if=talent.dark_shadow.enabled&combo_points.deficit>=2+buff.shadow_blades.up&(dot.nightblade.remains>4+talent.subterfuge.enabled|cooldown.shadow_dance.charges_fractional>=1.9&(!equipped.denial_of_the_halfgiants|time>10))
		action.CallActionList(StealthALS, self.Requirements.StealthALS.One)
		-- actions+=/call_action_list,name=stealth_als,if=!talent.dark_shadow.enabled&(combo_points.deficit>=2+buff.shadow_blades.up|cooldown.shadow_dance.charges_fractional>=1.9+talent.enveloping_shadows.enabled)
		action.CallActionList(StealthALS, self.Requirements.StealthALS.Two)
		-- actions+=/call_action_list,name=finish,if=combo_points>=5+3*(buff.the_first_of_the_dead.up&talent.anticipation.enabled)+(talent.deeper_stratagem.enabled&!buff.shadow_blades.up&(mantle_duration=0|set_bonus.tier20_4pc)&(!buff.the_first_of_the_dead.up|variable.dsh_dfa))|(combo_points>=4&combo_points.deficit<=2&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)|(target.time_to_die<=1&combo_points>=3)
		action.CallActionList(Finisher, self.Requirements.Finisher.One)
		-- actions+=/call_action_list,name=finish,if=variable.dsh_dfa&cooldown.symbols_of_death.remains<=1&combo_points>=2&equipped.the_first_of_the_dead&spell_targets.shuriken_storm<2
		action.CallActionList(Finisher, self.Requirements.Finisher.Two)
		-- actions+=/wait,sec=time_to_sht.4,if=combo_points=5&time_to_sht.4<=1&energy.deficit>=30
		-- actions+=/wait,sec=time_to_sht.5,if=combo_points=5&time_to_sht.5<=1&energy.deficit>=30
		-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
		action.CallActionList(Builder)
	end

	return self;
end

local APL = APL(nameAPL, "ChunkySpud: Subtlety Rogue", addonTable.Enum.SpecID.ROGUE_SUBTLETY);