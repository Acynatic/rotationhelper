local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

-- Localize Vars
local Core = addon.Core.General;
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Function for converting booleans returns to numbers
local val = Core.ToNumber;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Consumable;

local nameAPL = "lunaeclipse_demonhunter_havoc";

local function Variables(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Function to set variables that change in combat.
	function self.Rotation(action)
		-- actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
		self.waiting_for_nemesis = not (not Talent.Nemesis.Enabled() or Talent.Nemesis.Cooldown.Up() or Talent.Nemesis.Cooldown.Remains() > Target.TimeToDie() or Talent.Nemesis.Cooldown.Remains() > 60);
		-- actions+=/variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
		self.waiting_for_chaos_blades = not (not Talent.ChaosBlades.Enabled() or Talent.ChaosBlades.Cooldown.Up() or Talent.ChaosBlades.Cooldown.Remains() > Target.TimeToDie() or Talent.ChaosBlades.Cooldown.Remains() > 60);
		-- # "Getting ready to use meta" conditions, this is used in a few places.
		-- actions+=/variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
		self.pooling_for_meta = not Talent.Demonic.Enabled() and Spell.Metamorphosis.Cooldown.Remains() < 6 and Player.Fury.Deficit() > 30 and (not self.waiting_for_nemesis or Talent.Nemesis.Cooldown.Remains() < 10)	and (not self.waiting_for_chaos_blades or Talent.ChaosBlades.Cooldown.Remains() < 6);
		-- # Blade Dance conditions. Always if First Blood is talented or the T20 4pc set bonus, otherwise at 6+ targets with Chaos Cleave or 3+ targets without.
		-- actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
		self.blade_dance = Talent.FirstBlood.Enabled() or addonTable.Tier20_4PC	or Enemies.GetEnemies(8) >= 3 + (val(Talent.ChaosCleave.Enabled()) * 3);
		-- # Blade Dance pooling condition, so we don't spend too much fury on Chaos Strike when we need it soon.
		-- actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
		self.pooling_for_blade_dance = self.blade_dance and Player.Fury() < 75 - val(Talent.FirstBlood.Enabled()) * 20;

		-- There is no way to do raid_event.adds in game, so we are just going to skip this.
		-- # Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
		-- actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
	end

	return self;
end

-- Create a variable so we can call the functions to set rotation variables.
local Variables = Variables("Variables");

local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=duration
		ChaosBlades = function()
			return Player.Buff(Buff.Metamorphosis).Up()
				or Spell.Metamorphosis.Cooldown.Remains() > 60
				or Target.TimeToDie() <= Talent.ChaosBlades.BaseDuration();
		end,

		Metamorphosis = {
			-- actions.cooldown=metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
			Use = function()
				return not (Talent.Demonic.Enabled() or Variables.pooling_for_meta or Variables.waiting_for_nemesis or Variables.waiting_for_chaos_blades)
					or Target.TimeToDie() < 25;
			end,

			-- actions.cooldown+=/metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up
			Demonic = function()
				return Talent.Demonic.Enabled()
				   and Player.Buff(Buff.Metamorphosis).Up();
			end,
		},

		-- We can't do raid events so just skip that condition.
		-- actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
		Nemesis = function()
			return Player.Buff(Buff.ChaosBlades).Up()
				or Player.Buff(Buff.Metamorphosis).Up()
				or Spell.Metamorphosis.Cooldown.Remains() < 20
				or Target.TimeToDie() <= 60;
		end,

		-- actions.cooldown+=/potion,if=buff.metamorphosis.remains>25|target.time_to_die<30
		ProlongedPower = function()
			return Player.Buff(Buff.Metamorphosis).Remains() > 25
				or Target.TimeToDie() < 30;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function to set variables that change in combat.
	function self.Rotation(action)
		-- # Use Metamorphosis when we are done pooling Fury and when we are not waiting for other cooldowns to sync.
		action.EvaluateAction(Spell.Metamorphosis, self.Requirements.Metamorphosis.Use);
		action.EvaluateAction(Spell.Metamorphosis, self.Requirements.Metamorphosis.Demonic);

		-- # If adds are present, use Nemesis on the lowest HP add in order to get the Nemesis buff for AoE
		-- We can't do raid_events so we are just going to skip this line and do the not raid adds condition
		-- actions.cooldown+=/nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
		action.EvaluateAction(Talent.Nemesis, self.Requirements.Nemesis);
		action.EvaluateAction(Talent.ChaosBlades, self.Requirements.ChaosBlades);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
	end

	return self;
end

-- Create a variable so we can call the cooldowns rotation.
local Cooldowns = Cooldowns("Cooldowns");

local function Demonic(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.demonic+=/annihilation,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
		Annihilation = function()
			return (not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up() or Player.Fury.Deficit() < 30 + val(Player.Buff(Buff.Prepared).Up()) * 8 or Player.Buff(Buff.Metamorphosis).Remains() < 5)
			   and not Variables.pooling_for_blade_dance;
		end,

		-- actions.demonic+=/blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
		BladeDance = function()
			return Variables.blade_dance
			   and Spell.EyeBeam.Cooldown.Remains() > 5
			   and not Spell.Metamorphosis.Cooldown.Up();
		end,

		-- Pooling for chaos strike is not implimented because it is based solely on when adds spawn which we don't know
		-- actions.demonic+=/chaos_strike,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
		ChaosStrike = function()
			return (not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up() or Player.Fury.Deficit() < 30 + val(Player.Buff(Buff.Prepared).Up()) * 8)
			   and not Variables.pooling_for_meta
			   and not Variables.pooling_for_blade_dance;
		end,

		-- actions.demonic+=/death_sweep,if=variable.blade_dance
		DeathSweep = function()
			return Variables.blade_dance;
		end,

		-- actions.demonic+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>16)
		EyeBeam = function(numEnemies)
			return numEnemies > Core.DesiredTargets()
				or Player.Buff(Buff.Metamorphosis).Duration() <= 30
				or (addonTable.Tier21_4PC and Player.Buff(Buff.Metamorphosis).Remains() > 16);
		end,

		-- actions.demonic+=/felblade,if=fury.deficit>=30&(fury<40|buff.metamorphosis.down)
		Felblade = function()
			return Player.Fury.Deficit() >= 30
			   and (Player.Fury() < 40 or Player.Buff(Buff.Metamorphosis).Down());
		end,

		FelRush = {
			-- There is no way to do movement distance, so skip it.
			-- actions.demonic+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
			Use = function()
				return not Target.InRange(8)
				   and not Talent.Momentum.Enabled();
			end,

			-- # Fel Rush for Momentum.
			-- We can't do the raid events, so we will just skip those conditions.
			-- actions.demonic+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
			Momentum = function()
				return (Talent.Momentum.Enabled() or Talent.FelMastery.Enabled())
				   and (not Talent.Momentum.Enabled() or (Spell.FelRush.Charges() == 2 or Spell.VengefulRetreat.Cooldown.Remains() > 4) and Player.Buff(Buff.Momentum).Down())
				   and Spell.FelRush.Charges() == 2;
			end,

			-- Can't do time to raid movement compared to recharge, so lets just do it on specified charges
			-- actions.demonic+=/fel_rush,if=!talent.momentum.enabled&!cooldown.eye_beam.ready&(buff.metamorphosis.down|talent.demon_blades.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
			NoMomentum = function()
				return not Talent.Momentum.Enabled()
				   and (Player.Buff(Buff.Metamorphosis).Down() or Talent.DemonBlades.Enabled())
				   and Spell.FelRush.Charges() == 2;
			end,
		},

		-- Can't do raid events, so just skip those conditions
		-- actions.demonic+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up))
		FuryOfTheIllidari = function(numEnemies)
			return numEnemies > Core.DesiredTargets()
				or (not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up());
		end,

		ThrowGlaive = {
			-- actions.demonic+=/throw_glaive,if=buff.out_of_range.up|!talent.bloodlet.enabled
			Use = function()
				return not Target.InRange(8)
					or not Talent.Bloodlet.Enabled();
			end,

			Bloodlet = {
				-- Can't do time to raid adds compared to recharge, so lets just suggest on max charges
				-- actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
				Use = function()
					return Talent.Bloodlet.Enabled()
					   and (not Talent.MasterOfTheGlaive.Enabled() or not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up())
					   and Spell.ThrowGlaive.Charges() == Spell.ThrowGlaive.Charges.Max();
				end,

				-- Can't do raid events, so just skip those conditions
				-- actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
				AOE = function(numEnemies)
					return Talent.Bloodlet.Enabled()
					   and (not Talent.MasterOfTheGlaive.Enabled() or not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up())
					   and numEnemies >= 3;
				end,

				-- actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
				Charges = function()
					return Talent.Bloodlet.Enabled()
					   and (not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up())
					   and Spell.ThrowGlaive.Charges() == 2;
				end,
			},
		},

		-- # Vengeful Retreat backwards through the target to minimize downtime.
		-- actions.demonic+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
		VengefulRetreat = function()
			return (Talent.Prepared.Enabled() or Talent.Momentum.Enabled())
			   and Player.Buff(Buff.Prepared).Down()
			   and Player.Buff(Buff.Momentum).Down();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- There is no way to signal to pick up fragments or where to move to, so we are just going to skip this.
		-- actions.demonic=pick_up_fragment,if=fury.deficit>=35&(cooldown.eye_beam.remains>5|buff.metamorphosis.up)
		action.EvaluateAction(Spell.VengefulRetreat, self.Requirements.VengefulRetreat);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.Momentum);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Bloodlet.Charges);
		action.EvaluateAction(Spell.DeathSweep, self.Requirements.DeathSweep);
		-- actions.demonic+=/fel_eruption
		action.EvaluateAction(Talent.FelEruption, true);
		action.EvaluateAction(Artifact.FuryOfTheIllidari, self.Requirements.FuryOfTheIllidari);
		action.EvaluateAction(Spell.BladeDance, self.Requirements.BladeDance);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Bloodlet.AOE, Enemies.GetEnemies(Spell.ThrowGlaive));
		action.EvaluateAction(Talent.Felblade, self.Requirements.Felblade);
		action.EvaluateAction(Spell.EyeBeam, self.Requirements.EyeBeam, Enemies.GetEnemies(Spell.EyeBeam));
		action.EvaluateAction(Spell.Annihilation, self.Requirements.Annihilation);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Bloodlet.Use);
		action.EvaluateAction(Spell.ChaosStrike, self.Requirements.ChaosStrike);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.NoMomentum);
		-- actions.demonic+=/demons_bite
		action.EvaluateAction(Spell.DemonsBite, true);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Use);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.Use);
		-- We can't do movement.distance, so just skip this suggestion.
		-- actions.demonic+=/vengeful_retreat,if=movement.distance>15
	end

	-- actions+=/run_action_list,name=demonic,if=talent.demonic.enabled
	function self.Use()
		return Talent.Demonic.Enabled();
	end

	return self;
