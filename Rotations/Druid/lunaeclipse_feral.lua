local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

local Core = addon.Core.General;
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Table for storing variables used across sub-rotations.
local Variables = {};

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable;

-- Rotation Variables
local nameAPL = "lunaeclipse_druid_feral";

local function getThrashDistance()
	return Legendary.LuffaWrappings.Equipped() and 17
		or 8;
end

-- Cooldowns Rotation
local function Cooldowns(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.cooldowns+=/ashamanes_frenzy,if=combo_points>=2&(!talent.bloodtalons.enabled|buff.bloodtalons.up)
		AshamanesFrenzy = function()
			return Player.ComboPoints() >= 2
			   and (not Talent.Bloodtalons.Enabled() or Player.Buff(Buff.Bloodtalons).Up());
		end,

		-- actions.cooldowns+=/berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
		Berserk = function()
			return Player.Energy() >= 30
			   and (Spell.TigersFury.Cooldown.Remains() > 5 or Player.Buff(Buff.TigersFury).Up());
		end,

		-- actions.cooldowns+=/elunes_guidance,if=combo_points=0&energy>=50
		ElunesGuidance = function()
			return Player.ComboPoints() == 0
			   and Player.Energy() >= 50;
		end,

		-- actions.cooldowns+=/incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
		Incarnation = function()
			return Player.Energy() >= 30
			   and (Spell.TigersFury.Cooldown.Remains() > 15 or Player.Buff(Buff.TigersFury).Up());
		end,

		-- actions.cooldowns+=/potion,name=prolonged_power,if=target.time_to_die<65|(time_to_die<180&(buff.berserk.up|buff.incarnation.up))
		ProlongedPower = function()
			return Target.TimeToDie() < 65
				or (Target.TimeToDie() < 180 and (Player.Buff(Buff.Berserk).Up() or Player.Buff(Buff.Incarnation).Up()));
		end,

		-- actions.cooldowns+=/prowl,if=buff.incarnation.remains<0.5&buff.jungle_stalker.up
		Prowl = function()
			return Player.Buff(Buff.Incarnation).Remains() < 0.5
			   and Player.Buff(Buff.JungleStalker).Up();
		end,

		-- actions.cooldowns+=/shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
		Shadowmeld = function()
			return Player.ComboPoints() < 5
			   and Player.Energy() >= Spell.Rake.Cost()
			   and Target.Debuff(Debuff.Rake).PersistentMultiplier() < 2.1
			   and Player.Buff(Buff.TigersFury).Up()
			   and (Player.Buff(Buff.Bloodtalons).Up() or not Talent.Bloodtalons.Enabled())
			   and (not Talent.Incarnation.Enabled() or Talent.Incarnation.Cooldown.Remains() > 18)
			   and not Player.Buff(Buff.Incarnation).Up();
		end,

		-- actions.cooldowns+=/tigers_fury,if=energy.deficit>=60
		TigersFury = function()
			return Player.Energy.Deficit() >= 60;
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Prowl, self.Requirements.Prowl);
		action.EvaluateAction(Spell.Berserk, self.Requirements.Berserk);
		action.EvaluateAction(Spell.TigersFury, self.Requirements.TigersFury);
		-- actions.cooldowns+=/berserking
		action.EvaluateAction(Racial.Berserking, true);
		action.EvaluateAction(Talent.ElunesGuidance, self.Requirements.ElunesGuidance);
		action.EvaluateAction(Talent.Incarnation, self.Requirements.Incarnation);
		action.EvaluateAction(Consumable.ProlongedPower, self.Requirements.ProlongedPower);
		action.EvaluateAction(Artifact.AshamanesFrenzy, self.Requirements.AshamanesFrenzy);
		action.EvaluateAction(Racial.Shadowmeld, self.Requirements.Shadowmeld);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Cooldowns = Cooldowns("Cooldowns");

