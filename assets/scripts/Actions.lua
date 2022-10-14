local CellAnimations = require "CellAnimations"
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
	isCustom = false
}
function CombineRule.preCondition(character : Character) : boolean
	return true
end

function CombineRule:callback(character : Character, pos : Vector2Int, checkOnly : boolean) : boolean

end

---@class CharacterCommand
local CharacterCommand = {}
function CharacterCommand:Execute()

end

---@class CharacterAction
---@field character Character
local CharacterAction = {
	character = {},
}
function CharacterAction:Execute() : boolean
	return self:ExecuteImpl(false)
end
function CharacterAction:CanExecute(): boolean
	return self:ExecuteImpl(true)
end
CharacterAction.__index = CharacterAction

function CharacterAction:new() : CharacterAction
	local action = {}
	setmetatable(action, self)
	return action
end
--returns true if really executed or can be executed
function CharacterAction:ExecuteImpl(checkOnly : boolean) : boolean
	return false
end

function Actions.RuleToString(rule)
	if not rule then
		return "nil"
	end
	return string.format("char/item/ground %s/%s/%s -> %s/%s/%s", CellTypeInv[rule.charType], CellTypeInv[rule.itemType], CellTypeInv[rule.groundType],
															CellTypeInv[rule.newCharType], CellTypeInv[rule.newItemType], CellTypeInv[rule.newGroundType])
end

function Actions.CreateDoNothingAtPosAction(character : Character, pos : Vector2Int) : CharacterAction
	local action = CharacterAction:new()

	action.character = character
	action.intPos = pos

	function action:ExecuteImpl(checkOnly) : boolean
		return true
	end

	return action
end

function Actions.CreateWakeUpImmediatelyAction(character : Character) : CharacterAction
	local action = CharacterAction:new()

	action.character = character

	function action:ExecuteImpl(checkOnly) : boolean
		--TODO more clear why sleepingPos ~= nil (sleeping not in bed)
		if not character.isSleeping or character.sleepingPos ~= nil then
			return false
		end
		if checkOnly then
			return true
		end
		character:SetIsSleeping(false)
		
		return true
	end

	return action
end

function Actions.CreateSleepImmediatelyAction(character : Character) : CharacterAction
	local action = CharacterAction:new()

	action.character = character

	function action:ExecuteImpl(checkOnly) : boolean
		--TODO dont sleep if already sleeping ?
		if checkOnly then
			return true
		end
		character:SetIsSleeping(true)
		
		return true
	end

	return action
end

function Actions:Init()
	self:Term()

	self:RegisterPickableItems()
	self:RegisterAllCombineRules()
end

function Actions:GetAllIsSubtype(cellTypeParent : integer)
	local result = {}
	for cellTypeName, cellType in pairs(CellType) do
		if self:IsSubtype(cellType, cellTypeParent) then
			table.insert(result, cellType)
		end
	end
	return result
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
	pickableItems[CellType.Wool] = true
	pickableItems[CellType.Bed] = true
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
	if CellType.WheatCollected_AnyNotFull == parentType then
		if childType >= CellType.WheatCollected_1 and childType < CellType.WheatCollected_1 + GameConsts.maxWheatStackSize - 1 then
			return true
		end
	end
	if CellType.Bread_Any == parentType then
		if childType >= CellType.Bread_1 and childType <= CellType.Bread_1 + GameConsts.maxBreadStackSize - 1 then
			return true
		end
	end
	if CellType.Eatable_Any == parentType then
		if childType >= CellType.Bread_1 and childType <= CellType.Bread_1 + GameConsts.maxBreadStackSize - 1 or childType == CellType.BushWithBerries then
			return true
		end
	end
	if CellType.Stove_Any == parentType then
		if childType == CellType.Stove or childType == CellType.StoveWithWood or childType == CellType.StoveWithWoodFired then
			return true
		end
	end
	if CellType.Campfire_Any == parentType then
		if childType == CellType.Campfire or childType == CellType.CampfireWithWood or childType == CellType.CampfireWithWoodFired then
			return true
		end
	end
	if CellType.Fence_Any == parentType then
		if childType == CellType.Fence or childType == CellType.FenceX or childType == CellType.FenceZ or childType == CellType.FenceXZ then
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


