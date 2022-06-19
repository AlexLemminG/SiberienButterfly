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
	print("AppleUpdate")
end

return Apple