-- SingleTargetFinishers Rotation
local function Finishers(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.st_finishers+=/ferocious_bite,max_energy=1
		FerociousBite = function()
			return Player.Energy() >= 50;
		end,

		-- actions.st_finishers+=/maim,if=buff.fiery_red_maimers.up
		Maim = function()
			return Player.Buff(Buff.FieryRedMaimers).Up();
		end,

		-- actions.st_finishers+=/rip,target_if=!ticking|(remains<=duration*0.3)&(target.health.pct>25&!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
		Rip = function(numEnemies, Target)
			return not Target.Debuff(Debuff.Rip).Up()
				or Target.Debuff(Debuff.Rip).Refreshable()
			   and (Target.Health.Percent() > 25 and not Talent.Sabertooth.Enabled())
				or (Target.Debuff(Debuff.Rip).Remains() < Target.Debuff(Debuff.Rip).Duration() * 0.8 and Player.PersistentMultiplier(Spell.Rip) > Target.Debuff(Debuff.Rip).PersistentMultiplier())
			   and Target.TimeToDie() > 8;
		end,

		SavageRoar = {
			-- actions.st_finishers+=/savage_roar,if=buff.savage_roar.down
			Use = function()
				return Player.Buff(Buff.SavageRoar).Down();
			end,

			-- actions.st_finishers+=/savage_roar,if=buff.savage_roar.remains<12
			Refresh = function()
				return Player.Buff(Buff.SavageRoar).Remains() < 12;
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluatePoolAction(Talent.SavageRoar, self.Requirements.SavageRoar.Use);
		action.EvaluatePoolAction(Spell.Rip, self.Requirements.Rip);
		action.EvaluatePoolAction(Talent.SavageRoar, self.Requirements.SavageRoar.Refresh);
		action.EvaluateAction(Spell.Maim, self.Requirements.Maim);
		action.EvaluateAction(Spell.FerociousBite, self.Requirements.FerociousBite)
	end

	-- actions.single_target+=/run_action_list,name=st_finishers,if=combo_points>4
	function self.Use()
		return Player.ComboPoints() > 4;
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Finishers = Finishers("Finishers");

-- Generators Rotation
local function Generators(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		BrutalSlash = {
			-- We can't do raid events in game, so just skip that part, and only use at max charges.
			-- actions.st_generators+=/brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))
			Use = function()
				return Player.Buff(Buff.TigersFury).Up()
				   and Talent.BrutalSlash.Charges() == Talent.BrutalSlash.Charges.Max();
			end,

			-- actions.st_generators+=/brutal_slash,if=spell_targets.brutal_slash>desired_targets
			Adds = function(numEnemies)
				return numEnemies > Core.DesiredTargets();
			end,
		},

		-- Because refreshable returns true if debuff is missing we need to check for Lunar Inspiration talent.
		-- actions.st_generators+=/moonfire_cat,target_if=refreshable
		Moonfire = function()
			return Talent.LunarInspiration.Enabled()
			   and Target.Debuff(Debuff.Moonfire).Refreshable();
		end,

		Rake = {
			-- actions.st_generators+=/rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
			Use = function()
				return not Target.Debuff(Debuff.Rake).Up()
					or (not Talent.Bloodtalons.Enabled() and Target.Debuff(Debuff.Rake).Refreshable())
				   and Target.TimeToDie() > 4;
			end,

			-- actions.st_generators+=/rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
			Bloodtalons = function()
				return Talent.Bloodtalons.Enabled()
				   and Player.Buff(Buff.Bloodtalons).Up()
				   and (Target.Debuff(Debuff.Rake).Remains() <= 7 and Player.PersistentMultiplier(Spell.Rake) > Target.Debuff(Debuff.Rake).PersistentMultiplier() * 0.85)
				   and Target.TimeToDie() > 4;
			end,
		},

		Regrowth = {
			-- actions.st_generators+=/regrowth,if=equipped.ailuro_pouncers&talent.bloodtalons.enabled&(buff.predatory_swiftness.stack>2|(buff.predatory_swiftness.stack>1&dot.rake.remains<3))&buff.bloodtalons.down
			Use = function()
				return Legendary.AiluroPouncers.Equipped()
				   and Talent.Bloodtalons.Enabled()
				   and (Player.Buff(Buff.PredatorySwiftness).Stack() > 2 or (Player.Buff(Buff.PredatorySwiftness).Stack() > 1 and Target.Debuff(Debuff.Rake).Remains() < 3))
				   and Player.Buff(Buff.Bloodtalons).Down();
			end,

			-- actions.st_generators=regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points>=2&cooldown.ashamanes_frenzy.remains<gcd
			AshamanesFrenzy = function()
				return Talent.Bloodtalons.Enabled()
				   and Player.Buff(Buff.PredatorySwiftness).Up()
				   and Player.Buff(Buff.Bloodtalons).Down()
				   and Player.ComboPoints() >= 2
				   and Artifact.AshamanesFrenzy.Cooldown.Remains() < Player.GCD();
			end,

			-- actions.st_generators+=/regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
			Rake = function()
				return Talent.Bloodtalons.Enabled()
				   and Player.Buff(Buff.PredatorySwiftness).Up()
				   and Player.Buff(Buff.Bloodtalons).Down()
				   and Player.ComboPoints() == 4
				   and Target.Debuff(Debuff.Rake).Remains() < 4;
			end,
		},

		-- actions.st_generators+=/shred,if=dot.rake.remains>(action.shred.cost+action.rake.cost-energy)%energy.regen|buff.clearcasting.react
		Shred = function()
			return Target.Debuff(Debuff.Rake).Remains() > (Spell.Shred.Cost() + Spell.Rake.Cost() - Player.Energy()) / Player.Energy.Regen()
				or Player.Buff(Buff.Clearcasting).React();
		end,

		-- actions.st_generators+=/swipe_cat,if=spell_targets.swipe_cat>1
		Swipe = function(numEnemies)
			return numEnemies > 1;
		end,

		Thrash = {
			-- actions.st_generators+=/thrash_cat,if=refreshable&(variable.use_thrash=2|spell_targets.thrash_cat>1)
			Use = function(numEnemies)
				return Target.Debuff(Debuff.Thrash).Refreshable()
				   and (Variables.use_thrash == 2 or numEnemies > 1);
			end,

			-- actions.st_generators+=/thrash_cat,if=refreshable&(spell_targets.thrash_cat>2)
			AOE = function(numEnemies)
				return Target.Debuff(Debuff.Thrash).Refreshable()
				   and numEnemies > 2;
			end,

			-- actions.st_generators+=/thrash_cat,if=spell_targets.thrash_cat>3&equipped.luffa_wrappings&talent.brutal_slash.enabled
			LuffaWrappings = function(numEnemies)
				return numEnemies > 3
				   and Legendary.LuffaWrappings.Equipped()
				   and Talent.BrutalSlash.Enabled();
			end,

			-- actions.st_generators+=/thrash_cat,if=refreshable&variable.use_thrash=1&buff.clearcasting.react
			Clearcasting = function()
				return Target.Debuff(Debuff.Thrash).Refreshable()
				   and Variables.use_thrash == 1
				   and Player.Buff(Buff.Clearcasting).React();
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.AshamanesFrenzy);
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.Rake);
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.Use);
		action.EvaluateAction(Talent.BrutalSlash, self.Requirements.BrutalSlash.Adds, Enemies.GetEnemies(8));
		action.EvaluatePoolAction(Spell.Thrash, self.Requirements.Thrash.AOE, Enemies.GetEnemies(getThrashDistance()));
		action.EvaluatePoolAction(Spell.Thrash, self.Requirements.Thrash.LuffaWrappings, Enemies.GetEnemies(getThrashDistance()));
		action.EvaluatePoolAction(Spell.Rake, self.Requirements.Rake.Use);
		action.EvaluatePoolAction(Spell.Rake, self.Requirements.Rake.Bloodtalons);
		action.EvaluateAction(Talent.BrutalSlash, self.Requirements.BrutalSlash.Use);
		action.EvaluateAction(Spell.Moonfire, self.Requirements.Moonfire)
		action.EvaluatePoolAction(Spell.Thrash, self.Requirements.Thrash.Use, Enemies.GetEnemies(getThrashDistance()));
		action.EvaluateAction(Spell.Thrash, self.Requirements.Thrash.Clearcasting);
		action.EvaluatePoolAction(Spell.Swipe, self.Requirements.Swipe, Enemies.GetEnemies(8));
		action.EvaluateAction(Spell.Shred, self.Requirements.Shred);
	end

	return self;
