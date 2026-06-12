-- All game tuning lives in this one file.
-- Change numbers, rename things, or add new upgrades to the list below —
-- the shop UI and the server logic both build themselves from this table.

local Config = {}

Config.GameName = "Click Empire"

-- The server ignores clicks beyond this rate (basic anti-autoclicker).
Config.MaxClicksPerSecond = 15

Config.AutosaveInterval = 60 -- seconds between automatic saves
Config.LeaderboardRefreshInterval = 60 -- seconds between leaderboard updates
Config.LeaderboardSize = 10

-- Upgrade types:
--   "click" = adds Power to the cash you earn per click
--   "auto"  = adds Power to the cash you earn automatically every second
-- Cost to buy the (n+1)th copy = BaseCost * CostMult ^ n
Config.Upgrades = {
	{ Id = "finger", Name = "Stronger Finger", Desc = "+1 per click", Type = "click", Power = 1, BaseCost = 15, CostMult = 1.15 },
	{ Id = "auto1", Name = "Auto Clicker", Desc = "+1 per second", Type = "auto", Power = 1, BaseCost = 60, CostMult = 1.15 },
	{ Id = "glove", Name = "Golden Glove", Desc = "+5 per click", Type = "click", Power = 5, BaseCost = 150, CostMult = 1.15 },
	{ Id = "auto2", Name = "Click Robot", Desc = "+8 per second", Type = "auto", Power = 8, BaseCost = 700, CostMult = 1.15 },
	{ Id = "fist", Name = "Diamond Fist", Desc = "+30 per click", Type = "click", Power = 30, BaseCost = 2000, CostMult = 1.15 },
	{ Id = "auto3", Name = "Click Factory", Desc = "+50 per second", Type = "auto", Power = 50, BaseCost = 9000, CostMult = 1.15 },
	{ Id = "mitt", Name = "Mega Mitt", Desc = "+200 per click", Type = "click", Power = 200, BaseCost = 25000, CostMult = 1.15 },
	{ Id = "auto4", Name = "Click Lab", Desc = "+300 per second", Type = "auto", Power = 300, BaseCost = 100000, CostMult = 1.15 },
	{ Id = "auto5", Name = "Quantum Clicker", Desc = "+2000 per second", Type = "auto", Power = 2000, BaseCost = 1200000, CostMult = 1.15 },
}

-- Rebirth: reset cash + upgrades for a permanent earnings multiplier.
-- Cost of the (n+1)th rebirth = BaseCost * CostMult ^ n
-- Earnings multiplier = 1 + MultiplierPerRebirth * rebirths
Config.Rebirth = {
	BaseCost = 100000,
	CostMult = 6,
	MultiplierPerRebirth = 1,
}

-- Fast lookup by id (used by the server to validate purchases).
Config.UpgradeById = {}
for _, upgrade in Config.Upgrades do
	Config.UpgradeById[upgrade.Id] = upgrade
end

function Config.GetUpgradeCost(upgrade, owned)
	return math.floor(upgrade.BaseCost * upgrade.CostMult ^ owned)
end

function Config.GetRebirthCost(rebirths)
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostMult ^ rebirths)
end

function Config.GetMultiplier(rebirths)
	return 1 + Config.Rebirth.MultiplierPerRebirth * rebirths
end

function Config.GetClickPower(upgrades, rebirths)
	local power = 1
	for _, upgrade in Config.Upgrades do
		if upgrade.Type == "click" then
			power += (upgrades[upgrade.Id] or 0) * upgrade.Power
		end
	end
	return power * Config.GetMultiplier(rebirths)
end

function Config.GetAutoPower(upgrades, rebirths)
	local power = 0
	for _, upgrade in Config.Upgrades do
		if upgrade.Type == "auto" then
			power += (upgrades[upgrade.Id] or 0) * upgrade.Power
		end
	end
	return power * Config.GetMultiplier(rebirths)
end

return Config
