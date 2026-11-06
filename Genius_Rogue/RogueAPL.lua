if select(2, UnitClass("player")) ~= "ROGUE" then return end

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local LibSpell = LibStub("LibSpells-4.3")
local APL = {}

function APL.Spell(spellID, auraID, unit, filter)
	return LibSpell:New(spellID, auraID, unit, filter)
end

-- Resolve a ranked spell ID to its localized name so SpellIdentifier-based
-- APIs select the highest rank the player has learned.
function APL.RankedSpell(spellID)
	local identifier = spellID
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and spellInfo and not (issecrettable and issecrettable(spellInfo)) then
			local name = spellInfo.name
			if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
				identifier = name
			end
		end
	end
	return LibSpell:New(identifier)
end

function APL.Aura(spellID, unit, filter)
	return LibSpell:New(nil, spellID, unit, filter)
end

function APL.CanCast(spell, targetUnit, ignoreCooldown, allowUnknownRange)
	if not spell then return false end
	-- Accept either a unit token or a LibUnit object.
	if type(targetUnit) == "table" then targetUnit = targetUnit.unit end
	local ok, result = pcall(spell.CanCast, spell, targetUnit, ignoreCooldown, allowUnknownRange)
	if not ok or (issecretvalue and issecretvalue(result)) then return false end
	return result == true
end

function APL.CanBreak(target)
	if not target then return false end
	local ok, result = pcall(target.CanBreak, target)
	if not ok or (issecretvalue and issecretvalue(result)) then return false end
	return result == true
end

function APL.Known(spellID)
	local foundFalse
	if IsPlayerSpell then
		local ok, known = pcall(IsPlayerSpell, spellID)
		if ok and not (issecretvalue and issecretvalue(known)) then
			if known == true or known == 1 then return true end
			if known == false or known == 0 then foundFalse = true end
		end
	end
	if IsSpellKnown then
		local ok, known = pcall(IsSpellKnown, spellID)
		if ok and not (issecretvalue and issecretvalue(known)) then
			if known == true or known == 1 then return true end
			if known == false or known == 0 then foundFalse = true end
		end
	end
	if foundFalse then return false end
	return nil
end

function APL.Up(aura)
	if not aura then return false end
	local ok, result = pcall(aura.Up, aura)
	if not ok or (issecretvalue and issecretvalue(result)) then return nil end
	if result == true or result == false then return result end
	return nil
end

function APL.AnyUp(...)
	local unknown = false
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value == true then return true end
		if value ~= false then unknown = true end
	end
	if unknown then return nil end
	return false
end

function APL.Remains(aura)
	if not aura then return nil end
	local ok, result = pcall(aura.GetRemainingTime, aura)
	if not ok or (issecretvalue and issecretvalue(result)) or type(result) ~= "number" then return nil end
	return result
end

function APL.Stack(aura)
	if not aura then return nil end
	local ok, result = pcall(aura.GetStack, aura)
	if not ok or (issecretvalue and issecretvalue(result)) or type(result) ~= "number" then return nil end
	return result
end

function APL.Refreshable(aura)
	if not aura then return false end
	local ok, result = pcall(aura.NeedRefresh, aura)
	if not ok or (issecretvalue and issecretvalue(result)) then return false end
	return result == true
end

function APL.Cooldown(spell)
	if not spell then return nil end
	local ok, remaining = pcall(spell.GetCooldown, spell)
	if not ok or (issecretvalue and issecretvalue(remaining)) or type(remaining) ~= "number" then return nil end
	return remaining
end

function APL.Charges(spell)
	if not spell then return nil, nil end
	local ok, current, maximum = pcall(spell.GetCharges, spell)
	if not ok or (issecretvalue and (issecretvalue(current) or issecretvalue(maximum))) then return nil, nil end
	if type(current) ~= "number" or type(maximum) ~= "number" then return nil, nil end
	return current, maximum
end

function APL.IsChecked(button)
	if not button then return false end
	local ok, checked = pcall(button.GetChecked, button)
	return ok and (checked == true or checked == 1)
end

function APL.EnergyPercent(power)
	if issecretvalue and issecretvalue(power) then return nil end
	if type(power) ~= "number" or not UnitPowerMax then return nil end
	local energyPowerType = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
	local ok, maximum = pcall(UnitPowerMax, "player", energyPowerType)
	if not ok or (issecretvalue and issecretvalue(maximum)) or type(maximum) ~= "number" or maximum <= 0 then return nil end
	return power / maximum * 100
end

Core.RogueAPL = APL
