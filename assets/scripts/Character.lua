
local Character = {
	runAnimation = nil,
	standAnimation = nil,
	runWithItemAnimation = nil,
	standWithItemAnimation = nil,
	animator,
	scale = 1.0
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
	
	local transform = self:gameObject():GetComponent("Transform")
	transform:SetScale(vector(self.scale, self.scale, self.scale))
end

function Character:Update()
	self.animator:SetAnimation(self.standWithItemAnimation)
end

return Character