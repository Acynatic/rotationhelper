local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Core = addon.Core.General;
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;
local Settings = addon.Core.Settings;

-- Function for converting booleans returns to numbers
local val = Core.ToNumber;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Legendary, Item, Debuff, Consumable;

-- Rotation Variables
local nameAPL = "chunkyspud_paladin_retribution";

-- Cooldowns Rotation
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		SpecterOfBetrayal = function(...)
			-- actions.cooldowns=use_item,name=specter_of_betrayal,if=(buff.crusade.up&buff.crusade.stack>=15|cooldown.crusade.remains>gcd*2)|(buff.avenging_wrath.up|cooldown.avenging_wrath.remains>gcd*2)
			return (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack >= 15 or Talent.Crusade.Cooldown.Remains() > Player.GCD() * 2)
				or (Player.Buff(Buff.AvengingWrath).Up() or Spell.AvengingWrath.Cooldown.Remains() > Player.GCD() * 2)
		end,
		OldWar = function(...)
			--actions.cooldowns+=/potion,name=old_war,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
			return (Player.HasBloodlust() or Player.Buff(Buff.AvengingWrath).Up() or Player.Buff(Buff.Crusade).Up()
				and Player.Buff(Buff.Crusade).Remains() < 25 or Target.TimeToDie() <= 40)
		end,
		ArcaneTorrent = function(...)
			-- actions+=/arcane_torrent,if=focus.deficit>=30
			return Settings.GetCharacterValue("ScriptOptions", "OPT_ARCANE_TORRENT_INTERRUPT") == 0
				and Player.HolyPower() <= 4;
		end,
		Crusade = function(...)
			-- actions.cooldowns+=/crusade,if=holy_power>=3|((equipped.137048|race.blood_elf)&holy_power>=2)
			return Player.HolyPower() >= 3
				or ((Legendary.LiadrinsFuryUnleashed.Equipped() or Player.Race("BloodElf")) and Player.HolyPower() >= 2)
		end,
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Item.SpecterOfBetrayal, self.Requirements.SpecterOfBetrayal)
		action.EvaluateAction(Consumable.OldWar, self.Requirements.OldWar)
		--actions.cooldowns+=/blood_fury
		action.EvaluateAction(Racial.BloodFury, true)
		--actions.cooldowns+=/berserking
		action.EvaluateAction(Racial.Berserking, true)
		--actions.cooldowns+=/arcane_torrent,if=holy_power<=4
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent)
		--actions.cooldowns+=/holy_wrath
		action.EvaluateAction(Talent.HolyWrath, true)
		--actions.cooldowns+=/shield_of_vengeance
		action.EvaluateAction(Spell.ShieldOfVengeance, true)
		--actions.cooldowns+=/avenging_wrath
		action.EvaluateAction(Spell.AvengingWrath, true)
		--actions.cooldowns+=/crusade,if=holy_power>=3|((equipped.137048|race.blood_elf)&holy_power>=2)
		action.EvaluateAction(Talent.Crusade, self.Requirements.Crusade)
	end

	return self
end

-- Create a variable so we can call the normal rotation.
local Cooldowns = Cooldowns("Cooldowns")

