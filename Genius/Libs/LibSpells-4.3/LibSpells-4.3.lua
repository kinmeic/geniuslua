---------------------
-- Local Definations
---------------------
local MAJOR_VERSION = "LibSpells-4.3"
local MINOR_VERSION = 10000 + tonumber(("$Rev: 002 $"):match("%d+"))

if not LibStub then error(MAJOR_VERSION .. " requires LibStub.") end
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local AuraRestrictionTypeNames = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }

local function IsUninspectable(value)
	if issecretvalue and issecretvalue(value) then return true end
	if type(value) == "table" and issecrettable and issecrettable(value) then return true end
	return false
end

local function ReadAuraField(aura, field)
	if not aura or IsUninspectable(aura) then return nil, false end
	local value = aura[field]
	if IsUninspectable(value) then return nil, false end
	return value, true
end

local function GetSpellData(spellID)
	if C_Spell and C_Spell.GetSpellInfo then
		return C_Spell.GetSpellInfo(spellID)
	elseif GetSpellInfo then
		local name, _, iconID, castTime = GetSpellInfo(spellID)
		if name then
			return { name = name, iconID = iconID, castTime = castTime }
		end
	end
end

local function GetSafeField(object, field)
	local value, readable = ReadAuraField(object, field)
	if readable then return value end
end

local function GetAuraData(unit, index, filter)
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
	elseif UnitAura then
		local name, icon, count, dispelName, duration, expirationTime, source,
			isStealable, nameplateShowPersonal, spellId = UnitAura(unit, index, filter)
		if name then
			return {
				name = name, icon = icon, applications = count, dispelName = dispelName,
				duration = duration, expirationTime = expirationTime, sourceUnit = source,
				isStealable = isStealable, nameplateShowPersonal = nameplateShowPersonal,
				spellId = spellId,
			}
		end
	end
end

local function GetAuraDurationObject(unit, aura)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDuration) then return end
	local auraInstanceID, readable = ReadAuraField(aura, "auraInstanceID")
	if not readable or not auraInstanceID then return end
	local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
	if ok then return durationObject end
end

local function GetAuraRefreshCarryOverDuration(unit, auraInstanceID)
	if not (C_UnitAuras and C_UnitAuras.GetRefreshCarryOverDuration) or not auraInstanceID then return end
	local ok, duration = pcall(C_UnitAuras.GetRefreshCarryOverDuration, unit, auraInstanceID)
	if not ok or IsUninspectable(duration) or type(duration) ~= "number" or duration < 0 or duration ~= duration then
		return
	end
	return duration
end

local function GetDurationObjectNumber(durationObject, methodName)
	if not durationObject then return nil, false end
	local ok, value = pcall(function()
		local getter = durationObject[methodName]
		if not getter then return nil end
		return getter(durationObject)
	end)
	if not ok or IsUninspectable(value) or type(value) ~= "number" then
		return nil, false
	end
	return value, true
end

local function GetAuraValues(aura, unit)
	if not aura then return 0, 0, 0, 0, true, true, true, nil, false, nil, true end

	local auraInstanceID = GetSafeField(aura, "auraInstanceID")
	local count, countKnown = ReadAuraField(aura, "applications")
	local auraCharges, auraChargesKnown = ReadAuraField(aura, "charges")
	local duration, durationKnown = ReadAuraField(aura, "duration")
	local expires, expirationKnown = ReadAuraField(aura, "expirationTime")
	if type(duration) ~= "number" then
		duration, durationKnown = nil, false
	end
	if type(expires) ~= "number" then
		expires, expirationKnown = nil, false
	end
	local durationObject = GetAuraDurationObject(unit, aura)
	local nativeDuration, nativeDurationKnown = GetDurationObjectNumber(durationObject, "GetTotalDuration")
	if nativeDurationKnown then
		duration, durationKnown = nativeDuration, true
	elseif duration == nil then
		durationKnown = false
	end

	if expirationKnown and expires == 0 then
		return math.huge, count or 0, duration or 0, 0, true, true, countKnown, durationObject, true, auraCharges, auraChargesKnown, auraInstanceID
	end

	local remaining, remainingKnown = GetDurationObjectNumber(durationObject, "GetRemainingDuration")
	if not remainingKnown and expirationKnown then
		remaining, remainingKnown = expires - GetTime(), true
	end
	if not remainingKnown then
		return 0, count or 0, duration or 0, 0, false, durationKnown, countKnown, durationObject, false, auraCharges, auraChargesKnown, auraInstanceID
	end
	return math.max(0, remaining), count or 0, duration or 0, 0, true, durationKnown, countKnown, durationObject, false, auraCharges, auraChargesKnown, auraInstanceID
