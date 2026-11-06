if not LibStub then error("kGenius requires LibStub.") end

local Core = LibStub("AceAddon-3.0"):NewAddon("kGenius", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("kGenius")

local function RegisterSupportedEvent(addon, event, handler)
	-- C_EventUtils.IsEventValid is absent in some client flavors. Validate when
	-- available, then protect registration itself as the final compatibility check.
	if C_EventUtils and C_EventUtils.IsEventValid then
		local ok, valid = pcall(C_EventUtils.IsEventValid, event)
		if ok and not valid then return false end
	end
	local ok
	if handler then
		ok = pcall(addon.RegisterEvent, addon, event, handler)
	else
		ok = pcall(addon.RegisterEvent, addon, event)
	end
	return ok
end

local function CreateIndicator()
	local indicator = _G.GeniusIndicator
	if not indicator then
		indicator = CreateFrame("Frame", "GeniusIndicator", UIParent)
	end
	indicator:SetParent(UIParent)
	indicator:SetSize(120, 22)
	indicator:ClearAllPoints()
	indicator:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	indicator:SetFrameStrata("FULLSCREEN")
	indicator:SetFrameLevel(UIParent:GetFrameLevel() + 10)
	indicator:EnableMouse(true)
	if indicator.SetClampedToScreen then indicator:SetClampedToScreen(true) end

	local color = _G.GeniusIndicatorColor or indicator.Color
	if not color then
		color = indicator:CreateTexture("GeniusIndicatorColor", "ARTWORK")
		color:SetTexture("Interface\\Buttons\\WHITE8x8")
		color:SetSize(18, 18)
		color:SetPoint("LEFT", indicator, "LEFT", 0, 0)
		color:SetVertexColor(0, 0, 0, 1)
	end
	indicator.Color = color

	local label = _G.GeniusIndicatorText or indicator.Label
	if not label then
		label = indicator:CreateFontString("GeniusIndicatorText", "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", color, "RIGHT", 4, 0)
		label:SetWidth(96)
		label:SetJustifyH("LEFT")
		label:SetTextColor(1, 1, 0)
		label:SetText("Genius!")
	end
	indicator.Label = label
	return indicator, color, label
end

local function CreateSwitch(panel, index)
	local name = "GeniusPanelSwitch" .. index
	local switch = _G[name] or CreateFrame("CheckButton", name, panel)
	switch:SetParent(panel)
	switch:SetSize(146, 20)
	switch:ClearAllPoints()
	switch:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12 - ((index - 1) * 23))
	switch:RegisterForClicks("LeftButtonUp")

	local function AddCheckTexture(method, texturePath, layer)
		local texture = switch:CreateTexture(nil, layer)
		texture:SetTexture(texturePath)
		texture:SetSize(18, 18)
		texture:SetPoint("LEFT", switch, "LEFT", 0, 0)
		switch[method](switch, texture)
	end
	AddCheckTexture("SetNormalTexture", "Interface\\Buttons\\UI-CheckBox-Up", "ARTWORK")
	AddCheckTexture("SetPushedTexture", "Interface\\Buttons\\UI-CheckBox-Down", "ARTWORK")
	AddCheckTexture("SetCheckedTexture", "Interface\\Buttons\\UI-CheckBox-Check", "OVERLAY")
	AddCheckTexture("SetHighlightTexture", "Interface\\Buttons\\UI-CheckBox-Highlight", "HIGHLIGHT")

	local labelName = name .. "Text"
	local label = _G[labelName] or switch:CreateFontString(labelName, "OVERLAY", "GameFontHighlight")
	label:ClearAllPoints()
	label:SetPoint("LEFT", switch, "LEFT", 24, 0)
	label:SetWidth(118)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	label:SetTextColor(1, 1, 1)
	switch.Text = label
	return switch
end

local function CreatePanel()
	local panel = _G.GeniusPanel or CreateFrame("Frame", "GeniusPanel", UIParent)
	panel:SetParent(UIParent)
	panel:SetSize(160, 112)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -220)
	panel:SetFrameStrata("BACKGROUND")
	if not panel.Background then
		local background = panel:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints(panel)
		background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		background:SetVertexColor(0.03, 0.03, 0.03, 0.82)
		panel.Background = background
	end
	return panel
end

-- 按键颜色映射
local keys = {
	["D1"] = 10,
	["D2"] = 15,
	["D3"] = 20,
	["D4"] = 25,
	["D5"] = 30,
	["D6"] = 35,
	["D7"] = 40,
	["D8"] = 45,
	["D9"] = 50,
	["D0"] = 55,
	["S-"] = 60,
	["S="] = 65,
	["S`"] = 130,
	["F1"] = 70,
	["F2"] = 75,
	["F3"] = 80,
	["F4"] = 85,
	["F5"] = 90,
	["F6"] = 95,
	["F7"] = 100,
	["F8"] = 105,
	["F9"] = 110,
	["F10"] = 115,
	["F11"] = 120,
	["F12"] = 125,
	["X1"] = 150,
	["X2"] = 155,
	["SPACE"] = 200
}

-- 定时器
local MainTimer = 0

local function IsPlayerInCombat(core)
	if UnitAffectingCombat then
		local ok, inCombat = pcall(UnitAffectingCombat, "player")
		if ok and not (issecretvalue and issecretvalue(inCombat)) then
			if inCombat == true or inCombat == 1 then return true end
			if inCombat == false or inCombat == 0 then return false end
		end
	end
	return core.CombatTime ~= nil and core.CombatTime ~= 0
end

