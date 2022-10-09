local CellType = require("CellType")
local Grid = require("Grid")
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
	selectionGO = nil,
	wasInDialogPrevFrame = false,
	character = nil
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

	self.selectionGO = AssetDatabase:Load("prefabs/selection.asset")
	assert(self.selectionGO ~= nil, "selectionGO not found")
	self.selectionGO = Instantiate(self.selectionGO)
	self.selectionGO.tag = "notselection"
	
	self.character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent

	self:gameObject():GetScene():AddGameObject(self.selectionGO)

	if World.playerCharacter then
		LogError("Player character is not nil")
	end

	self.character.name = "Player"

	World.playerCharacter = self.character
end

function PlayerController:OnDisable()
	if World.playerCharacter ~= self.character then
		LogError("Player character is not this player character")
	end
	World.playerCharacter = nil
	self:gameObject():GetScene():RemoveGameObject(self.selectionGO)
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
	
    if Game.dayTimePercent >= GameConsts.goToSleepImmediatelyTimePercent or Game.dayTimePercent < GameConsts.wakeUpDayTimePercent then
		self.character:SetIsSleeping(true)
    elseif Game.dayTimePercent >= GameConsts.goToSleepDayTimePercent or Game.dayTimePercent <= GameConsts.wakeUpDayTimePercent then
		-- time to go to bed mr. player
	elseif self.character.isSleeping then
		self.character:SetIsSleeping(false)
    end

	if self.character.isSleeping then
		return
	end

	local input = Input

	local velocity = vector(0,0,0)
	if input:GetKey("W") then
		velocity = velocity + vector(0,0,1)
	end
	if input:GetKey("S") then
		velocity = velocity + vector(0,0,-1)
	end
	if input:GetKey("A") then
		velocity = velocity + vector(-1,0,0)
	end
	if input:GetKey("D") then
		velocity = velocity + vector(1,0,0)
	end
	
	if Length(velocity) > 1.0 then
		velocity = velocity / Length(velocity)
	end
	-- TODO use camera
	velocity = vector(-velocity.z, velocity.y, velocity.x)
	velocity = velocity * self.character.maxSpeed

	if self.character.item ~= CellType.None then
		velocity = velocity * 0.8
	end
	--TODO should be handled by Character class
	self.character:SetVelocity(velocity)
	
	local grid = World.items
	local selectionTrans = self.selectionGO:GetComponent("Transform")
	
	local cellPos = grid:GetClosestIntPos(self.transform:GetPosition())
	local pos = grid:GetCellWorldCenter(cellPos)
	
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
	if nearestCharacter then
		action = self.character:GetActionOnCharacter(nearestCharacter)
        Dbg.DrawPoint(nearestCharacter:GetPosition() + vector(0,2.0,0), 0.25)
		Game:DrawStats(nearestCharacter)
	end

	
	if not action then
		--TODO sleep on bed vs pick bed action differentiation
		action = self.character:GetActionOnCellPos(cellPos)
	end
	if action == nil or action.isCharacter or not action:CanExecute() then
		pos = pos - vector(0,10000,0) --TODO propper hide selection
	end
	selectionTrans:SetPosition(pos)
	if action and action.isCharacter and nearestCharacter then
        Dbg.DrawPoint(nearestCharacter:GetPosition() + vector(0,2.0,0), 0.25)
	end

	if self.character:IsInDialog() or self.wasInDialogPrevFrame then
		action = nil
	end
	self.wasInDialogPrevFrame = self.character:IsInDialog()
	if Input:GetKeyDown("Space") then
		self.character:ExecuteAction(action)
	end

	local cellTypeText = CellTypeInv[grid:GetCell(cellPos).type]
	if cellTypeText then
		Dbg.Text(string.format("%s", cellTypeText))
	else
		Dbg.Text(string.format("%d", grid:GetCell(cellPos).type))
	end
end

return PlayerController