end

local function GetAuraDataSafely(unit, index, filter)
	local ok, aura = pcall(GetAuraData, unit, index, filter)
	if not ok then return nil, false end
	if IsUninspectable(aura) then return nil, false end
	return aura, true
end

local function IsAuraDataRestricted()
	if GetRestrictedActionStatus and Enum and Enum.RestrictedActionType and Enum.RestrictedActionType.SecretAuras then
		local ok, restricted = pcall(GetRestrictedActionStatus, Enum.RestrictedActionType.SecretAuras)
		if ok and type(restricted) == "boolean" then return restricted end
	end

	local restrictionTypes = Enum and Enum.AddOnRestrictionType
	if C_RestrictedActions and restrictionTypes then
		for _, name in ipairs(AuraRestrictionTypeNames) do
			local restrictionType = restrictionTypes[name]
			if restrictionType ~= nil then
				if C_RestrictedActions.GetAddOnRestrictionState then
					local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, restrictionType)
					if ok and state ~= nil and state ~= 0 then return true end
				end
				if C_RestrictedActions.IsAddOnRestrictionActive then
					local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, restrictionType)
					if ok and active then return true end
				end
			end
		end
	end

	return false
end

local function GetSpellChargesInfo(spellID)
	if C_Spell and C_Spell.GetSpellCharges then
		local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
		if not ok then return nil, nil, nil, nil, false, nil, nil end
		-- nil means this spell is not charge-based; a secret table means the
		-- cooldown data is restricted and must not be presented as zero charges.
		if not info then return 0, 0, 0, 0, true, 1, false end
		if IsUninspectable(info) then return nil, nil, nil, nil, false, nil, nil end
		local current, currentKnown = ReadAuraField(info, "currentCharges")
		local maximum, maximumKnown = ReadAuraField(info, "maxCharges")
		local start, startKnown = ReadAuraField(info, "cooldownStartTime")
		local duration, durationKnown = ReadAuraField(info, "cooldownDuration")
		local rate, rateKnown = ReadAuraField(info, "chargeModRate")
		if not (currentKnown and maximumKnown and startKnown and durationKnown and rateKnown)
			or type(current) ~= "number" or type(maximum) ~= "number" then
			return nil, nil, nil, nil, false, nil, nil
		end
		return current, maximum, start or 0, duration or 0, true, rate or 1, maximum > 0
	elseif GetSpellCharges then
		local ok, current, maximum, start, duration, rate = pcall(GetSpellCharges, spellID)
		if not ok then return nil, nil, nil, nil, false, nil, nil end
		if current == nil and maximum == nil and start == nil and duration == nil then
			return 0, 0, 0, 0, true, 1, false
		end
		if type(current) ~= "number" or type(maximum) ~= "number" then
			return nil, nil, nil, nil, false, nil, nil
		end
		return current, maximum, start or 0, duration or 0, true, rate or 1, maximum > 0
	end
	return 0, 0, 0, 0, true, 1, false
end

local GetSpellCooldownLegacy = GetSpellCooldown

local function GetSpellCooldownInfo(spellID)
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if not ok or not info then return nil, nil, nil end
		local start, startKnown = ReadAuraField(info, "startTime")
		local duration, durationKnown = ReadAuraField(info, "duration")
		local enabled, enabledKnown = ReadAuraField(info, "isEnabled")
		local modRate, rateKnown = ReadAuraField(info, "modRate")
		if not (startKnown and durationKnown and enabledKnown and rateKnown) then return nil, nil, nil, nil end
		return start, duration, enabled, modRate or 1
	elseif GetSpellCooldownLegacy then
		local ok, start, duration, enabled, modRate = pcall(GetSpellCooldownLegacy, spellID)
		if ok then return start, duration, enabled, modRate or 1 end
	end
	return nil, nil, nil, nil
end

