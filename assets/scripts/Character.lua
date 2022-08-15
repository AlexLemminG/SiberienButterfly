local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local World = require("World")

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

function IsPickable(itemType)
	return itemType ~= CellType.None and itemType ~= CellType.Any
end

function Action_TransformWithGround(character, intPos, newItemOnCharacter, newItemAtCell, newGroundItem, callback)
	local action = {}
	action.func = 
		function(action)
			if newItemOnCharacter ~= CellType.Any then
				character:SetItem(newItemOnCharacter)
			end

			if newItemAtCell ~= CellType.Any then
				local cell = World.items:GetCell(intPos)
				cell.type = newItemAtCell
				World.items:SetCell(cell)
			end

			if newGroundItem ~= CellType.Any then
				local cell = World.ground:GetCell(intPos)
				cell.type = newGroundItem
				World.ground:SetCell(cell)
			end

			if callback then
				callback(character, intPos)
			end
		end
	return action
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
		itemRules[groundType] = {newCharType = newCharType, newGroundType = newGroundType, newItemType = newItemType, callback = callback}
	end
end

function RegisterCombineRule(charType, itemType, newCharType, newItemType)
	RegisterCombineRuleForItemAndGround(charType, itemType, CellType.Any, newCharType, newItemType, CellType.Any)
end

function RegisterCombineRuleForGround(charType, groundType, newCharType, newGroundType)
	RegisterCombineRuleForItemAndGround(charType, CellType.Any, groundType, newCharType, CellType.Any, newGroundType)
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

function RegisterAllCombineRules()
	combineRules = {}

	RegisterCombineRuleForItemAndGround(CellType.None, CellType.Wheat, CellType.Any, CellType.None, CellType.WheatCollected_2, CellType.Ground)
	-- WHEAT combine
	local maxWheatStackSize = 6
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
	RegisterCombineRuleForGround(CellType.None, CellType.Ground, CellType.None, CellType.GroundPrepared)

	-- plant wheat
	local setDefaultStateForPlantAction = 
		function(character, intPos)
			local cell = World.items:GetCell(intPos)
			cell.float1 = 0.0
			World.items:SetCell(cell)
		end
	RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1, CellType.None, CellType.GroundPrepared, CellType.None, CellType.WheatPlanted_0, CellType.GroundPrepared, setDefaultStateForPlantAction)
	for i = 2, maxWheatStackSize, 1 do
		RegisterCombineRuleForItemAndGround(CellType.WheatCollected_1 - 1 + i, CellType.None, CellType.GroundPrepared, CellType.WheatCollected_1 - 1 + i - 1, CellType.WheatPlanted_0, CellType.GroundPrepared, setDefaultStateForPlantAction)
	end
end

function GetCombineAction(character, intPos)
	local charItem = character.item
	local cellItem = World.items:GetCell(intPos).type
	local groundItem = World.ground:GetCell(intPos).type

	local rule = GetCombineRule(charItem, cellItem, groundItem)
	-- print(CellTypeInv[charItem], CellTypeInv[cellItem], CellTypeInv[groundItem])
	if rule then
		-- print(CellTypeInv[rule.newCharType], CellTypeInv[rule.newItemType], CellTypeInv[rule.newGroundType])
		return Action_TransformWithGround(character, intPos, rule.newCharType, rule.newItemType, rule.newGroundType, rule.callback)
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
	return action:func(self)
end

return Character