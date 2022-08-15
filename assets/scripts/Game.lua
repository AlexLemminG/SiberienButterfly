local World = require("World")
local Game = {
	playerGO = nil,
	characterPrefab = nil,
	luaPlayerGO = nil
}
local Component = require("Component")
local CellType = require("CellType")
setmetatable(Game, Component)
Game.__index = Game

function Game:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end


function Game:OnEnable()
	World:Init()
	math.randomseed(42)
	for x = 0, 19, 1 do
		for y = 0, 19, 1 do
			local height = math.random(10) / 40
			local cell = World.items:GetCell({x=x,y=y})
			if math.random(100) > 90 then
				cell.type = CellType.Wheat
			else
				cell.type = CellType.None
			end
			cell.z = height
			World.items:SetCell(cell)

			cell = World.ground:GetCell({x=x,y=y})
			if math.random(100) > 32 then
				cell.type = CellType.GroundWithGrass
			elseif math.random(100) > 50 then
				cell.type = CellType.GroundPrepared
			else
				cell.type = CellType.Ground
			end
			cell.z = height
			World.ground:SetCell(cell)
		end
	end

	self.playerGO = self:gameObject():GetScene():FindGameObjectByTag("player")
	
	self.characterPrefab = AssetDatabase():Load("prefabs/character.asset")
	
	self.luaPlayerGO = Instantiate(self.characterPrefab)
	self.luaPlayerGO:GetComponent("Transform"):SetPosition(vector(10.0,0.0,10.0))
	self.luaPlayerGO.tag = "player"
	-- local pointLight = self.luaPlayerGO:AddComponent("PointLight")
	local playerScript = self.luaPlayerGO:AddComponent("LuaComponent")
	
	playerScript.luaObj = { scriptName = "PlayerController", data = {}}
	-- playerScript.scriptName = "Character"	--- TODO support from engine
	-- playerScript.scale = 0.8

	self:gameObject():GetScene():AddGameObject(self.luaPlayerGO)

end


function Game:OnDisable()
	if self.luaPlayerGO ~= nil then
		self:gameObject():GetScene():RemoveGameObject(self.luaPlayerGO)
	end
end

function Game:GrowAllPlants(dt)
	local items = World.items
	local v = Vector2Int:new()
	local dt = Time().deltaTime()
	for x = 0, 19, 1 do
		for y = 0, 19, 1 do
			v.x = x
			v.y = y
			local cell = items:GetCell(v)
			if cell.type == CellType.WheatPlanted_0 then
				cell.float1 = cell.float1 + dt
				if cell.float1 >= 1.0 then -- to params
					cell.float1 = 0.0
					cell.type = CellType.WheatPlanted_1
				end
			elseif cell.type == CellType.WheatPlanted_1 then
				cell.float1 = cell.float1 + dt
				if cell.float1 >= 1.0 then
					cell.type = CellType.Wheat
				end
			else
				continue
			end
			items:SetCell(cell)
		end
	end
end

function Game:Update()
	self:GrowAllPlants(Time().deltaTime())
end

return Game