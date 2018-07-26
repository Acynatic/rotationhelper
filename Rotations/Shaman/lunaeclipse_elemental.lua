local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

--- Localize Vars
local Core = addon.Core.General;
local Objects = addon.Core.Objects;
local Enemies = addonTable.Enemies;
-- Objects

local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Aura, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_shaman_elemental";

-- AOE Rotation
local function AOE(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.aoe+=/chain_lightning,target_if=debuff.lightning_rod.down
		ChainLightning = function()
			return Target.Debuff(Aura.LightningRod).Down();
		end,

		-- actions.aoe+=/elemental_blast,if=!talent.lightning_rod.enabled&spell_targets.chain_lightning<4
		ElementalBlast = function()
			return not Talent.LightningRod.Enabled()
			   and Enemies.GetEnemies(Spell.ChainLightning) < 4;
		end,

		FlameShock = {
			-- actions.aoe+=/flame_shock,if=spell_targets.chain_lightning<4&maelstrom>=20,target_if=refreshable
			Use = function()
				return Enemies.GetEnemies(Spell.ChainLightning) < 4
				   and Player.Maelstrom() >= 20
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.aoe+=/flame_shock,moving=1,target_if=refreshable
			Moving = function()
				return Player.IsMoving()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,
		},

		-- actions.aoe+=/lava_beam,target_if=debuff.lightning_rod.down
		LavaBeam = function()
			return Target.Debuff(Aura.LightningRod).Down();
		end,

		LavaBurst = {
			-- actions.aoe+=/lava_burst,if=dot.flame_shock.remains>cast_time&buff.lava_surge.up&!talent.lightning_rod.enabled&spell_targets.chain_lightning<4
			Use = function()
				return Target.Debuff(Aura.FlameShock).Remains() > Spell.LavaBurst.CastTime()
				   and Player.Buff(Aura.LavaSurge).Up()
				   and not Talent.LightningRod.Enabled()
				   and Enemies.GetEnemies(Spell.ChainLightning) < 4;
			end,

			-- actions.aoe+=/lava_burst,moving=1
			Moving = function()
				return Player.IsMoving();
			end,
		}
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- actions.aoe=stormkeeper
		action.EvaluateAction(Artifact.Stormkeeper, true);
		-- actions.aoe+=/ascendance
		action.EvaluateAction(Talent.Ascendance, true);
		-- actions.aoe+=/liquid_magma_totem
		action.EvaluateAction(Talent.LiquidMagmaTotem, true);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Use);
		-- actions.aoe+=/earthquake
		action.EvaluateAction(Spell.Earthquake, true);
		action.EvaluateAction(Spell.LavaBurst, self.Requirements.LavaBurst.Use);
		action.EvaluateAction(Talent.ElementalBlast, self.Requirements.ElementalBlast);
		action.EvaluateAction(Spell.LavaBeam, self.Requirements.LavaBeam);
		-- actions.aoe+=/lava_beam
		action.EvaluateAction(Spell.LavaBeam, true);
		action.EvaluateAction(Spell.ChainLightning, self.Requirements.ChainLightning);
		-- actions.aoe+=/chain_lightning
		action.EvaluateAction(Spell.ChainLightning, true);
		action.EvaluateAction(Spell.LavaBurst, self.Requirements.LavaBurst.Moving);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Moving);
	end

	-- actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
	function self.Use(numEnemies)
		return numEnemies > 2
		   and (Enemies.GetEnemies(Spell.ChainLightning) > 2 or Enemies.GetEnemies(Spell.LavaBeam) > 2);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local AOE = AOE("AOE");

