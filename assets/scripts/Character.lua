
local Character = {
	runAnimation = nil,
	standAnimation = nil,
	runWithItemAnimation = nil,
	standWithItemAnimation = nil,
	animator = nil,
	rigidBody = nil
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
end

function Character:Update()
	self.animator:SetAnimation(self.runAnimation)
end
--TODO global func or vector.func
function Length(v : vector)
	return math.sqrt (v.x*v.x + v.y*v.y + v.z*v.z)
end
function Lerp(a,b,t) return a * (1-t) + b * t end

function Character:Move(deltaPos : vector)
	local trans = self.rigidBody:GetTransform()
	if Length(deltaPos) > 0.1 then
		Mathf.SetRot(trans, Quaternion.LookAt(deltaPos, vector(0,1,0)))
	end
	self.rigidBody:SetTransform(trans)
	--print("q=", Quaternion.LookAt(vector(0,0,1), vector(0,1,0)):scalar())

	self.rigidBody:Activate()

	local velocity = self.rigidBody:GetLinearVelocity()
	local newVelocity = Lerp(velocity, deltaPos, 0.8)
	newVelocity = vector(newVelocity.x, math.min(velocity.y, 0), newVelocity.z)
	
	self.rigidBody:SetLinearVelocity(newVelocity)

	self.rigidBody:SetAngularVelocity(vector(0,0,0))

	if Length(deltaPos) > 0.1 then
		self.animator:SetAnimation(self.runAnimation)
	else
		self.animator:SetAnimation(self.standAnimation) 
	end
end

return Character