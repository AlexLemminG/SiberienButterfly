local Apple = {}
local Component = require("Component")

setmetatable(Apple, Component)
Apple.__index = Apple


function Apple:new(o)
	o = Component:new(o)
	setmetatable(o, self)
	return o
end

function Apple:Update()
	-- print("AppleUpdate")
end

function Apple:OnEnable()

	print("Hello from Apple 1")
	local test = Foo()
	
	local fooRest = 33
	fooRest = test:foo(3)
	print("foo result = ", fooRest)
	
	local gooRest = test:goo(3, 0.14)
	print("goo result = ", gooRest)
	test:boo()
	print("Hello from Apple 2")

end

return Apple