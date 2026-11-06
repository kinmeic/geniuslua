---------------------
-- Local Definations
---------------------
local MAJOR_VERSION = "LibUnit-6.0"
local MINOR_VERSION = 60000 + tonumber(("$Rev: 001 $"):match("%d+"))

if not LibStub then error(MAJOR_VERSION .. " requires LibStub.") end
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax = UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax
local C_SpecializationInfo = C_SpecializationInfo
local C_UnitAuras = C_UnitAuras
local select = select

local function ReadableNumber(value)
	if issecretvalue and issecretvalue(value) then return nil end
	if type(value) ~= "number" then return nil end
	return value
end

local function GetAuraField(aura, field)
	if issecretvalue and issecretvalue(aura) then return end
	if not aura then return end
	if issecrettable and issecrettable(aura) then return end
	local value = aura[field]
	if issecretvalue and issecretvalue(value) then return end
	return value
end

local function HasAuraData(aura)
	if issecretvalue and issecretvalue(aura) then return false end
	return aura ~= nil
end

local function GetAuraDataByIndex(unit, index, filter)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
	if ok then return aura end
end

function lib:New(unit)
	local obj = {}
	obj.unit = unit
	
	-- 基本属性
	obj.HP = 0
	obj.HPM = 0					-- 最大血量
	obj.HPL = 0					-- 血量损失
	obj.HPP = 0					-- 血量百分比
	obj.HPKnown = false
	obj.HPMKnown = false
	obj.MP = 0
	obj.MPM = 0
	obj.MPL = 0
	obj.MPP = 0
	obj.MPKnown = false
	obj.MPMKnown = false
	obj.CPS = 0
	obj.CPSKnown = false
	obj.Moving = false
	obj.Threat = 0
	obj.BreakList = {}
	obj.MPMT = 0				-- 能量自己回满需要的时间
	
	setmetatable(obj, self)
	self.__index = self
	return obj
end

-- 更新所有状态
function lib:Update()
	if UnitExists(self.unit) then
		local hp, hpMax = ReadableNumber(self:GetHP()), ReadableNumber(self:GetHPMax())
		self.HPKnown, self.HPMKnown = hp ~= nil, hpMax ~= nil
		self.HP, self.HPM = hp or 0, hpMax or 0
		self.HPL = (hp and hpMax) and (hpMax - hp) or 0
		self.HPP = (hp and hpMax and hpMax > 0) and (hp / hpMax * 100) or nil
		local mp, mpMax = ReadableNumber(self:GetMP()), ReadableNumber(self:GetMPMax())
		self.MPKnown, self.MPMKnown = mp ~= nil, mpMax ~= nil
		self.MP, self.MPM = mp or 0, mpMax or 0
		self.MPL = (mp and mpMax) and (mpMax - mp) or 0
		self.MPP = (mp and mpMax and mpMax > 0) and (mp / mpMax * 100) or nil
		local cps = ReadableNumber(self:GetCP())
		self.CPSKnown, self.CPS = cps ~= nil, cps or 0
		self.Threat = self:GetThreat()
		local regen = GetPowerRegen and ReadableNumber(GetPowerRegen()) or nil
		self.MPMT = (mp and mpMax and regen and regen > 0) and (self.MPL / regen) or nil
	else
		self.HP = 0
		self.HPM = 0
		self.HPL = 0
		self.HPP = 100
		self.HPKnown = false
		self.HPMKnown = false
		self.MP = 0
		self.MPM = 0
		self.MPL = 0
		self.MPP = 0
		self.MPKnown = false
		self.MPMKnown = false
		self.MPP = 0
		self.CPS = 0
		self.CPSKnown = false
		self.Threat = 0
		self.MPMT = 0
	end
end

-- 获取名称
function lib:GetName()
	return UnitName(self.unit)
end

-- 获取职业
function lib:GetClass()
	return select(2, UnitClass(self.unit))
end