-- Priority Rotation
local function Priority(rotationName)
	-- Inherits Rotation Class so ge the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName)

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		BladeOfJustice = function(...)
			-- actions.priority+=/blade_of_justice,if=holy_power<=3-set_bonus.tier20_4pc
			return Player.HolyPower() <= 3 - val(addonTable.Tier20_4PC)
		end,
		CrusaderStrike = {
			One = function(...)
				-- actions.priority+=/crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.65-talent.the_fires_of_justice.enabled*0.25&holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)&debuff.judgment.remains>gcd
				return Spell.CrusaderStrike.Charges() >= 1.65 - val(Talent.FiresOfJustice.Enabled()) * 0.25
						and Player.HolyPower() <= 4
						and (Spell.BladeOfJustice.Cooldown.Remains() > Player.GCD() * 2
						or Talent.DivineHammer.Cooldown.Remains() > Player.GCD() * 2)
						and Target.Debuff(Debuff.Judgement).Remains() > Player.GCD()
			end,
			Two = function(...)
				--actions.priority+=/crusader_strike,if=holy_power<=4
				return Player.HolyPower() <= 4
			end,
		},
		ExecutionSentence = function(numEnemies, ...)
			-- actions.priority=execution_sentence,if=spell_targets.divine_storm<=3&(cooldown.judgment.remains<gcd*4.5|debuff.judgment.remains>gcd*4.5)
			return numEnemies <= 3
					and (Spell.Judgement.Cooldown.Remains() < Player.GCD() * 4.5
					or Target.Debuff(Debuff.Judgement).Remains() > Player.GCD() * 4.5)
		end,
		Consecration = function(...)
			-- actions.priority+=/consecration,if=(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)
			return (Spell.BladeOfJustice.Cooldown.Remains() > Player.GCD() * 2
					or Talent.DivineHammer.Cooldown.Remains() < Player.GCD() * 2)
		end,
		DivineHammer = function(...)
			-- actions.priority+=/divine_hammer,if=holy_power<=3-set_bonus.tier20_4pc
			return Player.HolyPower() <= 3 - val(addonTable.Tier20_4PC)
		end,
		DivineStorm = {
			One = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Player.Buff(Buff.DivinePurpose).Up()
						and Player.Buff(Buff.DivinePurpose).Remains() < Player.GCD() * 2
			end,
			Two = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&holy_power>=5&buff.divine_purpose.react
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Player.HolyPower() >= 5
						and Player.Buff(Buff.DivinePurpose).React()
			end,
			Three = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=3&(buff.crusade.up&buff.crusade.stack<15|buff.liadrins_fury_unleashed.up)
				return Target.Debuff(Debuff.Judgement).Up()
						and numEnemies >= 2
						and Player.HolyPower() >= 3
						and (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() < 15
						or Player.Buff(Buff.LiadrinsFuryUnleashed).Up())
			end,
			Four = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&holy_power>=5
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Player.HolyPower() >= 5
			end,
			Five = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&artifact.wake_of_ashes.enabled&cooldown.wake_of_ashes.remains<gcd*2
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Artifact.WakeOfAshes.Cooldown.Remains() < Player.GCD() * 2
			end,
			Six = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd*1.5
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Player.Buff(Buff.WhisperOfTheNathrezim).Up()
						and Player.Buff(Buff.WhisperOfTheNathrezim).Remains() < Player.GCD() * 1.5
			end,
			Seven = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.divine_purpose.react
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Player.Buff(Buff.DivinePurpose).React()
			end,
			Eight = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.the_fires_of_justice.react
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
						and Player.Buff(Buff.FiresOfJustice).React()
			end,
			Nine = function(numEnemies, ...)
				-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable
				return Target.Debuff(Debuff.Judgement).Up()
						and (numEnemies >= 2
						or (Player.Buff(Buff.ScarletInquisitors).Stack() >= 29
						and (Player.Buff(Buff.AvengingWrath).Up()
						or (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() >= 15)
						or (Talent.Crusade.Cooldown.Remains() > 15 and not Player.Buff(Buff.Crusade).Up())
						or Spell.AvengingWrath.Cooldown.Remains() > 15)))
			end,
		},
		HammerOfJustice = function(numEnemies, ...)
			-- actions.priority+=/hammer_of_justice,if=equipped.137065&target.health.pct>=75&holy_power<=4
			return Legendary.JusticeGaze.Equipped()
					and Target.Health.Percent() >= 75
					and Player.HolyPower() <= 4
		end,
		Judgement = function(numEnemies, ...)
			-- actions.priority+=/judgment,if=dot.execution_sentence.ticking&dot.execution_sentence.remains<gcd*2&debuff.judgment.remains<gcd*2
			return Target.Debuff(Debuff.ExecutionSentence).Up()
					and Target.Debuff(Debuff.ExecutionSentence).Remains() < Player.GCD() * 2
					and Target.Debuff(Debuff.Judgement).Remains() < Player.GCD() * 2
		end,
		JusticarsVengeance = {
			One = function(...)
				-- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2&!equipped.137020
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.Buff(Buff.DivinePurpose).Up()
						and Player.Buff(Buff.DivinePurpose).Remains() < Player.GCD() * 2
						and not Legendary.WhisperOfTheNathrezim.Equipped()
			end,
			Two = function(...)
				-- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react&!equipped.137020
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.HolyPower() >= 5
						and Player.Buff(Buff.DivinePurpose).React()
						and not Legendary.WhisperOfTheNathrezim.Equipped()
			end,
			Three = function(...)
				-- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.react&!equipped.137020
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.Buff(Buff.DivinePurpose).React()
						and not Legendary.WhisperOfTheNathrezim.Equipped()
			end,
		},
		TemplarsVerdict = {
			One = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.Buff(Buff.DivinePurpose).Up()
						and Player.Buff(Buff.DivinePurpose).Remains() < Player.GCD() * 2
			end,
			Two = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.HolyPower() >= 5
						and Player.Buff(Buff.DivinePurpose).React()
			end,
			Three = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(buff.crusade.up&buff.crusade.stack<15|buff.liadrins_fury_unleashed.up)
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.HolyPower() >= 3
						and (Player.Buff(Buff.Crusade).Up() and Player.Buff(Buff.Crusade).Stack() < 15
						or Player.Buff(Buff.LiadrinsFuryUnleashed).Up())
			end,
			Four = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=5
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.HolyPower() >= 5
			end,
			Five = function(...)
				-- actions.priority+=/templars_verdict,if=(equipped.137020|debuff.judgment.up)&artifact.wake_of_ashes.enabled&cooldown.wake_of_ashes.remains<gcd*2
				return (Legendary.WhisperOfTheNathrezim.Equipped() or Target.Debuff(Debuff.Judgement).Up()
						and Artifact.WakeOfAshes.Cooldown.Remains() < Player.GCD() * 2)
			end,
			Six = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd*1.5
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.Buff(Buff.WhisperOfTheNathrezim).Up()
						and Player.Buff(Buff.WhisperOfTheNathrezim).Remains() < Player.GCD() * 1.5
			end,
			Seven = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.react
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.Buff(Buff.DivinePurpose).React()
			end,
			Eight = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.the_fires_of_justice.react
				return Target.Debuff(Debuff.Judgement).Up()
						and Player.Buff(Buff.FiresOfJustice).React()
			end,
			Nine = function(...)
				-- actions.priority+=/templars_verdict,if=debuff.judgment.up&(!talent.execution_sentence.enabled|cooldown.execution_sentence.remains>gcd*2)
				return Target.Debuff(Debuff.Judgement).Up()
						and (not Talent.ExecutionSentence.Enabled() or Talent.ExecutionSentence.Cooldown.Remains() > Player.GCD * 2)
			end,
		},
		WakeOfAshes = function(...)
			-- actions.priority+=/wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15)&(holy_power<=0|holy_power=1&(cooldown.blade_of_justice.remains>gcd|cooldown.divine_hammer.remains>gcd)|holy_power=2&((cooldown.zeal.charges_fractional<=0.65|cooldown.crusader_strike.charges_fractional<=0.65)))
			return (Player.HolyPower() <= 0 or Player.HolyPower() == 1
					and (Spell.BladeOfJustice.Cooldown.Remains() > Player.GCD() or Talent.DivineHammer.Cooldown.Remains() > Player.GCD())
					or Player.HolyPower() == 2 and ((Talent.Zeal.Charges() <= 0.65 or Spell.CrusaderStrike.Charges() <= 0.65)))
		end,
		Zeal = {
			One = function(...)
				-- actions.priority+=/zeal,if=cooldown.zeal.charges_fractional>=1.65&holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)&debuff.judgment.remains>gcd
				return Talent.Zeal.Charges() <= 1.65
						and Player.HolyPower() <= 4
						and (Spell.BladeOfJustice.Cooldown.Remains() > Player.GCD() * 2
						or Talent.DivineHammer.Cooldown.Remains() > Player.GCD() * 2)
						and Target.Debuff(Debuff.Judgement).Remains() > Player.GCD()
			end,
			Two = function(...)
				-- actions.priority+=/zeal,if=holy_power<=4
				return Player.HolyPower() <= 4
			end,
		},
	}

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.ExecutionSentence, self.Requirements.ExecutionSentence)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.One)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Two)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Three)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Four)
		action.EvaluateAction(Talent.JusticarsVengeance, self.Requirements.JusticarsVengeance.One)
		action.EvaluateAction(Talent.JusticarsVengeance, self.Requirements.JusticarsVengeance.Two)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.One)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Two)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Three)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Four)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Five)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Six)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Five)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Six)
		action.EvaluateAction(Spell.Judgement, self.Requirements.Judgement)
		action.EvaluateAction(Talent.Consecration, self.Requirements.Consecration)
		action.EvaluateAction(Artifact.WakeOfAshes, self.Requirements.WakeOfAshes)
		action.EvaluateAction(Spell.BladeOfJustice, self.Requirements.BladeOfJustice)
		action.EvaluateAction(Talent.DivineHammer, self.Requirements.DivineHammer)
		action.EvaluateAction(Spell.Judgement, true)
		action.EvaluateAction(Talent.Zeal, self.Requirements.Zeal.One)
		action.EvaluateAction(Spell.CrusaderStrike, self.Requirements.CrusaderStrike.One)
		action.EvaluateAction(Talent.Consecration, true)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Seven)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Eight)
		action.EvaluateAction(Spell.DivineStorm, self.Requirements.DivineStorm.Nine)
		action.EvaluateAction(Talent.JusticarsVengeance, self.Requirements.JusticarsVengeance.Three)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Seven)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Eight)
		action.EvaluateAction(Spell.TemplarsVerdict, self.Requirements.TemplarsVerdict.Nine)
		action.EvaluateAction(Spell.HammerOfJustice, self.Requirements.HammerOfJustice)
		action.EvaluateAction(Talent.Zeal, self.Requirements.Zeal.Two)
		action.EvaluateAction(Spell.CrusaderStrike, self.Requirements.CrusaderStrike.Two)
	end

	return self