local function GetSpellCooldownDurationObject(spellID)
	if not (C_Spell and C_Spell.GetSpellCooldownDuration) then return end
	local ok, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID)
	if ok and not IsUninspectable(durationObject) then return durationObject end
end

local function IsSpellUsable(spellID)
	if C_Spell and C_Spell.IsSpellUsable then
		local ok, usable, insufficientPower = pcall(C_Spell.IsSpellUsable, spellID)
		if not ok then return nil, nil end
		if issecretvalue and (issecretvalue(usable) or issecretvalue(insufficientPower)) then
			return nil, nil
		end
		return usable, insufficientPower
	elseif IsUsableSpell then
		local ok, usable, insufficientPower = pcall(IsUsableSpell, spellID)
		if ok then return usable, insufficientPower end
	end
	return nil, nil
end

local IsSpellInRangeLegacy = IsSpellInRange

local function IsSpellInRange(spellID, unit)
	if C_Spell and C_Spell.IsSpellInRange then
		local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, unit)
		if ok then
			if inRange == true or inRange == 1 then return true end
			if inRange == false or inRange == 0 then return false end
		end
	elseif IsSpellInRangeLegacy then
		local ok, inRange = pcall(IsSpellInRangeLegacy, spellID, unit)
		if not ok then return nil end
		if inRange == 1 then return true end
		if inRange == 0 then return false end
	end
	return nil
end

local function IsSpellHelpful(spellID)
	if C_Spell and C_Spell.IsSpellHelpful then
		local ok, helpful = pcall(C_Spell.IsSpellHelpful, spellID)
		if ok then return helpful end
	elseif IsHelpfulSpell then
		local ok, helpful = pcall(IsHelpfulSpell, spellID)
		if not ok then return nil end
		return helpful == true or helpful == 1
	end
	return nil
end

-- Metatable
local function GetKnownTimeleft(value)
	if IsUninspectable(value) then return end
	if type(value) == "number" then return value end
	if not value or value.timeleftKnown == false or IsAuraDataRestricted() then return end
	if value.permanentAura then return math.huge end
	local remaining, remainingKnown = GetDurationObjectNumber(value.auraDurationObject, "GetRemainingDuration")
	if remainingKnown then return math.max(0, remaining) end
	local sampledAt = value.timeleftUpdatedAt or GetTime()
	local elapsed = math.max(0, GetTime() - sampledAt)
	return math.max(0, (value.timeleft or 0) - elapsed)
end

lib.__sub = function(op1, op2)
	local left1, left2 = GetKnownTimeleft(op1), GetKnownTimeleft(op2)
	if left1 == nil or left2 == nil then return nil end
	return left1 - left2
end

lib.__add = function(op1, op2)
	local left1, left2 = GetKnownTimeleft(op1), GetKnownTimeleft(op2)
	if left1 == nil or left2 == nil then return nil end
	return left1 + left2
end

-- 创建实例
function lib:New(spellId, auraId, unit, filter, magiclock)
	local object = {}
	
	local spellInfo = spellId and GetSpellData(spellId)
	local auraInfo = GetSpellData(auraId or spellId)
	object.name = GetSafeField(spellInfo, "name") or "*"
	object.aura = GetSafeField(auraInfo, "name")
	object.sid = spellId
	object.aid = auraId or spellId
	object.unit = unit or "target"
	object.filter = filter or "HARMFUL|PLAYER"
	object.magiclock = magiclock or 0	--防止重复施法标记
	object.key = ""		--按键
	
	object.CD = 0
	object.CDMAX = 0
	object.CDEnabled = nil
	object.timeleft = 0
	object.timeleftKnown = true
	object.timeleftUpdatedAt = GetTime()
	object.permanentAura = false
	object.count = 0
	object.countKnown = true
	object.duration = 0
	object.durationKnown = true
	object.refresh = 0	-- 刷新效果最大值
	object.auraDurationObject = nil
	object.tick = 0
	object.damage = 0
	object.charges = 0
	object.maxCharges = 0
	object.chargesKnown = false
	object.chargeBased = nil
	object.chargeleft = nil
	object.chargeDuration = nil
	object.auraCharges = nil
	object.auraChargesKnown = false
	
	setmetatable(object, self)
	self.__index = self
	return object
end