-- 当前生命值
function lib:GetHP()
	return ReadableNumber(UnitHealth(self.unit))
end

-- 最大生命值
function lib:GetHPMax()
	return ReadableNumber(UnitHealthMax(self.unit))
end

-- 当前法力值
function lib:GetMP(powerType, ...)
	if not UnitPower then return nil end
	return ReadableNumber(UnitPower(self.unit, powerType, ...))
end

-- 最大法力值
function lib:GetMPMax(powerType)
	if not UnitPowerMax then return nil end
	return ReadableNumber(UnitPowerMax(self.unit, powerType))
end

-- 是否在副本
function lib:InInstance()
	local isInstance, instanceType = IsInInstance()
	if isInstance and (instanceType == "party" or instanceType == "raid") then
		return 1
	else
		return 0
	end
end

-- 獲取連擊點數
function lib:GetCP()
	if UnitPower then
		return ReadableNumber(UnitPower("player", 4))
	elseif GetComboPoints then
		return ReadableNumber(GetComboPoints("player", "target"))
	end
end

-- 獲取角色位置變化
function lib:Moving()
	return IsPlayerMoving()
end

-- 是否可以攻击
function lib:CanAttack(inCombat)
	if IsMounted() or UnitInVehicle("player") then return end	--在马上或载具上
	if not UnitExists(self.unit) then return end	--目标不存在
	if UnitIsDeadOrGhost(self.unit) then return end
	if inCombat == true and (not UnitAffectingCombat("player")) then return end
	if UnitCanAttack("player", self.unit) then
		return true
	end
end

-- 是否是玩家
function lib:IsPlayer()
	return UnitIsPlayer(self.unit)
end

-- 是否已经死亡
function lib:Dead()
	return UnitIsDeadOrGhost(self.unit)
end

-- 是否可以打断施法
function lib:CanBreak()
	if not UnitExists("target") then return end
	local spell = UnitCastingInfo("target")
	if issecretvalue and issecretvalue(spell) then return end
	if not spell then
		spell = UnitChannelInfo("target")
		if issecretvalue and issecretvalue(spell) then return end
	end
	if not spell then return end
	
	local name = UnitName("target")
	if not (issecretvalue and issecretvalue(name)) and self.BreakList[name] and self.BreakList[name] ~= spell then
		return
	end
	
	local notInterruptible = select(8, UnitCastingInfo("target"))
	if issecretvalue and issecretvalue(notInterruptible) then return end
	if notInterruptible == false then
		return true
	end
	local channelNotInterruptible = select(7, UnitChannelInfo("target"))
	if issecretvalue and issecretvalue(channelNotInterruptible) then return end
	if channelNotInterruptible == false then
		return true
	end
end

-- 获取仇恨
function lib:GetThreat()
	-- Forever does not expose UnitDetailedThreatSituation. UnitThreatSituation
	-- only provides a coarse 0-3 status, not this method's threat percentage.
	if not UnitDetailedThreatSituation then return nil end
	local ok, _, _, threat = pcall(UnitDetailedThreatSituation, self.unit, self.unit.."target")
	if not ok then return nil end
	if issecretvalue and issecretvalue(threat) then return nil end
	return threat or 0
--	return math.floor(threat or 0)
end

-- Coarse supported replacement for callers that can use threat tiers rather
-- than the detailed percentage returned by GetThreat().
function lib:GetThreatSituation()
	if not UnitThreatSituation then return nil end
	local ok, threat = pcall(UnitThreatSituation, self.unit, self.unit.."target")
	if not ok then return nil end
	if issecretvalue and issecretvalue(threat) then return nil end
	return threat
end

-- 获取天赋
function lib:GetTalent()
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		return C_SpecializationInfo.GetSpecialization() or 0
	elseif GetSpecialization then
		return GetSpecialization()
	end
end

-- 获取姿态
function lib:GetStance()
	return GetShapeshiftForm() or 0
end

