local ComponentTemplate = {
}
local Component = require("Component")

setmetatable(ComponentTemplate, Component)
ComponentTemplate.__index = ComponentTemplate

function ComponentTemplate:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function ComponentTemplate:Update()

end

function ComponentTemplate:OnEnable()

end

function ComponentTemplate:OnDisable()

end

return ComponentTemplate
