local Apple = {
	someField = "hello Apple Field",
	someInt = 44
}
local Component = require("Component")

setmetatable(Apple, Component)
Apple.__index = Apple


function Apple:new(o)
	o = Component:new(o)
	setmetatable(o, self)
	return o
end

function Apple:Update()
	local trans = self:gameObject():GetComponent("Transform")
	local velocity = vector(3,0,-2)
	trans:SetPosition(trans:GetPosition() + velocity * deltaTime())
end

function Apple:OnEnable()

	print("Hello from Apple 1 ", someInt)
	local test = Foo()
	
	-- gameObject()
	
	local fooRest = 33
	fooRest = test:foo(3)
	print("foo result = ", fooRest)
	
	local gooRest = test:goo(3, 0.14)
	print("goo result = ", gooRest)
	test:boo()
	print("Hello from Apple 2")
	
	-- test:gc()
	local go = self:gameObject()
	local trans = go:GetComponent("Transform")
	print(trans)
	local pos = trans:GetPosition()
	print(pos)
	pos = -pos
	trans:SetPosition(pos)
	print(pos)
end

return Apple