-- Ascendance Rotation
local function Ascendance(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.single_asc=ascendance,if=dot.flame_shock.remains>buff.ascendance.duration&(time>=60|buff.bloodlust.up)&cooldown.lava_burst.remains>0&!buff.stormkeeper.up
		Ascendance = function()
			return Target.Debuff(Aura.FlameShock).Remains() > Talent.Ascendance.BaseDuration()
			   and (Core.CombatTime() >= 60 or Player.HasBloodlust())
			   and Spell.LavaBurst.Cooldown.Remains() > 0
			   and not Player.Buff(Aura.Stormkeeper).Up();
		end,

		-- actions.single_asc+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
		ChainLightning = function(numEnemies)
			return numEnemies > 1
			   and Enemies.GetEnemies(Spell.ChainLightning) > 1;
		end,

		Earthquake = {
			-- actions.single_asc+=/earthquake,if=buff.echoes_of_the_great_sundering.up&(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.the_deceivers_blood_pact&maelstrom>85&talent.aftershock.enabled)
			Use = function()
				return Player.Buff(Aura.EchoesOfTheGreatSundering).Up()
				   and (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Trait.Enabled and Player.Maelstrom() >= 86)
				    or Legendary.TheDeceiversBloodPact.Equipped()
				   and Player.Maelstrom() > 85
				   and Talent.Aftershock.Enabled();
			end,

			-- actions.single_asc+=/earthquake,if=buff.echoes_of_the_great_sundering.up&(buff.earthen_strength.up|buff.echoes_of_the_great_sundering.duration<=3|maelstrom>=117)|(buff.earthen_strength.up|maelstrom>=104)&spell_targets.earthquake>1&!equipped.echoes_of_the_great_sundering
			EchosOfTheGreatSundering = function(numEnemies)
				return Player.Buff(Aura.EchoesOfTheGreatSundering).Up()
				   and (Player.Buff(Aura.EarthenStrength).Up() or Player.Buff(Aura.EchoesOfTheGreatSundering).Duration() <= 3 or Player.Maelstrom() >= 117)
				    or (Player.Buff(Aura.EarthenStrength).Up() or Player.Maelstrom() >= 104)
				   and numEnemies > 1
				   and not Legendary.EchoesOfTheGreatSundering.Equipped();
			end,
		};

		EarthShock = {
			-- actions.single_asc+=/earth_shock,if=(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)&(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.the_deceivers_blood_pact&talent.aftershock.enabled&(maelstrom>85&equipped.echoes_of_the_great_sundering|maelstrom>70&equipped.smoldering_heart))
			Use = function(numEnemies)
				return (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped())
				   and (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Trait.Enabled() and Player.Maelstrom() >= 86 or Legendary.TheDeceiversBloodPact.Equipped() and Talent.Aftershock.Enabled() and (Player.Maelstrom() > 85 and Legendary.EchoesOfTheGreatSundering.Equipped() or Player.Maelstrom() > 70 and Legendary.SmolderingHeart.Equipped()));
			end,

			-- actions.single_asc+=/earth_shock,if=(maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92)&(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)
			EchoesOfTheGreatSundering = function(numEnemies)
				return (Player.Maelstrom() >= 117 or not Artifact.SwellingMaelstrom.Trait.Enabled() and Player.Maelstrom() >= 92)
				   and (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped());
			end,

			-- actions.single_asc+=/earth_shock,moving=1
			Moving = function()
				return Player.IsMoving();
			end,
		},

		FlameShock = {
			-- actions.single_asc+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
			Use = function()
				return Player.Maelstrom() >= 20
				   and Player.Buff(Aura.ElementalFocus).Up()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.single_asc+=/flame_shock,if=maelstrom>=20&remains<=buff.ascendance.duration&cooldown.ascendance.remains+buff.ascendance.duration<=duration
			Ascendance = function()
				return Player.Maelstrom() >= 20
				   and Target.Debuff(Aura.FlameShock).Remains() <= Talent.Ascendance.BaseDuration()
				   and Talent.Ascendance.Cooldown.Remains() + Talent.Ascendance.BaseDuration() <= Spell.FlameShock.BaseDuration();
			end,

			-- actions.single_asc+=/flame_shock,moving=1,target_if=refreshable
			Moving = function()
				return Player.IsMoving()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.single_asc+=/flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
			Refresh = function()
				return not Target.Debuff(Aura.FlameShock).Up()
				    or Target.Debuff(Aura.FlameShock).Remains() <= Player.GCD();
			end,
		},

		-- actions.single_asc+=/lava_beam,if=active_enemies>1&spell_targets.lava_beam>1
		LavaBeam = function(numEnemies)
			return numEnemies > 1
			   and Enemies.GetEnemies(Spell.LavaBeam) > 1;
		end,

		-- cooldown_react can't be done right now.
		-- actions.single_asc+=/lava_burst,if=dot.flame_shock.remains>cast_time&(cooldown_react|buff.ascendance.up)
		LavaBurst = function()
			return Target.Debuff(Aura.FlameShock).Remains() > Spell.LavaBurst.CastTime()
			   and Player.Buff(Aura.Ascendance).Up();
		end,

		LightningBolt = {
			-- actions.single_asc+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
			Use = function()
				return Player.Buff(Aura.PowerOfTheMaelstrom).Up()
				   and Enemies.GetEnemies(Spell.ChainLightning) < 3;
			end,

			-- actions.single_asc+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&buff.stormkeeper.up&spell_targets.chain_lightning<3
			Stormkeeper = function()
				return Player.Buff(Aura.PowerOfTheMaelstrom).Up()
				   and Player.Buff(Aura.Stormkeeper).Up()
				   and Enemies.GetEnemies(Spell.ChainLightning) < 3;
			end,
		},

		-- actions.single_asc+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
		LiquidMagmaTotem = function(numEnemies)
			return numEnemies < Core.DesiredTargets() + 3
		end,

		-- actions.single_asc+=/stormkeeper,if=(raid_event.adds.count<3|raid_event.adds.in>50)&time>5&!buff.ascendance.up
		Stormkeeper = function(numEnemies)
			return numEnemies < Core.DesiredTargets() + 3
			   and Core.CombatTime() > 5
			   and not Player.Buff(Aura.Ascendance).Up();
		end,

		-- actions.single_asc+=/totem_mastery,if=buff.resonance_totem.remains<10|(buff.resonance_totem.remains<(buff.ascendance.duration+cooldown.ascendance.remains)&cooldown.ascendance.remains<15)
		TotemMastery = function()
			return Player.Buff(Aura.ResonanceTotem).Remains() < 10
			    or (Player.Buff(Aura.ResonanceTotem).Remains() < (Talent.Ascendance.BaseDuration() + Talent.Ascendance.Cooldown.Remains()) and Talent.Ascendance.Cooldown.Remains() < 15);
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Talent.Ascendance, self.Requirements.Ascendance);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Refresh);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Ascendance);
		-- actions.single_asc+=/elemental_blast
		action.EvaluateAction(Talent.ElementalBlast, true);
		action.EvaluateAction(Spell.Earthquake, self.Requirements.Earthquake.EchosOfTheGreatSundering);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.EchosOfTheGreatSundering);
		action.EvaluateAction(Artifact.Stormkeeper, self.Requirements.Stormkeeper);
		action.EvaluateAction(Talent.LiquidMagmaTotem, self.Requirements.LiquidMagmaTotem);
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.Stormkeeper);
		action.EvaluateAction(Spell.LavaBurst, self.Requirements.LavaBurst);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Use);
		action.EvaluateAction(Spell.Earthquake, self.Requirements.Earthquake.Use);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Use);
		action.EvaluateAction(Talent.TotemMastery, self.Requirements.TotemMastery);
		action.EvaluateAction(Spell.LavaBeam, self.Requirements.LavaBeam);
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.Use);
		action.EvaluateAction(Spell.ChainLightning, self.Requirements.ChainLightning);
		-- actions.single_asc+=/lightning_bolt
		action.EvaluateAction(Spell.LightningBolt, true);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Moving);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Moving);
	end

	-- actions+=/run_action_list,name=single_asc,if=talent.ascendance.enabled
	function self.Use()
		return Talent.Ascendance.Enabled();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Ascendance = Ascendance("Ascendance");

