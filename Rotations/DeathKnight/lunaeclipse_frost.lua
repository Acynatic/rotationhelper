local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_deathknight_frost";

-- BoSPooling Rotation
local function BoSPooling(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		Frostscythe = {
			-- actions.bos_pooling+=/frostscythe,if=spell_targets.frostscythe>=3
			Use = function(numEnemies)
				return numEnemies >= 3;
			end,

			-- actions.bos_pooling+=/frostscythe,if=buff.killing_machine.react&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
			KillingMachine = function(numEnemies)
				return Player.Buff(Buff.KillingMachine).React()
				   and (not Legendary.KoltirasNewfoundWill.Equipped() or numEnemies >= 2);
			end,
		},

		FrostStrike = {
			-- actions.bos_pooling+=/frost_strike,if=cooldown.breath_of_sindragosa.remains>rune.time_to_4&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
			Use = function()
				return Talent.BreathOfSindragosa.Cooldown.Remains() > Player.Runes.TimeToX(4)
				   and (not Talent.ShatteringStrikes.Enabled() or Target.Debuff(Debuff.Razorice).Stack() < 5 or Talent.BreathOfSindragosa.Cooldown.Remains() > 6);
			end,

			-- actions.bos_pooling+=/frost_strike,if=(cooldown.remorseless_winter.remains<(gcd*2)|buff.gathering_storm.stack=10)&cooldown.breath_of_sindragosa.remains>rune.time_to_4&talent.gathering_storm.enabled&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
			GatheringStorm = function()
				return (Spell.RemorselessWinter.Cooldown.Remains() < Player.GCD() * 2 or Player.Buff(Buff.GatheringStorm).Stack() == 10)
				   and Talent.BreathOfSindragosa.Cooldown.Remains() > Player.Runes.TimeToX(4)
				   and Talent.GatheringStorm.Enabled()
				   and (not Talent.ShatteringStrikes.Enabled() or Target.Debuff(Debuff.Razorice).Stack() < 5 or Talent.BreathOfSindragosa.Cooldown.Remains() > 6);
			end,

			-- actions.bos_pooling+=/frost_strike,if=runic_power.deficit<30&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>rune.time_to_4)
			RunicPower = function()
				return Player.RunicPower.Deficit() < 30
				   and (not Talent.ShatteringStrikes.Enabled() or Target.Debuff(Debuff.Razorice).Stack() < 5 or Talent.BreathOfSindragosa.Cooldown.Remains() > Player.Runes.TimeToX(4));
			end,

			-- actions.bos_pooling+=/frost_strike,if=runic_power.deficit<5&set_bonus.tier19_4pc&cooldown.breath_of_sindragosa.remains&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
			Tier19 = function()
				return Player.RunicPower.Deficit() < 5
				   and addonTable.Tier19_4PC
				   and Talent.BreathOfSindragosa.Cooldown.Down()
				   and (not Talent.ShatteringStrikes.Enabled() or Target.Debuff(Debuff.Razorice).Stack() < 5 or Talent.BreathOfSindragosa.Cooldown.Remains() > 6);
			end,
		},

		-- actions.bos_pooling+=/glacial_advance,if=spell_targets.glacial_advance>=2
		GlacialAdvance = function(numEnemies)
			return numEnemies >= 2;
		end,

		HowlingBlast = {
			-- actions.bos_pooling+=/howling_blast,if=buff.rime.up&(buff.remorseless_winter.up|cooldown.remorseless_winter.remains>gcd|(!equipped.perseverance_of_the_ebon_martyr&!talent.gathering_storm.enabled))
			Use = function()
				return Player.Buff(Buff.Rime).Up()
				   and (Player.Buff(Buff.RemorselessWinter).Up() or Spell.RemorselessWinter.Cooldown.Remains() > Player.GCD() or (not Legendary.PerseveranceOfTheEbonMartyr.Equipped() and not Talent.GatheringStorm.Enabled()));
			end,

			-- actions.bos_pooling+=/howling_blast,if=buff.rime.up&rune.time_to_4<(gcd*2)
			Rime = function()
				return Player.Buff(Buff.Rime).Up()
				   and Player.Runes.TimeToX(4) < Player.GCD() * 2;
			end,
		},

		Obliterate = {
			-- actions.bos_pooling+=/obliterate,if=!buff.rime.up&(!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>gcd)
			Use = function()
				return not Player.Buff(Buff.Rime).Up()
				   and (not Talent.GatheringStorm.Enabled() or Spell.RemorselessWinter.Cooldown.Remains() > Player.GCD());
			end,

			-- actions.bos_pooling+=/obliterate,if=!buff.rime.up&!(talent.gathering_storm.enabled&!(cooldown.remorseless_winter.remains>(gcd*2)|rune>4))&rune>3
			NoRime = function()
				return not Player.Buff(Buff.Rime).Up()
				   and not (Talent.GatheringStorm.Enabled() and not (Spell.RemorselessWinter.Cooldown.Remains() > Player.GCD() * 2 or Player.Runes() > 4))
				   and Player.Runes() > 3;
			end,

			-- actions.bos_pooling+=/obliterate,if=rune.time_to_6<gcd&!talent.gathering_storm.enabled
			Runes = function()
				return Player.Runes.TimeToX(6) < Player.GCD()
				   and not Talent.GatheringStorm.Enabled();
			end,

			-- actions.bos_pooling+=/obliterate,if=rune.time_to_4<gcd&(cooldown.breath_of_sindragosa.remains|runic_power.deficit>=30)
			RunicPower = function()
				return Player.Runes.TimeToX(4) < Player.GCD()
				   and (Talent.BreathOfSindragosa.Cooldown.Down() or Player.RunicPower.Deficit() >= 30);
			end,
		},

		RemorselessWinter = {
			-- actions.bos_pooling+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
			Use = function(numEnemies)
				return numEnemies >= 2;
			end,

			-- actions.bos_pooling=remorseless_winter,if=talent.gathering_storm.enabled
			GatheringStorm = function()
				return Talent.GatheringStorm.Enabled();
			end,

			-- actions.bos_pooling+=/remorseless_winter,if=buff.rime.up&equipped.perseverance_of_the_ebon_martyr
			PerseveranceOfTheEbonMartyr = function()
				return Player.Buff(Buff.Rime).Up()
				   and Legendary.PerseveranceOfTheEbonMartyr.Equipped();
			end,
		},

		-- actions.bos_pooling+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.react&debuff.razorice.stack=5
		SindragosasFury = function()
			return (Legendary.ConsortsColdCore.Equipped() or Player.Buff(Buff.PillarOfFrost).Up())
			   and Player.Buff(Buff.UnholyStrength).React()
			   and Target.Debuff(Debuff.Razorice).Stack() == 5;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.GatheringStorm);
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast.Rime);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.Runes);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.RunicPower);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.Tier19);
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.PerseveranceOfTheEbonMartyr);
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast.Use);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.NoRime);
		action.EvaluateAction(Artifact.SindragosasFury, self.Requirements.SindragosasFury);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.RunicPower);
		action.EvaluateAction(Talent.FrostScythe, self.Requirements.FrostScythe.KillingMachine, Enemies.GetEnemies(Talent.Frostscythe));
		action.EvaluateAction(Talent.GlacialAdvance, self.Requirements.GlacialAdvance, Enemies.GetEnemies(30));
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.Use, Enemies.GetEnemies(8));
		action.EvaluateAction(Talent.Frostscythe, self.Requirements.Frostscythe.Use, Enemies.GetEnemies(Talent.Frostscythe));
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.GatheringStorm);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.Use);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.Use);
	end

	-- actions+=/run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<15
	function self.Use()
		return Talent.BreathOfSindragosa.Enabled()
		   and Talent.BreathOfSindragosa.Cooldown.Remains() < 15;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local BoSPooling = BoSPooling("BoSPooling");

