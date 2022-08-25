local Actions = {
	pickableItems = {},
	combineRules = {}
}
local CellType = require("CellType")
local World = require("World")
local CellTypeInv = require("CellTypeInv")
local CellAnimType = require("CellAnimType")
local GameConsts = require("GameConsts")


---@class CombineRule
local CombineRule = {
	charType = CellType.Any,
	itemType = CellType.Any,
	groundType = CellType.Any,
	newCharType = CellType.Any,
	newItemType = CellType.Any,
	newGroundType = CellType.Any,
}
function CombineRule.preCondition(character : Character) : boolean
	return true
end
function CombineRule:callback(character : Character, pos : Vector2Int) 

end

---@class CharacterCommand
local CharacterCommand = {}
function CharacterCommand:Execute()

end

function Actions.RuleToString(rule)
	if not rule then
		return "nil"
	end
	return string.format("char/item/ground %s/%s/%s -> %s/%s/%s", CellTypeInv[rule.charType], CellTypeInv[rule.itemType], CellTypeInv[rule.groundType],
															CellTypeInv[rule.newCharType], CellTypeInv[rule.newItemType], CellTypeInv[rule.newGroundType])
end

function Actions:Init()
	self:Term()

	self:RegisterPickableItems()
	self:RegisterAllCombineRules()
end

function Actions:RegisterPickableItems()
	local pickableItems = self.pickableItems

	for i = 1, GameConsts.maxWheatStackSize, 1 do
		pickableItems[CellType.WheatCollected_1 - 1 + i] = true
	end
	for i = 1, GameConsts.maxBreadStackSize, 1 do
		pickableItems[CellType.Bread_1 - 1 + i] = true
	end
	pickableItems[CellType.Wood] = true
	pickableItems[CellType.Stone] = true
	pickableItems[CellType.Fence] = true
	pickableItems[CellType.FlintStone] = true
	pickableItems[CellType.Flour] = true
	pickableItems[CellType.Stove] = true
	pickableItems[CellType.StoveWithWood] = true
end

function Actions:IsPickable(itemType)
	return self.pickableItems[itemType]
end

function Actions:IsSubtype(childType : integer, parentType : integer) : boolean
	if parentType == CellType.Any then
		return true
	end
	if childType == parentType then
		return true
	end
	if CellType.WheatCollected_Any == parentType then
		if childType >= CellType.WheatCollected_1 and childType <= CellType.WheatCollected_1 + GameConsts.maxWheatStackSize - 1 then
			return true
		end
	end
	if CellType.Bread_Any == parentType then
		if childType >= CellType.Bread_1 and childType <= CellType.Bread_1 + GameConsts.maxBreadStackSize - 1 then
			return true
		end
	end
	return false
end

function Actions:GetDropRule(itemType : integer) : CombineRule|nil
	return self:GetCombineRule(nil, itemType, CellType.None, CellType.Any) --TODO not exactly (wheat will be planted on prepared ground)
end

function Actions:GetPickupRule(itemType : integer) : CombineRule|nil
	return self:GetCombineRule(nil, CellType.None, itemType, CellType.Any) --TODO not exactly (not examples sorry =|)
end

function Actions:Term()
	self.pickableItems = {}
end

function Action_ExecuteRule(character, intPos, rule)
	local action = {}
	action.rule = rule
	action.intPos = intPos
	action.character = character
	function action:Execute()
		--do return end
		if rule.isCustom then
			if rule.callback then
				rule.callback(character, intPos)
			else
				print("Custom rule without callback ", Actions.RuleToString(rule))
			end
			return
		end
		if rule.newCharType ~= CellType.Any then
			character:SetItem(rule.newCharType)
		end

		if rule.newItemType ~= CellType.Any then
			local cell = World.items:GetCell(intPos)
			cell.type = rule.newItemType
			World.items:SetCell(cell)
		end

		if rule.newGroundType ~= CellType.Any then
			local cell = World.ground:GetCell(intPos)
			cell.type = rule.newGroundType
			World.ground:SetCell(cell)
		end

		if rule.callback then
			rule.callback(character, intPos)
		end
	end

	return action
end

function Action_TransformWithGround(character, intPos, newItemOnCharacter, newItemAtCell, newGroundItem, callback)
	local rule = { newCharType = newItemOnCharacter, newItemType = newItemAtCell, newGroundType = newGroundItem,
		callback = callback }
	return Action_ExecuteRule(character, intPos, rule)
end

function Action_Transform(character, intPos, newItemOnCharacter, newItemAtCell)
	return Action_TransformWithGround(character, intPos, newItemOnCharacter, newItemAtCell, CellType.Any)
end

function Actions:RegisterCombineRule_Custom(charType, itemType, groundType, newCharType, newItemType, newGroundType,
                                            callback)
	local rule = self:RegisterCombineRuleForItemAndGround(charType, itemType, groundType, newCharType, newItemType,
		newGroundType
		, callback)
	if rule == nil then
		return nil
	end
	rule.isCustom = true
	return rule
end

