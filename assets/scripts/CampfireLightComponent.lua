local CampfireLightComponent = {
    light = nil,
    initialIntencity = 3.0
}
local Component = require("Component")

setmetatable(CampfireLightComponent, Component)
CampfireLightComponent.__index = CampfireLightComponent

function CampfireLightComponent:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function CampfireLightComponent:Update()
    local time = Time.time()
    self.light.intensity = self.initialIntencity *
        (1
            + 0.1 * math.sin(time * 13)
            + 0.1 * math.sin(time * 7)
            + 0.03 * math.sin(time * 77)
        )
end

function CampfireLightComponent:OnEnable()
    self.light = self:gameObject():GetComponent("PointLight")
    self.initialIntencity = self.light.intensity
end

function CampfireLightComponent:OnDisable()

end

return CampfireLightComponent
