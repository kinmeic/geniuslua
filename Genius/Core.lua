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

function Core:SavePanelPosition()
	if not self.Panel or not self.db then return end
	local x, top = self.Panel:GetLeft(), self.Panel:GetTop()
	if type(x) ~= "number" or type(top) ~= "number" then return end
	local y = top - UIParent:GetHeight()
	self.db.panelPosition = { x = x, y = y }
	self.Panel:ClearAllPoints()
	self.Panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

function Core:SetPanelUnlocked(unlocked)
	if not self.Panel then return end
	unlocked = unlocked == true
	self.db.panelUnlocked = unlocked
	self.PanelUnlocked = unlocked
	self.Panel:SetMovable(unlocked)
	self.Panel:SetFrameStrata(unlocked and "DIALOG" or self.Panel.LockedFrameStrata)
	if self.Panel.DragHandle then
		self.Panel.DragHandle:SetShown(unlocked)
	end
	if unlocked then
		self.Panel:Show()
	elseif not (self.Auto or self.Manual) then
		self.Panel:Hide()
	end
end

function Core:RegisterOptions()
	if self.SettingsCategory or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
	local category = Settings.RegisterVerticalLayoutCategory("Genius")
	local setting = Settings.RegisterProxySetting(
		category,
		"Genius_UnlockPanel",
		type(false),
		L["Unlock Panel"],
		self.db.panelUnlocked == true,
		function() return self.db.panelUnlocked == true end,
		function(value) self:SetPanelUnlocked(value) end
	)
	Settings.CreateCheckbox(category, setting)
	Settings.RegisterAddOnCategory(category)
	self.SettingsCategory = category
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
	GeniusDB = type(GeniusDB) == "table" and GeniusDB or {}
	self.db = GeniusDB
	if type(self.db.panelUnlocked) ~= "boolean" then self.db.panelUnlocked = false end

	-- Widgets and their layout are defined in XML before this file loads.
	self.Indicator = assert(_G.GeniusIndicator, "GeniusIndicator is missing from indicator.xml")
	self.Indicator.Color = assert(_G.GeniusIndicatorColor, "GeniusIndicatorColor is missing from indicator.xml")
	self.Label = assert(_G.GeniusIndicatorText, "GeniusIndicatorText is missing from indicator.xml")
	self.Indicator.Label = self.Label

	self.Panel = assert(_G.GeniusPanel, "GeniusPanel is missing from switchs.xml")
	self.Panel.Background = _G.GeniusPanelBackground
	self.Panel.DragHandle = assert(_G.GeniusPanelDragHandle, "GeniusPanelDragHandle is missing from switchs.xml")
	self.Panel.DragHandle.Text = assert(_G.GeniusPanelDragHandleText, "GeniusPanelDragHandleText is missing from switchs.xml")
	self.Panel.DragHandle.Text:SetText(L["Drag Panel"])
	self.Panel.LockedFrameStrata = self.Panel:GetFrameStrata()
	self.Panel:SetMovable(false)
	if self.Panel.SetClampedToScreen then self.Panel:SetClampedToScreen(true) end
	local position = self.db.panelPosition
	if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
		self.Panel:ClearAllPoints()
		self.Panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", position.x, position.y)
	end
	self.Panel.DragHandle:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and Core.PanelUnlocked then Core.Panel:StartMoving() end
	end)
	self.Panel.DragHandle:SetScript("OnMouseUp", function()
		if Core.PanelUnlocked then
			Core.Panel:StopMovingOrSizing()
			Core:SavePanelPosition()
		end
	end)
	for index = 1, 4 do
		local name = "GeniusPanelSwitch" .. index
		local switch = assert(_G[name], name .. " is missing from switchs.xml")
		switch.Text = assert(_G[name .. "Text"], name .. "Text is missing from switchs.xml")
		self["Switch" .. index] = switch
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
	self.Indicator:Show()
	self:RegisterOptions()
	self:SetPanelUnlocked(self.db.panelUnlocked)
	
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
