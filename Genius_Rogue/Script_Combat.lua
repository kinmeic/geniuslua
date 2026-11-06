if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local APL = Core.RogueAPL
local SW2 = _G["GeniusPanelSwitch2"]
local SW3 = _G["GeniusPanelSwitch3"]
local SW4 = _G["GeniusPanelSwitch4"]

local Kick = APL.Spell(1766)
local Ambush = APL.Spell(8676)
-- Forever keeps Sinister Strike as a ranked Classic spell (1752 and later
-- ranks). Resolve its localized spell name so the client uses the highest
-- learned rank instead of the unrelated/deprecated 193315 ID.
local SinisterStrike = APL.Spell(1752)
local SinisterStrikeByName = APL.RankedSpell(1752)
local PistolShot = APL.Spell(185763)
local Dispatch = APL.Spell(2098)
local BetweenTheEyes = APL.Spell(315341)
local CoupDeGrace = APL.Spell(441776)
local Eviscerate = APL.Spell(6760)
local KillingSpree = APL.Spell(51690)
local AdrenalineRush = APL.Spell(13750)
local BladeFlurry = APL.Spell(13877)
local BladeRush = APL.Spell(271877)
local Preparation = APL.Spell(1277933)
local KeepItRolling = APL.Spell(381989)
local RollTheBones = APL.Spell(1214909)

local Opportunity = APL.Aura(195627, "player", "HELPFUL|PLAYER")
local Audacity = APL.Aura(386270, "player", "HELPFUL|PLAYER")
local LoadedDice = APL.Aura(256171, "player", "HELPFUL|PLAYER")
local AdrenalineRushBuff = APL.Aura(13750, "player", "HELPFUL|PLAYER")
local BladeFlurryBuff = APL.Aura(13877, "player", "HELPFUL|PLAYER")
local Supercharge1 = APL.Aura(470398, "player", "HELPFUL|PLAYER")
local Supercharge2 = APL.Aura(470406, "player", "HELPFUL|PLAYER")
local RTBBuffs = LibStub("LibSpells-4.3"):NewAuras(
	{ 193356, 193357, 193358, 193359, 199600, 199603 }, "player", "HELPFUL|PLAYER")

function Core:RogueCombat(power, comboPoints, stealthed, target, maxComboPoints)
	Opportunity:Update(true)
	Audacity:Update(true)
	LoadedDice:Update(true)
	AdrenalineRushBuff:Update(true)
	BladeFlurryBuff:Update(true)
	Supercharge1:Update(true)
	Supercharge2:Update(true)
	RTBBuffs:Update()

	local aoe = APL.IsChecked(SW4)
	local maxCP = maxComboPoints or 5
	local cp = comboPoints
	local energyPercent = APL.EnergyPercent(power)
	local rtbCount
	if RTBBuffs.timeleftKnown ~= false then rtbCount = RTBBuffs.affects end
	local opportunityRemains = APL.Remains(Opportunity)
	local loadedDiceUp = APL.Up(LoadedDice)

	if not APL.IsChecked(SW2) and APL.CanBreak(target) and APL.CanCast(Kick) then
		return "S="
	end

	local adrenalineRushUp = APL.Up(AdrenalineRushBuff)
	local bladeFlurryUp = APL.Up(BladeFlurryBuff)
	local betweenTheEyesCooldown = APL.Cooldown(BetweenTheEyes)
	if not APL.IsChecked(SW3) and adrenalineRushUp == false and APL.CanCast(AdrenalineRush) then
		return "D4"
	end

	if aoe and bladeFlurryUp == false and APL.CanCast(BladeFlurry) then return "D3" end
	if rtbCount ~= nil and rtbCount >= 3 and APL.CanCast(KeepItRolling) then return "D8" end
	local betweenTheEyesReady = betweenTheEyesCooldown ~= nil and betweenTheEyesCooldown <= 0
	local rerollThreshold
	if loadedDiceUp == false or (loadedDiceUp == true and betweenTheEyesCooldown ~= nil and not betweenTheEyesReady) then
		rerollThreshold = 1
	elseif loadedDiceUp == true and betweenTheEyesReady then
		rerollThreshold = 2
	end
	if rtbCount ~= nil and (rtbCount == 0 or (rerollThreshold ~= nil and rtbCount == rerollThreshold))
		and APL.CanCast(RollTheBones) then
		return "D8"
	end

	if not APL.IsChecked(SW3) and APL.CanCast(BladeRush)
		and (aoe or energyPercent ~= nil and energyPercent < 80) then
		return "D9"
	end

	if not APL.IsChecked(SW3) then
		local adrenalineCooldown = APL.Cooldown(AdrenalineRush)
		local betweenTheEyesNotReady = betweenTheEyesCooldown ~= nil and betweenTheEyesCooldown > 0
		local killingSpreeCooldown = APL.Cooldown(KillingSpree)
		local killingSpreeNotReady = killingSpreeCooldown ~= nil and killingSpreeCooldown > 0
		if APL.CanCast(Preparation) and adrenalineCooldown ~= nil and adrenalineCooldown > 30
			and betweenTheEyesNotReady and killingSpreeNotReady then
			return "D4"
		end
	end

	local finishThreshold = math.max(1, maxCP - 1)
	if cp ~= nil and cp >= finishThreshold then
		local holdBetweenTheEyes = APL.Up(Supercharge1) == true and APL.Up(Supercharge2) == false
		if not holdBetweenTheEyes and APL.CanCast(BetweenTheEyes) then return "D5" end

		local adrenalineCooldown = APL.Cooldown(AdrenalineRush)
		if (APL.Up(Supercharge1) or (adrenalineCooldown ~= nil and adrenalineCooldown > 120))
			and APL.CanCast(KillingSpree) then
			return "D0"
		end

		if APL.CanCast(CoupDeGrace) then return "D5" end
		if APL.CanCast(Dispatch) then return "D5" end
		if APL.CanCast(Eviscerate, nil, true, true) then return "D5" end
	end

	-- Hidden Opportunity and Audacity make Ambush the preferred builder.
	if stealthed == true and APL.Up(Audacity) and APL.CanCast(Ambush) then return "D2" end

	local opportunityUp = APL.Up(Opportunity)
	if opportunityUp and APL.CanCast(PistolShot)
		and ((cp ~= nil and cp >= maxCP - 1)
			or (opportunityRemains ~= nil and opportunityRemains < 2)) then
		return "D6"
	end

	if stealthed == true and APL.CanCast(Ambush) then return "D2" end
	-- Sinister Strike has no individual cooldown. Its cooldown/charge query can
	-- be restricted during combat, and Forever may hide range; only reject an
	-- explicit out-of-range result here.
	if APL.CanCast(SinisterStrike, nil, true, true)
		or APL.CanCast(SinisterStrikeByName, nil, true, true) then
		return "D2"
	end
	if opportunityUp and APL.CanCast(PistolShot) then return "D6" end
	return nil
end