-- BoSTicking Rotation
local function BoSTicking(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.bos_ticking+=/empower_rune_weapon,if=runic_power<30&rune.time_to_2>gcd
		EmpowerRuneWeapon = function()
			return Player.RunicPower() < 30
			   and Player.Runes.TimeToX(2) > Player.GCD();
		end,

		-- actions.bos_ticking+=/frostscythe,if=buff.killing_machine.react&(!equipped.koltiras_newfound_will|talent.gathering_storm.enabled|spell_targets.frostscythe>=2)
		Frostscythe = function(numEnemies)
			return Player.Buff(Buff.KillingMachine).React()
			   and (not Legendary.KoltirasNewfoundWill.Equipped() or Talent.GatheringStorm.Enabled() or numEnemies() >= 2);
		end,

		FrostStrike = {
			-- actions.bos_ticking+=/frost_strike,if=set_bonus.tier20_2pc&runic_power.deficit<=15&rune<=3&buff.pillar_of_frost.up&!talent.shattering_strikes.enabled
			Use = function()
				return addonTable.Tier20_2PC
				   and Player.RunicPower.Deficit() <= 15
				   and Player.Runes() <= 3
				   and Player.Buff(Buff.PillarOfFrost).Up()
				   and not Talent.ShatteringStrikes.Enabled();
			end,

			-- actions.bos_ticking=frost_strike,if=talent.shattering_strikes.enabled&runic_power<40&rune.time_to_2>2&cooldown.empower_rune_weapon.remains&debuff.razorice.stack=5&(cooldown.horn_of_winter.remains|!talent.horn_of_winter.enabled)
			ShatteringStrikes = function()
				return Talent.ShatteringStrikes.Enabled()
				   and Player.RunicPower() < 40
				   and Player.Runes.TimeToX(2) > 2
				   and Spell.EmpowerRuneWeapon.Cooldown.Down()
				   and Target.Debuff(Debuff.Razorice).Stack() == 5
				   and (Talent.HornOfWinter.Cooldown.Down() or not Talent.HornOfWinter.Enabled());
			end,
		},

		-- actions.bos_ticking+=/glacial_advance,if=spell_targets.glacial_advance>=2
		GlacialAdvance = function(numEnemies)
			return numEnemies >= 2;
		end,

		-- actions.bos_ticking+=/horn_of_winter,if=runic_power.deficit>=30&rune.time_to_3>gcd
		HornOfWinter = function()
			return Player.RunicPower.Deficit() >= 30
			   and Player.Runes.TimeToX(3) > Player.GCD();
		end,

		-- actions.bos_ticking+=/howling_blast,if=((runic_power>=20&set_bonus.tier19_4pc)|runic_power>=30)&buff.rime.up
		HowlingBlast = function()
			return ((Player.RunicPower() >= 20 and addonTable.Tier19_4PC) or Player.RunicPower() >= 30)
			   and Player.Buff(Buff.Rime).Up();
		end,

		Obliterate = {
			-- actions.bos_ticking+=/obliterate,if=runic_power.deficit>25|rune>3
			Use = function()
				return Player.RunicPower.Deficit() > 25
					or Player.Runes() > 3;
			end,

			-- actions.bos_ticking+=/obliterate,if=runic_power<=45|rune.time_to_5<gcd
			Runes = function()
				return Player.RunicPower() <= 45
					or Player.Runes.TimeToX(5) < Player.GCD();
			end,
		},

		RemorselessWinter = {
			-- actions.bos_ticking+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
			Use = function(numEnemies)
				return numEnemies >= 2;
			end,

			-- actions.bos_ticking+=/remorseless_winter,if=runic_power>=30&((buff.rime.up&equipped.perseverance_of_the_ebon_martyr)|(talent.gathering_storm.enabled&(buff.remorseless_winter.remains<=gcd|!buff.remorseless_winter.remains)))
			GatheringStorm = function()
				return Player.RunicPower() >= 30
				   and ((Player.Buff(Buff.Rime).Up() and Legendary.PerseveranceOfTheEbonMartyr.Equipped()) or (Talent.GatheringStorm.Enabled() and (Player.Buff(Buff.RemorselessWinter).Remains() <= Player.GCD() or not Player.Buff(Buff.RemorselessWinter).Up())));
			end,
		},

		-- actions.bos_ticking+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.react&debuff.razorice.stack=5
		SindragosasFury = function()
			return (Legendary.ConsortsColdCore.Equipped() or Player.Buff(Buff.PillarOfFrost).Up())
			   and Player.Buff(Buff.UnholyStrength).React()
			   and Target.Debuff(Debuff.Razorice).Stack() == 5;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.ShatteringStrikes);
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.GatheringStorm);
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.Use);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.Runes);
		action.EvaluateAction(Artifact.SindragosasFury, self.Requirements.SindragosasFury);
		action.EvaluateAction(Talent.HornOfWinter, self.Requirements.HornOfWinter);
		action.EvaluateAction(Talent.Frostscythe, self.Requirements.Frostscythe, Enemies.GetEnemies(Talent.Frostscythe));
		action.EvaluateAction(Talent.GlacialAdvance, self.Requirements.GlacialAdvance, Enemies.GetEnemies(30));
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.Use, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.Use);
		action.EvaluateAction(Spell.EmpowerRuneWeapon, self.Requirements.EmpowerRuneWeapon);
	end

	-- actions+=/run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
	function self.Use()
		return Player.Buff(Buff.BreathOfSindragosa).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local BoSTicking = BoSTicking("BoSTicking");