end

-- Create a variable so we can call the demonic rotation.
local Demonic = Demonic("Demonic");

local function Normal(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.normal+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
		Annihilation = function()
			return (Talent.DemonBlades.Enabled() or not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up() or Player.Fury.Deficit() < 30 + val(Player.Buff(Buff.Prepared).Up()) * 8 or Player.Buff(Buff.Metamorphosis).Remains() < 5)
			   and not Variables.pooling_for_blade_dance;
		end,

		-- actions.normal+=/blade_dance,if=variable.blade_dance
		BladeDance = function()
			return Variables.blade_dance;
		end,

		-- Pooling for chaos strike is not implimented because it is based solely on when adds spawn which we don't know
		-- actions.normal+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
		ChaosStrike = function()
			return (Talent.DemonBlades.Enabled() or not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up() or Player.Fury.Deficit() < 30 + val(Player.Buff(Buff.Prepared).Up()))
			   and not Variables.pooling_for_meta
			   and not Variables.pooling_for_blade_dance;
		end,

		-- actions.normal+=/death_sweep,if=variable.blade_dance
		DeathSweep = function()
			return Variables.blade_dance;
		end,

		-- We can't do raid events, so skip these.
		-- actions.normal+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|(talent.blind_fury.enabled&fury.deficit>=35)|set_bonus.tier21_2pc
		EyeBeam = function(numEnemies)
			return numEnemies > Core.DesiredTargets()
				or numEnemies >= 3
				or (Talent.BlindFury.Enabled() and Player.Fury.Deficit() >= 35)
				or addonTable.Tier21_2PC;
		end,

		-- # Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
		-- We can't do raid events, so skip these.
		-- actions.normal+=/fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
		FelBarrage = function(numEnemies)
			return (Player.Buff(Buff.Momentum).Up() or not Talent.Momentum.Enabled())
			   and (numEnemies > Core.DesiredTargets() or Talent.FelBarrage.Charges() == Talent.FelBarrage.Charges.Max());
		end,

		Felblade = {
			-- We can't do movement.distance, so skip this.
			-- actions.normal+=/felblade,if=movement.distance>15|buff.out_of_range.up
			Use = function()
				return not Target.InRange(8);
			end,

			-- actions.normal+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
			Fury = function()
				return Player.Fury() < 15
				   and (Spell.DeathSweep.Cooldown.Remains() < 2 * Player.GCD() or Spell.BladeDance.Cooldown.Remains() < 2 * Player.GCD());
			end,

			-- actions.normal+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
			Prepared = function()
				return Player.Fury.Deficit() >= 30 + val(Player.Buff(Buff.Prepared).Up()) * 8;
			end,
		},

		FelRush = {
			-- There is no way to do movement distance, so skip it.
			-- actions.normal+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
			Use = function()
				return not Target.InRange(8)
				   and not Talent.Momentum.Enabled();
			end,

			-- actions.normal+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled&!buff.metamorphosis.up
			Charges = function()
				return Spell.FelRush.Charges() == 2
				   and not Talent.Momentum.Enabled()
				   and not Talent.FelMastery.Enabled()
				   and not Player.Buff(Buff.Metamorphosis).Up();
			end,

			-- # Fel Rush for Momentum and for fury from Fel Mastery.
			-- We can't do the raid events, so we will just skip those conditions.
			-- actions.normal+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
			Momentum = function()
				return (Talent.Momentum.Enabled() or Talent.FelMastery.Enabled())
				   and (not Talent.Momentum.Enabled() or (Spell.FelRush.Charges() == 2 or Spell.VengefulRetreat.Cooldown.Remains() > 4) and Player.Buff(Buff.Momentum).Down())
				   and (not Talent.FelMastery.Enabled() or Player.Fury.Deficit() >= 25)
				   and Spell.FelRush.Charges() == 2;
			end,

			-- Can't do time to raid movement compared to recharge, so lets just suggest on max charges
			-- actions.normal+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
			NoMomentum = function()
				return not Talent.Momentum.Enabled
				   and Spell.FelRush.Charges() == Spell.FelRush.Charges.Max()
				   and (Talent.DemonBlades.Enabled() or Player.Buff(Buff.Metamorphosis).Down());
			end,
		},

		-- Can't do raid events, so just skip those conditions
		-- actions.normal+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
		FuryOfTheIllidari = function(numEnemies)
			return numEnemies > Core.DesiredTargets()
				or ((not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up()) and (not Talent.ChaosBlades.Enabled() or Player.Buff(Buff.ChaosBlades).Up() or Talent.ChaosBlades.Cooldown.Remains() > 30 or Target.TimeToDie() < Talent.ChaosBlades.Cooldown.Remains()));
		end,

		ThrowGlaive = {
			-- actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled
			Use = function()
				return not Talent.Bloodlet.Enabled();
			end,

			Bloodlet = {
				-- Can't do time to raid adds compared to recharge, so lets just suggest on max charges
				-- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
				Use = function()
					return Talent.Bloodlet.Enabled()
					   and (not Talent.MasterOfTheGlaive.Enabled() or not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up())
					   and Spell.ThrowGlaive.Charges() == Spell.ThrowGlaive.Charges.Max();
				end,

				-- Can't do raid events, so just skip those conditions
				-- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
				AOE = function(numEnemies)
					return Talent.Bloodlet.Enabled()
					   and (not Talent.MasterOfTheGlaive.Enabled() or not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up())
					   and numEnemies >= 3;
				end,

				-- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
				Charges = function()
					return Talent.Bloodlet.Enabled()
					   and (not Talent.Momentum.Enabled() or Player.Buff(Buff.Momentum).Up())
					   and Spell.ThrowGlaive.Charges() == 2;
				end,
			},

			-- actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
			NoBloodlet = function(numEnemies)
				return not Talent.Bloodlet.Enabled()
				   and Player.Buff(Buff.Metamorphosis).Down()
				   and numEnemies >= 3;
			end,

			-- actions.normal+=/throw_glaive,if=buff.out_of_range.up
			Range = function()
				return not Target.InRange(8);
			end,
		},

		-- # Vengeful Retreat backwards through the target to minimize downtime.
		-- actions.normal+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
		VengefulRetreat = function()
			return (Talent.Prepared.Enabled() or Talent.Momentum.Enabled())
			   and Player.Buff(Buff.Prepared).Down()
			   and Player.Buff(Buff.Momentum).Down();
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		-- There is no way to signal to pick up fragments or where to move to, so we are just going to skip this.
		-- actions.normal=pick_up_fragment,if=talent.demonic_appetite.enabled&fury.deficit>=35
		action.EvaluateAction(Spell.VengefulRetreat, self.Requirements.VengefulRetreat);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.Momentum);
		action.EvaluateAction(Talent.FelBarrage, self.Requirements.FelBarrage);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Bloodlet.Charges);
		action.EvaluateAction(Talent.Felblade, self.Requirements.Felblade.Fury);
		action.EvaluateAction(Spell.DeathSweep, self.Requirements.DeathSweep);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.Charges);
		-- actions.normal+=/fel_eruption
		action.EvaluateAction(Talent.FelEruption, true);
		action.EvaluateAction(Artifact.FuryOfTheIllidari, self.Requirements.FuryOfTheIllidari);
		action.EvaluateAction(Spell.BladeDance, self.Requirements.BladeDance);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Bloodlet.AOE, Enemies.GetEnemies(Spell.ThrowGlaive));
		action.EvaluateAction(Talent.Felblade, self.Requirements.Felblade.Prepared);
		action.EvaluateAction(Spell.EyeBeam, self.Requirements.EyeBeam, Enemies.GetEnemies(Spell.EyeBeam));
		action.EvaluateAction(Spell.Annihilation, self.Requirements.Annihilation);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Bloodlet.Use);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.NoBloodlet, Enemies.GetEnemies(Spell.ThrowGlaive));
		action.EvaluateAction(Spell.ChaosStrike, self.Requirements.ChaosStrike);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.NoMomentum);
		-- actions.normal+=/demons_bite
		action.EvaluateAction(Spell.DemonsBite, true);
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Range);
		action.EvaluateAction(Talent.Felblade, self.Requirements.Felblade.Use);
		action.EvaluateAction(Spell.FelRush, self.Requirements.FelRush.Use);
		-- Can't do movement.distance so just skip this.
		-- actions.normal+=/vengeful_retreat,if=movement.distance>15
		action.EvaluateAction(Spell.ThrowGlaive, self.Requirements.ThrowGlaive.Use);
	end

	return self;
