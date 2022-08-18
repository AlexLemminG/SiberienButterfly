local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local World = require("World")
local CellAnimType = require("CellAnimType")

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function RuleToString(rule)
	return ("newCharItem="..CellTypeInv[rule.newCharType] .. " newCellItem=" .. CellTypeInv[rule.newItemType] .. " newGroundItem=" .. CellTypeInv[rule.newGroundType])
end

local Character = {
	runAnimation = nil,
	standAnimation = nil,
	runWithItemAnimation = nil,
	standWithItemAnimation = nil,
	animator = nil,
	rigidBody = nil,
	item = CellType.None,
	prevSpeed = 0.0,
	itemGO = nil
}
local Component = require("Component")
setmetatable(Character, Component)
Character.__index = Character

function Character:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function Character:OnEnable()
	self.runAnimation = AssetDatabase():Load("models/Vintik.blend$Run")
	self.standAnimation = AssetDatabase():Load("models/Vintik.blend$Stand")
	self.runWithItemAnimation = AssetDatabase():Load("models/Vintik.blend$RunWithItem")
	self.standWithItemAnimation = AssetDatabase():Load("models/Vintik.blend$StandWithItem")
	self.animator = self:gameObject():GetComponent("Animator")
	self.rigidBody = self:gameObject():GetComponent("RigidBody")
	
	local itemPrefab = AssetDatabase():Load("prefabs/carriedItem.asset")
	self.itemGO = Instantiate(itemPrefab)
	self:gameObject():GetScene():AddGameObject(self.itemGO)
	local parentedTransform = self.itemGO:GetComponent("ParentedTransform")
	local itemMatrix = parentedTransform.localMatrix
	Mathf.SetScale(itemMatrix, vector(1.5,1.5,1.5)) -- TODO based on character scale inv
	parentedTransform.localMatrix = itemMatrix
	local attachBoneIdx = 24 -- TODO
	parentedTransform:SetParentAsBone(self:gameObject():GetComponent("MeshRenderer"), attachBoneIdx)

	self:SetItem(CellType.None)

	RegisterPickableItems()
	RegisterAllCombineRules() --TODO in Game class
end

function Character:SetItem(item : number)
	local allMeshes = AssetDatabase():Load("models/GridCells.blend")
	local itemMeshRenderer = self.itemGO:GetComponent("MeshRenderer")
	self.item = item
	itemMeshRenderer.mesh = GridSystem():GetMeshByCellType(item)

	self:UpdateAnimation()
end

function Character:OnDisable()
	self:gameObject():GetScene():RemoveGameObject(self.itemGO)
end

--TODO global func or vector.func
function Length(v : vector)
	return math.sqrt (v.x*v.x + v.y*v.y + v.z*v.z)
end

function Lerp(a,b,t) return a * (1-t) + b * t end

function Character:Update()
	self.animator:SetAnimation(self.runAnimation)

	-- setting Y coord to ground character
	local trans = self.rigidBody:GetTransform()
	local pos = Mathf.GetPos(trans)
	local grid = World.items
	local cellPos = grid:GetClosestIntPos(pos)
	local dt = Time().deltaTime() -- TODO Time:deltaTime somehow ?
	pos = vector(pos.x, Lerp(pos.y, grid:GetCellWorldCenter(cellPos).y, dt * 20.0), pos.z)
	Mathf.SetPos(trans, pos)
	self.rigidBody:SetTransform(trans)
	
	local velocity = self.rigidBody:GetLinearVelocity()
	velocity = vector(velocity.x, 0.0, velocity.z)
	self.rigidBody:SetLinearVelocity(velocity)
end

function Character:Move(velocity : vector)
	local trans = self.rigidBody:GetTransform()
	if Length(velocity) > 0.1 then
		Mathf.SetRot(trans, Quaternion.LookAt(velocity, vector(0,1,0)))
	end
	self.rigidBody:SetTransform(trans)
	--print("q=", Quaternion.LookAt(vector(0,0,1), vector(0,1,0)):scalar())

	self.rigidBody:Activate()

	local prevVelocity = self.rigidBody:GetLinearVelocity()
	local newVelocity = Lerp(prevVelocity, velocity, 0.8)
	newVelocity = vector(newVelocity.x, 0.0, newVelocity.z)
	
	self.rigidBody:SetLinearVelocity(newVelocity)

	self.rigidBody:SetAngularVelocity(vector(0,0,0))

	self.prevSpeed = Length(newVelocity)
	self:UpdateAnimation()
