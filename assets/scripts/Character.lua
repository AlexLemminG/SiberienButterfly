local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local World = require("World")

local Character = {
	runAnimation = nil,
	standAnimation = nil,
	runWithItemAnimation = nil,
	standWithItemAnimation = nil,
	animator = nil,
	rigidBody = nil,
	item = CellType.NONE,
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

	self:SetItem(CellType.NONE)
end

function Character:SetItem(item : number)
	local allMeshes = AssetDatabase():Load("models/GridCells.blend")
	local itemMeshRenderer = self.itemGO:GetComponent("MeshRenderer")
	self.item = item
	if item == CellType.NONE then
		itemMeshRenderer.mesh = nil
	else
		local meshName = CellTypeInv[item]
		meshName = string.lower(meshName)
		meshName = string.upper(meshName:sub(1, 1)) .. meshName:sub(2, meshName:len())
		itemMeshRenderer.mesh = allMeshes:FindMesh(meshName)
	end

	self:UpdateAnimation()
end

function Character:OnDisable()
	self:gameObject():GetScene():RemoveGameObject(self.itemGO)
end

function Character:Update()
	self.animator:SetAnimation(self.runAnimation)
end
--TODO global func or vector.func
function Length(v : vector)
	return math.sqrt (v.x*v.x + v.y*v.y + v.z*v.z)
end
function Lerp(a,b,t) return a * (1-t) + b * t end

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
	newVelocity = vector(newVelocity.x, math.min(prevVelocity.y, 0), newVelocity.z)
	
	self.rigidBody:SetLinearVelocity(newVelocity)

	self.rigidBody:SetAngularVelocity(vector(0,0,0))

	self.prevSpeed = Length(newVelocity)
	self:UpdateAnimation()
end

function Character:UpdateAnimation()
	local animation = self.runAnimation
	if self.prevSpeed > 0.1 then
		animation = self.runAnimation
		if self.item ~= CellType.NONE then
			animation = self.runWithItemAnimation
		end
	else
		animation = self.standAnimation
		if self.item ~= CellType.NONE then
			animation = self.standWithItemAnimation
		end
	end
	self.animator:SetAnimation(animation)

	self.animator.speed = 2.0
end

function IsPickable(itemType)
	return itemType ~= CellType.NONE
end

function Action_PickItem(character, intPos)
	local action = {}
	action.func = 
		function(action)
			local cell = World.items:GetCell(intPos)
			local t = cell.type
			cell.type = character.item
			character:SetItem(t)
			World.items:SetCell(cell)
		end
	return action
end

function Action_DropItem(character, intPos)
	return Action_PickItem(character, intPos)
end

function Character:GetActionOnCellPos(intPos)
	local cell = World.items:GetCell(intPos)
	if self.item == CellType.NONE and IsPickable(cell.type) then
		return Action_PickItem(self, intPos)
	end
	if cell.type == CellType.NONE and self.item ~= CellType.NONE then
		return Action_DropItem(self, intPos)
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