end

-- Create a variable so we can call the normal rotation.
local Normal = Normal("Normal");

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "LunaEclipse",
		GuideAuthor = "Kib and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Raiding (Chaos Blades)"] = "2220311",
		["Dungeon / Mythic+ (Demonic)"] = "3310133",
		["Solo"] = "2320213",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		Blur = function()
			return Player.DamagePredicted(5) >= 25;
		end,

		ChaosNova = function()
			return Target.InRange(8);
		end,

		Darkness = function()
			return Player.DamagePredicted(4) >= 30;
		end,

		-- actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&talent.demonic.enabled)
		Metamorphosis = function()
			return not (Talent.DemonReborn.Enabled() and Talent.Demonic.Enabled());
		end,

		Netherwalk = function()
			return Player.DamagePredicted(3) >= 50;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		-- Spells
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(202719),
			Shadowmeld = Objects.newSpell(58984),
		};

		Artifact = {
			-- Abilities
			FuryOfTheIllidari = Objects.newSpell(201467);
		};

		Spell = {
			-- Abilities
			Annihilation = Objects.newSpell(201427),
			BladeDance = Objects.newSpell(188499),
			ChaosStrike = Objects.newSpell(162794),
			DeathSweep = Objects.newSpell(210152),  -- Uses the same checkbox as this is a stance replacement not a talent replacement.
			DemonsBite = Objects.newSpell(162243),
			EyeBeam = Objects.newSpell(198013),
			Metamorphosis = Objects.newSpell(191427),
			ThrowGlaive = Objects.newSpell(185123),
			-- Crowd Control
			ChaosNova = Objects.newSpell(179057),
			ConsumeMagic = Objects.newSpell(183752),
			Imprison = Objects.newSpell(217832),
			-- Defensive
			Blur = Objects.newSpell(198589),
			Darkness = Objects.newSpell(196718),
			-- Utility
			FelRush = Objects.newSpell(195072),
			SpectralSight = Objects.newSpell(188501),
			VengefulRetreat = Objects.newSpell(198793),
		};

		Talent = {
			-- Active Talents
			ChaosBlades = Objects.newSpell(247938),
			FelBarrage = Objects.newSpell(211053),
			Felblade = Objects.newSpell(232893),
			FelEruption = Objects.newSpell(211881),
			Nemesis = Objects.newSpell(206491),
			Netherwalk = Objects.newSpell(196555),
			-- Passive Talents
			BlindFury = Objects.newSpell(203550),
			Bloodlet = Objects.newSpell(206473),
			ChaosCleave = Objects.newSpell(206475),
			DemonBlades = Objects.newSpell(203555),
			Demonic = Objects.newSpell(213410),
			DemonicAppetite = Objects.newSpell(206478),
			DemonReborn = Objects.newSpell(193897),
			DesperateInstincts = Objects.newSpell(205411),
			FelMastery = Objects.newSpell(192939),
			FirstBlood = Objects.newSpell(206416),
			MasterOfTheGlaive = Objects.newSpell(203556),
			Momentum = Objects.newSpell(206476),
			Prepared = Objects.newSpell(203551),
			SoulRending = Objects.newSpell(204909),
			UnleashedPower = Objects.newSpell(206477),
		};

		Buff = {
			-- Buffs
			BladeDance = Spell.BladeDance,
			Blur = Objects.newSpell(212800),
			ChaosBlades = Talent.ChaosBlades,
			FelBarrage = Talent.FelBarrage,
			Metamorphosis = Objects.newSpell(162264),
			Momentum = Talent.Momentum,
			Netherwalk = Talent.Netherwalk,
			Prepared = Talent.Prepared,
			SpectralSight = Spell.SpectralSight,
		};

		Debuff = {
			-- Debuffs
			ChaosNova = Spell.ChaosNova,
			FelEruption = Talent.FelEruption,
			Imprison = Spell.Imprison,
			Nemesis = Talent.Nemesis,
		};

		Consumable = {
			-- Potions
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Shadowmeld);
		config.AOEOptions(options, Spell.BladeDance, Spell.ChaosNova, Spell.EyeBeam, Talent.FelBarrage, Artifact.FuryOfTheIllidari);
		config.CooldownOptions(options, Talent.ChaosBlades, Talent.Felblade, Talent.FelEruption, Spell.FelRush, Spell.Metamorphosis, Talent.Nemesis, Spell.VengefulRetreat);
		config.DefensiveOptions(options, Spell.Blur, Spell.Darkness, Talent.Netherwalk);
		config.UtilityOptions(options, Spell.Imprison, Spell.SpectralSight);
	end

	-- Function for destroying action objects such as spells, buffs, debuffs and items, called when the rotation is no longer the active rotation.
	function self.Disable()
		Racial = nil;
		Artifact = nil;
		Spell = nil;
		Talent = nil;
		Buff = nil;
		Debuff = nil;
		Consumable = nil;
	end

	-- Function for checking the rotation that displays on the Defensives icon.
	function self.Defensive(action)
		-- The abilities here should be listed from highest damage required to suggest to lowest,
		-- Specific damage types before all damage types.

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Talent.Netherwalk, self.Requirements.Netherwalk);
		action.EvaluateDefensiveAction(Spell.Darkness, self.Requirements.Darkness);
		action.EvaluateDefensiveAction(Spell.Blur, self.Requirements.Blur);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.ConsumeMagic, true);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Spell.ChaosNova, self.Requirements.ChaosNova);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
		action.EvaluateAction(Spell.Metamorphosis, self.Requirements.Metamorphosis);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.CallActionList(Variables);
		action.CallActionList(Cooldowns);
		action.RunActionList(Demonic);
		-- actions+=/run_action_list,name=normal
		action.RunActionList(Normal);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Havoc Demon Hunter", addonTable.Enum.SpecID.DEMONHUNTER_HAVOC);