-- ColdHeart Rotation
local function ColdHeart(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ChainsOfIce = {
			-- actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack>=4&target.time_to_die<=gcd
			Use = function()
				return Player.Buff(Buff.ColdHeart).Stack() >= 4
				   and Target.TimeToDie() <= Player.GCD();
			end,

			-- actions.cold_heart+=/chains_of_ice,if=buff.pillar_of_frost.up&buff.pillar_of_frost.remains<gcd&(buff.cold_heart.stack>=11|(buff.cold_heart.stack>=10&set_bonus.tier20_4pc))
			PillarOfFrost = function()
				return Player.Buff(Buff.PillarOfFrost).Up()
				   and Player.Buff(Buff.PillarOfFrost).Remains() < Player.GCD()
				   and (Player.Buff(Buff.ColdHeart).Stack() >= 11 or (Player.Buff(Buff.ColdHeart).Stack() >= 10 and addonTable.Tier20_4PC));
			end,

			-- actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack>12&buff.unholy_strength.react&talent.shattering_strikes.enabled
			ShatteringStrikes = function()
				return Player.Buff(Buff.ColdHeart).Stack() > 12
				   and Player.Buff(Buff.UnholyStrength).React()
				   and Talent.ShatteringStrikes.Enabled();
			end,

			-- actions.cold_heart=chains_of_ice,if=buff.cold_heart.stack=20&buff.unholy_strength.react&cooldown.pillar_of_frost.remains>6
			Stacks = function()
				return Player.Buff(Buff.ColdHeart).Stack() == 20
				   and Player.Buff(Buff.UnholyStrength).React()
				   and Spell.PillarOfFrost.Cooldown.Remains() > 6;
			end,

			-- actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack>16&buff.unholy_strength.react&buff.unholy_strength.remains<gcd&cooldown.pillar_of_frost.remains>6
			UnholyStrength = function()
				return Player.Buff(Buff.ColdHeart).Stack() > 16
				   and Player.Buff(Buff.UnholyStrength).React()
				   and Player.Buff(Buff.UnholyStrength).Remains() < Player.GCD()
				   and Spell.PillarOfFrost.Cooldown.Remains() > 6;
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.Stacks);
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.PillarOfFrost);
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.UnholyStrength);
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.ShatteringStrikes);
		action.EvaluateAction(Spell.ChainsOfIce, self.Requirements.ChainsOfIce.Use);
	end

	-- actions.cooldowns+=/call_action_list,name=cold_heart,if=equipped.cold_heart&((buff.cold_heart.stack>=10&!buff.obliteration.up&debuff.razorice.stack=5)|target.time_to_die<=gcd)
	function self.Use()
		return Legendary.ColdHeart.Equipped()
		   and ((Player.Buff(Buff.ColdHeart).Stack() >= 10 and not Player.Buff(Buff.Obliteration).Up() and Target.Debuff(Debuff.Razorice).Stack() == 5) or Target.TimeToDie() <= Player.GCD());
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local ColdHeart = ColdHeart("ColdHeart");

