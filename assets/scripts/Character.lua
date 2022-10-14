local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local World = require("World")
local Game = require("Game")
local CellAnimType = require("CellAnimType")
local Utils = require("Utils")
local RandomNamesGenerator = require("RandomNamesGenerator")

local Actions = require("Actions")
local Component = require("Component")

---@class Character : Component
---@field characterController CharacterControllerBase|nil
local Character = {
	transform = nil,
	runAnimation = nil,
	standAnimation = nil,
	runWithItemAnimation = nil,
	standWithItemAnimation = nil,
	deathAnimation = nil,
	animator = nil,
	rigidBody = nil,
	item = CellType.None,
	prevSpeed = 0.0,
	maxSpeed = 2.0,
	itemGO = nil,
	hunger = 0.5,
	health = 1.0,
	desiredVelocity = vector(0,0,0),
	characterController = nil,
	name = "Name",
	isDead = false,
	isSleeping = false,
	sleepingPos = nil,
	baseModelFile = "models/Vintik.blend",
	type = "Character",
	walkingMaxSpeedMultiplier = 0.5
}
local Component = require("Component")
setmetatable(Character, Component)
Character.__index = Character

function Character:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end


function Character:SaveState() : any
	local state = {}
	state.hunger = self.hunger
	state.health = self.health
	state.name = self.name
	state.isDead = self.isDead
	state.isSleeping = self.isSleeping
	if self.isSleeping and self.sleepingPos then
		state.sleepingPos = {x=self.sleepingPos.x, y=self.sleepingPos.y}
	end
	local position = self:GetPosition()
	local rotation = self.transform:GetRotation()
	state.position = { x=position.x, y=position.y, z=position.z }
	local lookVector = rotation:vector()
	local lookScalar = rotation:scalar()
	state.rotation = { x=lookVector.x, y=lookVector.y, z=lookVector.z, w= lookScalar }
	state.itemName = CellTypeInv[self.item]
	state.type = self.type
	if self.characterController then
		state.characterController = self.characterController:SaveState()
	end
	return state
end
--Called right after adding to world!
function Character:LoadState(savedState)
	self.health = savedState.health
	self.hunger = savedState.hunger
	self.name = savedState.name
	self.isDead = savedState.isDead
	self.isSleeping = savedState.isSleeping
	if self.isSleeping then
		if savedState.sleepingPos then
			self.sleepingPos = Vector2Int.new()
			self.sleepingPos.x = savedState.sleepingPos.x
			self.sleepingPos.y = savedState.sleepingPos.y
		end
	end
	local position = vector(savedState.position.x, savedState.position.y, savedState.position.z)
	local rotation = Quaternion:new()
	rotation:set_scalar(savedState.rotation.w)
	rotation:set_vector(vector(savedState.rotation.x,savedState.rotation.y,savedState.rotation.z))
	local transform = self.rigidBody:GetTransform()
	Mathf.SetPos(transform, position)
	Mathf.SetRot(transform, rotation)
	self.rigidBody:SetTransform(transform)
	self.transform:SetPosition(position)
	self.transform:SetRotation(rotation)
	if savedState.type and self.type ~= savedState.type then
		LogError("Character type not assigned correctly")
	end
	if savedState.itemName then
		local item = CellType[savedState.itemName]
		if item then
			self:SetItem(item)
		end
	end
	if savedState.characterController then
		if self.characterController then
			self.characterController:LoadState(savedState.characterController)
		else
			LogError("Have savedState.characterController but not self.characterController")
		end
	end

	if self:IsDead() then
		self.isDead = false
		self:Die()
	end

	if self.isSleeping then
		self.isSleeping = false
		self:SetIsSleeping(true, self.sleepingPos)
	end
end

