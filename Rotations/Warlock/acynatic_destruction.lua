local addonName, addonTable = ...; -- Pulls back the Addon-Local Variables and store them locally.
local addon = _G[addonName];

local math, pairs = math, pairs;

local Core = addon.Core.General;
local Enemies = addonTable.Enemies;
local Objects = addon.Core.Objects;

-- Function for converting booleans returns to numbers
local val = Core.ToNumber;

-- Objects
local Player = addon.Units.Player;
local Target = addon.Units.Target;
local Pet = addon.Units.Pet;
local Racial, Artifact, Spell, Talent, Buff, Debuff, Item, Legendary, Consumable;

-- Rotation Variables
local nameAPL = "acynatic_destruction";

local Variables = {};

local function cooldownSindoreiSpite()
	return math.max(180 - Buff.SindoreiSpite.TimeSinceLastBuff(), 0);
end

local function remainingHavoc()
	for unitID, currentUnit in pairs(addon.NameplateUnits) do
		if currentUnit.GUID() ~= Target.GUID() and currentUnit.Debuff(Debuff.Havoc).Up() then
			return currentUnit.Debuff(Debuff.Havoc).Remains();
		end
	end

	return 0;
end

-- Base APL Class
local function APL(rotationName, rotationDescription, specID)
	-- Inherits APL Class so get the base class.
	local self = addonTable.rotationsAPL(rotationName, rotationDescription, specID);

	-- Store the information for the script.
	self.scriptInfo = {
		SpecializationID = self.SpecID,
		ScriptAuthor = "Acynatic",
		GuideAuthor = "Furty and Simcraft",
		GuideLink = "https://www.icy-veins.com/wow/destruction-warlock-pve-dps-guide",
		WoWVersion = 70305,
	};

	-- Set the preset builds for the script.
	self.presetBuilds = {
		["Dungeons / Raiding"] = "1203022",
		["World Quests"] = "1102013",
	};

	-- Table to hold requirements to use spells and items listed in the rotation.
	self.Requirements = {
		ArcaneTorrent = function()
			return Target.InRange(8);
		end,

		Immolate = {
			riority1 = function(numEnemies)
				return numEnemies == 2
				   and Talent.RoaringBlaze.Enabled()
				   and not Spell.Havoc.Cooldown.Down()
				   and Target.Debuff(Debuff.Immolate).Remains() <= Variables.remainingHavoc;
			end,

			Priority2 = function(numEnemies)
				return (numEnemies < 5 or not Talent.FireAndBrimstone.Enabled())
				   and Target.Debuff(Debuff.Immolate).Remains() <= 3;
			end,

			Priority3 = function(numEnemies)
				return (numEnemies < 5 or not Talent.FireAndBrimstone.Enabled())
				   and (not Talent.Cataclysm.Enabled() or Talent.Cataclysm.Cooldown.Remains() >= (Spell.Immolate.CastTime() * numEnemies))
				   and numEnemies > 1
				   and Target.Debuff(Debuff.Immolate).Remains() <= 3
				   and (not Talent.RoaringBlaze.Enabled() or (not Target.Debuff(Debuff.RoaringBlaze).Up() and Spell.Conflagrate.Charges() < (2 + val(addonTable.Tier19_4PC))));
			end,

			Priority4 = function()
				return Talent.RoaringBlaze.Enabled()
				   and Target.Debuff(Debuff.Immolate).Remains() <= Target.Debuff(Debuff.Immolate).Duration()
				   and not Target.Debuff(Debuff.RoaringBlaze).Up()
				   and Target.TimeToDie() > 10
				   and (Spell.Conflagrate.Charges == (2 + val(addonTable.Tier19_4PC)) or (Spell.Conflagrate.Charges == (1 + val(addonTable.Tier19_4PC)) and Spell.Conflagrate.Charges.Recharge() < Spell.Immolate.CastTime() + Player.GCD()) or Target.TimeToDie() < 24);
			end,

			Priority5 = function(numEnemies)
				return (numEnemies < 5 or not Talent.FireAndBrimstone.Enabled())
				   and (not Talent.Cataclysm.Enabled() or Talent.Cataclysm.Cooldown.Remains() >= Spell.Immolate.CastTime() * numEnemies)
				   and not Talent.RoaringBlaze.Enabled()
				   and Target.Debuff(Debuff.Immolate).Refreshable();
			end,
		},

		Havoc = function(numEnemies)
			return numEnemies > 1
			   and (numEnemies < 4 or Talent.WreakHavoc.Enabled() and numEnemies < 6)
			   and not Target.Debuff(Debuff.Havoc).Up();
		end,

		DimensionalRift = {
			ChargeCap = function()
				return Artifact.DimensionalRift.Charges() == 3;
			end,

			SpaceTimeLessons = function()
				return Legendary.LessonsOfSpacetime.Equipped()
				   and not Player.Buff(Buff.LessonsOfSpacetime).Up()
				   and ((not Talent.GrimoireOfSupremacy.Enabled() and not Spell.SummonDoomguard.Cooldown.Down()) or (Talent.GrimoireOfService.Enabled()) or (Talent.SoulHarvest.Enabled() and not Spell.SoulHarvest.Cooldown.Down()));
			end,

			Normal = function()
				return Target.TimeToDie() <= 32
					or not Legendary.LessonsOfSpacetime.Equipped()
					or Artifact.DimensionalRift.Charges() > 1
					or (not Legendary.LessonsOfSpacetime.Equipped()	and (not Talent.GrimoireOfService.Enabled()) and (not Talent.SoulHarvest.Enabled() or Artifact.DimensionalRift.Charges.Recharge() < Spell.SoulHarvest.Cooldown.Remains()) and (not Talent.GrimoireOfSupremacy.Enabled() or Artifact.DimensionalRift.Charges.Recharge() < Spell.SummonDoomguard.Remains()));
			end,
		},

		Cataclysm = function(numEnemies)
			return numEnemies >= 3;
		end,

		DeadlyGrace = function()
			return Player.Buff(Buff.SoulHarvest).Up()
				or Target.TimeToDie() <= 45;
		end,

		Shadowburn = {
			ConflagrationOfChaos = function()
				return Player.SoulShards() < 4
				   and Player.Buff(Buff.ConflagrationOfChaos).Remains() <= Spell.ChaosBolt.CastTime();
			end,

			Normal = function()
				return (Talent.Shadowburn.Charges() == 1 + val(addonTable.Tier19_4PC) and Talent.Shadowburn.Charges.Recharge() < Spell.ChaosBolt.CastTime()	or Talent.Shadowburn.Charges() == 2 + val(addonTable.Tier19_4PC))
				   and Player.SoulShards() < 5;
			end,
		},

		Conflagrate = {
			Priority1 = function()
				return Talent.RoaringBlaze.Enabled()
				   and (Spell.Conflagrate.Charges() == 2 + val(addonTable.Tier19_4PC) or (Spell.Conflagrate.Charges() >= 1 + val(addonTable.Tier19_4PC)	and Spell.Conflagrate.Charges.Recharge() < Player.GCD()) or Target.TimeToDie() < 24);
			end,

			Priority2 = function(numEnemies)
				return Talent.RoaringBlaze.Enabled()
				   and Target.Debuff(Debuff.RoaringBlaze).Stack() > 0
				   and Target.Debuff(Debuff.Immolate).Refreshable()
				   and (numEnemies == 1 or Player.SoulShards() < 3)
				   and Player.SoulShards() < 5;
			end,

			Priority3 = function()
				return not Talent.RoaringBlaze.Enabled()
				   and Player.Buff(Buff.Backdraft).Stack() < 3
				   and (Spell.Conflagrate.Charges() == 1 + val(addonTable.Tier19_4PC) and Spell.Conflagrate.Charges.Recharge() < Spell.ChaosBolt.CastTime()	or Spell.Conflagrate.Charges() == 2 + val(addonTable.Tier19_4PC))
				   and Player.SoulShards() < 5;
			end,

			Priority4 = function()
				return not Talent.RoaringBlaze.Enabled()
				   and Player.Buff(Buff.Backdraft).Stack() < 3;
			end,
		},

		LifeTap = {
			Priority1 = function()
				return Talent.EmpoweredLifeTap.Enabled()
				   and Player.Buff(Buff.EmpoweredLifeTap).Remains() <= Player.GCD();
			end,

			Priority2 = function()
				return Talent.EmpoweredLifeTap.Enabled()
				   and Player.Buff(Buff.EmpoweredLifeTap).Refreshable();
			end,

			Precombat = function()
				return Talent.EmpoweredLifeTap.Enabled()
				   and not Player.Buff(Buff.EmpoweredLifeTap).Up();
			end,
		},

		SummonInfernal = {
			Priority1 = function(numEnemies)
				return Artifact.LordOfFlames.Trait.Rank() > 0
				   and not Player.Debuff(Debuff.LordOfFlames).Up()
				   and not Talent.GrimoireOfSacrifice.Enabled();
			end,

			Priority2 = function(numEnemies)
				return not Talent.GrimoireOfSupremacy.Enabled()
				   and numEnemies > 2
				   and not Talent.GrimoireOfSacrifice.Enabled();
			end,

			Priority3 = function(numEnemies)
				return Talent.GrimoireOfSupremacy.Enabled()
				   and numEnemies > 1
				   and Legendary.SindoreiSpite.Equipped()
				   and Variables.cooldownSindoreiSpite == 0;
			end,

			Precombat = function()
				return not Pet.Family("Infernal")
				   and Talent.GrimoireOfSupremacy.Enabled()
				   and Artifact.LordOfFlames.Trait.Rank() > 0
				   and Player.Debuff(Debuff.LordOfFlames).Down();
			end,

			Precombat2 = function(numEnemies)
				return not Pet.Family("Infernal")
				   and Talent.GrimoireOfSupremacy.Enabled()
				   and numEnemies > 1;
			end,
		},

		SummonDoomguard = {
			Priority1 = function(numEnemies)
				return not Talent.GrimoireOfSupremacy.Enabled()
				   and not Talent.GrimoireOfSacrifice.Enabled()
				   and numEnemies <= 2
				   and (Target.TimeToDie() > 180 or Target.Health.Percent() <= 20 or Target.TimeToDie() < 30);
			end,

			Priority2 = function(numEnemies)
				return Talent.GrimoireOfSupremacy.Enabled()
				   and not Talent.GrimoireOfSacrifice.Enabled()
				   and numEnemies == 1
				   and Artifact.LordOfFlames.Trait.Rank() > 0
				   and Player.Debuff(Debuff.LordOfFlames).Up()
				   and not Pet.Family("Doomguard");
			end,

			Priority3 = function(numEnemies)
				return Talent.GrimoireOfSupremacy.Enabled()
				   and numEnemies > 1
				   and Legendary.SindoreiSpite.Equipped()
				   and Variables.cooldownSindoreiSpite == 0;
			end,

			Precombat = function()
				return not Pet.Family("Doomguard")
				   and Talent.GrimoireOfSupremacy.Enabled()
				   and Player.Debuff(Debuff.LordOfFlames).Up();
			end,
		},

		SoulHarvest = function()
			return not Player.Buff(Buff.SoulHarvest).Up();
		end,

		ChaosBolt = {
			Priority1 = function(numEnemies)
				return numEnemies < 4
				   and Variables.remainingHavoc > Spell.ChaosBolt.CastTime();
			end,

			Priority2 = function(numEnemies)
				return numEnemies < 3
				   and (Spell.Havoc.Cooldown.Remains() > 12	and Spell.Havoc.Cooldown.Down()	or numEnemies == 1 or Player.SoulShards() > 5 - (numEnemies * 1.5) or Target.TimeToDie() <= 10);
			end,
		},

		ChannelDemonfire = function(numEnemies)
			return Target.Debuff(Debuff.Immolate).Remains() > Talent.ChannelDemonfire.CastTime()
			   and (numEnemies == 1 or Variables.remainingHavoc < Spell.ChaosBolt.CastTime());
		end,

		RainOfFire = {
			Normal = function(numEnemies)
				return numEnemies >= 3;
			end,

			WreakHavoc = function(numEnemies)
				return numEnemies >= 6
				   and Talent.WreakHavoc.Enabled();
			end,
		},

		DarkPact = function()
			return Player.DamagePredicted(5) >= 20;
		end,

		UnendingResolve = function()
			return Player.DamagePredicted(4) >= 35;
		end,

		SummonImp = function()
			return not Pet.Family("Imp")
			   and not Talent.GrimoireOfSupremacy.Enabled()
			   and (not Talent.GrimoireOfSacrifice.Enabled() or Player.Buff(Buff.DemonicPower).Down());
		end,

		DrainLife = function()
			return Player.Health.Percent() < 50;
		end,

		CauterizeMaster = function()
			return Pet.Family("Imp")
			   and Player.Health.Percent() < 90;
		end,

		GrimoireOfSacrifice = function()
			return Talent.GrimoireOfSacrifice.Enabled();
		end,

		Shadowfury = function()
			return Target.InRange(30);
		end,

		ShadowLock = function()
			return Pet.Family("Doomguard");
		end,

		SpellLock = function()
			return Pet.Family("Felhunter");
		end,
	};

	Objects.FinalizeRequirements(self.Requirements);

	function self.Enable()
		Racial = {
			-- Abilities
			ArcaneTorrent = Objects.newSpell(69179),
			Berserking = Objects.newSpell(26297),
			BloodFury = Objects.newSpell(33702),
		};

		Artifact = {
			-- Abilities
			DimensionalRift = Objects.newSpell(196586),
			-- Traits
			LordOfFlames = Objects.newSpell(224103),
		};

		Spell = {
			Banish = Objects.newSpell(710),
			CreateHealthstone = Objects.newSpell(6201),
			CreateSoulwell = Objects.newSpell(29893),
			DemonicGateway = Objects.newSpell(111711),
			EnslaveDemon = Objects.newSpell(1098),
			EyeOfKilrogg = Objects.newSpell(126),
			Fear = Objects.newSpell(5782),
			HealthFunnel = Objects.newSpell(755),
			RitualOfSummoning = Objects.newSpell(698),
			ServiceImp = Objects.newSpell(111859),
			Soulstone = Objects.newSpell(20707),
			SummonDoomguard = Objects.newSpell(18540),
			SummonFelhunter = Objects.newSpell(691),
			SummonInfernal = Objects.newSpell(1122),
			SummonImp = Objects.newSpell(688),
			SummonSuccubus = Objects.newSpell(712),
			SummonVoidwalker = Objects.newSpell(697),
			UnendingBreath = Objects.newSpell(5697),
			UnendingResolve = Objects.newSpell(104773),

			CauterizeMaster = Objects.newSpell(119899),
			SpellLock = Objects.newSpell(19647),
			ShadowLock = Objects.newSpell(171139),

			ChaosBolt = Objects.newSpell(116858),
			Conflagrate = Objects.newSpell(17962),
			DrainLife = Objects.newSpell(234153),
			Havoc = Objects.newSpell(80240),
			Immolate = Objects.newSpell(348),
			Incinerate = Objects.newSpell(29722),
			LifeTap = Objects.newSpell(1454),
			RainOfFire = Objects.newSpell(5740),
		};

		Talent = {
			Backdraft = Objects.newSpell(196406),
			RoaringBlaze = Objects.newSpell(205184),
			Shadowburn = Objects.newSpell(17877),
			ReverseEntropy = Objects.newSpell(205148),
			Eradication = Objects.newSpell(196412),
			EmpoweredLifeTap = Objects.newSpell(235157),
			DemonicCircle = Objects.newSpell(48018),
			MortalCoil = Objects.newSpell(6789),
			Shadowfury = Objects.newSpell(30283),
			Cataclysm = Objects.newSpell(152108),
			FireAndBrimstone = Objects.newSpell(196408),
			SoulHarvest = Objects.newSpell(196098),
			DemonSkin = Objects.newSpell(219272),
			BurningRush = Objects.newSpell(111400),
			DarkPact = Objects.newSpell(108416),
			GrimoireOfSupremacy = Objects.newSpell(152107),
			GrimoireOfSacrifice = Objects.newSpell(108503),
			GrimoireOfService = Objects.newSpell(108501),
			WreakHavoc = Objects.newSpell(196410),
			ChannelDemonfire = Objects.newSpell(196447),
			SoulConduit = Objects.newSpell(215941),
		};

		Buff = {
			-- Buffs
			LessonsOfSpacetime = Objects.newSpell(236176),
			SoulHarvest = Talent.SoulHarvest,
			ConflagrationOfChaos = Objects.newSpell(196546),
			Backdraft = Objects.newSpell(117828),
			EmpoweredLifeTap = Objects.newSpell(235156),
			DemonicPower = Objects.newSpell(196099),
			-- Legendaries
			SindoreiSpite = Objects.newSpell(208871);
		};

		Debuff = {
			Immolate = Objects.newSpell(157736),
			RoaringBlaze = Objects.newSpell(205690),
			Havoc = Spell.Havoc,
			LordOfFlames = Objects.newSpell(226802),
		};

		Item = {};

		Legendary = {
			SindoreiSpite = Objects.newItem(132379),
			LessonsOfSpaceTime = Objects.newItem(144369),
		};

		Consumable = {
			DeadlyGrace = Objects.newItem(127843),
		};

		Objects.FinalizeActions(Racial, Artifact, Spell, Talent, Buff, Debuff, Item, Legendary, Consumable);
	end

	function self.SetupConfiguration(config, options)
		config.RacialOptions(options, Racial.ArcaneTorrent, Racial.Berserking, Racial.BloodFury);
		config.AOEOptions(options, Talent.Cataclysm, Talent.ChannelDemonfire, Talent.FireAndBrimstone, Spell.RainOfFire);
		config.BuffOptions(options, Spell.UnendingBreath);
		config.CooldownOptions(options, Artifact.DimensionalRift, Spell.Havoc, Spell.LifeTap, Talent.ReverseEntropy, Talent.Shadowburn, Talent.SoulHarvest, Talent.SoulConduit);
		config.DefensiveOptions(options, Spell.CauterizeMaster, Talent.DarkPact, Spell.DrainLife, Spell.UnendingResolve);
		config.PetOptions(options, Spell.EyeOfKilrogg, Talent.GrimoireOfSacrifice, Spell.HealthFunnel, Spell.ServiceImp, Spell.SummonDoomguard, Spell.SummonFelhunter,
								Spell.SummonInfernal, Spell.SummonImp, Spell.SummonSuccubus, Spell.SummonVoidwalker);
		config.UtilityOptions(options, Spell.Banish, Talent.BurningRush, Spell.CreateHealthstone, Spell.CreateSoulwell, Talent.DemonicCircle, Spell.DemonicGateway,
									Spell.EnslaveDemon, Spell.Fear, Talent.MortalCoil, Spell.RitualOfSummoning, Spell.Soulstone);
	end

	function self.Disable()
		Racial = nil;
		Artifact = nil;
		Spell = nil;
		Talent = nil;
		Buff = nil;
		Debuff = nil;
		Item = nil;
		Legendary = nil;
		Consumable = nil;
	end

	function self.Opener(action)
	end

	function self.Defensive(action)
		-- Protects against all types of damage
		action.EvaluateDefensiveAction(Spell.UnendingResolve, self.Requirements.UnendingResolve);
		action.EvaluateDefensiveAction(Talent.DarkPact, self.Requirements.DarkPact);

		-- Self Healing goes at the end and is only suggested if a major cooldown is not needed.
		action.EvaluateDefensiveAction(Spell.CauterizeMaster, self.Requirements.CauterizeMaster);
		action.EvaluateDefensiveAction(Spell.DrainLife, self.Requirements.DrainLife);
	end

	function self.Interrupt(action)
		action.EvaluateInterruptAction(Spell.ShadowLock, true);
		action.EvaluateInterruptAction(Spell.SpellLock, self.Requirements.SpellLock);
		action.EvaluateInterruptAction(Racial.ArcaneTorrent, self.Requirements.ArcaneTorrent);

		-- Stuns
		if Target.IsStunnable() then
			action.EvaluateInterruptAction(Talent.Shadowfury, self.Requirements.Shadowfury);
		end
	end

	function self.Precombat(action)
		action.EvaluateAction(Spell.SummonImp, self.Requirements.SummonImp);
		action.EvaluateAction(Spell.SummonInfernal, self.Requirements.SummonInfernal.Precombat);
		action.EvaluateAction(Spell.SummonInfernal, self.Requirements.SummonInfernal.Precombat2, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.SummonDoomguard, self.Requirements.SummonDoomguard.Precombat);
		action.EvaluateAction(Talent.GrimoireOfSacrifice, self.Requirements.GrimoireOfSacrifice);
		action.EvaluateAction(Spell.LifeTap, self.Requirements.LifeTap.Precombat);
		action.EvaluateAction(Consumable.DeadlyGrace, true);
		action.EvaluateAction(Spell.ChaosBolt, true);
	end

	function self.Combat(action)
		Variables.remainingHavoc = remainingHavoc();
		Variables.cooldownSindoreiSpite = cooldownSindoreiSpite();

		action.EvaluateCycleAction(Spell.Immolate, self.Requirements.Immolate.Priority1, Enemies.GetEnemies(Spell.Immolate));
		action.EvaluateAction(Spell.Havoc, self.Requirements.Havoc, Enemies.GetEnemies(Spell.Havoc));
		action.EvaluateAction(Artifact.DimensionalRift, self.Requirements.DimensionalRift.ChargeCap);
		action.EvaluateAction(Talent.Cataclysm, self.Requirements.Cataclysm, Enemies.GetEnemies(Talent.Cataclysm));
		action.EvaluateAction(Spell.Immolate, self.Requirements.Immolate.Priority2, Enemies.GetEnemies(Spell.Immolate));
		action.EvaluateCycleAction(Spell.Immolate, self.Requirements.Immolate.Priority3, Enemies.GetEnemies(Spell.Immolate));
		action.EvaluateAction(Spell.Immolate, self.Requirements.Immolate.Priority4);
		action.EvaluateAction(Racial.Berserking, true);
		action.EvaluateAction(Racial.BloodFury, true);
		action.EvaluateAction(Consumable.DeadlyGrace, self.Requirements.DeadlyGrace);
		action.EvaluateAction(Talent.Shadowburn, self.Requirements.Shadowburn.ConflagrationOfChaos);
		action.EvaluateAction(Talent.Shadowburn, self.Requirements.Shadowburn.Normal);
		action.EvaluateAction(Spell.Conflagrate, self.Requirements.Conflagrate.Priority1);
		action.EvaluateAction(Spell.Conflagrate, self.Requirements.Conflagrate.Priority2, Enemies.GetEnemies(Spell.Conflagrate));
		action.EvaluateAction(Spell.Conflagrate, self.Requirements.Conflagrate.Priority3);
		action.EvaluateAction(Spell.LifeTap, self.Requirements.LifeTap.Priority1);
		action.EvaluateAction(Artifact.DimensionalRift, self.Requirements.DimensionalRift.SpaceTimeLessons);
		action.EvaluateAction(Spell.ServiceImp, true);
		action.EvaluateAction(Spell.SummonInfernal, self.Requirements.SummonInfernal.Priority1, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.SummonDoomguard, self.Requirements.SummonDoomguard.Priority1, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.SummonInfernal, self.Requirements.SummonInfernal.Priority2, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.SummonDoomguard, self.Requirements.SummonDoomguard.Priority2, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.SummonDoomguard, self.Requirements.SummonDoomguard.Priority3, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.SummonInfernal, self.Requirements.SummonInfernal.Priority3, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Talent.SoulHarvest, self.Requirements.SoulHarvest);
		action.EvaluateAction(Spell.ChaosBolt, self.Requirements.ChaosBolt.Priority1, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Talent.ChannelDemonfire, self.Requirements.ChannelDemonfire, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.RainOfFire, self.Requirements.RainOfFire.Normal, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.RainOfFire, self.Requirements.RainOfFire.WreakHavoc, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Artifact.DimensionalRift, self.Requirements.DimensionalRift.Normal);
		action.EvaluateAction(Spell.LifeTap, self.Requirements.LifeTap.Priority2);
		action.EvaluateAction(Talent.Cataclysm, true);
		action.EvaluateAction(Spell.ChaosBolt, self.Requirements.ChaosBolt.Priority2, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Talent.Shadowburn, true);
		action.EvaluateAction(Spell.Conflagrate, self.Requirements.Conflagrate.Priority4);
		action.EvaluateCycleAction(Spell.Immolate, self.Requirements.Immolate.Priority5, Enemies.GetEnemies(Spell.ChaosBolt));
		action.EvaluateAction(Spell.Incinerate, true);
		action.EvaluateAction(Spell.LifeTap, true);
	end

	return self;
end

local APL = APL(nameAPL, "Acynatic: Destruction Warlock", addonTable.Enum.SpecID.WARLOCK_DESTRUCTION);