
local PlayerController = {
	speed = 3,
	rigidBody = nil,
	transform = nil,
	selectionGO = nil
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

	self.selectionGO = AssetDatabase():Load("prefabs/selection.asset")
	assert(self.selectionGO ~= nil, "selectionGO not found")
	self.selectionGO = Instantiate(self.selectionGO)
	self.selectionGO.tag = "notselection"

	self:gameObject():GetScene():AddGameObject(self.selectionGO)
end

function PlayerController:OnDisable()
	self:gameObject():GetScene():RemoveGameObject(self.selectionGO)
end

function Length(v : vector)
	return math.sqrt (v.x*v.x + v.y*v.y + v.z*v.z)
end
function Lerp(a,b,t) return a * (1-t) + b * t end

function PlayerController:Update()
	local input = Input()

	
	local deltaPos = vector(0,0,0)
	if input:GetKey("W") then
		deltaPos = deltaPos + vector(0,0,1)
	end
	if input:GetKey("S") then
		deltaPos = deltaPos + vector(0,0,-1)
	end
	if input:GetKey("A") then
		deltaPos = deltaPos + vector(-1,0,0)
	end
	if input:GetKey("D") then
		deltaPos = deltaPos + vector(1,0,0)
	end

	if Length(deltaPos) > 1.0 then
		deltaPos = deltaPos / Length(deltaPos)
	end
	-- TODO use camera
	deltaPos = vector(-deltaPos.z, deltaPos.y, deltaPos.x)
	deltaPos = deltaPos * self.speed

	local character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent
	character:Move(deltaPos)

	

	local grid = Grid()	
	local selectionTrans = self.selectionGO:GetComponent("Transform")
	
	local cellPos = grid:GetClosestIntPos(self.transform:GetPosition())
	local pos = grid:GetCellWorldCenter(cellPos)
	
	pos = pos + vector(0,0.0,0)
	selectionTrans:SetPosition(pos)

	local cell = grid:GetCell(cellPos)
	if Input():GetKeyDown("Space") then
		cell.type = (cell.type + 1) % 2
		grid:SetCell(cell)
	end
end

return PlayerController