if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")

-- 开关定义
local SW2 = _G["GeniusPanelSwitch2"]

-- 单位定义
local LibUnit = LibStub("LibUnit-6.0")
local Target = LibUnit:New("target")

-- 法术定义
local LibSpell = LibStub("LibSpells-4.3")

-- 通用技能
local KK = LibSpell:New(1766)                                      --脚踢

-- 战斗技能
local SnD = LibSpell:New(5171, 5171, "player", "HELPFUL|PLAYER")  --切割
local EV = LibSpell:New(2098)                                      --刺骨
local SS = LibSpell:New(1752)                                      --邪恶攻击

-- 变量定义
local comboAtLastUpdate = nil

-- 获取技能名称，用于匹配当前已学等级
local GetSpellName = function(spellID)
	if C_Spell and C_Spell.GetSpellName then
		local ok, spellName = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(spellName) == "string"
			and not (issecretvalue and issecretvalue(spellName)) then
			return spellName
		end
	elseif GetSpellInfo then
		local spellName = GetSpellInfo(spellID)
		if type(spellName) == "string" then return spellName end
	end
end

local SnDByName = LibSpell:New(GetSpellName(5171), 5171, "player", "HELPFUL|PLAYER")
local EVByName = LibSpell:New(GetSpellName(2098))
local SSByName = LibSpell:New(GetSpellName(1752))

local function EstimateSliceDuration()
	local combo = comboAtLastUpdate
	if type(combo) ~= "number" or (issecretvalue and issecretvalue(combo)) or combo < 1 then return nil end
	return 6 + 3 * combo
end

SnD:SetAuraEstimator(EstimateSliceDuration, { 6774 })
SnDByName:SetAuraEstimator(EstimateSliceDuration, { 6774 })

-- 战斗循环
local main = function(power, combo, target, maxComboPoints)
	LibSpell:UpdateAuras()
	comboAtLastUpdate = combo

	if not SW2:GetChecked() and target:CanBreak() and KK:CanCast("target", false, true) then --脚踢
		return "S="
	end

	local refreshSliceAndDice = SnD:LE(2)
	if refreshSliceAndDice == nil then
		refreshSliceAndDice = true
	end

	if combo ~= nil and combo >= 2 and refreshSliceAndDice
		and (SnD:CanCast(nil, true, true) or SnDByName:CanCast(nil, true, true)) then --切割
		return "D6"
	elseif combo ~= nil and combo >= maxComboPoints
		and (EV:CanCast(nil, true, true) or EVByName:CanCast(nil, true, true)) then --刺骨
		return "D5"
	elseif (combo == nil or combo < maxComboPoints)
		and (SS:CanCast(nil, true, true) or SSByName:CanCast(nil, true, true)) then --邪恶攻击
		return "D2"
	end
end

function Core:RogueCombat(power, comboPoints, stealthed, target, maxComboPoints)
	return main(power, comboPoints, target or Target, maxComboPoints or 5)
end
