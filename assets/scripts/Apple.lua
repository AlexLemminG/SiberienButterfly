local Apple = {
    followSpeed = 1.0,
    someField = "hello Apple Field",
    someInt = 44,
    editor = {
        i = 0,
        str = "",
        b = true,
        f = 0.0,
        inner = {
            f = 0.0
        }
    }
}
local Component = require("Component")

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

setmetatable(Apple, Component)
Apple.__index = Apple

function Apple:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function lerp(a, b, t)
    t = math.max(0.0, math.min(t, 1.0))
    return a * (1.0 - t) + b * t
end

function GetGrid()
    return Grid()
end

function Apple:Update()
    -- local trans = self:gameObject():GetComponent("Transform")
    -- local velocity = vector(3, 0, -2)
    -- local posT = Time():time() * 5
    -- local pos = vector(math.sin(posT), 0.0, math.cos(posT))

    -- local player = self:gameObject():GetScene():FindGameObjectByTag("player")
    -- local newPos = lerp(trans:GetPosition(), player:GetComponent("Transform"):GetPosition(),
    -- Time():deltaTime() * self.followSpeed)
    -- trans:SetPosition(newPos)
    -- -- trans:SetPosition(pos)
    -- -- print(dump(self.editor))

    -- -- print(Input:GetKey("Z"))
    -- -- print(Time():time())

    -- local t = Transform()

    -- print(self.grid == Grid():Get())
end

function Apple:OnEnable()
    -- print("WHYYYYYYYYYYYYYYYYYYYYYYY")
    -- print(dump(Grid():GetCell({x=3,y=4})))
    -- local cell = Grid():GetCell({x=4,y=4})
    -- local cell2 = GridCell()
    -- cell2.type = 3
    -- Grid():SetCell(cell2)
    -- self.f = 3
    -- print("Hello from Apple 1 ", self.someInt)
    -- local test = Foo() --TODO some error here

    -- -- gameObject()

    -- local fooRest = 33
    -- fooRest = test:foo(3)
    -- print("foo result = ", fooRest)

    -- local gooRest = test:goo(3, 0.14)
    -- print("goo result = ", gooRest)
    -- test:boo()
    -- print("Hello from Apple 2")

    -- -- test:gc()
    -- print(self)
    -- print(self.gameObject)
    -- local go = self:gameObject()
    -- local trans = go:GetComponent("Transform")
    -- print(trans)
    -- local pos = trans:GetPosition()
    -- print(pos)
    -- pos = -pos
    -- trans:SetPosition(pos)
    -- print(pos)

    -- self.grid = GetGrid()
end

return Apple