-- Cooldowns Rotation
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = {
			-- actions.cooldowns=arcane_torrent,if=runic_power.deficit>=20&!talent.breath_of_sindragosa.enabled
			Use = function()
				return Player.RunicPower.Deficit() >= 20
				   and not Talent.BreathOfSindragosa.Enabled();
			end,

			-- actions.cooldowns+=/arcane_torrent,if=dot.breath_of_sindragosa.ticking&runic_power.deficit>=50&rune<2
			BreathOfSindragosa = function()
				return Player.Buff(Buff.BreathOfSindragosa).Up()
				   and Player.RunicPower.Deficit() >= 50
				   and Player.Runes() < 2;
			end,
		},

		-- actions.cooldowns+=/berserking,if=buff.pillar_of_frost.up
		Berserking = function()
			return Player.Buff(Buff.PillarOfFrost).Up();
		end,

		-- actions.cooldowns+=/blood_fury,if=buff.pillar_of_frost.up
		BloodFury = function()
			return Player.Buff(Buff.PillarOfFrost).Up();
		end,

		-- actions.cooldowns+=/breath_of_sindragosa,if=buff.pillar_of_frost.up
		BreathOfSindragosa = function()
			return Player.Buff(Buff.PillarOfFrost).Up();
		end,

		-- actions.cooldowns+=/use_item,name=draught_of_souls,if=rune.time_to_5<3&(!dot.breath_of_sindragosa.ticking|runic_power>60)
		DraughtOfSouls = function()
			return Player.Runes.TimeToX(5) < 3
			   and (not Player.Buff(Buff.BreathOfSindragosa).Up() or Player.RunicPower() > 60);
		end,

		-- actions.cooldowns+=/use_item,name=feloiled_infernal_machine,if=!talent.obliteration.enabled|buff.obliteration.up
		FelOiledInfernalMachine = function()
			return not Talent.Obliteration.Enabled()
				or Player.Buff(Buff.Obliteration).Up();
		end,

		-- actions.cooldowns+=/use_item,name=horn_of_valor,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
		HornOfValor = function()
			return Player.Buff(Buff.PillarOfFrost).Up()
			   and (not Talent.BreathOfSindragosa.Enabled() or not Talent.BreathOfSindragosa.Cooldown.Remains() > 0);
		end,

		-- actions.cooldowns+=/hungering_rune_weapon,if=!buff.hungering_rune_weapon.up&rune.time_to_2>gcd&runic_power<40
		HungeringRuneWeapon = function()
			return not Player.Buff(Buff.HungeringRuneWeapon).Up()
			   and Player.Runes.TimeToX(2) > Player.GCD()
			   and Player.RunicPower() < 40;
		end,

		-- actions.cooldowns+=/obliteration,if=rune>=1&runic_power>=20&(!talent.frozen_pulse.enabled|rune<2|buff.pillar_of_frost.remains<=12)&(!talent.gathering_storm.enabled|!cooldown.remorseless_winter.ready)&(buff.pillar_of_frost.up|!talent.icecap.enabled)
		Obliteration = function()
			return Player.Runes() >= 1
			   and Player.RunicPower() >= 20
			   and (not Talent.FrozenPulse.Enabled() or Player.Rune() <2 or Player.Buff(Buff.PillarOfFrost).Remains() <= 12)
			   and (not Talent.GatheringStorm.Enabled() or not Spell.RemorselessWinter.Cooldown.Up())
			   and (Player.Buff(Buff.PillarOfFrost).Up() or not Talent.Icecap.Enabled());
		end,

		PillarOfFrost = {
			-- actions.cooldowns+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains>40
			BreathOfSindragosa = function()
				return Talent.BreathOfSindragosa.Enabled()
				   and Talent.BreathOfSindragosa.Cooldown.Remains() > 40;
			end,

			-- actions.cooldowns+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.ready&runic_power>50
			BreathOfSindragosaReady = function()
				return Talent.BreathOfSindragosa.Enabled()
					and Talent.BreathOfSindragosa.Cooldown.Up()
					and Player.RunicPower() > 50;
			end,

			-- actions.cooldowns+=/pillar_of_frost,if=talent.hungering_rune_weapon.enabled
			HungeringRuneWeapon = function()
				return Talent.HungeringRuneWeapon.Enabled();
			end,

			-- actions.cooldowns+=/pillar_of_frost,if=talent.obliteration.enabled&(cooldown.obliteration.remains>20|cooldown.obliteration.remains<10|!talent.icecap.enabled)
			Obliteration = function()
				return Talent.Obliteration.Enabled()
				   and (Talent.Obliteration.Cooldown.Remains() > 20 or Talent.Obliteration.Cooldown.Remains() < 10 or not Talent.Icecap.Enabled());
			end,
		},

		-- actions.cooldowns+=/potion,if=buff.pillar_of_frost.up&(dot.breath_of_sindragosa.ticking|buff.obliteration.up|talent.hungering_rune_weapon.enabled)
		ProlongedPower = function()
			return Player.Buff(Buff.PillarOfFrost).Up()
			   and (Player.Buff(Buff.BreathOfSindragosa).Up() or Player.Buff(Buff.Obliteration).Up() or Talent.HungeringRuneWeapon.Enabled());
		end,

		-- actions.cooldowns+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
		RingOfCollapsingFutures = function()
			return (Player.Buff(Buff.Temptation).Stack() == 0 and Target.TimeToDie() > 60)
				or Target.TimeToDie() < 60;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent.Use);
		action.EvaluateAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent.BreathOfSindragosa);
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);
		action.EvaluateAction(Item.RingOfCollapsingFutures, self.Requirements.RingOfCollapsingFutures);
		action.EvaluateAction(Item.HornOfValor, self.Requirements.HornOfValor);
		action.EvaluateAction(Item.DraughtOfSouls, self.Requirements.DraughtOfSouls);
		action.EvaluateAction(Item.FelOiledInfernalMachine, self.Requirements.FelOiledInfernalMachine);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Spell.PillarOfFrost, self.Requirements.PillarOfFrost.Obliteration);
		action.EvaluateAction(Spell.PillarOfFrost, self.Requirements.PillarOfFrost.BreathOfSindragosaReady);
		action.EvaluateAction(Spell.PillarOfFrost, self.Requirements.PillarOfFrost.BreathOfSindragosa);
		action.EvaluateAction(Spell.PillarOfFrost, self.Requirements.PillarOfFrost.HungeringRuneWeapon);
		action.EvaluateAction(Talent.BreathOfSindragosa, self.Requirements.BreathOfSindragosa);

		action.CallActionList(ColdHeart);

		action.EvaluateAction(Talent.Obliteration, self.Requirements.Obliteration);
		action.EvaluateAction(Talent.HungeringRuneWeapon, self.Requirements.HungeringRuneWeapon);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Cooldowns = Cooldowns("Cooldowns");

