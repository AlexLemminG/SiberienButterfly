
local PlayerController = {
	speed = 3,
	rigidBody = nil
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
end

local function Length(v : vector)
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

	local velocity = self.rigidBody:GetLinearVelocity()
	local newVelocity = Lerp(velocity, deltaPos, 0.8)
	newVelocity = vector(newVelocity.x, math.min(velocity.y, 0), newVelocity.z)
	self.rigidBody:SetLinearVelocity(newVelocity)

	self.rigidBody:SetAngularVelocity(vector(0,0,0))

	
end

return PlayerController