end

-- Create a variable so we can call the rotations functions.
local Generators = Generators("Generators");

-- Standard Rotation
local function Standard(rotationName)
	-- Inherits Rotation Class so get the base class.
	local self = addonTable.rotationsClass(nameAPL, rotationName);

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions.single_target=cat_form,if=!buff.cat_form.up
		CatForm = function()
			return not Player.Buff(Buff.CatForm).Up();
		end,

		FerociousBite = {
			-- actions.single_target+=/ferocious_bite,if=buff.apex_predator.up&((combo_points>4&(buff.incarnation.up|talent.moment_of_clarity.enabled))|(talent.bloodtalons.enabled&buff.bloodtalons.up&combo_points>3))
			ApexPredator = function()
				return Player.Buff(Buff.ApexPredator).Up()
				   and ((Player.ComboPoints() > 4 and (Player.Buff(Buff.Incarnation).Up() or Talent.MomentOfClarity.Enabled())) or (Talent.Bloodtalons.Enabled() and Player.Buff(Buff.Bloodtalons).Up() and Player.ComboPoints() > 3));
			end,

			-- actions.single_target+=/ferocious_bite,target_if=dot.rip.ticking&dot.rip.remains<3&target.time_to_die>10&(target.health.pct<25|talent.sabertooth.enabled)
			Use = function()
				return Target.Debuff(Debuff.Rip).Up()
				   and Target.Debuff(Debuff.Rip).Remains() < 3
				   and Target.TimeToDie() > 10
				   and (Target.Health.Percent() < 25 or Talent.Sabertooth.Enabled());
			end,
		},

		-- actions.single_target+=/rake,if=buff.prowl.up|buff.shadowmeld.up
		Rake = function()
			return Player.Buff(Buff.Prowl).Up()
				or Player.Buff(Buff.Shadowmeld).Up();
		end,

		Regrowth = {
			-- actions.single_target+=/regrowth,if=combo_points=5&buff.predatory_swiftness.up&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8)
			Use = function()
				return Player.ComboPoints() == 5
					and Player.Buff(Buff.PredatorySwiftness).Up()
					and Talent.Bloodtalons.Enabled()
					and Player.Buff(Buff.Bloodtalons).Down()
					and (not Player.Buff(Buff.Incarnation).Up() or Target.Debuff(Debuff.Rip).Remains() < 8);
			end,

			-- actions.single_target+=/regrowth,if=combo_points>3&talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.apex_predator.up&buff.incarnation.down
			ApexPredator = function()
				return Player.ComboPoints() > 3
				   and Talent.Bloodtalons.Enabled()
				   and Player.Buff(Buff.PredatorySwiftness).Up()
				   and Player.Buff(Buff.ApexPredator).Up()
				   and Player.Buff(Buff.Incarnation).Down();
			end,
		},
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Rotation(action)
		action.EvaluateAction(Spell.CatForm, self.Requirements.CatForm);
		action.EvaluateAction(Spell.Rake, self.Requirements.Rake);

		-- actions.single_target+=/call_action_list,name=cooldowns
		action.CallActionList(Cooldowns);

		action.EvaluateAction(Spell.Regrowth, self.Requirements.FerociousBite.Use);
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.Use);
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.ApexPredator);
		action.EvaluateAction(Spell.Regrowth, self.Requirements.FerociousBite.ApexPredator);

		action.RunActionList(Finishers);
		-- actions.single_target+=/run_action_list,name=st_generators
		action.RunActionList(Generators);
	end

	-- actions=run_action_list,name=single_target,if=dot.rip.ticking|time>15
	function self.Use()
		return Target.Debuff(Debuff.Rip).Up()
			or Core.CombatTime() > 15;
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
		GuideAuthor = "Xanzara and SimCraft",
		GuideLink = "https://www.icy-veins.com/wow/feral-druid-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Savage Roar"] = "2000232",
		["Brutal Slash"] = "2000221",
		["Solo / World Quests"] = "1001321",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		-- actions+=/moonfire_cat,if=talent.lunar_inspiration.enabled&!ticking
		Moonfire = function()
			return Talent.LunarInspiration.Enabled()
			   and not Target.Debuff(Debuff.Moonfire).Up();
		end,

		-- actions+=/rake,if=!ticking|buff.prowl.up
		Rake = function()
			return not Target.Debuff(Debuff.Rake).Up()
				or Player.Buff(Buff.Prowl).Up();
		end,

		Regrowth = {
			-- actions+=/regrowth,if=(talent.sabertooth.enabled|buff.predatory_swiftness.up)&talent.bloodtalons.enabled&buff.bloodtalons.down&combo_points=5
			Use = function()
				return (Talent.Sabertooth.Enabled() or Player.Buff(Buff.PredatorySwiftness).Up())
				   and Talent.Bloodtalons.Enabled()
				   and Player.Buff(Buff.Bloodtalons).Down()
				   and Player.ComboPoints() == 5;
			end,

			-- actions.precombat+=/regrowth,if=talent.bloodtalons.enabled
			Precombat = function()
				return Talent.Bloodtalons.Enabled();
			end,
		},

		Renewal = function()
			return Player.DamagePredicted(3) >= 15
				and Player.Health.Percent() < 70;
		end,

		-- actions+=/rip,if=combo_points=5
		Rip = function()
			return Player.ComboPoints() == 5;
		end,

		-- actions+=/savage_roar,if=!buff.savage_roar.up
		SavageRoar = function()
			return not Player.Buff(Buff.SavageRoar).Up();
		end,

		SurvivalInstincts = function()
			return Player.DamagePredicted(3) >= 25;
		end,

		-- actions+=/thrash_cat,if=!ticking&variable.use_thrash>0
		Thrash = function()
			return not Target.Debuff(Debuff.Thrash).Up()
			   and Variables.use_thrash > 0;
		end,

		Typhoon = function()
			return Target.InRange(15);
		end,

		WarStomp = function()
			return Target.InRange(5);
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	-- Function for setting up action objects such as spells, buffs, debuffs and items, called when the rotation becomes the active rotation.
	function self.Enable()
		Racial = {
			-- Abilities
			Berserking = Objects.newSpell(26297),
			Shadowmeld = Objects.newSpell(58984),
			WarStomp = Objects.newSpell(20549),
		};

		Artifact = {
			-- Ability
			AshamanesFrenzy = Objects.newSpell(210722),
		};

		Spell = {
			-- Abilities
			Berserk = Objects.newSpell(106951),
			FerociousBite = Objects.newSpell(22568),
			Maim = Objects.newSpell(22570),
			Moonfire = Objects.newSpell(155625),
			Rake = Objects.newSpell(1822),
			Rip = Objects.newSpell(1079),
			Shred = Objects.newSpell(5221),
			Swipe = Objects.newSpell(213764),
			Thrash = Objects.newSpell(106832),
			TigersFury = Objects.newSpell(5217),
			-- Crowd Control
			EntanglingRoots = Objects.newSpell(339),
			SkullBash = Objects.newSpell(106839),
			-- Defensive
			SurvivalInstincts = Objects.newSpell(61336),
			-- Utility
			CatForm = Objects.newSpell(228545),
			Dash = Objects.newSpell(1850),
			Prowl = Objects.newSpell(5215),
			Regrowth = Objects.newSpell(8936),
			Rebirth = Objects.newSpell(20484),
			Revive = Objects.newSpell(50769),
			StampedingRoar = Objects.newSpell(106898),
		};

		Talent = {
			-- Active Talents
			BrutalSlash = Objects.newSpell(202028),
			DisplacerBeast = Objects.newSpell(102280),
			ElunesGuidance = Objects.newSpell(202060),
			Incarnation = Objects.newSpell(102543),
			MassEntanglement = Objects.newSpell(102359),
			MightyBash = Objects.newSpell(5211),
			Renewal = Objects.newSpell(108238),
			SavageRoar = Objects.newSpell(52610),
			Typhoon = Objects.newSpell(132469),
			WildCharge = Objects.newSpell(102401),
			-- Passive Talents
			BalanceAffinity = Objects.newSpell(197488),
			BloodScent = Objects.newSpell(202022),
			Bloodtalons = Objects.newSpell(155672),
			GuardianAffinity = Objects.newSpell(217615),
			JaggedWounds = Objects.newSpell(202032),
			LunarInspiration = Objects.newSpell(155580),
			MomentOfClarity = Objects.newSpell(236068),
			Predator = Objects.newSpell(202021),
			RestorationAffinity = Objects.newSpell(197492),
			Sabertooth = Objects.newSpell(202031),
			SoulOfTheForest = Objects.newSpell(158476),
			-- Honor Talents
			EnragedMaim = Objects.newSpell(236026),
			RipAndTear = Objects.newSpell(203242),
			Thorns = Objects.newSpell(236696),
		};

		Buff = {
			-- Buffs
			Berserk = Spell.Berserk,
			Bloodtalons = Objects.newSpell(145152),
			CatForm = Spell.CatForm,
			Clearcasting = Objects.newSpell(16870),
			Dash = Spell.Dash,
			DisplacerBeast = Talent.DisplacerBeast,
			ElunesGuidance = Talent.ElunesGuidance,
			Incarnation = Talent.Incarnation,
			JungleStalker = Objects.newSpell(252071),
			PredatorySwiftness = Objects.newSpell(69369),
			Prowl = Spell.Prowl,
			Regrowth = Spell.Regrowth,
			SavageRoar = Talent.SavageRoar,
			Shadowmeld = Racial.Shadowmeld,
			StampedingRoar = Spell.StampedingRoar,
			SurvivalInstincts = Spell.SurvivalInstincts,
			TigersFury = Spell.TigersFury,
			-- Legendary Buffs
			ApexPredator = Objects.newSpell(252752),
			FieryRedMaimers = Objects.newSpell(236757),
		};

		Debuff = {
			-- Debuffs
			InfectedWounds = Objects.newSpell(58180),
			Maim = Spell.Maim,
			MassEntanglement = Talent.MassEntanglement,
			Moonfire = Spell.Moonfire,
			Rake = Objects.newSpell(155722),
			Rip = Spell.Rip,
			Thrash = Spell.Thrash,
		};

		Legendary = {
			-- Legendaries
			AiluroPouncers = Objects.newItem(137024),
			LuffaWrappings = Objects.newItem(137056),
		};

		Item = {};

		Consumable = {
			-- Potions
			OldWar = Objects.newItem(127844),
			ProlongedPower = Objects.newItem(142117),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Legendary, Item, Consumable);
	end

	-- Function for setting up the configuration screen, called when rotation becomes the active rotation.
	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.Berserking, Racial.Shadowmeld);
		config.AOEOptions(options, Talent.BrutalSlash, Spell.Swipe, Spell.Thrash);
		config.BuffOptions(options, Spell.CatForm, Spell.Prowl, Talent.Thorns);
		config.CooldownOptions(options, Artifact.AshamanesFrenzy, Spell.Berserk, Talent.ElunesGuidance, Talent.EnragedMaim, Talent.Incarnation, Spell.Maim, Spell.Regrowth,
									 Talent.RipAndTear, Talent.SavageRoar, Spell.TigersFury);
		config.DefensiveOptions(options, Spell.SurvivalInstincts, Talent.Renewal);
		config.UtilityOptions(options, Spell.EntanglingRoots, Spell.Dash, Spell.Rebirth, Spell.Revive, Spell.StampedingRoar, Talent.DisplacerBeast);
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

		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.SurvivalInstincts, self.Requirements.SurvivalInstincts);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Talent.Renewal, self.Requirements.Renewal);
	end

	-- Function for displaying interrupts when target is casting an interruptible spell.
	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.SkullBash, true);
		action.EvaluateInterruptAction(Talent.Typhoon, self.Requirements.Typhoon);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Talent.MightyBash, true);
			action.EvaluateInterruptAction(Spell.Maim, true);
			action.EvaluateInterruptAction(Racial.WarStomp, self.Requirements.WarStomp);
		end
	end

	-- Function for displaying opening rotation.
	function self.Opener(action)
	end

	-- Function for setting any pre-combat variables, is always called even if you don't have a target.
	function self.PrecombatVariables()
		-- actions.precombat+=/variable,name=use_thrash,value=0
		Variables.use_thrash = 0;
		-- actions.precombat+=/variable,name=use_thrash,value=1,if=equipped.luffa_wrappings
		if Legendary.LuffaWrappings.Equipped() then
			Variables.use_thrash = 1;
		end
	end

	-- Function for displaying any actions before combat starts.
	function self.Precombat(action)
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.Precombat);
		-- actions.precombat+=/cat_form
		action.EvaluateAction(Spell.CatForm, true);
		-- actions.precombat+=/prowl
		action.EvaluateAction(Spell.Prowl, true);
		-- actions.precombat+=/potion
		action.EvaluateAction(Consumable.ProlongedPower, true);
	end

	-- Function for checking the rotation that displays on the Single Target, AOE, Off GCD and CD icons.
	function self.Combat(action)
		action.RunActionList(Standard);

		action.EvaluateAction(Spell.Rake, self.Requirements.Rake);
		action.EvaluateAction(Spell.Moonfire, self.Requirements.Moonfire);
		action.EvaluateAction(Talent.SavageRoar, self.Requirements.SavageRoar);
		-- actions+=/berserk
		action.EvaluateAction(Spell.Berserk, true);
		-- actions+=/incarnation
		action.EvaluateAction(Talent.Incarnation, true);
		-- actions+=/tigers_fury
		action.EvaluateAction(Spell.TigersFury, true);
		-- actions+=/ashamanes_frenzy
		action.EvaluateAction(Artifact.AshamanesFrenzy, true);
		action.EvaluateAction(Spell.Regrowth, self.Requirements.Regrowth.Use);
		action.EvaluateAction(Spell.Rip, self.Requirements.Rip);
		action.EvaluateAction(Spell.Thrash, self.Requirements.Thrash);
		-- actions+=/shred
		action.EvaluateAction(Spell.Shred, true);
	end

	return self;
end

local APL = APL(nameAPL, "LunaEclipse: Feral Druid", addonTable.Enum.SpecID.DRUID_FERAL);