end

function Character:UpdateAnimation()
	local animation = self.runAnimation
	if self.prevSpeed > 0.1 then
		animation = self.runAnimation
		if self.item ~= CellType.None then
			animation = self.runWithItemAnimation
		end
	else
		animation = self.standAnimation
		if self.item ~= CellType.None then
			animation = self.standWithItemAnimation
		end
	end
	self.animator:SetAnimation(animation)

	self.animator.speed = 2.0
end

local pickableItems = {}
local maxWheatStackSize = 6
local maxBreadStackSize = 6

function RegisterPickableItems() 
	pickableItems = {}
	for i = 1, maxWheatStackSize, 1 do
		pickableItems[CellType.WheatCollected_1 - 1 + i] = true		
	end
	for i = 1, maxBreadStackSize, 1 do
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

function IsPickable(itemType)
	return pickableItems[itemType]
end

function Action_ExecuteRule(character, intPos, rule)
	local action = {}
	action.rule = rule
	action.func = 
		function(action)
			--do return end
			if rule.isCustom then
				if rule.callback then
					rule.callback(character, intPos)
				else
					print("Custom rule without callback ", RuleToString(rule))
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
	local rule = {newCharType=newItemOnCharacter, newItemType=newItemAtCell, newGroundType=newGroundItem, callback=callback}
	return Action_ExecuteRule(character, intPos, rule)
end

function Action_Transform(character, intPos, newItemOnCharacter, newItemAtCell)
	return Action_TransformWithGround(character, intPos, newItemOnCharacter, newItemAtCell, CellType.Any)
end

function Action_PickItem(character, intPos)
	local cell = World.items:GetCell(intPos)
	return Action_Transform(character, intPos, cell.type, character.item)
end

function Action_DropItem(character, intPos)
	return Action_PickItem(character, intPos)
end

combineRules = {}

function RegisterCombineRule_Custom(charType, itemType, groundType, newCharType, newItemType, newGroundType, callback, overrideIfExists)
	local rule = RegisterCombineRuleForItemAndGround(charType, itemType, groundType, newCharType, newItemType, newGroundType, callback, overrideIfExists)
	if rule == nil then
		return nil
	end
	rule.isCustom = true
	return rule
end

function RegisterCombineRuleForItemAndGround(charType, itemType, groundType, newCharType, newItemType, newGroundType, callback, overrideIfExists)
	local charRules = combineRules[charType]
	if charRules == nil then
		charRules = {}
		combineRules[charType] = charRules
	end
	local itemRules = charRules[itemType]
	if itemRules == nil then
		itemRules = {}
		charRules[itemType] = itemRules
	end
	if itemRules[groundType] == nil or overrideIfExists then
		local rule = {newCharType = newCharType, newGroundType = newGroundType, newItemType = newItemType, callback = callback}
		itemRules[groundType] = rule
		return rule
	end
	return nil
end

function RegisterCombineRule(charType, itemType, newCharType, newItemType, callback)
	return RegisterCombineRuleForItemAndGround(charType, itemType, CellType.Any, newCharType, newItemType, CellType.Any, callback)
end

function RegisterCombineRuleForGround(charType, groundType, newCharType, newGroundType, callback)
	return RegisterCombineRuleForItemAndGround(charType, CellType.Any, groundType, newCharType, CellType.Any, newGroundType, callback)
end

function GetCombineRule_NoAnyChecks(charType, itemType, groundType)
	local charRules = combineRules[charType]
	if charRules == nil then
		return nil
	end
	local itemRules = charRules[itemType]
	if itemRules == nil then
		return nil
	end
	return itemRules[groundType]
end

function GetCombineRule(charType, itemType, groundType)
	local rule = GetCombineRule_NoAnyChecks(charType, itemType, groundType)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(charType, itemType, CellType.Any)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(charType, CellType.Any, groundType)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(charType, CellType.Any, CellType.Any)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(CellType.Any, itemType, groundType)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(CellType.Any, CellType.Any, groundType)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(CellType.Any, itemType, CellType.Any)
	if rule then return rule end
	rule = GetCombineRule_NoAnyChecks(CellType.Any, CellType.Any, CellType.Any)
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