-- Icefury Rotation
local function Icefury(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- The addon either passes active_enemies or spell_targets not both, but if spell_targets is greater than 1, active_enemies must also be greater than 1.
		-- actions.single_if+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
		ChainLightning = function(numEnemies)
			return numEnemies > 1;
		end,

		Earthquake = {
			-- actions.single_if+=/earthquake,if=buff.echoes_of_the_great_sundering.up&(buff.earthen_strength.up|buff.echoes_of_the_great_sundering.duration<=3|maelstrom>=117)|(buff.earthen_strength.up|maelstrom>=104)&spell_targets.earthquake>1&!equipped.echoes_of_the_great_sundering
			Use = function(numEnemies)
				return Player.Buff(Aura.EchoesOfTheGreatSundering).Up()
				   and (Player.Buff(Aura.EarthenStrength).Up() or Player.Buff(Aura.EchoesOfTheGreatSundering).Duration() <= 3 or Player.Maelstrom() >= 117)
				    or (Player.Buff(Aura.EarthenStrength).Up() or Player.Maelstrom() >= 104)
				   and numEnemies > 1
				   and not Legendary.EchoesOfTheGreatSundering.Equipped();
			end,

			-- actions.single_if+=/earthquake,if=buff.echoes_of_the_great_sundering.up&(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.the_deceivers_blood_pact&maelstrom>85&talent.aftershock.enabled)
			EchoesOfTheGreatSundering = function()
				return Player.Buff(Aura.EchoesOfTheGreatSundering).Up()
				   and (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 86 or Legendary.TheDeceiversBloodPact.Equipped() and Player.Maelstrom() > 85 and Talent.Aftershock.Enabled());
			end,
		},

		EarthShock = {
			-- actions.single_if+=/earth_shock,if=(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)&(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.the_deceivers_blood_pact&talent.aftershock.enabled&(maelstrom>85&equipped.echoes_of_the_great_sundering|maelstrom>70&equipped.smoldering_heart))
			Use = function(numEnemies)
				return (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped())
				   and (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 86 or Legendary.TheDeceiversBloodPact.Equipped() and Talent.Aftershock.Enabled() and (Player.Maelstrom() > 85 and Legendary.EchoesOfTheGreatSundering.Equipped() or Player.Maelstrom() > 70 and Legendary.SmolderingHeart.Equipped()));
			end,

			-- actions.single_if+=/earth_shock,if=(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=92)&(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)&buff.earthen_strength.up
			EarthenStrength = function(numEnemies)
				return (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 92)
				   and (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped())
				   and Player.Buff(Aura.EarthenStrength).Up();
			end,

			-- actions.single_if+=/earth_shock,if=(maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92)&(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)
			Maelstrom = function(numEnemies)
				return (Player.Maelstrom() >= 117 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 92)
				   and (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped());
			end,

			-- actions.single_if+=/earth_shock,moving=1
			Moving = function()
				return Player.IsMoving();
			end,
		},

		FlameShock = {
			-- actions.single_if+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
			ElementalFocus = function()
				return Player.Maelstrom() >= 20
				   and Player.Buff(Aura.ElementalFocus).Up()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.single_if+=/flame_shock,moving=1,target_if=refreshable
			Moving = function()
				return Player.IsMoving()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.single_if=flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
			Refresh = function()
				return not Target.Debuff(Aura.FlameShock).Up()
				    or Target.Debuff(Aura.FlameShock).Remains() <= Player.GCD();
			end,
		},

		FrostShock = {
			-- We can't do raid movement events so just skip that part.
			-- actions.single_if+=/frost_shock,if=buff.icefury.up&((maelstrom>=20&raid_event.movement.in>buff.icefury.remains)|buff.icefury.remains<(1.5*spell_haste*buff.icefury.stack+1))
			Use = function()
				local spell_haste = 1 / (1 + (Player.HastePercent() / 100));

				return Player.Buff(Aura.Icefury).Up()
				   and (Player.Maelstrom() >= 20 or Player.Buff(Aura.IceFury).Remains() < (1.5 * spell_haste * (Player.Buff(Aura.Icefury).Stack() + 1)))
			end,

			-- actions.single_if+=/frost_shock,if=buff.icefury.up&maelstrom>=20&!buff.ascendance.up&buff.earthen_strength.up
			Icefury = function()
				return Player.Buff(Aura.Icefury).Up()
				   and Player.Maelstrom() >= 20
				   and not Player.Buff(Aura.Ascendance).Up()
				   and Player.Buff(Aura.EarthenStrength).Up();
			end,

			-- actions.single_if+=/frost_shock,moving=1,if=buff.icefury.up
			Moving = function()
				return Player.IsMoving()
				   and Player.Buff(Aura.Icefury).Up();
			end,
		},

		-- We can't do raid_event.movement.in events so skip that.
		-- actions.single_if+=/icefury,if=(raid_event.movement.in<5|maelstrom<=101&artifact.swelling_maelstrom.enabled|!artifact.swelling_maelstrom.enabled&maelstrom<=76)&!buff.ascendance.up
		Icefury = function()
			return	(Player.Maelstrom() <= 101 and Artifact.SwellingMaelstrom.Enabled() or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() <= 76)
			   and not Player.Buff(Aura.Ascendance).Up();
		end,

		-- The addon either passes active_enemies or spell_targets not both, but if spell_targets is greater than 1, active_enemies must also be greater than 1.
		-- actions.single_if+=/lava_beam,if=active_enemies>1&spell_targets.lava_beam>1
		LavaBeam = function(numEnemies)
			return numEnemies > 1;
		end,

		-- actions.single_if+=/lava_burst,if=dot.flame_shock.remains>cast_time&cooldown_react
		LavaBurst = function()
			return Target.Debuff(Aura.FlameShock).Remains() > Spell.LavaBurst.CastTime()
			   and Spell.LavaBurst.Cooldown.React();
		end,

		LightningBolt = {
			-- actions.single_if+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
			Use = function(numEnemies)
				return Player.Buff(Aura.PowerOfTheMaelstrom).Up()
				   and numEnemies < 3;
			end,

			-- actions.single_if+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&buff.stormkeeper.up&spell_targets.chain_lightning<3
			Stormkeeper = function(numEnemies)
				return Player.Buff(Aura.PowerOfTheMaelstrom).Up()
				   and Player.Buff(Aura.Stormkeeper).Up()
				   and numEnemies < 3;
			end,
		},

		-- We can't do raid_event.adds.in so just skip that, use Desired Targets (number of boss frames) to determine number of adds.
		-- actions.single_if+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
		LiquidMagmaTotem = function(numEnemies)
			return numEnemies - Core.DesiredTargets() < 3;
		end,

		-- We can't do raid_event.adds.in so just skip that, use Desired Targets (number of boss frames) to determine number of adds.
		-- actions.single_if+=/stormkeeper,if=(raid_event.adds.count<3|raid_event.adds.in>50)&!buff.ascendance.up
		Stormkeeper = function(numEnemies)
			return numEnemies - Core.DesiredTargets() < 3
			   and not Player.Buff(Aura.Ascendance).Up();
		end,

		-- actions.single_if+=/totem_mastery,if=buff.resonance_totem.remains<10
		TotemMastery = function()
			return Player.Buff(Aura.ResonanceTotem).Remains() < 10;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Refresh);
		-- actions.single_if+=/elemental_blast
		action.EvaluateAction(Talent.ElementalBlast, true);
		action.EvaluateAction(Spell.Earthquake, self.Requirements.Earthquake.Use, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.EarthenStrength, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Spell.FrostShock, self.Requirements.FrostShock.Icefury);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Maelstrom, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Artifact.Stormkeeper, self.Requirements.Stormkeeper);
		action.EvaluateAction(Talent.Icefury, self.Requirements.Icefury);
		action.EvaluateAction(Talent.LiquidMagmaTotem, self.Requirements.LiquidMagmaTotem);
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.Stormkeeper, Enemies.GetEnemies(Spell.ChainLightning));
		action.EvaluateAction(Spell.LavaBurst, self.Requirements.LavaBurst);
		action.EvaluateAction(Spell.FrostShock, self.Requirements.FrostShock.Use);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.ElementalFocus);
		action.EvaluateAction(Spell.Earthquake, self.Requirements.Earthquake.EchoesOfTheGreatSundering);
		action.EvaluateAction(Spell.FrostShock, self.Requirements.FrostShock.Moving);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Use, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Talent.TotemMastery, self.Requirements.TotemMastery);
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.Use, Enemies.GetEnemies(Spell.ChainLightning));
		action.EvaluateAction(Spell.LavaBeam, self.Requirements.LavaBeam, Enemies.GetEnemies(Spell.LavaBeam));
		action.EvaluateAction(Spell.ChainLightning, self.Requirements.ChainLightning, Enemies.GetEnemies(Spell.ChainLightning));
		-- actions.single_if+=/lightning_bolt
		action.EvaluateAction(Spell.LightningBolt, true);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Moving);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Moving);
	end

	-- actions+=/run_action_list,name=single_if,if=talent.icefury.enabled
	function self.Use()
		return Talent.Icefury.Enabled();
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Icefury = Icefury("Icefury");

