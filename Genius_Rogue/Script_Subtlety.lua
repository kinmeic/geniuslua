if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local APL = Core.RogueAPL
local SW2 = _G["GeniusPanelSwitch2"]
local SW3 = _G["GeniusPanelSwitch3"]
local SW4 = _G["GeniusPanelSwitch4"]

local Kick = APL.Spell(1766)
local Shadowstrike = APL.Spell(185438)
local ShurikenStorm = APL.Spell(197835)
local Gloomblade = APL.Spell(200758)
local Backstab = APL.Spell(53)
local Eviscerate = APL.Spell(196819)
local BlackPowder = APL.Spell(319175)
local SecretTechnique = APL.Spell(280719)
local CoupDeGrace = APL.Spell(441776)
local ShadowDance = APL.Spell(185313, 185422, "player", "HELPFUL|PLAYER")
local ShadowBlades = APL.Spell(121471, 121471, "player", "HELPFUL|PLAYER")
local GoremawsBite = APL.Spell(426591)
local Vanish = APL.Spell(1856)

local StealthBuff = APL.Aura(1784, "player", "HELPFUL|PLAYER")
local VanishBuff = APL.Aura(11327, "player", "HELPFUL|PLAYER")
local DarkestNight = APL.Aura(457280, "player", "HELPFUL|PLAYER")
local DeathstalkersMark = APL.Aura(457129, "target", "HARMFUL|PLAYER")
local ShadowTechniques = APL.Aura(196911, "player", "HELPFUL|PLAYER")
local AncientArts = APL.Aura(1269163, "player", "HELPFUL|PLAYER")
local LingeringShadow = APL.Aura(386081, "player", "HELPFUL|PLAYER")
local Supercharge1 = APL.Aura(470398, "player", "HELPFUL|PLAYER")

function Core:RogueSubtlety(power, comboPoints, stealthed, target, maxComboPoints)
	ShadowDance:Update(true)
	ShadowBlades:Update(true)
	StealthBuff:Update(true)
	VanishBuff:Update(true)
	DarkestNight:Update(true)
	DeathstalkersMark:Update(true)
	ShadowTechniques:Update(true)
	AncientArts:Update(true)
	LingeringShadow:Update(true)
	Supercharge1:Update(true)

	local aoe = APL.IsChecked(SW4)
	local maxCP = maxComboPoints or 5
	local cp = comboPoints
	local energyPercent = APL.EnergyPercent(power)
	local inStealth = APL.AnyUp(stealthed, APL.Up(StealthBuff), APL.Up(VanishBuff), APL.Up(ShadowDance))
	local darkestNightUp = APL.Up(DarkestNight)
	local deathstalkerMarkUp = APL.Up(DeathstalkersMark)
	local shadowDanceUp = APL.Up(ShadowDance)
	local shadowBladesUp = APL.Up(ShadowBlades)
	local secretCooldown = APL.Cooldown(SecretTechnique)
	local secretTechniqueReady = secretCooldown ~= nil and secretCooldown <= 0
	local supercharge1Up = APL.Up(Supercharge1)
	local ancientArtsTalentKnown = APL.Known(1268936)

	if not APL.IsChecked(SW2) and APL.CanBreak(target) and APL.CanCast(Kick) then
		return "S="
	end

	-- Spend Shadow Techniques at the Apex setup point before entering a burst window.
	local shadowTechniqueStacks = APL.Stack(ShadowTechniques)
	if ancientArtsTalentKnown == true and shadowTechniqueStacks ~= nil and shadowTechniqueStacks >= 5
		and APL.Up(AncientArts) == false then
		if aoe and (supercharge1Up == true or secretTechniqueReady)
			and APL.CanCast(ShurikenStorm) then return "D0" end
		if not aoe and cp ~= nil and cp < maxCP then
			local setupWindow = darkestNightUp == true or supercharge1Up == true or secretTechniqueReady
			local lingeringShadowStacks = APL.Stack(LingeringShadow)
			if setupWindow and lingeringShadowStacks ~= nil and lingeringShadowStacks >= 35
				and APL.CanCast(Gloomblade) then return "D2" end
			if setupWindow and APL.CanCast(Shadowstrike) then return "D2" end
		end
	end

	-- Cooldowns: use Goremaw's Bite inside Dance and align Shadow Blades with finishers.
	if shadowDanceUp and APL.Up(AncientArts) == false and APL.CanCast(GoremawsBite) then return "D4" end
	if shadowBladesUp == false and (shadowDanceUp or (cp ~= nil and cp >= maxCP - 1))
		and APL.CanCast(ShadowBlades) then
		return "D9"
	end

	-- Shadow Dance is automatic unless the manual Dance switch is enabled.
	if not APL.IsChecked(SW3) and inStealth == false and energyPercent ~= nil and energyPercent >= 30
		and cp ~= nil and ((cp >= maxCP - 1) or (cp <= 2 and deathstalkerMarkUp))
		and APL.CanCast(ShadowDance) then
		return "D3"
	end

	-- Vanish is useful as an extra stealth window at low combo points.
	if inStealth == false and energyPercent ~= nil and energyPercent >= 50
		and cp ~= nil and cp <= 2 and APL.CanCast(Vanish) then
		return "D3"
	end

	local finishThreshold = maxCP
	if darkestNightUp == false then finishThreshold = math.max(1, maxCP - 1) end
	if cp ~= nil and cp >= finishThreshold then
		if shadowDanceUp and APL.CanCast(SecretTechnique) then return "D5" end

		local shadowDanceCooldown = APL.Cooldown(ShadowDance)
		if shadowDanceUp == false and secretCooldown ~= nil and secretCooldown <= 0
			and shadowDanceCooldown ~= nil and shadowDanceCooldown > 0
			and APL.CanCast(SecretTechnique) then
			return "D5"
		end

		if aoe and APL.CanCast(BlackPowder) then return "D0" end
		if APL.CanCast(CoupDeGrace) then return "D5" end
		if APL.CanCast(Eviscerate) then return "D5" end
	end

	-- Builders follow the APL: Shadowstrike in stealth, Shuriken Storm for AoE,
	-- then Gloomblade/Backstab as single-target fillers.
	if aoe and APL.CanCast(ShurikenStorm) then return "D0" end
	if inStealth == true and APL.CanCast(Shadowstrike) then return "D2" end
	if inStealth == false and APL.CanCast(Gloomblade) then return "D2" end
	if inStealth == false and APL.CanCast(Backstab) then return "D2" end
	return nil
end
