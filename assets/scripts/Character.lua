local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local World = require("World")
local Game = require("Game")
local CellAnimType = require("CellAnimType")
local Utils = require("Utils")

local Actions = require("Actions")
local Component = require("Component")

---@class Character : Component
local Character = {
	transform = nil,
	runAnimation = nil,
	standAnimation = nil,
	runWithItemAnimation = nil,
	standWithItemAnimation = nil,
	animator = nil,
	rigidBody = nil,
	item = CellType.None,
	prevSpeed = 0.0,
	itemGO = nil,
	hunger = 0.5,
	health = 1.0,
	desiredVelocity = vector(0,0,0),
	characterController = nil
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
	self.transform = self:gameObject():GetComponent("Transform")
	
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

	self.rigidBody:SetAngularFactor(vector(0,0,0))

	table.insert(World.characters, self)

end


---comment
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
	self:UpdateMovement()
	self:UpdateAnimation()

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

function Character:UpdateMovement()
	local desiredVelocity = self.desiredVelocity
	if self:IsInDialog() then
		desiredVelocity = vector(0,0,0)
	end

	local desiredVelocityXZ = vector(desiredVelocity.x, 0.0, desiredVelocity.z)
	local trans = self.rigidBody:GetTransform()
	local realVelocity = self.rigidBody:GetLinearVelocity()
	local realVelocityXZ = vector(realVelocity.x, 0.0, realVelocity.z)
	if Length(realVelocityXZ) > 0.1 then
		Mathf.SetRot(trans, Quaternion.LookAt(realVelocityXZ, vector(0,1,0)))
	end
	self.rigidBody:SetTransform(trans)
	--print("q=", Quaternion.LookAt(vector(0,0,1), vector(0,1,0)):scalar())

	self.rigidBody:Activate()

	local prevVelocity = self.rigidBody:GetLinearVelocity()
	local newVelocity = Lerp(prevVelocity, desiredVelocityXZ, 0.8)
	newVelocity = vector(newVelocity.x, 0.0, newVelocity.z)
	
	self.rigidBody:SetLinearVelocity(newVelocity)

	self.rigidBody:SetAngularVelocity(vector(0,0,0))

	self.prevSpeed = Length(newVelocity)
end

function Character:SetVelocity(velocity : vector)
	self.desiredVelocity = velocity
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


function Character:GetActionOnCharacter(character : Character)
	if not character then
		return nil
	end
	--TODO only for player
	local action = {}
	action.isCharacter = true
	action.selfCharacter = self
	action.otherCharacter = character
	function action:func()
			if Game.currentDialog then
				Game:EndDialog()
			else
				Game:BeginDialog(self.selfCharacter, character)
			end
		end
	return action
end

function Character:GetActionOnCellPos(intPos)
	local cell = World.items:GetCell(intPos)

	local combineAction = Actions:GetCombineAction(self, intPos)
	if combineAction then
		return combineAction
	end
	return nil
end

function Character:GetIntPos() : Vector2Int
	return World.items:GetClosestIntPos(self:GetPosition())
end

function Character:GetPosition() : Vector3
	return self.transform:GetPosition()
end

function Character:GetPosition2D() : Vector2
	local result = Vector2:new()
	local pos3d = self:GetPosition() 
	result.x = pos3d.x
	result.y = pos3d.z
	return result
end

function Character:ExecuteAction(action)
	if action == nil then
		return false
	end
	--print("exec", RuleToString(action.rule))
	-- print(Utils.TableToString(self))
	return action:func()
end

function Character:GetHumanName()
	return "Mike"
end

function Character:IsInDialog() : boolean
	return Game.currentDialog and (Game.currentDialog.characterA == self or Game.currentDialog.characterB == self)
end

return Character