-- Lightning Rod Rotation
local function LightningRod(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ChainLightning = {
			-- The addon either passes active_enemies or spell_targets not both, but if spell_targets is greater than 1, active_enemies must also be greater than 1.
			-- actions.single_lr+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
			Use = function(numEnemies)
				return numEnemies > 1;
			end,

			-- The addon either passes active_enemies or spell_targets not both, but if spell_targets is greater than 1, active_enemies must also be greater than 1.
			-- actions.single_lr+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1,target_if=debuff.lightning_rod.down
			NoLightningRod = function(numEnemies)
				return numEnemies > 1
				   and Target.Debuff(Aura.LightningRod).Down();
			end,
		},

		Earthquake = {
			-- actions.single_lr+=/earthquake,if=buff.echoes_of_the_great_sundering.up&(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.the_deceivers_blood_pact&maelstrom>85&talent.aftershock.enabled)
			Use = function()
				return Player.Buff(Aura.EchoesOfTheGreatSundering).Up()
				   and (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 86 or Legendary.TheDeceiversBloodPact.Equipped() and Player.Maelstrom() > 85 and Talent.Aftershock.Enabled());
			end,

			-- actions.single_lr+=/earthquake,if=buff.echoes_of_the_great_sundering.up&(buff.earthen_strength.up|buff.echoes_of_the_great_sundering.duration<=3|maelstrom>=117)|(buff.earthen_strength.up|maelstrom>=104)&spell_targets.earthquake>1&!equipped.echoes_of_the_great_sundering
			EchoesOfTheGreatSundering = function(numEnemies)
				return Player.Buff(Aura.EchoesOfTheGreatSundering).Up()
				   and (Player.Buff(Aura.EarthenStrength).Up() or Player.Buff(Aura.EchoesOfTheGreatSundering).Duration() <= 3 or Player.Maelstrom() >= 117)
				    or (Player.Buff(Aura.EarthenStrength).Up() or Player.Maelstrom() >= 104)
				   and numEnemies > 1
				   and not Legendary.EchoesOfTheGreatSundering.Equipped();
			end
		},

		EarthShock = {
			-- actions.single_lr+=/earth_shock,if=(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)&(maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.the_deceivers_blood_pact&talent.aftershock.enabled&(maelstrom>85&equipped.echoes_of_the_great_sundering|maelstrom>70&equipped.smoldering_heart))
			Use = function(numEnemies)
				return (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped())
				   and (Player.Maelstrom() >= 111 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 86 or Legendary.TheDeceiversBloodPact.Equipped() and Talent.Aftershock.Enabled() and (Player.Maelstrom() > 85 and Legendary.EchoesOfTheGreatSundering.Equipped() or Player.Maelstrom() > 70 and Legendary.SmolderingHeart.Equipped()));
			end,

			-- actions.single_lr+=/earth_shock,if=(maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92)&(spell_targets.earthquake=1|equipped.echoes_of_the_great_sundering)
			Maelstrom = function(numEnemies)
				return (Player.Maelstrom() >= 117 or not Artifact.SwellingMaelstrom.Enabled() and Player.Maelstrom() >= 92)
				   and (numEnemies == 1 or Legendary.EchoesOfTheGreatSundering.Equipped());
			end,

			-- actions.single_lr+=/earth_shock,moving=1
			Moving = function()
				return Player.IsMoving();
			end,
		},

		FlameShock = {
			-- actions.single_lr+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
			Use = function()
				return Player.Maelstrom() >= 20
				   and Player.Buff(Aura.ElementalFocus).Up()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.single_lr+=/flame_shock,moving=1,target_if=refreshable
			Moving = function()
				return Player.IsMoving()
				   and Target.Debuff(Aura.FlameShock).Refreshable();
			end,

			-- actions.single_lr=flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
			Refresh = function()
				return not Target.Debuff(Aura.FlameShock).Up()
					or Target.Debuff(Aura.FlameShock).Remains() <= Player.GCD();
			end,
		},

		LavaBeam = {
			-- The addon either passes active_enemies or spell_targets not both, but if spell_targets is greater than 1, active_enemies must also be greater than 1.
			-- actions.single_lr+=/lava_beam,if=active_enemies>1&spell_targets.lava_beam>1
			Use = function(numEnemies)
				return numEnemies > 1;
			end,

			-- The addon either passes active_enemies or spell_targets not both, but if spell_targets is greater than 1, active_enemies must also be greater than 1.
			-- actions.single_lr+=/lava_beam,if=active_enemies>1&spell_targets.lava_beam>1,target_if=debuff.lightning_rod.down
			NoLightningRod = function(numEnemies)
				return numEnemies > 1
				   and Target.Debuff(Aura.LightningRod).Down();
			end,
		},

		-- actions.single_lr+=/lava_burst,if=dot.flame_shock.remains>cast_time&cooldown_react
		LavaBurst = function()
			return Target.Debuff(Aura.FlameShock).Remains() > Spell.LavaBurst.CastTime()
			   and Spell.LavaBurst.Cooldown.React();
		end,

		LightningBolt = {
			-- actions.single_lr+=/lightning_bolt,target_if=debuff.lightning_rod.down
			Use = function()
				return Target.Debuff(Aura.LightningRod).Down();
			end,

			-- actions.single_lr+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3,target_if=debuff.lightning_rod.down
			NoLightningRod = function(numEnemies)
				return Player.Buff(Aura.PowerOfTheMaelstrom).Up()
				   and numEnemies < 3
				   and Target.Debuff(Aura.LightningRod).Down();
			end,

			-- actions.single_lr+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
			PowerOfTheMaelstrom = function(numEnemies)
				return Player.Buff(Aura.PowerOfTheMaelstrom).Up()
				   and numEnemies < 3;
			end,
		},
		-- We can't do raid_event.adds.in so just skip that, use Desired Targets (number of boss frames) to determine number of adds.
		-- actions.single_lr+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
		LiquidMagmaTotem = function(numEnemies)
			return numEnemies - Core.DesiredTargets() < 3;
		end,

		-- We can't do raid_event.adds.in so just skip that, use Desired Targets (number of boss frames) to determine number of adds.
		-- actions.single_lr+=/stormkeeper,if=(raid_event.adds.count<3|raid_event.adds.in>50)&!buff.ascendance.up
		Stormkeeper = function(numEnemies)
			return numEnemies - Core.DesiredTargets() < 3
			   and not Player.Buff(Aura.Ascendance).Up();
		end,

		-- actions.single_lr+=/totem_mastery,if=buff.resonance_totem.remains<10|(buff.resonance_totem.remains<(buff.ascendance.duration+cooldown.ascendance.remains)&cooldown.ascendance.remains<15)
		TotemMastery = function()
			return Player.Buff(Aura.ResonanceTotem).Remains() < 10
			    or (Player.Buff(Aura.ResonanceTotem).Remains() < (Player.Buff(Aura.Ascendance).Duration() + Talent.Ascendance.cooldown.Remains()) and Talent.Ascendance.Cooldown.Remains() < 15);
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Refresh);
		-- actions.single_lr+=/elemental_blast
		action.EvaluateAction(Talent.ElementalBlast, true);
		action.EvaluateAction(Spell.Earthquake, self.Requirements.Earthquake.EchoesOfTheGreatSundering, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Maelstrom, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Artifact.Stormkeeper, self.Requirements.Stormkeeper);
		action.EvaluateAction(Talent.LiquidMagmaTotem, self.Requirements.LiquidMagmaTotem);
		action.EvaluateAction(Spell.LavaBurst, self.Requirements.LavaBurst);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Use);
		action.EvaluateAction(Spell.Earthquake, self.Requirements.Earthquake.Use);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Use, Enemies.GetEnemies(Spell.Earthquake));
		action.EvaluateAction(Talent.TotemMastery, self.Requirements.TotemMastery);
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.NoLightningRod, Enemies.GetEnemies(Spell.ChainLightning));
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.PowerOfTheMaelstrom, Enemies.GetEnemies(Spell.ChainLightning));
		action.EvaluateAction(Spell.LavaBeam, self.Requirements.LavaBeam.NoLightningRod, Enemies.GetEnemies(Spell.LavaBeam));
		action.EvaluateAction(Spell.LavaBeam, self.Requirements.LavaBeam.Use, Enemies.GetEnemies(Spell.LavaBeam));
		action.EvaluateAction(Spell.ChainLightning, self.Requirements.ChainLightning.NoLightningRod, Enemies.GetEnemies(Spell.ChainLightning));
		action.EvaluateAction(Spell.ChainLightning, self.Requirements.ChainLightning.Use, Enemies.GetEnemies(Spell.ChainLightning));
		action.EvaluateAction(Spell.LightningBolt, self.Requirements.LightningBolt.Use);
		-- actions.single_lr+=/lightning_bolt
		action.EvaluateAction(Spell.LightningBolt, true);
		action.EvaluateAction(Spell.FlameShock, self.Requirements.FlameShock.Moving);
		action.EvaluateAction(Spell.EarthShock, self.Requirements.EarthShock.Moving);
	end

	-- We want this to be the default if the player has not reached level 100 so add an extra condition so it will run.
	-- actions+=/run_action_list,name=single_lr,if=talent.lightning_rod.enabled
	function self.Use()
		return Talent.LightningRod.Enabled()
		    or Player.Level() < 100;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local LightningRod = LightningRod("LightningRod");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Storm Earth and Lava",
		GuideLink = "https://www.icy-veins.com/wow/elemental-shaman-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Ascendance"] = "3001331",
		["Icefury"] = "3001333",
		["Lightning Rod / Mythic+"] = "3001312",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		AstralShift = function()
			return Player.DamagePredicted(3) >= 20;
		end,

		-- actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
		Berserking = function()
			return not Talent.Ascendance.Enabled()
				or Player.Buff(Aura.Ascendance).Up();
		end,

		-- actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
		BloodFury = function()
			return not Talent.Ascendance.Enabled()
			    or Player.Buff(Aura.Ascendance).Up()
			    or Talent.Ascendance.Cooldown.Remains() > 50;
		end,

		BullRush = function()
			return Target.InRange(6);
		end,

		-- actions+=/use_item,name=gnawed_thumb_ring,if=equipped.gnawed_thumb_ring&(talent.ascendance.enabled&!buff.ascendance.up|!talent.ascendance.enabled)
		GnawedThumbRing = function()
			return Item.GnawedThumbRing.Equipped()
			   and (Talent.Ascendance.Enabled() and not Player.Buff(Aura.Ascendance).Up() or not Talent.Ascendance.Enabled());
		end,

		HealingSurge = function()
			return Player.Health.Percent() < 60;
		end,

		LightningSurgeTotem = function()
			return Target.Casting.Remains() > 2;
		end,

		-- actions+=/potion,if=cooldown.fire_elemental.remains>280|target.time_to_die<=60
		ProlongedPower = function()
			return Spell.FireElemental.Cooldown.Remains() > 280
			    or Target.TimeToDie() <= 60;
		end,

		-- actions+=/totem_mastery,if=buff.resonance_totem.remains<2
		TotemMastery = function()
			return Player.Buff(Aura.ResonanceTotem).Remains() < 2;
		end,

		WarStomp = function()
			return Target.InRange(5);
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		Racial = {
			Berserking = Objects.newSpell(26297),
			BloodFury = Objects.newSpell(33702),
			BullRush = Objects.newSpell(255654),
			GiftOfTheNaaru = Objects.newSpell(109142),
			QuakingPalm = Objects.newSpell(107079),
			RocketBarrage = Objects.newSpell(69041),
			RocketJump = Objects.newSpell(69070),
			Stoneform = Objects.newSpell(20594),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Active
			Stormkeeper = Objects.newSpell(205495),
			-- Passive
			ArtificialStamina = Objects.newSpell(211309),
			CallTheThunder = Objects.newSpell(191493),
			ConcordanceOfTheLegionfall = Objects.newSpell(239042),
			EarthenAttunement = Objects.newSpell(191598),
			ElectricDischarge = Objects.newSpell(191577),
			ElementalDestabilization = Objects.newSpell(238069),
			Elementalist = Objects.newSpell(191512),
			Firestorm = Objects.newSpell(191740),
			FuryOfTheStorms = Objects.newSpell(191717),
			LavaImbued = Objects.newSpell(191504),
			MasterOfTheElements = Objects.newSpell(191647),
			MoltenBlast = Objects.newSpell(191572),
			PowerOfTheEarthenRing = Objects.newSpell(241202),
			PowerOfTheMaelstrom = Objects.newSpell(191861),
			ProtectionOfTheElements = Objects.newSpell(191569),
			SeismicStorm = Objects.newSpell(238141),
			ShamanisticHealing = Objects.newSpell(191582),
			StaticOverload = Objects.newSpell(191602),
			StormkeepersPower = Objects.newSpell(214931),
			SurgeOfPower = Objects.newSpell(215414),
			SwellingMaelstrom = Objects.newSpell(238105),
			TheGroundTrembles = Objects.newSpell(191499),
			VolcanicInferno = Objects.newSpell(192630),
		};

		Spell = {
			-- Active
			AncestralSpirit = Objects.newSpell(2008),
			AstralRecal = Objects.newSpell(556),
			AstralShift = Objects.newSpell(108271),
			Bloodlust = Objects.newSpell(2825),
			ChainLightning = Objects.newSpell(188443),
			CleanseSpirit = Objects.newSpell(51886),
			EarthbindTotem = Objects.newSpell(2484),
			EarthElemental = Objects.newSpell(198103),
			Earthquake = Objects.newSpell(61882),
			EarthShock = Objects.newSpell(8042),
			FarSight = Objects.newSpell(6196),
			FireElemental = Objects.newSpell(198067),
			FlameShock = Objects.newSpell(188389),
			FrostShock = Objects.newSpell(196840),
			GhostWolf = Objects.newSpell(2645),
			HealingSurge = Objects.newSpell(8004),
			Heroism = Objects.newSpell(32182),
			Hex = Objects.newSpell(51514),
			LavaBeam = Objects.newSpell(114074),
			LavaBurst = Objects.newSpell(51505),
			LightningBolt = Objects.newSpell(188196),
			Purge = Objects.newSpell(370),
			Thunderstorm = Objects.newSpell(51490),
			WaterWalking = Objects.newSpell(546),
			WindShear = Objects.newSpell(57994),
			-- Passive
			ElementalFocus = Objects.newSpell(16164),
			ElementalFury = Objects.newSpell(60188),
			ElementalOverload = Objects.newSpell(168534),
			Fulmination = Objects.newSpell(190493),
			LavaSurge = Objects.newSpell(77756),
			Maelstrom = Objects.newSpell(187828),
			Reincarnation = Objects.newSpell(20608),
		};

		Talent = {
			-- Active
			Ascendance = Objects.newSpell(114050),
			AncestralGuidance = Objects.newSpell(108281),
			EarthgrabTotem = Objects.newSpell(51485),
			ElementalBlast = Objects.newSpell(117014),
			ElementalMastery = Objects.newSpell(16166),
			GustOfWind = Objects.newSpell(192063),
			Icefury = Objects.newSpell(210714),
			LightningSurgeTotem = Objects.newSpell(192058),
			LiquidMagmaTotem = Objects.newSpell(192222),
			StormElemental = Objects.newSpell(192249),
			TotemMastery = Objects.newSpell(210643),
			VoodooTotem = Objects.newSpell(196932),
			WindRushTotem = Objects.newSpell(192077),
			-- Passive
			Aftershock = Objects.newSpell(210707),
			AncestralSwiftness = Objects.newSpell(192087),
			EarthenRage = Objects.newSpell(170374),
			EchoOfTheElements = Objects.newSpell(108283),
			ElementalFusion = Objects.newSpell(192235),
			LightningRod = Objects.newSpell(210689),
			PathOfFlame = Objects.newSpell(201909),
			PrimalElementalist = Objects.newSpell(117013),
		};

		Aura = {
			AncestralGuidance = Objects.newSpell(108281),
			ArtificialStamina = Objects.newSpell(211309),
			Ascendance = Objects.newSpell(114050),
			AstralShift = Objects.newSpell(108271),
			Bloodlust = Objects.newSpell(2825),
			ConcordanceOfTheLegionfall = Objects.newSpell(242583),
			Earthbind = Objects.newSpell(116947),
			EarthenStrength = Objects.newSpell(252141),
			Earthgrab = Objects.newSpell(64695),
			Earthquake = Objects.newSpell(182387),
			EarthquakeStun = Objects.newSpell(77505),
			ElementalBlastCriticalStrike = Objects.newSpell(118522),
			ElementalBlastHaste = Objects.newSpell(173183),
			ElementalBlastMastery = Objects.newSpell(173184),
			ElementalFocus = Objects.newSpell(16246),
			ElementalMastery = Objects.newSpell(16166),
			EmberTotem = Objects.newSpell(210658),
			EyeOfTheStorm = Objects.newSpell(157384),
			FarSight = Objects.newSpell(6196),
			FlameShock = Objects.newSpell(188389),
			FrostShock = Objects.newSpell(196840),
			GhostWolf = Objects.newSpell(2645),
			Heroism = Objects.newSpell(32182),
			Hex = Objects.newSpell(51514),
			Icefury = Objects.newSpell(210714),
			LavaSurge = Objects.newSpell(77762),
			LightningRod = Objects.newSpell(197209),
			PowerOfTheEarthenRing = Objects.newSpell(241202),
			PowerOfTheMaelstrom = Objects.newSpell(191877),
			ResonanceTotem = Objects.newSpell(202192),
			StaticCharge = Objects.newSpell(118905),
			StaticOverload = Objects.newSpell(191634),
			Stormkeeper = Objects.newSpell(205495),
			StormTotem = Objects.newSpell(210652),
			TailwindTotem = Objects.newSpell(210659),
			Thunderstorm = Objects.newSpell(51490),
			WaterWalking = Objects.newSpell(546),
			WindRush = Objects.newSpell(192082),

			-- Legendaries
			EchoesOfTheGreatSundering = Objects.newSpell(208723),
		};

		-- Items
		Legendary = {
			EchoesOfTheGreatSundering = Objects.newItem(137074),
			SmolderingHeart = Objects.newItem(151819),
			TheDeceiversBloodPact = Objects.newItem(137035),
		};

		Item = {
			GnawedThumbRing = Objects.newItem(134526),
		};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Aura, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.Berserking, Racial.BloodFury, Racial.BullRush, Racial.GiftOfTheNaaru, Racial.RocketBarrage, Racial.RocketJump, Racial.Stoneform);
		config.AOEOptions(options, Spell.ChainLightning, Spell.Earthquake, Spell.LavaBeam, Talent.LiquidMagmaTotem, Spell.Thunderstorm);
		config.BuffOptions(options, Talent.TotemMastery);
		config.CooldownOptions(options, Talent.Ascendance, Spell.Bloodlust, Spell.EarthElemental, Talent.ElementalBlast, Talent.ElementalMastery, Spell.FireElemental,
									 Spell.Heroism, Talent.Icefury, Talent.StormElemental, Artifact.Stormkeeper);
		config.DefensiveOptions(options, Spell.AstralShift);
		-- Setup the Utility options
		config.UtilityOptions(options, Talent.AncestralGuidance, Spell.CleanseSpirit, Spell.EarthbindTotem, Talent.EarthgrabTotem, Spell.FrostShock, Talent.GustOfWind,
									Spell.HealingSurge, Spell.Hex, Spell.Purge, Talent.VoodooTotem, Talent.WindRushTotem);
	end

	-- Function for destroying action objects such as spells, buffs, debuffs and items, called when the rotation is no longer the active rotation.
	function self.Disable()
		Racial = nil;
		Artifact = nil;
		Spell = nil;
		Talent = nil;
		Aura = nil;
		Legendary = nil;
		Item = nil;
		Consumable = nil;
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
		-- The abilities here should be listed from highest damage required to suggest to lowest,
		-- Specific damage types before all damage types.

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.AstralShift, self.Requirements.AstralShift);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.HealingSurge, self.Requirements.HealingSurge);
	end

	-- Function for displaying interrupts when Target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.WindShear, true);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Racial.QuakingPalm, true);
			action.EvaluateInterruptAction(Racial.BullRush, self.Requirements.BullRush);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
			action.EvaluateInterruptAction(Talent.LightningSurgeTotem, self.Requirements.LightningSurgeTotem);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for setting any pre-combat variables, is always called even if you don't have a target.
	function self.PrecombatVariables()
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
-- Add the standard use check for totem mastery so it doesn't continue to suggest it if you have already used it.
-- actions.precombat+=/totem_mastery
		action.EvaluateAction(Talent.TotemMastery, self.Requirements.TotemMastery);
-- actions.precombat+=/fire_elemental
		action.EvaluateAction(Spell.FireElemental, true);
-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
-- actions.precombat+=/elemental_blast
		action.EvaluateAction(Talent.ElementalBlast, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Talent.TotemMastery, self.Requirements.TotemMastery);
		-- actions+=/fire_elemental
		action.EvaluateAction(Spell.FireElemental, true);
		-- actions+=/storm_elemental
		action.EvaluateAction(Talent.StormElemental, true);
		-- actions+=/elemental_mastery
		action.EvaluateAction(Talent.ElementalMastery, true);
		action.EvaluateAction(Item.GnawedThumbRing, self.Requirements.GnawedThumbRing);
		action.EvaluateAction(Racial.BloodFury, self.Requirements.BloodFury);
		action.EvaluateAction(Racial.Berserking, self.Requirements.Berserking);

		action.RunActionList(AOE);
		action.RunActionList(Ascendance);
		action.RunActionList(Icefury);
		action.RunActionList(LightningRod);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Elemental Shaman", addonTable.Enum.SpecID.SHAMAN_ELEMENTAL);