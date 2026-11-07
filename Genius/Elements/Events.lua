local select = select

-- 单位定义
local LibUnit = LibStub("LibUnit-6.0")
local Player = LibUnit:New("player")

local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")
local L = LibStub("AceLocale-3.0"):GetLocale("kGenius")

local function GetTalentName(index)
	if not index or index == 0 then return end

	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local _, name = C_SpecializationInfo.GetSpecializationInfo(index, false)
		return name
	elseif GetSpecializationInfo then
		return select(2, GetSpecializationInfo(index, false))
	end
end

local function GetSpellName(spellID)
	if not spellID or (issecretvalue and issecretvalue(spellID)) then return end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and not (issecretvalue and issecretvalue(name)) then return name end
	elseif C_Spell and C_Spell.GetSpellInfo then
		local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and spellInfo and not (issecrettable and issecrettable(spellInfo)) then
			local name = spellInfo.name
			if not (issecretvalue and issecretvalue(name)) then return name end
		end
	elseif GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and not (issecretvalue and issecretvalue(name)) then return name end
	end
end

function Core:VARIABLES_LOADED()
	self.Talent = Player:GetTalent()
	self.Stance = Player:GetStance()
end

function Core:PLAYER_ALIVE()
	self.Talent = Player:GetTalent()
	self.Stance = Player:GetStance()
end

function Core:PLAYER_REGEN_DISABLED()
	self:Print(L["Enter Combat"])
	self:ShowNotifier(L["Enter Combat"])
	self.CombatTime = GetTime()
	if self["ENTER_COMBAT"] then
		self["ENTER_COMBAT"](self)
	end
	self:UpdateIndicator()
end

function Core:PLAYER_REGEN_ENABLED()
	self:Print(L["Leave Combat"])
	self:ShowNotifier(L["Leave Combat"])
	self.CombatTime = 0
	if self["LEAVE_COMBAT"] then
		self["LEAVE_COMBAT"](self)
	end
	self:UpdateIndicator()
end

function Core:RefreshTalent(showNotice)
	self.Talent = Player:GetTalent()
	self.Stance = Player:GetStance()
	if showNotice and self.Talent and self.Talent > 0 then
		local talentName = GetTalentName(self.Talent) or L["Normal"]
		self:Printf(L["Change Talent"], talentName)
	end
	if self["TALENT_CHANGED"] then
		self["TALENT_CHANGED"](self, self.Talent)
	end
end

function Core:PLAYER_TALENT_UPDATE()
	self:RefreshTalent(true)
end

function Core:UPDATE_SHAPESHIFT_FORM()
	if Player:GetStance() == self.Stance then return end
	if self.ShowStanceNotice == false then return end
	self.Stance = Player:GetStance()
	if self.Stance ~= 0 then
		local _, _, _, spellID = GetShapeshiftFormInfo(self.Stance)
		local stanceName = GetSpellName(spellID) or L["Normal"]
		self:Printf(L["Change Stance"], stanceName)
	else
		self:Printf(L["Change Stance"], L["Normal"])
	end
end

function Core:UNIT_SPELLCAST_SENT(event, unit, target, castGUID, spellID)
	if unit ~= "player" then return end
	self:Press(nil)
	if self["SPELLCAST_SENTED"] then
		self["SPELLCAST_SENTED"](self, GetSpellName(spellID), spellID, target, castGUID)
	end
end

function Core:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID, castBarID)
	if unit ~= "player" then return end
	local LibSpell = LibStub("LibSpells-4.3", true)
	if LibSpell then LibSpell:RecordAuraCast(spellID) end
	if self["SPELLCAST_SUCCEEDED"] then
		self["SPELLCAST_SUCCEEDED"](self, GetSpellName(spellID), spellID, castGUID, castBarID)
	end
end

-- 施法失败
function Core:UNIT_SPELLCAST_FAILED(event, unit, castGUID, spellID, interruptedBy, castBarID)
	if unit ~= "player" then return end
	self:Press(nil)
	if self["SPELLCAST_FAILED"] then
		if event ~= "UNIT_SPELLCAST_INTERRUPTED" then
			castBarID = interruptedBy
			interruptedBy = nil
		end
		self["SPELLCAST_FAILED"](self, GetSpellName(spellID), event, spellID, castGUID, interruptedBy, castBarID)
	end
end

-- error message on center of window
function Core:UI_ERROR_MESSAGE(event, errorType, message)
	if self["NEW_ERROR_MESSAGE"] then
		self["NEW_ERROR_MESSAGE"](self, message, errorType)
	end
end