function RegisterAllCombineRules()
	combineRules = {}

	RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.GroundPrepared, CellType.None, CellType.WheatCollected_2, CellType.Ground, RuleCallback_ItemAppear)
	RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.Any, CellType.None, CellType.WheatCollected_2, CellType.Any, RuleCallback_ItemAppear)
	-- WHEAT combine
	for i = 1, maxWheatStackSize - 1, 1 do
		for j = 1, maxWheatStackSize, 1 do
			local total = i + j
			if total <= maxWheatStackSize then
				RegisterCombineRule(CellType.WheatCollected_1 - 1 + i, CellType.WheatCollected_1 - 1 + j, CellType.WheatCollected_1 - 1 + total, CellType.None)
			elseif total < maxWheatStackSize * 2 then
				local reminder = total - maxWheatStackSize
				RegisterCombineRule(CellType.WheatCollected_1 - 1 + i, CellType.WheatCollected_1 - 1 + j, CellType.WheatCollected_1 + maxWheatStackSize - 1, CellType.WheatCollected_1 - 1 + reminder)
			end
		end
	end

	for CurrentCellTypeName,CurrentCellType in pairs(CellType) do
		if IsPickable(CurrentCellType) then
			-- pick
			RegisterCombineRule(CellType.None, CurrentCellType, CurrentCellType, CellType.None)
			-- drop
			RegisterCombineRule(CurrentCellType, CellType.None, CellType.None, CurrentCellType)
		end
	end

	RegisterCombineRuleForGround(CellType.None, CellType.GroundWithGrass, CellType.None, CellType.Ground)
	RegisterCombineRuleForItemAndGround(CellType.None, CellType.None, CellType.Ground, CellType.None, CellType.None, CellType.GroundPrepared)

	-- plant wheat
	local setDefaultStateForPlantAction = 
		function(character, intPos)
			local cell = World.items:GetCell(intPos)
			cell.animType = CellAnimType.WheatGrowing
			cell.animT = 0.0
			cell.animStopT = 1.0 --TODO param
			World.items:SetCell(cell)
		end
	RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1, CellType.None, CellType.GroundPrepared, CellType.None, CellType.WheatPlanted_0, CellType.GroundPrepared, setDefaultStateForPlantAction)
	for i = 2, maxWheatStackSize, 1 do
		RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1 - 1 + i, CellType.None, CellType.GroundPrepared, CellType.WheatCollected_1 - 1 + i - 1, CellType.WheatPlanted_0, CellType.GroundPrepared, setDefaultStateForPlantAction)
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

				cell.float4 += 1.0
			end
			World.items:SetCell(cell)
		end
	RegisterCombineRule_Custom(CellType.None, CellType.Tree, CellType.Any, CellType.None, CellType.Wood, CellType.Any, cutTreeCallback)
	RegisterCombineRule(CellType.Wood, CellType.Wood, CellType.None, CellType.Fence, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.Stone, CellType.Stone, CellType.None, CellType.Stove, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.Wood, CellType.Stone, CellType.None, CellType.CampfireWithWood, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.FlintStone, CellType.CampfireWithWood, CellType.FlintStone, CellType.CampfireWithWoodFired, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.Stone, CellType.WheatCollected_6, CellType.Stone, CellType.Flour, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.Stone, CellType.Stone, CellType.None, CellType.Stove, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.Wood, CellType.Stove, CellType.None, CellType.StoveWithWood, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.FlintStone, CellType.StoveWithWood, CellType.FlintStone, CellType.StoveWithWoodFired, RuleCallback_ItemAppear)
	RegisterCombineRule(CellType.Flour, CellType.StoveWithWoodFired, CellType.Bread_6, CellType.Stove)
end

function GetCombineAction(character, intPos)
	local charItem = character.item
	local cellItem = World.items:GetCell(intPos).type
	local groundItem = World.ground:GetCell(intPos).type

	local rule = GetCombineRule(charItem, cellItem, groundItem)
	-- print(CellTypeInv[charItem], CellTypeInv[cellItem], CellTypeInv[groundItem])
	if rule then
		return Action_ExecuteRule(character, intPos, rule)
	end

	if charItem == CellType.None and IsPickable(cellItem) then
		return Action_PickItem(character, intPos)
	end
	if cellItem == CellType.None and charItem ~= CellType.None then
		return Action_DropItem(character, intPos)
	end

	return nil
end

function Character:GetActionOnCellPos(intPos)
	local cell = World.items:GetCell(intPos)

	local combineAction = GetCombineAction(self, intPos)
	if combineAction then
		return combineAction
	end
	return nil
end

function Character:ExecuteAction(action)
	if action == nil then
		return false
	end
	--print("exec", RuleToString(action.rule))
	return action:func(self)
end

return Character