-- Obliteration Rotation
local function Obliteration(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.obliteration+=/frostscythe,if=(buff.killing_machine.up&(buff.killing_machine.react|prev_gcd.1.frost_strike|prev_gcd.1.howling_blast))&spell_targets.frostscythe>1
		Frostscythe = function(numEnemies)
			return (Player.Buff(Buff.KillingMachine).Up() and (Player.Buff(Buff.KillingMachine).React() or Player.PrevGCD(1, Spell.FrostStrike) or Player.PrevGCD(1, Spell.HowlingBlast)))
			   and numEnemies > 1;
		end,

		-- actions.obliteration+=/frost_strike,if=!buff.rime.up|rune.time_to_1>=gcd|runic_power.deficit<20
		FrostStrike = function()
			return not Player.Buff(Buff.Rime).Up()
				or Player.Runes.TimeToX(1) >= Player.GCD()
				or Player.RunicPower.Deficit() < 20;
		end,

		HowlingBlast = {
			-- actions.obliteration+=/howling_blast,if=buff.rime.up
			Use = function()
				return Player.Buff(Buff.Rime).Up();
			end,

			-- actions.obliteration+=/howling_blast,if=buff.rime.up&spell_targets.howling_blast>1
			Cleave = function(numEnemies)
				return Player.Buff(Buff.Rime).Up()
				   and numEnemies > 1;
			end,

			-- actions.obliteration+=/howling_blast,if=!buff.rime.up&spell_targets.howling_blast>2&rune>3&talent.freezing_fog.enabled&talent.gathering_storm.enabled
			GatheringStorm = function(numEnemies)
				return not Player.Buff(Buff.Rime).Up()
				   and numEnemies > 2
				   and Player.Runes() > 3
				   and Talent.FreezingFog.Enabled()
				   and Talent.GatheringStorm.Enabled();
			end,
		},

		-- actions.obliteration+=/obliterate,if=(buff.killing_machine.up&(buff.killing_machine.react|prev_gcd.1.frost_strike|prev_gcd.1.howling_blast))|(spell_targets.howling_blast>=3&!buff.rime.up)
		Obliterate = function(numEnemies)
			return (Player.Buff(Buff.KillingMachine).Up() and (Player.Buff(Buff.KillingMachine).React() or Player.PrevGCD(1, Spell.FrostStrike) or Player.PrevGCD(1, Spell.HowlingBlast)))
				or (numEnemies >= 3 and not Player.Buff(Buff.Rime).Up());
		end,

		-- actions.obliteration=remorseless_winter,if=talent.gathering_storm.enabled
		RemorselessWinter = function()
			return Talent.GatheringStorm.Enabled();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter);
		action.EvaluateAction(Talent.Frostscythe, self.Requirements.Frostscythe, Enemies.GetEnemies(Talent.Frostscythe));
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate, Enemies.GetEnemies(Spell.HowlingBlast));
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast.Cleave, Enemies.GetEnemies(Spell.HowlingBlast));
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast.GatheringStorm, Enemies.GetEnemies(Spell.HowlingBlast));
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike);
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast.Use);
		-- actions.obliteration+=/obliterate
		action.EvaluateAction(Spell.Obliterate, true);
	end

	-- actions+=/run_action_list,name=obliteration,if=buff.obliteration.up
	function self.Use()
		return Player.Buff(Buff.Obliteration).Up();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Obliteration = Obliteration("Obliteration");

