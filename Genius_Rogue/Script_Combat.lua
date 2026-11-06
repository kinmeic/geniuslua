if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local APL = Core.RogueAPL
local Switch2 = _G.GeniusPanelSwitch2

local Kick = APL.Spell(1766)
local SliceAndDice = APL.Spell(5171, 5171, "player", "HELPFUL|PLAYER")
local SliceAndDiceByName = APL.RankedSpell(5171, 5171, "player", "HELPFUL|PLAYER")
local Eviscerate = APL.Spell(6760)
local EviscerateByName = APL.RankedSpell(6760)
local SinisterStrike = APL.Spell(1752)
local SinisterStrikeByName = APL.RankedSpell(1752)

local function CanCastRanked(spell, rankedSpell)
	return APL.CanCast(spell, nil, true, true) or APL.CanCast(rankedSpell, nil, true, true)
end

function Core:RogueCombat(power, comboPoints, stealthed, target, maxComboPoints)
	if not APL.IsChecked(Switch2) and APL.CanBreak(target) and APL.CanCast(Kick, nil, false, true) then
		return "S="
	end

	SliceAndDice:Update()
	local sliceRemains = APL.Remains(SliceAndDice)
	local inOpener = self.CombatTime > 0 and GetTime() - self.CombatTime < 5
	if sliceRemains ~= nil and sliceRemains <= 2
		and (inOpener or comboPoints ~= nil and comboPoints >= 2)
		and CanCastRanked(SliceAndDice, SliceAndDiceByName) then
		return "D6"
	end

	local maxCP = maxComboPoints or 5
	local finishAt = math.max(1, maxCP - 1)
	if comboPoints ~= nil and comboPoints >= finishAt
		and CanCastRanked(Eviscerate, EviscerateByName) then
		return "D5"
	end

	if (comboPoints == nil or comboPoints < maxCP)
		and CanCastRanked(SinisterStrike, SinisterStrikeByName) then
		return "D2"
	end
end