end

-- Create a variable so we can call the rotations functions.
local Priority = Priority("Priority")

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "ChunkySpud",
		GuideAuthor = "Rebdull and SimCraft",
		GuideLink = "http://www.wowhead.com/retribution-paladin-guide",
		WoWVersion = 70300,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Single Target"] = "1212122",
		["2+ Targets"] = "3212122",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function(...)
			return Target.InRange(8);
		end,
		WarStomp = function(...)
			return Target.IsStunnable()
					and Target.InRange(8);
		end,
		HammerOfJustice = function(...)
			return Target.IsStunnable()
					and Target.InRange(10)
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		-- Spells
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(129597, false),
			Berserking = Objects.newSpell(26297, false),
			BloodFury = Objects.newSpell(33697, false),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Abilities
			WakeOfAshes = Objects.newSpell(205273),
		};

		Spell = {
			-- Abilities
			AvengingWrath = Objects.newSpell(31884),
			BladeOfJustice = Objects.newSpell(184575),
			CrusaderStrike = Objects.newSpell(35395),
			DivineStorm = Objects.newSpell(53385),
			Judgement = Objects.newSpell(20271),
			TemplarsVerdict = Objects.newSpell(85256),
			-- Defensive
			ShieldOfVengeance = Objects.newSpell(184662),
			DivineShield = Objects.newSpell(642),
			-- Utility
			HammerOfJustice = Objects.newSpell(853),
			HandOfHindrance = Objects.newSpell(183218),
			Rebuke = Objects.newSpell(96231),
			-- Legendary
			KiljaedensBurningWish = Objects.newSpell(144259),
		};

		Talent = {
			-- Talents
			BladeOfWrath = Objects.newSpell(231832),
			Consecration = Objects.newSpell(205228),
			Crusade = Objects.newSpell(231895),
			DivineHammer = Objects.newSpell(198034),
			DivinePurpose = Objects.newSpell(223817),
			ExecutionSentence = Objects.newSpell(213757),
			FinalVerdict = Objects.newSpell(198038),
			HolyWrath = Objects.newSpell(210220),
			JusticarsVengeance = Objects.newSpell(215661),
			FiresOfJustice = Objects.newSpell(203316),
			Zeal = Objects.newSpell(217020),
		};

		Buff = {
			-- Buffs
			Crusade = Objects.newSpell(231895),
			AvengingWrath = Objects.newSpell(31884),
			DivinePurpose = Objects.newSpell(223819),
			FiresOfJustice = Objects.newSpell(209785),
			--Legendaries
			ScarletInquisitors = Objects.newSpell(248289),
			LiadrinsFuryUnleashed = Objects.newSpell(194912),
			WhisperOfTheNathrezim = Objects.newSpell(234143),
		};

		Debuff = {
			-- Debuffs
			Judgement = Objects.newSpell(197277),
			ExecutionSentence = Objects.newSpell(213757),
		}

		-- Items
		Legendary = {
			-- Legendaries
			WhisperOfTheNathrezim = Objects.newItem(137020),
			JusticeGaze = Objects.newItem(137065),
			LiadrinsFuryUnleashed = Objects.newItem(137048),
		};

		Item = {
			SpecterOfBetrayal = Objects.newItem(151190),
		}

		Consumable = {
			-- Potions
			OldWar = Objects.newItem(127844),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.AOEOptions(options, Spell.DivineStorm);
		config.CooldownOptions(options, Spell.AvengingWrath, Talent.Crusade);
		config.DefensiveOptions(options, Spell.DivineShield, Spell.ShieldOfVengeance);
	end

	-- Function for destroying action objects such as spells, buffs, debuffs and items, called when the rotation is no longer the active rotation.
	function self.Disable()
		Racial = nil;
		Artifact = nil;
		Spell = nil;
		Talent = nil;
		Buff = nil;
		Debuff = nil;
		Legendary = nil
		Consumable = nil;
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.Rebuke, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);
		action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for setting any pre-combat variables, is always called even if you don't have a target.
	function self.PrecombatVariables()
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.OldWar, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.CallActionList(Cooldowns);
		action.RunActionList(Priority);
	end

	return self;
end

local APL = APL(nameAPL, "ChunkySpud: Retribution Paladin", addonTable.Enum.SpecID.PALADIN_RETRIBUTION);