---@return CombineRule[]
function Actions:GetAllCombineRules(charType : integer, itemType : integer, groundType : integer)
	local result = {}
	for key, value in pairs(self.combineRules) do
		if not self:IsSubtype(key, charType) then
			continue
		end
		for key2, value2 in pairs(value) do
			if not self:IsSubtype(key2, itemType) then
				continue
			end
			for key3, value3 in pairs(value2) do
				if self:IsSubtype(key3, groundType) then
					for index, rule in ipairs(value3) do
						table.insert(result, rule)
					end
				end
			end
		end
	end
	return result
end

function Actions:RegisterCombineRuleForItemAndGround(charType, itemType, groundType, newCharType, newItemType,
                                                     newGroundType,
                                                     callback) : CombineRule
	local rule = {charType = charType, itemType = itemType, groundType = groundType, newCharType = newCharType, newGroundType = newGroundType, newItemType = newItemType, callback = callback }
	local charRules = self.combineRules[charType]
	if charRules == nil then
		charRules = {}
		self.combineRules[charType] = charRules
	end
	local itemRules = charRules[itemType]
	if itemRules == nil then
		itemRules = {}
		charRules[itemType] = itemRules
	end
	if itemRules[groundType] == nil then
		itemRules[groundType] = {}
	end
	table.insert(itemRules[groundType], rule)
	return rule
end

function Actions:RegisterCombineRule(charType, itemType, newCharType, newItemType, callback)
	return self:RegisterCombineRuleForItemAndGround(charType, itemType, CellType.Any, newCharType, newItemType, CellType.Any
		,
		callback)
end

function Actions:RegisterCombineRuleForGround(charType, groundType, newCharType, newGroundType, callback)
	return self:RegisterCombineRuleForItemAndGround(charType, CellType.Any, groundType, newCharType, CellType.Any,
		newGroundType
		, callback)
end

function Actions:GetCombineRule_NoAnyChecks(character : Character|nil, charType : integer, itemType : integer, groundType : integer)
	local charRules = self.combineRules[charType]
	if charRules == nil then
		return nil
	end
	local itemRules = charRules[itemType]
	if itemRules == nil then
		return nil
	end
	local rules = itemRules[groundType]
	if not rules then
		return nil
	end
	for i, rule in ipairs(rules) do
		if not rule.preCondition or not character or rule.preCondition(character) then
			return rule
		end
	end
	return nil
end

function Actions:GetCombineRule(character : Character|nil, charType : integer, itemType : integer, groundType : integer) : CombineRule|nil
	local rule = self:GetCombineRule_NoAnyChecks(character, charType, itemType, groundType)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, charType, itemType, CellType.Any)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, charType, CellType.Any, groundType)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, charType, CellType.Any, CellType.Any)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, CellType.Any, itemType, groundType)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, CellType.Any, CellType.Any, groundType)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, CellType.Any, itemType, CellType.Any)
	if rule then return rule end
	rule = self:GetCombineRule_NoAnyChecks(character, CellType.Any, CellType.Any, CellType.Any)
	if rule then return rule end
	return nil
end

function SetAppearAnimation(cell)
	cell.animType = CellAnimType.ItemAppear
	cell.animT = 0.0
	cell.animStopT = 0.1
end

function RuleCallback_ItemAppear(character, intPos)
	local cell = World.items:GetCell(intPos)
	if cell.type ~= CellType.None then
		SetAppearAnimation(cell)
		World.items:SetCell(cell)
	end
end

function RuleCallback_EatBread(character, intPos)
	local cell = World.items:GetCell(intPos)
	if cell.type >= CellType.Bread_1 and cell.type <= CellType.Bread_1 - 1 + GameConsts.maxBreadStackSize then
		if cell.type == CellType.Bread_1 then
			cell.type = CellType.None
		else
			cell.type = cell.type - 1
		end
		-- TODO dec character hunger
		character.hunger = character.hunger - 0.25
		World.items:SetCell(cell)
	end
end

