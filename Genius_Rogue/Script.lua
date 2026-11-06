if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local LibUnit = LibStub("LibUnit-6.0")
local Player = LibUnit:New("player")
local Target = LibUnit:New("target")
local SW2 = _G["GeniusPanelSwitch2"]

-- Baseline abilities used before a specialization is selected.
local NoSpecKick = Core.RogueAPL.Spell(1766)
local NoSpecSinisterStrike = Core.RogueAPL.Spell(1752)
local NoSpecSinisterStrikeByName = Core.RogueAPL.RankedSpell(1752)
local NoSpecEviscerate = Core.RogueAPL.Spell(6760)

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function CanTargetAttack(requireCombat)
	local mounted = IsMounted()
	local inVehicle = UnitInVehicle("player")
	if IsSecret(mounted) or IsSecret(inVehicle) or mounted or inVehicle then return false end

	local exists = UnitExists("target")
	if IsSecret(exists) or not exists then return false end
	local dead = UnitIsDeadOrGhost("target")
	if IsSecret(dead) or dead then return false end

	if requireCombat then
		local inCombat = UnitAffectingCombat("player")
		if IsSecret(inCombat) or not inCombat then return false end
	end

	local canAttack = UnitCanAttack("player", "target")
	return not IsSecret(canAttack) and canAttack == true
end

local function IsStealthed()
	local stealthed = Player:IsStealthed()
	if IsSecret(stealthed) then return nil end
	if type(stealthed) == "boolean" then return stealthed end
	if not GetShapeshiftFormID then return nil end
	local formID = GetShapeshiftFormID()
	if IsSecret(formID) then return nil end
	if type(formID) ~= "number" then return nil end
	return formID == 30
end

local function GetComboPointsMax()
	if not UnitPowerMax then return 5 end
	local ok, maximum = pcall(UnitPowerMax, "player", 4)
	if not ok or IsSecret(maximum) or type(maximum) ~= "number" or maximum < 1 then return 5 end
	return maximum
end

local function GetPlayerEnergy()
	if not UnitPower then return nil end
	local energyPowerType = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
	local ok, energy = pcall(UnitPower, "player", energyPowerType)
	if not ok or IsSecret(energy) or type(energy) ~= "number" then return nil end
	return energy
end

function Core:RogueNoSpecialization(power, comboPoints, stealthed, target, maxComboPoints)
	local APL = self.RogueAPL
	if not APL.IsChecked(SW2) and APL.CanBreak(target) and APL.CanCast(NoSpecKick) then
		return "S="
	end

	local finishAt = maxComboPoints or 5
	if comboPoints ~= nil and comboPoints >= finishAt
		and APL.CanCast(NoSpecEviscerate, nil, true, true) then
		return "D5"
	end

	if APL.CanCast(NoSpecSinisterStrike, nil, true, true)
		or APL.CanCast(NoSpecSinisterStrikeByName, nil, true, true) then
		return "D2"
	end
	return nil
end

function Core:Manual()
	if not CanTargetAttack(true) then
		self:Press(nil)
		return
	end

	Player:Update()

	local comboPoints
	if Player.CPSKnown then comboPoints = Player.CPS end
	local energy = GetPlayerEnergy()
	local stealthed = IsStealthed()
	local maxComboPoints = GetComboPointsMax()
	local actionKey

	if self.Talent == 1 then
		actionKey = self:RogueAssassination(energy, comboPoints, stealthed, Target, maxComboPoints)
	elseif self.Talent == 2 then
		actionKey = self:RogueCombat(energy, comboPoints, stealthed, Target, maxComboPoints)
	elseif self.Talent == 3 then
		actionKey = self:RogueSubtlety(energy, comboPoints, stealthed, Target, maxComboPoints)
	else
		actionKey = self:RogueNoSpecialization(energy, comboPoints, stealthed, Target, maxComboPoints)
	end

	-- Keep the basic builder available when a specialization APL has no usable
	-- recommendation yet (for example, before its spec-specific builder is learned).
	if not actionKey then
		local APL = self.RogueAPL
		if APL and (APL.CanCast(NoSpecSinisterStrike, nil, true, true)
			or APL.CanCast(NoSpecSinisterStrikeByName, nil, true, true)) then
			actionKey = "D2"
		end
	end

	self:Press(actionKey)
end

function Core:Auto()
	if self.Switch1 and self.Switch1:GetChecked() then
		self:Manual()
	else
		self:Press(nil)
	end
end

function Core:TALENT_CHANGED(talentID)
	local labels = {
		"自动攻击",
		"禁止断法",
		talentID == 3 and "手动影舞" or "手动爆发",
		"群体攻击",
	}
	if self.Panel then self.Panel:Show() end
	for index = 1, 4 do
		local switch = self["Switch" .. index]
		if switch then
			switch:Show()
			switch:SetChecked(false)
			if switch.Text then switch.Text:SetText(labels[index]) end
		end
	end

	self.ShowStanceNotice = false
end
