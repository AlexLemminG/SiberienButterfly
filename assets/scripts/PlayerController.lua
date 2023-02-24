local CellType = require("CellType")
-- local Grid = require("Grid")
local World = require("World")
local WorldQuery = require("WorldQuery")
local Game       = require("Game")
local CellTypeInv= require("CellTypeInv")
local GameConsts = require("GameConsts")

---@class PlayerController
---@field character Character|nil
local PlayerController = {
	rigidBody = nil,
	transform = nil,
	selectionSquareGO = nil,
	selectionArrowGO = nil,
	wasInDialogPrevFrame = false,
	character = nil,
	isInSettingsMarkingMode = false
}
local Component = require("Component")
setmetatable(PlayerController, Component)
PlayerController.__index = PlayerController

function PlayerController:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function PlayerController:OnEnable()
	self.rigidBody = self:gameObject():GetComponent("RigidBody")
	self.transform = self:gameObject():GetComponent("Transform")

	local selectionSquarePrefab = AssetDatabase:Load("prefabs/selection.asset")
	assert(selectionSquarePrefab ~= nil, "selectionGO not found")
	self.selectionSquareGO = Instantiate(selectionSquarePrefab)
	
	local selectionArrowPrefab = AssetDatabase:Load("prefabs/selectionArrow.asset")
	assert(selectionArrowPrefab ~= nil, "selectionArrowGO not found")
	self.selectionArrowGO = Instantiate(selectionArrowPrefab)
	
	self.character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent

	self:gameObject():GetScene():AddGameObject(self.selectionSquareGO)
	self:gameObject():GetScene():AddGameObject(self.selectionArrowGO)

	self.character.maxSpeed += 0.5

	if World.playerCharacter then
		LogError("Player character is not nil")
	end

	--self.character.name = "Player"

	World.playerCharacter = self.character
end

function PlayerController:OnDisable()
	if World.playerCharacter ~= self.character then
		LogError("Player character is not this player character")
	end
	World.playerCharacter = nil
	self:gameObject():GetScene():RemoveGameObject(self.selectionSquareGO)
	self:gameObject():GetScene():RemoveGameObject(self.selectionArrowGO)
end

function Length(v : vector)
	return math.sqrt (v.x*v.x + v.y*v.y + v.z*v.z)
end
function Lerp(a,b,t) return a * (1-t) + b * t end

function PlayerController:Update()
	if self.character:IsDead() then
		return
	end

	Game:DrawStats(self.character)
	
    if Game.dayTime >= GameConsts.goToSleepImmediatelyDayTime or Game.dayTime < GameConsts.wakeUpDayTime then
		self.character:SetIsSleeping(true)
    elseif Game.dayTime >= GameConsts.goToSleepDayTime or Game.dayTime <= GameConsts.wakeUpDayTime then
		-- time to go to bed mr. player
	elseif self.character.isSleeping then
		self.character:SetIsSleeping(false)
    end

	if self.character.isSleeping then
		return
	end

	local input = Input

	local velocity = vector(0,0,0)
	if input:GetKey("W") or input:GetKey("dpup") then
		velocity = velocity + vector(0,0,1)
	end
	if input:GetKey("S") or input:GetKey("dpdown") then
		velocity = velocity + vector(0,0,-1)
	end
	if input:GetKey("A") or input:GetKey("dpleft") then
		velocity = velocity + vector(-1,0,0)
	end
	if input:GetKey("D") or input:GetKey("dpright") then
		velocity = velocity + vector(1,0,0)
	end
	
	if Length(velocity) > 1.0 then
		velocity = velocity / Length(velocity)
	end
	-- TODO use camera
	velocity = vector(-velocity.z, velocity.y, velocity.x)
	velocity = velocity * self.character.maxSpeed

	self.character.isRunning = not (input:GetKey("Left Shift") or input:GetKey("rightshoulder"))

	self.character:SetVelocity(velocity)
	
	local grid = World.items
	local intPos = self.character:GetIntPos()
	local pos = grid:GetCellWorldCenter(intPos)

	-- local zeroPos = Vector2Int.new()
	-- zeroPos.x = 10
	-- zeroPos.y = 10
	-- local path = World.navigation:CalcPath(cellPos, zeroPos)
	-- Game.DbgDrawPath(path)

	pos = pos + vector(0,0.0,0)
	
	local maxCharacterInteractionDistance = 0.75
    local nearestCharacter = WorldQuery:FindNearestCharacterToInterract(self.character:GetPosition2D(), function(character : Character) return character ~= self.character end)
    if nearestCharacter then
		local distance = Vector2.Distance(nearestCharacter:GetPosition2D(), self.character:GetPosition2D())
		if distance > maxCharacterInteractionDistance then
			nearestCharacter = nil
		end
    end

	local action = nil
	local selectionArrowPos = pos - vector(0,10000,0)
	if nearestCharacter then
		action = nearestCharacter:GetActionOnCharacter(self.character)
		if action and (not action.CanExecute or action:CanExecute()) then
			selectionArrowPos = nearestCharacter:GetPosition() + vector(0,1.5,0)
		end
		Game:DrawStats(nearestCharacter)
		Game:DrawHealthAndHungerUI(nearestCharacter, true)
	end

	
	if not action then
		--TODO sleep on bed vs pick bed action differentiation
		action = self.character:GetActionOnCellPos(intPos)
	end
	if action == nil or action.isCharacter or not action:CanExecute() then
		pos = pos - vector(0,10000,0) --TODO propper hide selection
	end

	local selectionTrans = self.selectionSquareGO:GetComponent("Transform")
	selectionTrans:SetPosition(pos)
	
	local selectionTrans = self.selectionArrowGO:GetComponent("Transform")
	selectionTrans:SetPosition(selectionArrowPos)

	if self.character:IsInDialog() or self.wasInDialogPrevFrame then
		action = nil
	end
	self.wasInDialogPrevFrame = self.character:IsInDialog()
	if Input:GetKeyDown("Space") or Input:GetKeyDown("a") then
		self.character:ExecuteAction(action)
	end

	local cellTypeText = CellTypeInv[grid:GetCell(intPos).type]
	if cellTypeText then
		Dbg.Text(string.format("%s", cellTypeText))
	else
		Dbg.Text(string.format("%d", grid:GetCell(intPos).type))
	end

	--TODO less hacky
	if Input:GetKey("M") or Input:GetKey("x") then
		local markings = World.markings
		local mark = markings:GetCell(intPos)
		if Input:GetKeyDown("M") or Input:GetKeyDown("x") then
			self.isInSettingsMarkingMode = mark.type == CellType.None
		end
		if self.isInSettingsMarkingMode then
			mark.type = CellType.MarkingRed
		else
			mark.type = CellType.None
		end
		markings:SetCell(mark)
	end
end

return PlayerController