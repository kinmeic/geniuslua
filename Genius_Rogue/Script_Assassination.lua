if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local APL = Core.RogueAPL
local SW2 = _G["GeniusPanelSwitch2"]
local SW3 = _G["GeniusPanelSwitch3"]
local SW4 = _G["GeniusPanelSwitch4"]

local Kick = APL.Spell(1766)
local Ambush = APL.Spell(8676)
local Mutilate = APL.Spell(1310707) -- Forever spell ID
local FanOfKnives = APL.Spell(51723)
local CrimsonTempest = APL.Spell(1247227)
local Deathmark = APL.Spell(360194)
local Kingsbane = APL.Spell(385627)
local Envenom = APL.Spell(32645)

local Garrote = APL.Spell(703, nil, "target", "HARMFUL|PLAYER")
local Rupture = APL.Spell(1943, nil, "target", "HARMFUL|PLAYER")
local DeathmarkDot = APL.Aura(360194, "target", "HARMFUL|PLAYER")
local EnvenomBuff = APL.Aura(32645, "player", "HELPFUL|PLAYER")
local DarkestNight = APL.Aura(457280, "player", "HELPFUL|PLAYER")

function Core:RogueAssassination(power, comboPoints, stealthed, target, maxComboPoints)
	Garrote:Update(true)
	Rupture:Update(true)
	DeathmarkDot:Update(true)
	EnvenomBuff:Update(true)
	DarkestNight:Update(true)

	local aoe = APL.IsChecked(SW4)
	local maxCP = maxComboPoints or 5
	local energyPercent = APL.EnergyPercent(power)
	local garroteUp = APL.Up(Garrote)
	local ruptureUp = APL.Up(Rupture)
	local envenomRemains = APL.Remains(EnvenomBuff)
	local darkestNightUp = APL.Up(DarkestNight)
	local spendThreshold = 5
	if darkestNightUp == true or darkestNightUp == nil then spendThreshold = math.max(5, maxCP) end

	if not APL.IsChecked(SW2) and APL.CanBreak(target) and APL.CanCast(Kick) then
		return "S="
	end

	-- Align Deathmark with active bleeds, Kingsbane, and Envenom.
	if not APL.IsChecked(SW3) then
		local kingsbaneCooldown = APL.Cooldown(Kingsbane)
		if APL.CanCast(Deathmark) and garroteUp and ruptureUp
			and kingsbaneCooldown ~= nil and kingsbaneCooldown <= 2
			and envenomRemains ~= nil and envenomRemains > 2 then
			return "D4"
		end

		local deathmarkCooldown = APL.Cooldown(Deathmark)
		if APL.CanCast(Kingsbane) and garroteUp and ruptureUp
			and (APL.Up(DeathmarkDot) or (deathmarkCooldown ~= nil and deathmarkCooldown > 52))
			and APL.Up(EnvenomBuff) then
			return "D8"
		end
	end

	-- Maintain Garrote before spending combo points. Stealth improves its next application.
	if APL.CanCast(Garrote) and APL.Refreshable(Garrote)
		and (stealthed == true or not aoe or garroteUp == false) then
		return "D9"
	end

	if comboPoints ~= nil and comboPoints >= 5 and APL.CanCast(Rupture)
		and (darkestNightUp == false or ruptureUp == false)
		and APL.Refreshable(Rupture) then
		return "D6"
	end

	-- Spread bleeds with Crimson Tempest while building in manual AoE mode.
	if aoe and comboPoints ~= nil and comboPoints < spendThreshold
		and APL.CanCast(CrimsonTempest) and (garroteUp == false or ruptureUp == false) then
		return "D0"
	end
	if darkestNightUp == true and comboPoints ~= nil and comboPoints == maxCP - 1
		and APL.CanCast(FanOfKnives) then
		return "D0"
	end

	if comboPoints ~= nil and comboPoints >= spendThreshold then
		local envenomDue = (envenomRemains ~= nil and envenomRemains <= 1)
			or APL.Up(DeathmarkDot)
			or (energyPercent ~= nil and energyPercent > 70)
			or (aoe and energyPercent ~= nil and energyPercent > 30)
		if envenomDue and APL.CanCast(Envenom) then return "D5" end
	end

	-- Rebuild. Fan of Knives follows the existing manual AoE toggle.
	if aoe and (comboPoints == nil or comboPoints < spendThreshold) and APL.CanCast(FanOfKnives) then return "D0" end
	-- CanCast also allows Ambush proc windows such as Blindside outside stealth.
	if APL.CanCast(Ambush) then return "D2" end
	if comboPoints == nil or comboPoints < spendThreshold then
		if APL.CanCast(Mutilate) then return "D2" end
	end

	-- Vanish timing depends on Improved Garrote and encounter adds, so it stays manual.
	return nil
end