-- 效果组
function lib:NewAuras(auras, unit, filter)
	local object = {}
	object.auras = {}
	
	for _, id in ipairs(auras) do
		local spellInfo = GetSpellData(id)
		local name = GetSafeField(spellInfo, "name")
		if name then
			table.insert(object.auras, name)
		end
	end
	
	object.timeleft = 0
	object.timeleftKnown = true
	object.timeleftUpdatedAt = GetTime()
	object.permanentAura = false
	object.count = 0
	object.countKnown = true
	object.duration = 0
	object.durationKnown = true
	object.auraCharges = nil
	object.auraChargesKnown = false
	object.refresh = 0	-- 刷新效果最大值
	object.auraDurationObject = nil
	object.tick = 0
	object.unit = unit or "target"
	object.filter = filter or "HARMFUL"
	object.affects = 0	-- 影响中的增益数量
	object.affects_list = {}
	
	setmetatable(object, self)
	self.__index = self
	return object
end

-- 设置目标
function lib:SetUnit(unit, filter)
	self.unit = unit or self.unit
	self.filter = filter or self.filter
end

-- 设置按键
function lib:SetKey(key)
	self.key = key
end

-- 更新信息
function lib:Update(useId)
	local timeleft, count, duration, value = 0, 0, 0, 0
	local timeleftKnown, durationKnown, countKnown, durationObject, permanentAura = true, true, true, nil, false
	local auraCharges, auraChargesKnown = nil, true
	local auraInstanceID
	local charges, maxCharges, cstart, cduration, chargesKnown, chargeModRate, chargeBased = 0, 0, 0, 0, true, 1, false
	
	if self.auras then
		timeleft, count, duration, value, timeleftKnown, durationKnown, countKnown, durationObject, permanentAura, auraCharges, auraChargesKnown, auraInstanceID = self:GetAuraByGroup()
	elseif useId then
		timeleft, count, duration, value, timeleftKnown, durationKnown, countKnown, durationObject, permanentAura, auraCharges, auraChargesKnown, auraInstanceID = self:GetAuraByID(self.aid)
		self.CD, self.CDMAX, self.CDEnabled = self:GetCooldown()
	else
		timeleft, count, duration, value, timeleftKnown, durationKnown, countKnown, durationObject, permanentAura, auraCharges, auraChargesKnown, auraInstanceID = self:GetAura(self.aura)
		self.CD, self.CDMAX, self.CDEnabled = self:GetCooldown()
	end
	
	if self.sid then
		charges, maxCharges, cstart, cduration, chargesKnown, chargeModRate, chargeBased = GetSpellChargesInfo(self.sid)
		if chargesKnown and type(cstart) == "number" and type(cduration) == "number" and type(chargeModRate) == "number" then
			cstart = cstart > 0 and math.max(0, cduration - (GetTime() - cstart) * chargeModRate) or 0
		else
			charges, maxCharges, cstart, cduration, chargeBased = nil, nil, nil, nil, nil
		end
	end
	
	self.timeleft = timeleft
	self.timeleftKnown = timeleftKnown ~= false
	self.timeleftUpdatedAt = GetTime()
	self.permanentAura = permanentAura == true
	self.count = count
	self.countKnown = countKnown ~= false
	self.auraCharges = auraCharges
	self.auraChargesKnown = auraChargesKnown ~= false
	self.duration = duration
	self.durationKnown = durationKnown ~= false
	self.auraInstanceID = auraInstanceID
	local refresh = GetAuraRefreshCarryOverDuration(self.unit, auraInstanceID)
	if refresh == nil then refresh = duration * 0.3 end
	self.refresh = refresh
	self.auraDurationObject = durationObject
	self.tick = value
	self.charges = charges
	self.maxCharges = maxCharges
	self.chargesKnown = chargesKnown ~= false
	self.chargeBased = chargeBased
	self.chargeleft = cstart
	self.chargeDuration = cduration
end