function Action_ExecuteRule(character, intPos, rule) : CharacterAction
	local action = CharacterAction:new()
	action.rule = rule
	action.intPos = intPos
	action.character = character
	function action:ExecuteImpl(checkOnly : boolean) : boolean
		--do return end
		local currentCharType = self.character.item
		local currentItemType = World.items:GetCell(self.intPos).type
		local currentGroundType = World.ground:GetCell(self.intPos).type

		local canExecute = 
		Actions:IsSubtype(currentCharType, self.rule.charType) 
		and 
		Actions:IsSubtype(currentItemType, self.rule.itemType) 
		and 
		Actions:IsSubtype(currentGroundType, self.rule.groundType)

		if rule.callback and not rule.callback(character, self.intPos, true) then
			canExecute = false
		end

		if checkOnly or not canExecute then
			return canExecute
		end

		if rule.isCustom then
			if rule.callback then
				rule.callback(character, intPos, false)
			else
				LogWarning("Custom rule without callback ", Actions.RuleToString(rule))
			end
			return true
		end

		if rule.newCharType ~= CellType.Any then
			character:SetItem(rule.newCharType)
		end

		if rule.newItemType ~= CellType.Any then
			local cell = World.items:GetCell(intPos)
			cell.type = rule.newItemType
			cell.animType = CellAnimType.None
			World.items:SetCell(cell)
		end

		if rule.newGroundType ~= CellType.Any then
			local cell = World.ground:GetCell(intPos)
			cell.type = rule.newGroundType
			cell.animType = CellAnimType.None
			World.ground:SetCell(cell)
		end

		if rule.callback then
			rule.callback(character, intPos, false)
		end
		return true
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
	return self:RegisterCombineRuleForItemAndGround(charType, CellType.None, groundType, newCharType, CellType.None,
		newGroundType
		, callback)
end

function Actions:GetCombineRuleFromSavable(savedRule) : CombineRule|nil

	--TODO get one specific rule from Actions
	local allRules = Actions:GetAllCombineRules_NoAnyChecks(nil, savedRule.charType, savedRule.itemType, savedRule.groundType)
	if not allRules then
		error("Failed to find specified rule")
		return nil
	end
	for index2, rule in ipairs(allRules) do
		--TODO extra checks (there are multiple allRules for a reason)
		if rule.newCharType == savedRule.newCharType and rule.newItemType == savedRule.newItemType and rule.newGroundType == savedRule.newGroundType then
			return rule
		end
	end
	
	return nil
end

function Actions:SavableFromCombineRule(rule : CombineRule)
	return rule
end

function Actions:GetAllCombineRules_NoAnyChecks(character : Character|nil, charType : integer, itemType : integer, groundType : integer)
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
	local result = nil
	for i, rule in ipairs(rules) do
		if not rule.preCondition or not character or rule.preCondition(character) then
			if not result then
				result = {}
			end
			table.insert(result, rule)
		end
	end
	return result
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

function RuleCallback_ItemAppearWithoutXZScale(character, intPos, checkOnly : boolean)
	if checkOnly then return true end
	local cell = World.items:GetCell(intPos)
	if cell.type ~= CellType.None then
		CellAnimations.SetAppearWithoutXZScale(cell)
		World.items:SetCell(cell)
	end
	return true
end
function RuleCallback_ItemAppear(character, intPos, checkOnly : boolean)
	if checkOnly then return true end
	local cell = World.items:GetCell(intPos)
	if cell.type ~= CellType.None then
		CellAnimations.SetAppear(cell)
		World.items:SetCell(cell)
	end
	return true
