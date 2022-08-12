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
				cell.type = CellType.SPHERE
			else
				cell.type = CellType.NONE
			end
			cell.z = height
			World.items:SetCell(cell)

			cell = World.ground:GetCell({x=x,y=y})
			cell.type = CellType.GROUND
			cell.z = height
			World.ground:SetCell(cell)
		end
	end

	print("World", World, World.items)

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


function Game:Update()
	
end

return Game