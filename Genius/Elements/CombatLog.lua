local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local L = LibStub("AceLocale-3.0"):GetLocale("kGenius")

local TargetCastEvents = CreateFrame("Frame")
local watchedEvents = {
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_STOP",
}

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function GetSpellName(spellID)
	if not spellID or IsSecret(spellID) then return end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and not IsSecret(name) then return name end
	elseif C_Spell and C_Spell.GetSpellInfo then
		local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
		if not ok then return end
		if spellInfo and not IsSecret(spellInfo) and not (issecrettable and issecrettable(spellInfo)) then
			local name = spellInfo.name
			if not IsSecret(name) then return name end
		end
	elseif GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and not IsSecret(name) then return name end
	end
end

function Core:RegisterTargetCastEvents()
	TargetCastEvents:UnregisterAllEvents()
	local registered = false

	for _, event in ipairs(watchedEvents) do
		local valid = true
		if C_EventUtils and C_EventUtils.IsEventValid then
			local ok, result = pcall(C_EventUtils.IsEventValid, event)
			if ok then valid = result end
		end
		if valid then
			local ok = pcall(TargetCastEvents.RegisterUnitEvent, TargetCastEvents, event, "target")
			registered = registered or ok
		end
	end

	if registered then
		TargetCastEvents:SetScript("OnEvent", function(_, event, unit, castGUID, spellID, interruptedBy, castBarID)
			Core:TARGET_SPELL_INTERRUPTED(event, unit, castGUID, spellID, interruptedBy, castBarID)
		end)
	end
end

function Core:UnregisterTargetCastEvents()
	TargetCastEvents:UnregisterAllEvents()
	TargetCastEvents:SetScript("OnEvent", nil)
end

function Core:TARGET_SPELL_INTERRUPTED(event, unit, castGUID, spellID, interruptedBy, castBarID)
	-- Target spell data and event payloads may be secret during restricted combat.
	-- Only report when the interrupt source and spell details are readable.
	if IsSecret(unit) or IsSecret(spellID) or IsSecret(interruptedBy) then return end
	if interruptedBy ~= UnitGUID("player") then return end

	local targetName = UnitName("target")
	local spellName = GetSpellName(spellID)
	if IsSecret(targetName) or IsSecret(spellName) then return end
	if not targetName or not spellName then return end

	self:Printf(L["Break Success"], targetName, spellName)
end