end

function RuleCallback_Eat(character, intPos, checkOnly : boolean)
	if checkOnly then return true end
	character.hunger = character.hunger - 0.25
	RuleCallback_ItemAppear(character, intPos)
	return true
end

function Actions:RegisterAllCombineRules()
	self.combineRules = {}

	self:RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.GroundPrepared, CellType.None,
		CellType.WheatCollected_2, CellType.Ground, RuleCallback_ItemAppear)
	self:RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.Any, CellType.None,
		CellType.WheatCollected_2, CellType.Any, RuleCallback_ItemAppear)

	-- WHEAT combine
	self:RegisterCombineRule(CellType.WheatCollected_AnyNotFull, CellType.WheatCollected_AnyNotFull, CellType.None)

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

	local RegisterEatRule = function (charType, itemType, newCharType, newItemType)
		local rule = self:RegisterCombineRule(charType, itemType, newCharType,
			newItemType, RuleCallback_Eat)
		rule.isEat = true --TODO not like that (use tags or something)
		rule.preCondition = function(character) return character.hunger > 0.25 end
	end
	-- eat bread
	for i = 1, GameConsts.maxBreadStackSize, 1 do
		local newBreadType = CellType.Bread_1 + i - 2
		if i == 1 then
			newBreadType = CellType.None
		end
		RegisterEatRule(CellType.None, CellType.Bread_1 - 1 + i, CellType.None, newBreadType)
	end
	RegisterEatRule(CellType.None, CellType.BushWithBerries, CellType.None, CellType.Bush)


	for CurrentCellTypeName, CurrentCellType in pairs(CellType) do
		--TODO less hacky with fence
		if self:IsPickable(CurrentCellType) and CurrentCellType ~= CellType.Fence then
			-- pick
			self:RegisterCombineRule(CellType.None, CurrentCellType, CurrentCellType, CellType.None)
			-- drop
			self:RegisterCombineRule(CurrentCellType, CellType.None, CellType.None, CurrentCellType)
		end
	end

	--Fence
	function UpdateSingleFence(intPos)
		local thisCell = World.items:GetCell(intPos)
		if not Actions:IsSubtype(thisCell.type, CellType.Fence_Any) then
			return
		end
		local typeBefore = thisCell.type
		
		intPos.x = intPos.x + 1
		local posXCell = World.items:GetCell(intPos)
		local xFence = Actions:IsSubtype(posXCell.type, CellType.Fence_Any)
		intPos.x = intPos.x - 1
		intPos.y = intPos.y + 1
		local posYCell = World.items:GetCell(intPos)
		local yFence = Actions:IsSubtype(posYCell.type, CellType.Fence_Any)
		intPos.y = intPos.y - 1 --intPos is object so return it back to initial state


		if xFence and yFence then
			thisCell.type = CellType.FenceXZ
		elseif xFence then
			thisCell.type = CellType.FenceX
		elseif yFence then
			thisCell.type = CellType.FenceZ
		else
			thisCell.type = CellType.Fence
		end

		if thisCell.type ~= typeBefore then
			World.items:SetCell(thisCell)
		end
		RuleCallback_ItemAppear(nil, intPos, false)
	end
	function UpdateFencesCallback(character, intPos, checkOnly) : boolean
		if checkOnly then return true end
		UpdateSingleFence(intPos)
		intPos.x = intPos.x + 1
		UpdateSingleFence(intPos)
		intPos.x = intPos.x - 2
		UpdateSingleFence(intPos)
		intPos.x = intPos.x + 1
		intPos.y = intPos.y + 1
		UpdateSingleFence(intPos)
		intPos.y = intPos.y - 2
		UpdateSingleFence(intPos)

		intPos.y = intPos.y + 1 --intPos is object so return it back to initial state
		return true
	end
	for name, groundedFenceType in pairs(self:GetAllIsSubtype(CellType.Fence_Any)) do
		-- pick
		self:RegisterCombineRule(CellType.None, groundedFenceType, CellType.Fence, CellType.None, UpdateFencesCallback)
		-- drop
		self:RegisterCombineRule(CellType.Fence, CellType.None, CellType.None, groundedFenceType, UpdateFencesCallback)
	end

	self:RegisterCombineRuleForGround(CellType.None, CellType.GroundWithGrass, CellType.None, CellType.Ground)
	self:RegisterCombineRuleForGround(CellType.None, CellType.GroundWithEatenGrass, CellType.None, CellType.Ground)
	self:RegisterCombineRuleForGround(CellType.None, CellType.Ground, CellType.None,	CellType.GroundPrepared)

	-- plant wheat
	self:RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1, CellType.None, CellType.GroundPrepared,
		CellType.None,
		CellType.WheatPlanted_0, CellType.GroundPrepared, RuleCallback_ItemAppearWithoutXZScale)
	for i = 2, GameConsts.maxWheatStackSize, 1 do
		self:RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1 - 1 + i, CellType.None, CellType.GroundPrepared,
			CellType.WheatCollected_1 - 1 + i - 1, CellType.WheatPlanted_0, CellType.GroundPrepared, RuleCallback_ItemAppearWithoutXZScale)
	end

	local cutTreeCallback =
	function(character, intPos, checkOnly : boolean) : boolean
		if checkOnly then return true end
		local cell = World.items:GetCell(intPos)
		if cell.animType ~= CellAnimType.None then
			return
		end
		if cell.float4 >= 3.0 then
			cell.type = CellType.Wood
			CellAnimations.SetAppear(cell)
		else
			cell.animType = CellAnimType.GotHit
			cell.animT = 0.0
			cell.animStopT = 0.2

			cell.float4 = cell.float4 + 1.0
		end
		World.items:SetCell(cell)
		return true
	end
	self:RegisterCombineRule_Custom(CellType.None, CellType.Tree, CellType.Any, CellType.None, CellType.Wood, CellType.Any,
		cutTreeCallback)
	self:RegisterCombineRule(CellType.Wood, CellType.Wood, CellType.None, CellType.Fence, UpdateFencesCallback)
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
	self:RegisterCombineRule(CellType.None, CellType.TreeSprout, CellType.None, CellType.None)
	self:RegisterCombineRule(CellType.Wool, CellType.Wood, CellType.None, CellType.Bed)

	self:RegisterCombineRuleForGround(CellType.Wood, CellType.Water, CellType.None,
		CellType.WoodenBridge)
		
	--eat grass
	--TODO make not available for humans
	self:RegisterCombineRuleForGround(CellType.None, CellType.GroundWithGrass, CellType.None,
		CellType.GroundWithEatenGrass, RuleCallback_Eat)


	local isBedOccupied = function (intPos) : boolean
		for index, character in ipairs(World.characters) do
			if character.isSleeping and intPos == character.sleepingPos then
				return true
			end
		end
		return false
	end

	local sleepCallback = function(character : Character, intPos, checkOnly : boolean) : boolean
		if isBedOccupied(intPos) then
			return false
		end
		--TODO is bed empty check and character is ready to sleep
		if checkOnly then return true end

		character:SetIsSleeping(true, intPos)
		--TODO implementation
		return true
	end
	self:RegisterCombineRule(CellType.None, CellType.Bed, CellType.None, CellType.BedOccupied,
		sleepCallback)

		
	local wakeUpCallback = function(character : Character, intPos, checkOnly : boolean) : boolean
		if not character.isSleeping or character.sleepingPos ~= intPos then
			return false
		end
		--TODO is bed empty check and character is ready to sleep
		if checkOnly then return true end

		character:SetIsSleeping(false, nil)
		--TODO implementation
		return true
	end
	self:RegisterCombineRule(CellType.None, CellType.BedOccupied, CellType.None, CellType.Bed,
		wakeUpCallback)
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