-- 是否可以施法
-- Returns true only when availability is known, false when blocked, and nil
-- when the client cannot provide enough information for a safe decision.
-- Set ignoreCooldown only for abilities without an individual cooldown; this
-- avoids reading cooldown/charge values that may be restricted during combat.
function lib:CanCast(targetUnit, ignoreCooldown, allowUnknownRange)
	if self.sid then
		local usable, nomana = IsSpellUsable(self.sid)
		if usable == false or nomana == true then return false end
		if usable ~= true or nomana ~= false then return nil end

		if not ignoreCooldown then
			local start, duration, enabled, modRate = GetSpellCooldownInfo(self.sid)
			if type(start) ~= "number" or type(duration) ~= "number" or type(modRate) ~= "number" then return nil end
			if enabled ~= true and enabled ~= false and enabled ~= 0 and enabled ~= 1 then return nil end
			if enabled == false or enabled == 0 then return false end

			local charges, _, _, _, chargesKnown, _, chargeBased = GetSpellChargesInfo(self.sid)
			if not chargesKnown then return nil end
			if chargeBased then
				if type(charges) ~= "number" then return nil end
				if charges <= 0 then return false end
			elseif start > 0 and duration > 0 then
				local cooldownRemaining = duration - (GetTime() - start) * modRate
				if cooldownRemaining > 0 then return false end
			end
		end
		
		local spell = self.sid or self.name
		local helpful = IsSpellHelpful(spell)
		-- Harmful spells default to the current target; helpful spells only have
		-- a meaningful recipient when the caller supplies one.
		local shouldCheckRange = helpful == false or targetUnit ~= nil
		if shouldCheckRange and not (targetUnit and UnitIsUnit and UnitIsUnit(targetUnit, "player")) then
			local inRange = IsSpellInRange(spell, targetUnit or "target")
			if inRange == false then return false end
			if inRange ~= true and not allowUnknownRange then return nil end
		end
		return true
	end
	return nil
end

-- 是否在有效距离
function lib:InRange(unit)
	local spell = self.sid or self.name
	return IsSpellInRange(spell, unit or "target")
end

-- 取得技能冷却时间
function lib:GetCooldown()
	local start, duration, enabled, modRate = GetSpellCooldownInfo(self.sid or self.name)
	if type(start) ~= "number" or type(duration) ~= "number" or type(modRate) ~= "number" then return nil, nil, nil end
	if enabled == false or enabled == 0 then return nil, duration, false end
	if enabled ~= true and enabled ~= 1 then return nil, duration, nil end
	if start <= 0 or duration <= 0 then return 0, duration, true end
	return math.max(0, duration - (GetTime() - start) * modRate), duration, true
end

function lib:GetCD()
	return self:GetCooldown()
end

function lib:IsChargeBased()
	if self.chargesKnown == false then return nil end
	return self.chargeBased == true
end

function lib:GetCharges()
	if self.chargesKnown == false or self.chargeBased == nil then return nil, nil end
	if self.chargeBased ~= true then return nil, nil end
	return self.charges, self.maxCharges
end

function lib:GetChargeCooldown()
	if self.chargesKnown == false or self.chargeBased == nil then return nil, nil end
	if self.chargeBased ~= true then return nil, nil end
	return self.chargeleft, self.chargeDuration
end

-- Native duration object for Cooldown/StatusBar widgets; numeric rules use GetCooldown().
function lib:GetCooldownDurationObject()
	return GetSpellCooldownDurationObject(self.sid or self.name)
end

-- 取得施法时间
function lib:GetCastTime()
	if not self.sid then return end
	local spellInfo = GetSpellData(self.sid)
	if spellInfo then
		return (GetSafeField(spellInfo, "castTime") or 0) / 1000
	else
		return 999
	end
end

-- 取得效果信息
function lib:GetAura(aura)
	if not aura then
		return 0, 0, 0, 0, true, true, true, nil, false, nil, true
	end

	for i = 1, 40 do
		local auraData, readable = GetAuraDataSafely(self.unit, i, self.filter)
		if not readable then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
		if not auraData then
			if IsAuraDataRestricted() then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
			return 0, 0, 0, 0, true, true, true, nil, false, nil, true
		end
		local auraName, nameKnown = ReadAuraField(auraData, "name")
		if not nameKnown then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
		if auraName == aura then
			return GetAuraValues(auraData, self.unit)
		end
	end
	if IsAuraDataRestricted() then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
	return 0, 0, 0, 0, true, true, true, nil, false, nil, true
end

