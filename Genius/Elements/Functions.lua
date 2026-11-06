local Core = LibStub("AceAddon-3.0"):GetAddon("kGenius")

local LibSpells = LibStub("LibSpells-4.3")
local SpellCheckers = {}

-- Shared spell availability check used by helpers such as CanDispel.
-- Cache the LibSpells objects because the main update loop may query them often.
function Core:CanCast(spellID, targetUnit)
	if type(spellID) ~= "number" and type(spellID) ~= "string" then return nil end
	local checker = SpellCheckers[spellID]
	if not checker then
		checker = LibSpells:New(spellID)
		SpellCheckers[spellID] = checker
	end
	return checker:CanCast(targetUnit)
end

local function GetAuraField(aura, field)
	if issecretvalue and issecretvalue(aura) then return end
	if not aura then return end
	if issecrettable and issecrettable(aura) then return end
	local value = aura[field]
	if issecretvalue and issecretvalue(value) then return end
	return value
end

local function GetAuraDataByIndex(unit, index, filter)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
	if ok then return aura end
end

--是否可以驱散
function Core:CanDispel(unit, spellName, dispelType)
	local name, auraType = nil, nil

	for i = 1, 40 do
		local aura = GetAuraDataByIndex(unit, i, "HARMFUL|RAID")
		name = GetAuraField(aura, "name")
		
		if not name then
			return
		else
			auraType = GetAuraField(aura, "dispelName")
			if dispelType then
				if dispelType == auraType then
					return Core:CanCast(spellName, unit)
				end
			else
				return Core:CanCast(spellName, unit)
			end
		end
	end
end

--是否能爆发
function Core:CanBurst()
	local level = UnitLevel("target")
	if issecretvalue and issecretvalue(level) then return nil end
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or UnitLevel("player")
	if issecretvalue and issecretvalue(maxLevel) then return nil end
	if level and level > 0 and maxLevel and level < maxLevel then return end
	
	local class = UnitClassification("target")
	if issecretvalue and issecretvalue(class) then return nil end
	if class == "elite" or class == "worldboss" then
		local canAttack = UnitCanAttack("player", "target")
		if issecretvalue and issecretvalue(canAttack) then return nil end
		return canAttack
	end
end

--是否装备了指定雕纹
function Core:SearchGlyph(id)
	-- Glyph sockets are not part of the Forever API. nil means unsupported;
	-- false is reserved for a supported search that found no matching glyph.
	if not GetGlyphSocketInfo or not NUM_GLYPH_SLOTS then return nil end
	for i = 1, NUM_GLYPH_SLOTS do
		local _, _, _, glyphSpell = GetGlyphSocketInfo(i)
		if glyphSpell and glyphSpell == id then
			return true
		end
	end
end