-- 是否是BOSS
function lib:IsBoss()
	local classification = UnitClassification(self.unit)
	if issecretvalue and issecretvalue(classification) then return end
	if classification == "worldboss" then
		return true
	end
	local level = UnitLevel(self.unit)
	if issecretvalue and issecretvalue(level) then return end
	if level == -1 then
		return true
	end
end

-- 是否是精英
function lib:IsElite()
	local classification = UnitClassification(self.unit)
	if issecretvalue and issecretvalue(classification) then return end
	if classification == "elite" then
		return true
	end
	local unitLevel = UnitLevel(self.unit)
	if issecretvalue and issecretvalue(unitLevel) then return end
	local playerLevel = ReadableNumber(UnitLevel("player"))
	if not playerLevel then return end
	if unitLevel - playerLevel >= 2 then
		return true
	else
		return self:IsBoss()
	end
end

-- 是否正在施法
function lib:Casting()
	local spell = UnitCastingInfo(self.unit)
	if issecretvalue and issecretvalue(spell) then return false end
	if spell then return spell end
	spell = UnitChannelInfo(self.unit)
	if issecretvalue and issecretvalue(spell) then return false end
	return spell or SpellIsTargeting()
end

-- 施法剩余时间
function lib:GetCastingTime()
	local name, _, _, _, startTime, endTime = UnitCastingInfo(self.unit)
	if issecretvalue and (issecretvalue(name) or issecretvalue(startTime) or issecretvalue(endTime)) then return nil end
	
	if name then
		return endTime / 1000 - GetTime()
	else
		return 0
	end
end

-- 返回单位唯一编号
function lib:GUID()
	return UnitGUID(self.unit)
end

-- 是否能驱散
function lib:CanDispel(dispelType1, dispelType2, dispelType3, dispelType4)
	for i = 1, 40 do
		local aura = GetAuraDataByIndex(self.unit, i, "HARMFUL|RAID")
		local name = GetAuraField(aura, "name")
		
		if not name then
			return
		end
		local auraType = GetAuraField(aura, "dispelName")
		if auraType and auraType == dispelType1 then
			return name
		elseif auraType and auraType == dispelType2 then
			return name
		elseif auraType and auraType == dispelType3 then
			return name
		elseif auraType and auraType == dispelType4 then
			return name
		end
	end
end

-- 是否能窃取
function lib:CanStealable()
	for i = 1, 40 do
		local aura = GetAuraDataByIndex(self.unit, i, "HELPFUL")
		if not HasAuraData(aura) then return end
		local isStealable = GetAuraField(aura, "isStealable")
		if isStealable == true or isStealable == 1 then
			return true
		end
	end
end

-- 返回天赋是否选中
function lib:TalentSelected(talentIndex)
	if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
		local ok, talent = pcall(C_SpecializationInfo.GetTalentInfo, { talentIndex = talentIndex })
		if not ok or not talent or (issecrettable and issecrettable(talent)) then return nil end
		local selected = GetAuraField(talent, "selected")
		local known = GetAuraField(talent, "known")
		local rank = ReadableNumber(GetAuraField(talent, "rank"))
		if (issecretvalue and (issecretvalue(selected) or issecretvalue(known))) or rank == nil then return nil end
		return selected or known or rank > 0
	end
end

-- 是否是坦克
function lib:IsTank()
	if UnitGroupRolesAssigned then
		local role = UnitGroupRolesAssigned(self.unit)
		if issecretvalue and issecretvalue(role) then return nil end
		return role == "TANK"
	elseif GetPartyAssignment then
		return GetPartyAssignment("MAINTANK", self.unit)
	end
end

-- 不是玩家本身
function lib:IsMe()
	return UnitIsUnit("player", self.unit)
end

-- 是否隐身
function lib:IsStealthed()
	if IsStealthed then
		local ok, stealthed = pcall(IsStealthed)
		if ok and not (issecretvalue and issecretvalue(stealthed)) then return stealthed end
	end
	return nil
end