function Core:UpdateIndicator()
	if not IsLeftShiftKeyDown() and self.Auto then
		self:Auto()
	else
		self:Press(nil)
	end
end

local OnUpdate = function(self, elapsed)
	MainTimer = MainTimer + elapsed

	if (MainTimer > 0.05) then
		MainTimer = MainTimer - 0.05
		Core:UpdateIndicator()
	end
end

-- 命令行执行
local OnCommand = function(msg)
	local arg, param = msg:match("^(%S*)%s*(.-)$");
	if arg == "auto" then
		local switch = Core.Switch1 or _G.GeniusPanelSwitch1
		if switch then
			switch:SetChecked(not (IsMetaKeyDown and IsMetaKeyDown()))
		end
		return
	end

	if Core.Manual then
		Core:Manual(arg, param)
	end
end

-- 插件初始化
function Core:OnInitialize()
	-- 控件映射
	local indicator, indicatorColor, indicatorLabel = CreateIndicator()
	self.Indicator = indicator
	self.Indicator.Color = indicatorColor
	self.Label = indicatorLabel

	-- The current client no longer provides the legacy OptionsCheckButtonTemplate.
	-- Build the panel controls directly so every client flavor gets real widgets.
	self.Panel = CreatePanel()
	for index = 1, 4 do
		self["Switch" .. index] = CreateSwitch(self.Panel, index)
	end
	self.Panel:Hide()
	
	-- 声明属性
	self.ShowStanceNotice = true
	self.Talent = 0
	self.Stance = 0
	self.CombatTime = 0
	self.CalcDamage = 0

	-- 天赋方案
	self.Scheme = {}
end

-- 插件启用
function Core:OnEnable()
	self.Indicator:SetFrameStrata("FULLSCREEN")
	if self.Indicator.SetClampedToScreen then self.Indicator:SetClampedToScreen(true) end
	self.Indicator:Show()
	
	-- 注册事件
	RegisterSupportedEvent(self, "VARIABLES_LOADED")			--参数加载
	RegisterSupportedEvent(self, "PLAYER_ALIVE")				--玩家复活
	RegisterSupportedEvent(self, "PLAYER_REGEN_DISABLED")		--进入战斗
	RegisterSupportedEvent(self, "PLAYER_REGEN_ENABLED")		--脱离战斗
	RegisterSupportedEvent(self, "PLAYER_TALENT_UPDATE")		--玩家天赋更新事件
	RegisterSupportedEvent(self, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE")
	RegisterSupportedEvent(self, "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE")
	RegisterSupportedEvent(self, "UPDATE_SHAPESHIFT_FORM")		--玩家姿态切换事件
	RegisterSupportedEvent(self, "UNIT_SPELLCAST_SENT")		--发送施法信息到服务器
	RegisterSupportedEvent(self, "UNIT_SPELLCAST_SUCCEEDED")	--施法成功
	RegisterSupportedEvent(self, "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED")		--施法失败
	RegisterSupportedEvent(self, "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED")	--施法中断
	RegisterSupportedEvent(self, "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_FAILED")	--施法失败
	RegisterSupportedEvent(self, "UI_ERROR_MESSAGE")			--错误消息
	if self.RegisterTargetCastEvents then
		self:RegisterTargetCastEvents()
	end
	
	-- 注册自动刷新
	self.Indicator:SetScript("OnUpdate", OnUpdate)
	self:HookScript(self.Indicator, "OnEnter", "ShowGameTooltip")
	
	-- 注册命令行
	SlashCmdList["GENIUSSLASH"] = OnCommand
	SLASH_GENIUSSLASH1 = "/genius"
	
	-- 显示加载
	if self.Auto or self.Manual then
		self:Printf(L["Module Enabled"], UnitClass("player"))
		self:RefreshTalent(true)
	else
		self:Printf(L["Module Not Found"], UnitClass("player"))
	end
end

-- 插件禁用
function Core:OnDisable()
	self.Indicator:SetScript("OnUpdate", nil)
	if self.UnregisterTargetCastEvents then
		self:UnregisterTargetCastEvents()
	end
end

-- 发送按键信息
function Core:Press(keyName)
	local combatGreen = IsPlayerInCombat(self) and (6 / 255) or 0
	if keyName and keys[keyName] then
		-- 有效按键
		self.Indicator.Color:SetVertexColor(keys[keyName] / 255, 6 / 255, 0, 1)
		self.Label:SetText(keyName)
	else
		-- 无效按键
		self.Indicator.Color:SetVertexColor(0, combatGreen, 0, 1)
		self.Label:SetText(IsLeftShiftKeyDown() and L["Pending"] or L["Waiting"])
	end
end

-- 显示鼠标提示
function Core:ShowGameTooltip()
	GameTooltip:SetOwner(self.Indicator, "ANCHOR_CURSOR")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(L["Information"])
	GameTooltip:AddDoubleLine(L["Talent"], self.Talent or 0, 0, 1, 0)
	GameTooltip:AddDoubleLine(L["Stance"], self.Stance or 0, 0, 1, 0)
	UpdateAddOnMemoryUsage()
	GameTooltip:AddDoubleLine(L["Memory"], format("%.2f",GetAddOnMemoryUsage("Genius")).." KB")
	GameTooltip:Show()
end

-- 显示提醒
function Core:ShowNotifier(text, continue, force)
	if (not GeniusNotifier) then return end
	if (not GeniusNotifier:IsShown()) or force then
		GeniusNotifier.text:SetText(text)
		GeniusNotifier.continue = continue or 1.5
		GeniusNotifier.last = GetTime()
		GeniusNotifier:Show()
		return GeniusNotifier.last
	end
end