function Character:OnEnable()
	--TODO support different models for different characters
	self.runAnimation = AssetDatabase:Load(self.baseModelFile.."$Run")
	self.standAnimation = AssetDatabase:Load(self.baseModelFile.."$Stand")
	self.runWithItemAnimation = AssetDatabase:Load(self.baseModelFile.."$RunWithItem")
	self.standWithItemAnimation = AssetDatabase:Load(self.baseModelFile.."$StandWithItem")
	self.deathAnimation = AssetDatabase:Load(self.baseModelFile.."$Death")
	
	self.animator = self:gameObject():GetComponent("Animator")
	self.rigidBody = self:gameObject():GetComponent("RigidBody")
	self.transform = self:gameObject():GetComponent("Transform")
	
	local itemPrefab = AssetDatabase:Load("prefabs/carriedItem.asset")
	self.itemGO = Instantiate(itemPrefab)
	self:gameObject():GetScene():AddGameObject(self.itemGO)
	local parentedTransform = self.itemGO:GetComponent("ParentedTransform")
	local itemMatrix = parentedTransform.localMatrix
	local characterScaleInv = 1.0 / self.transform:GetScale().x
	Mathf.SetScale(itemMatrix, vector(characterScaleInv,characterScaleInv,characterScaleInv)) -- TODO based on character scale inv
	parentedTransform.localMatrix = itemMatrix
	local meshRenderer = self:gameObject():GetComponent("MeshRenderer")
	meshRenderer:SetMesh(AssetDatabase:Load(self.baseModelFile).meshes[1])

	local attachBoneIndex = meshRenderer.mesh:GetBoneIndex("ItemAttachPoint")
	if attachBoneIndex ~= -1 then
		parentedTransform:SetParentAsBone(meshRenderer, attachBoneIndex)
	end

	if not self.item then
		self.item = CellType.None
	end
	self:SetItem(self.item)

	self.rigidBody:SetEnabled(true)
	self.rigidBody:SetAngularFactor(vector(0,0,0))

	self.name = RandomNamesGenerator:GetNext()

	table.insert(World.charactersIncludingDead, self)
	if not self:IsDead() then
		table.insert(World.characters, self)
	end
end


---comment
function Character:SetItem(item : number)
	local allMeshes = AssetDatabase:Load("models/GridCells.blend")
	local itemMeshRenderer = self.itemGO:GetComponent("MeshRenderer")
	self.item = item
	itemMeshRenderer.mesh = GridSystem:GetMeshByCellType(item)

	self:UpdateAnimation()
end

function Character:OnDisable()
	Utils.ArrayRemove(World.charactersIncludingDead, self)
	if not self:IsDead() then
		Utils.ArrayRemove(World.characters, self)
	end
	
	self:gameObject():GetScene():RemoveGameObject(self.itemGO)
end

--TODO global func or vector.func
function Length(v : vector)
	return math.sqrt (v.x*v.x + v.y*v.y + v.z*v.z)
end

function Lerp(a,b,t) return a * math.clamp(1-t,0,1) + b * math.clamp(t,0,1) end

function Character:Update()
	if self.isDead or self.isSleeping then
		return
	end
	self:UpdateMovement()
	self:UpdateAnimation()

	-- setting Y coord to ground character
	local trans = self.rigidBody:GetTransform()
	local pos = Mathf.GetPos(trans)
	local grid = World.items
	local cellPos = grid:GetClosestIntPos(pos)
	local dt = Time.deltaTime() -- TODO Time:deltaTime somehow ?
	pos = vector(pos.x, Lerp(pos.y, grid:GetCellWorldCenter(cellPos).y, dt * 20.0), pos.z)
	Mathf.SetPos(trans, pos)
	self.rigidBody:SetTransform(trans)
	
	local velocity = self.rigidBody:GetLinearVelocity()
	velocity = vector(velocity.x, 0.0, velocity.z)
	self.rigidBody:SetLinearVelocity(velocity)

	self:DrawName()
end