-- Standard Rotation
local function Standard(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.standard+=/empower_rune_weapon,if=!talent.breath_of_sindragosa.enabled|target.time_to_die<cooldown.breath_of_sindragosa.remains
		EmpowerRuneWeapon = function()
			return not Talent.BreathOfSindragosa.Enabled()
				or Target.TimeToDie() < Talent.BreathOfSindragosa.Cooldown.Remains();
		end,

		Frostscythe = {
			-- actions.standard+=/frostscythe,if=spell_targets.frostscythe>=3
			Use = function(numEnemies)
				return numEnemies >= 3;
			end,

			-- actions.standard+=/frostscythe,if=buff.killing_machine.react&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
			KillingMachine = function(numEnemies)
				return Player.Buff(Buff.KillingMachine).React()
				   and (not Legendary.KoltirasNewfoundWill.Equipped() or numEnemies >= 2);
			end,
		},

		FrostStrike = {
			-- actions.standard+=/frost_strike,if=!(runic_power<50&talent.obliteration.enabled&cooldown.obliteration.remains<=gcd)
			Use = function()
				return not (Player.RunicPower() < 50 and Talent.Obliteration.Enabled() and Talent.Obliteration.Cooldown.Remains() <= Player.GCD());
			end,

			-- actions.standard=frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<=gcd
			IcyTalons = function()
				return Talent.IcyTalons.Enabled()
				   and Player.Buff(Buff.IcyTalons).Remains() <= Player.GCD();
			end,

			-- actions.standard+=/frost_strike,if=talent.shattering_strikes.enabled&debuff.razorice.stack=5&buff.gathering_storm.stack<2&!buff.rime.up
			ShatteringStrikes = function()
				return Talent.ShatteringStrikes.Enabled()
				   and Target.Debuff(Debuff.Razorice).Stack() == 5
				   and Player.Buff(Buff.GatheringStorm).Stack() < 2
				   and not Player.Buff(Buff.Rime).Up();
			end,

			RunicPower = {
				-- actions.standard+=/frost_strike,if=runic_power.deficit<20
				Use = function()
					return Player.RunicPower.Deficit() < 20;
				end,

				-- actions.standard+=/frost_strike,if=runic_power.deficit<10&!buff.hungering_rune_weapon.up
				NoHungeringRuneWeapon = function()
					return Player.RunicPower.Deficit() < 10
					   and not Player.Buff(Buff.HungeringRuneWeapon).Up();
				end,

				-- actions.standard+=/frost_strike,if=(!talent.shattering_strikes.enabled|debuff.razorice.stack<5)&runic_power.deficit<10
				NoShatteringStrikes = function()
					return (not Talent.ShatteringStrikes.Enabled() or Target.Debuff(Debuff.Razorice).Stack() < 5)
					   and Player.RunicPower.Deficit() < 10;
				end,
			},
		},

		-- actions.standard+=/glacial_advance,if=spell_targets.glacial_advance>=2
		GlacialAdvance = function(numEnemies)
			return numEnemies >= 2;
		end,

		-- actions.standard+=/horn_of_winter,if=!buff.hungering_rune_weapon.up&(rune.time_to_2>gcd|!talent.frozen_pulse.enabled)
		HornOfWinter = function()
			return not Player.Buff(Buff.HungeringRuneWeapon).Up()
			   and (Player.Runes.TimeToX(2) > Player.GCD() or not Talent.FrozenPulse.Enabled());
		end,

		-- actions.standard+=/howling_blast,if=buff.rime.up
		HowlingBlast = function()
			return Player.Buff(Buff.Rime).Up();
		end,

		Obliterate = {
			-- actions.standard+=/obliterate,if=!talent.gathering_storm.enabled|talent.icy_talons.enabled
			Use = function()
				return not Talent.GatheringStorm.Enabled()
					or Talent.IcyTalons.Enabled();
			end,

			-- actions.standard+=/obliterate,if=(equipped.koltiras_newfound_will&talent.frozen_pulse.enabled&set_bonus.tier19_2pc=1)|rune.time_to_4<gcd&buff.hungering_rune_weapon.up
			HungeringRuneWeapon = function()
				return (Legendary.KoltirasNewfoundWill.Equipped() and Talent.FrozenPulse.Enabled() and addonTable.Tier19_2PC)
					or Player.Runes.TimeToX(4) < Player.GCD()
				   and Player.Buff(Buff.HungeringRuneWeapon).Up();
			end,

			-- actions.standard+=/obliterate,if=buff.killing_machine.react
			KillingMachine = function()
				return Player.Buff(Buff.KillingMachine).React();
			end,

			-- actions.standard+=/obliterate,if=!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>(gcd*2)
			NoGatheringStorm = function()
				return not Talent.GatheringStorm.Enabled()
					or Spell.RemorselessWinter.Cooldown.Remains() > Player.GCD() * 2;
			end,

			-- actions.standard+=/obliterate,if=(equipped.koltiras_newfound_will&talent.frozen_pulse.enabled&set_bonus.tier19_2pc=1)|rune.time_to_5<gcd
			Runes = function()
				return (Legendary.KoltirasNewfoundWill.Equipped() and Talent.FrozenPulse.Enabled() and addonTable.Tier19_2PC)
					or Player.Runes.TimeToX(5) < Player.GCD();
			end,
		},

		RemorselessWinter = {
			-- actions.standard+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
			Use = function(numEnemies)
				return numEnemies >= 2;
			end,

			-- actions.standard+=/remorseless_winter,if=(buff.rime.up&equipped.perseverance_of_the_ebon_martyr)|talent.gathering_storm.enabled
			GatheringStorm = function()
				return (Player.Buff(Buff.Rime).Up() and Legendary.PerseveranceOfTheEbonMartyr.Equipped())
					or Talent.GatheringStorm.Enabled();
			end,
		},

		-- actions.standard+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.react&debuff.razorice.stack=5
		SindragosasFury = function()
			return (Legendary.ConsortsColdCore.Equipped() or Player.Buff(Buff.PillarOfFrost).Up())
			   and Player.Buff(Buff.UnholyStrength).React()
			   and Target.Debuff(Debuff.Razorice).Stack() == 5;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.IcyTalons);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.ShatteringStrikes);
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.GatheringStorm);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.HungeringRuneWeapon);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.RunicPower.NoShatteringStrikes);
		action.EvaluateAction(Spell.HowlingBlast, self.Requirements.HowlingBlast);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.Runes);
		action.EvaluateAction(Artifact.SindragosasFury, self.Requirements.SindragosasFury);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.RunicPower.NoHungeringRuneWeapon);
		action.EvaluateAction(Talent.Frostscythe, self.Requirements.Frostscythe.KillingMachine, Enemies.GetEnemies(Talent.Frostscythe));
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.KillingMachine);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.RunicPower.Use);
		action.EvaluateAction(Spell.RemorselessWinter, self.Requirements.RemorselessWinter.Use, Enemies.GetEnemies(8));
		action.EvaluateAction(Talent.GlacialAdvance, self.Requirements.GlacialAdvance, Enemies.GetEnemies(30));
		action.EvaluateAction(Talent.Frostscythe, self.Requirements.Frostscythe.Use, Enemies.GetEnemies(Talent.Frostscythe));
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.NoGatheringStorm);
		action.EvaluateAction(Talent.HornOfWinter, self.Requirements.HornOfWinter);
		action.EvaluateAction(Spell.FrostStrike, self.Requirements.FrostStrike.Use);
		action.EvaluateAction(Spell.Obliterate, self.Requirements.Obliterate.Use);
		action.EvaluateAction(Spell.EmpowerRuneWeapon, self.Requirements.EmpowerRuneWeapon);
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
		GuideAuthor = "Ertrak and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/frost-death-knight-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raiding"] = "3210031",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		AntiMagicShell = function()
			return Player.MagicDamagePredicted(3) >= 30;
		end,

		DeathStrike = function()
			return Player.Buff(Buff.DarkSuccor).Up()
			   and Player.Health.Percent() < 90;
		end,

		IceboundFortitude = function()
			return Player.DamagePredicted(4) >= 25;
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
			SindragosasFury = Objects.newSpell(190778),
		};

		Spell = {
			-- Abilities
			FrostStrike = Objects.newSpell(49143),
			HowlingBlast = Objects.newSpell(49184),
			Obliterate = Objects.newSpell(49020),
			PillarOfFrost = Objects.newSpell(51271),
			RemorselessWinter = Objects.newSpell(196770),
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
			EmpowerRuneWeapon = Objects.newSpell(47568),
			PathOfFrost = Objects.newSpell(3714),
			RaiseAlly = Objects.newSpell(61999),
			WraithWalk = Objects.newSpell(212552),
		};

		Talent = {
			-- Active Talents
			BlindingSleet = Objects.newSpell(207167),
			BreathOfSindragosa = Objects.newSpell(152279),
			Frostscythe = Objects.newSpell(207230),
			GlacialAdvance = Objects.newSpell(194913),
			HornOfWinter = Objects.newSpell(57330),
			HungeringRuneWeapon = Objects.newSpell(207127),
			Obliteration = Objects.newSpell(207256),
			-- Passive Talents
			AbominationsMight = Objects.newSpell(207161),
			Avalanche = Objects.newSpell(207142),
			FreezingFog = Objects.newSpell(207060),
			FrozenPulse = Objects.newSpell(194909),
			GatheringStorm = Objects.newSpell(194912),
			Icecap = Objects.newSpell(207126),
			IcyTalons = Objects.newSpell(194878),
			InexorableAssault = Objects.newSpell(253593),
			MurderousEfficiency = Objects.newSpell(207061),
			Permafrost = Objects.newSpell(207200),
			RunicAttenuation = Objects.newSpell(207104),
			ShatteringStrikes = Objects.newSpell(207057),
			VolatileShielding = Objects.newSpell(207188),
			WinterIsComing = Objects.newSpell(207170),
			-- Honor Talents
			ChillStreak = Objects.newSpell(204160),
		};

		Buff = {
			-- Buffs
			AntiMagicShell = Spell.AntiMagicShell,
			BreathOfSindragosa = Objects.newSpell(155166),
			DarkSuccor = Objects.newSpell(101568),
			GatheringStorm = Objects.newSpell(211805),
			HungeringRuneWeapon = Talent.HungeringRuneWeapon,
			IceboundFortitude = Spell.IceboundFortitude,
			IcyTalons = Objects.newSpell(194879),
			KillingMachine = Objects.newSpell(51124),
			Obliteration = Talent.Obliteration,
			PathOfFrost = Spell.PathOfFrost,
			PillarOfFrost = Spell.PillarOfFrost,
			RemorselessWinter = Spell.RemorselessWinter,
			Rime = Objects.newSpell(59052),
			Temptation = Objects.newSpell(234143),
			UnholyStrength = Objects.newSpell(53365),
			WraithWalk = Spell.WraithWalk,
			-- Legendary Buffs
			ColdHeart = Objects.newSpell(235599),
	   };

		Debuff = {
			-- Debuffs
			BlindingSleet = Talent.BlindingSleet,
			ChainsOfIce = Spell.ChainsOfIce,
			ControlUndead = Spell.ControlUndead,
			DarkCommand = Spell.DarkCommand,
			FrostFever = Objects.newSpell(55095),
			Razorice = Objects.newSpell(51714),
			VoidTouched = Objects.newSpell(97821),
		};

		-- Items
		Legendary = {
			-- Legendaries
			ColdHeart = Objects.newItem(151796),
			ConsortsColdCore = Objects.newItem(144293),
			PerseveranceOfTheEbonMartyr = Objects.newItem(132459),
			KoltirasNewfoundWill = Objects.newItem(132366),
		};

		Item = {
			-- Rings
			RingOfCollapsingFutures = Objects.newItem(142173),
			-- Trinkets
			ConvergenceOfFates = Objects.newItem(140806),
			DraughtOfSouls = Objects.newItem(140808),
			FelOiledInfernalMachine = Objects.newItem(144482),
			HornOfValor = Objects.newItem(133642),
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
		config.AOEOptions(options, Talent.Frostscythe, Talent.GlacialAdvance, Spell.RemorselessWinter);
		config.CooldownOptions(options, Talent.BreathOfSindragosa, Item.ConvergenceOfFates, Spell.ChainsOfIce, Talent.ChillStreak, Item.DraughtOfSouls, Spell.EmpowerRuneWeapon, Item.FelOiledInfernalMachine,
									 Item.HornOfValor, Talent.HornOfWinter, Talent.HungeringRuneWeapon, Talent.Obliteration, Spell.PillarOfFrost, Item.RingOfCollapsingFutures, Artifact.SindragosasFury);
		config.DefensiveOptions(options, Spell.AntiMagicShell, Spell.IceboundFortitude, Spell.DeathStrike);
		config.UtilityOptions(options, Talent.BlindingSleet, Spell.ControlUndead, Spell.DeathGrip, Spell.RaiseAlly);
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
		action.EvaluateDefensiveAction(Spell.IceboundFortitude, self.Requirements.IceboundFortitude);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.DeathStrike, self.Requirements.DeathStrike);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.MindFreeze, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
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
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		-- actions+=/call_action_list,name=cooldowns
		action.CallActionList(Cooldowns);

		action.RunActionList(BoSPooling);
		action.RunActionList(BoSTicking);
		action.RunActionList(Obliteration);
		-- actions+=/call_action_list,name=standard
		action.CallActionList(Standard);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Frost Death Knight", addonTable.Enum.SpecID.DEATHKNIGHT_FROST);