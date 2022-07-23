
local Game = {
	playerGO = nil,
	selectionGO = nil,
	grid = nil,
	characterPrefab = nil,
	luaPlayerGO = nil
}
local Component = require("Component")
setmetatable(Game, Component)
Game.__index = Game

function Game:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

local A = { a = 1 }
A.__index = A
local B = { b = 2 }
B.__index = B
setmetatable(B, A)
local C = { c = 3 }
setmetatable(C, B)
print("C==========================================", C.a)


function Game:OnEnable()
	self.playerGO = self:gameObject():GetScene():FindGameObjectByTag("player")
	self.selectionGO = AssetDatabase():Load("prefabs/selection.asset")
	assert(self.selectionGO ~= nil, "selectionGO not found")
	print("SELEEE+++++++++++++++++++", self.selectionGO)
	self.selectionGO = Instantiate(self.selectionGO)
	print("SELEEE+++++++++++++++++++", self.selectionGO)
	-- local selectionTrans = self.selectionGO:GetComponent("Transform")
	
	self:gameObject():GetScene():AddGameObject(self.selectionGO)
	-- selectionTrans:SetPosition(vec3(0,0,0))
	
	self.grid = Grid()
	print("trans = ", selectionTrans)
	
	self.characterPrefab = AssetDatabase():Load("prefabs/character.asset")
	
	self.luaPlayerGO = Instantiate(self.characterPrefab)

	self.luaPlayerGO.tag = "LuaPlayer"
	-- local pointLight = self.luaPlayerGO:AddComponent("PointLight")
	local playerScript = self.luaPlayerGO:AddComponent("LuaComponent")
	
	playerScript.luaObj = { scriptName = "PlayerController", data = {}}
	-- playerScript.scriptName = "Character"	--- TODO support from engine
	-- playerScript.scale = 0.8

	self:gameObject():GetScene():AddGameObject(self.luaPlayerGO)
end


function Game:OnDisable()
	if self.selectionGO ~= nil then
		self:gameObject():GetScene():RemoveGameObject(self.selectionGO)
	end
	if self.luaPlayerGO ~= nil then
		self:gameObject():GetScene():RemoveGameObject(self.luaPlayerGO)
	end
end


function Game:Update()
	-- local selectionTrans = self.selectionGO:GetComponent("Transform")
	-- local playerTrans = self.playerGO:GetComponent("Transform")
	
	-- local cellPos = self.grid:GetClosestIntPos(playerTrans:GetPosition())
	-- local pos = self.grid:GetCellWorldCenter(cellPos)
	
	-- pos = pos + vector(0,0.0,0)
	-- selectionTrans:SetPosition(pos)

	-- if Input():GetKeyDown("Space") then
		-- print("Jump")
		-- local cell = self.grid:GetCell(cellPos)
		-- cell.type = (cell.type + 1) % 2
		-- self.grid:SetCell(cell)
	-- end
end

return Game