function Character:UpdateMovement()
	local desiredVelocity = self.desiredVelocity
	if self:IsInDialog() then
		desiredVelocity = vector(0,0,0)
	end
	local desiredVelocityLength = Length(desiredVelocity)
	if desiredVelocityLength > self.maxSpeed then
		desiredVelocity = desiredVelocity * (self.maxSpeed / desiredVelocityLength)
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
	local animSpeed = 1.0
	if self.prevSpeed > 0.1 then
		animSpeed = 2.0 * self.prevSpeed / self.maxSpeed
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

	self.animator.speed = animSpeed
end

--TODO move to controller and make different for different animals/characters
function Character:GetActionOnCharacter(character : Character)
	if not character or not self.characterController then
		return nil
	end
	return self.characterController:GetActionOnCharacter(character)
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

--Distance check is ignored
function Character:CanExecuteAction(action : CharacterAction)
	if action == nil then
		return false
	end
	return action:CanExecute()
end

function Character:ExecuteAction(action)
	if action == nil then
		return false
	end
	--print("exec", RuleToString(action.rule))
	-- print(Utils.TableToString(self))
	return action:Execute()
end

function Character:GetHumanName()
	return self.name
end

function Character:IsInDialog() : boolean
	return Game.currentDialog and (Game.currentDialog.characterA == self or Game.currentDialog.characterB == self)
end

function Character:CanInteract() : boolean
	return not (self:IsDead() or self.isSleeping)
end

function Character:IsDead() : boolean
	return self.isDead
end

function Character:SetIsSleeping(isSleeping : boolean, sleepingPos)
	if self.isSleeping == isSleeping then
		return
	end
	self.isSleeping = isSleeping
	self.sleepingPos = sleepingPos


	if isSleeping then
		if sleepingPos then
			local cellPos = World.ground:GetCellWorldCenter(sleepingPos)
			local position = cellPos + vector(0,0.25,0)
			local rotation = Quaternion.LookAt(vector(0,0,1), vector(0,1,0))
			-- rotation:set_scalar(savedState.rotation.w)
			-- rotation:set_vector(vector(savedState.rotation.x,savedState.rotation.y,savedState.rotation.z))
			local transform = self.transform:GetMatrix()
			Mathf.SetPos(transform, position)
			Mathf.SetRot(transform, rotation)
		self.transform:SetMatrix(transform)
		end
	end

	self.rigidBody:SetEnabled(not isSleeping)
	
	if isSleeping then
		self.animator:SetAnimation(self.deathAnimation)
	end
end

function Character:DrawName()
	if self == World.playerCharacter then
		--return
	end
	local camera = Camera
	camera = camera.GetMain()

	--TODO head pos
	local pos3d = self:GetPosition() + vector(0,1.5,0)
	local pos = camera:WorldPointToScreen(pos3d)

	local commandStatus = ""
	if self.characterController and not self.characterController.command then
		commandStatus = " no command"
	end
	local textOut = self.name..(commandStatus)
	local deltaX, deltaY = imgui.CalcTextSize(textOut)
	pos.x = pos.x - deltaX / 2.0

	imgui.SetNextWindowSize(deltaX * 2.0,deltaY * 2.0)
	imgui.SetNextWindowPos(pos.x,pos.y, imgui.constant.Cond.Always, 0.0,0.5)
	imgui.SetNextWindowBgAlpha(0.0)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar, winFlags.NoInputs, winFlags.NoScrollbar)
	imgui.PushID(tostring(self))
	imgui.Begin(string.format("CharacterName##%s",tostring(self)), nil, flags)
	imgui.TextUnformatted(textOut)
	imgui.End()
	imgui.PopID()
end

function Character:Die()
	if self:IsDead() then
		return
	end
	Utils.ArrayRemove(World.characters, self)
	self.isDead = true
	self.rigidBody:SetEnabled(false)
	self.animator:SetAnimation(self.deathAnimation)

	self.animator.speed = 1.0
end

function Character:GetWarmthImmediate() : number
	local temperature = Game:GetTemperatureAt(self:GetIntPos())
	return temperature
end

function Character:IsFreezing() : boolean
	return self:GetWarmthImmediate() < 0.5
end

return Character