function Actions:RegisterAllCombineRules()
	self.combineRules = {}

	self:RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.GroundPrepared, CellType.None,
		CellType.WheatCollected_2, CellType.Ground, RuleCallback_ItemAppear)
	self:RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.Any, CellType.None,
		CellType.WheatCollected_2, CellType.Any, RuleCallback_ItemAppear)
	-- WHEAT combine
	for i = 1, GameConsts.maxWheatStackSize - 1, 1 do
		for j = 1, GameConsts.maxWheatStackSize, 1 do
			local total = i + j
			if total <= GameConsts.maxWheatStackSize then
				self:RegisterCombineRule(CellType.WheatCollected_1 - 1 + i, CellType.WheatCollected_1 - 1 + j,
					CellType.WheatCollected_1 - 1 + total, CellType.None)
			elseif total < GameConsts.maxWheatStackSize * 2 then
				local reminder = total - GameConsts.maxWheatStackSize
				self:RegisterCombineRule(CellType.WheatCollected_1 - 1 + i, CellType.WheatCollected_1 - 1 + j,
					CellType.WheatCollected_1 + GameConsts.maxWheatStackSize - 1, CellType.WheatCollected_1 - 1 + reminder)
			end
		end
	end

	-- eat bread
	for i = 1, GameConsts.maxBreadStackSize, 1 do
		local newBreadType = CellType.Bread_1 + i - 2
		if i == 1 then
			newBreadType = CellType.None
		end
		local rule = self:RegisterCombineRule_Custom(CellType.None, CellType.Bread_1 - 1 + i, CellType.Any, CellType.None,
			newBreadType, CellType.Any, RuleCallback_EatBread)
		rule.isEat = true --TODO not like that (use tags or something)
		rule.preCondition = function(character) return character.hunger > 0.25 end
	end

	for CurrentCellTypeName, CurrentCellType in pairs(CellType) do
		if self:IsPickable(CurrentCellType) then
			-- pick
			self:RegisterCombineRule(CellType.None, CurrentCellType, CurrentCellType, CellType.None)
			-- drop
			self:RegisterCombineRule(CurrentCellType, CellType.None, CellType.None, CurrentCellType)
		end
	end

	self:RegisterCombineRuleForGround(CellType.None, CellType.GroundWithGrass, CellType.None, CellType.Ground)
	self:RegisterCombineRuleForItemAndGround(CellType.None, CellType.None, CellType.Ground, CellType.None, CellType.None,
		CellType.GroundPrepared)

	-- plant wheat
	local setDefaultStateForPlantAction =
	function(character, intPos)
		local cell = World.items:GetCell(intPos)
		cell.animType = CellAnimType.WheatGrowing
		cell.animT = 0.0
		cell.animStopT = 1.0 --TODO param
		World.items:SetCell(cell)
	end
	self:RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1, CellType.None, CellType.GroundPrepared,
		CellType.None,
		CellType.WheatPlanted_0, CellType.GroundPrepared, setDefaultStateForPlantAction)
	for i = 2, GameConsts.maxWheatStackSize, 1 do
		self:RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1 - 1 + i, CellType.None, CellType.GroundPrepared,
			CellType.WheatCollected_1 - 1 + i - 1, CellType.WheatPlanted_0, CellType.GroundPrepared, setDefaultStateForPlantAction)
	end

	local cutTreeCallback =
	function(character, intPos)
		local cell = World.items:GetCell(intPos)
		if cell.animType ~= CellAnimType.None then
			print(cell.animType)
			return
		end
		if cell.float4 >= 3.0 then
			cell.type = CellType.Wood
			SetAppearAnimation(cell)
		else
			cell.animType = CellAnimType.GotHit
			cell.animT = 0.0
			cell.animStopT = 0.2

			cell.float4 = cell.float4 + 1.0
		end
		World.items:SetCell(cell)
	end
	self:RegisterCombineRule_Custom(CellType.None, CellType.Tree, CellType.Any, CellType.None, CellType.Wood, CellType.Any,
		cutTreeCallback)
	self:RegisterCombineRule(CellType.Wood, CellType.Wood, CellType.None, CellType.Fence, RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Stone, CellType.Stone, CellType.None, CellType.Stove, RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Wood, CellType.Stone, CellType.None, CellType.CampfireWithWood,
		RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Wood, CellType.Campfire, CellType.None, CellType.CampfireWithWood,
		RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.FlintStone, CellType.CampfireWithWood, CellType.FlintStone,
		CellType.CampfireWithWoodFired
		, RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Stone, CellType.WheatCollected_6, CellType.Stone, CellType.Flour,
		RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Stone, CellType.Stone, CellType.None, CellType.Stove, RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Wood, CellType.Stove, CellType.None, CellType.StoveWithWood, RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.FlintStone, CellType.StoveWithWood, CellType.FlintStone, CellType.StoveWithWoodFired,
		RuleCallback_ItemAppear)
	self:RegisterCombineRule(CellType.Flour, CellType.StoveWithWoodFired, CellType.Bread_6, CellType.Stove)

end

function Actions:GetCombineAction(character, intPos)
	local charItem = character.item
	local cellItem = World.items:GetCell(intPos).type
	local groundItem = World.ground:GetCell(intPos).type

	local rule = self:GetCombineRule(character, charItem, cellItem, groundItem)
	if rule and rule.preCondition then
		if not rule.preCondition(character) then
			rule = nil
		end
	end
	-- print(CellTypeInv[charItem], CellTypeInv[cellItem], CellTypeInv[groundItem])
	if rule then
		return Action_ExecuteRule(character, intPos, rule)
	end

	return nil
end

function Actions:RuleCanBeApplied(character : Character, rule, charType, itemType, groundType) : boolean
	--TODO
	return true
end

function Actions:RuleToAction(character : Character, intPos, rule)
	if not character or not rule then
		return nil
	end
	local charItem = character.item
	local cellItem = World.items:GetCell(intPos).type
	local groundItem = World.ground:GetCell(intPos).type

	if not self:RuleCanBeApplied(character, rule, charItem, cellItem, groundItem) then
		return nil
	end
	return Action_ExecuteRule(character, intPos, rule)
end

return Actions