-- 根据ID获取效果信息
function lib:GetAuraByID(aid)
	for i = 1, 40 do
		local auraData, readable = GetAuraDataSafely(self.unit, i, self.filter)
		if not readable then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
		if not auraData then
			if IsAuraDataRestricted() then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
			return 0, 0, 0, 0, true, true, true, nil, false, nil, true
		end
		local spellId, spellIdKnown = ReadAuraField(auraData, "spellId")
		if not spellIdKnown then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
		if spellId == aid then
			return GetAuraValues(auraData, self.unit)
		end
	end
	
	if IsAuraDataRestricted() then return 0, 0, 0, 0, false, false, false, nil, false, nil, false end
	return 0, 0, 0, 0, true, true, true, nil, false, nil, true
end

-- 获取效果组信息
function lib:GetAuraByGroup()
	local timeleft, count, duration, tick = 0, 0, 0, 0
	local timeleftKnown, durationKnown, countKnown = true, true, true
	local auraCharges, auraChargesKnown = nil, true
	local durationObject, permanentAura = nil, false
	local auraInstanceID
	self.affects = 0
	self.affects_list = {}

	for _, auraName in ipairs(self.auras) do
		local auraTime, auraCount, auraDuration, auraTick, auraTimeKnown, auraDurationKnown, auraCountKnown, auraDurationObject, auraIsPermanent, auraAuraCharges, auraAuraChargesKnown, auraAuraInstanceID = self:GetAura(auraName)
		if not auraTimeKnown then
			timeleftKnown = false
			durationKnown = false
			countKnown = false
			auraChargesKnown = false
		elseif auraTime > 0 then
			self.affects = self.affects + 1
			table.insert(self.affects_list, auraName)
			if auraTime > timeleft then
				timeleft, count, duration, tick = auraTime, auraCount, auraDuration, auraTick
				countKnown = auraCountKnown
				durationKnown = auraDurationKnown
				durationObject = auraDurationObject
				permanentAura = auraIsPermanent
				auraCharges = auraAuraCharges
				auraChargesKnown = auraAuraChargesKnown
				auraInstanceID = auraAuraInstanceID
			end
		end
	end
	if not timeleftKnown then
		durationKnown = false
		countKnown = false
		auraCharges = nil
		auraChargesKnown = false
	end

	return timeleft, count, duration, tick, timeleftKnown, durationKnown, countKnown, durationObject, permanentAura, auraCharges, auraChargesKnown, auraInstanceID
end

-- Remaining time is nil when the aura data is currently secret or unavailable.
function lib:GetRemainingTime()
	return GetKnownTimeleft(self)
end

-- Native duration object for UI widgets such as Cooldown:SetCooldownFromDurationObject.
function lib:GetAuraDurationObject()
	return self.auraDurationObject
end

local function GetRuleTimeleft(self)
	return GetKnownTimeleft(self)
end

function lib:IsAuraPermanent()
	if self.timeleftKnown == false or IsAuraDataRestricted() then return nil end
	return self.permanentAura == true
end

-- 效果存在
function lib:Up()
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft > 0
end

-- 没有效果
function lib:NONE()
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft <= 0
end

-- 等于效果剩余时间
function lib:EQ(num)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft == num
end

-- 小于效果剩余时间
function lib:LT(num)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft < num
end

-- 小于等于效果剩余时间
function lib:LE(num)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft <= num
end

-- 大于效果剩余时间
function lib:RT(num)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft > num
end

-- 大于等于效果剩余时间
function lib:RE(num)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft >= num
end

-- 剩余效果范围内
function lib:BT(num1, num2)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft > num1 and timeleft < num2
end

function lib:BE(num1, num2)
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	return timeleft >= num1 and timeleft <= num2
end

-- 堆叠次数
function lib:GetStack()
	if self.countKnown == false then return nil end
	return self.count or 0
end

-- AuraData.charges is distinct from applications/stack count.
function lib:GetAuraCharges()
	if self.auraChargesKnown == false then return nil, false end
	return self.auraCharges, true
end

-- 效果存在
function lib:Ticking()
	return self:Up()
end

-- 效果需要刷新
function lib:NeedRefresh()
	local timeleft = GetRuleTimeleft(self)
	if timeleft == nil then return nil end
	if self.permanentAura then return false end
	if timeleft <= 0 then return true end
	if self.durationKnown == false then return nil end
	return timeleft <= self.refresh
end

function lib:Refreshable()
	return self:NeedRefresh()
end
