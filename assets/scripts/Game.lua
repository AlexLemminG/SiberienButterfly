local World = require("World")
local Game = {
	playerGO = nil,
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


function Game:OnEnable()
	self.playerGO = self:gameObject():GetScene():FindGameObjectByTag("player")
	
	self.grid = Grid()
	-- print("trans = ", selectionTrans)
	
	self.characterPrefab = AssetDatabase():Load("prefabs/character.asset")
	
	self.luaPlayerGO = Instantiate(self.characterPrefab)

	self.luaPlayerGO.tag = "player"
	-- local pointLight = self.luaPlayerGO:AddComponent("PointLight")
	local playerScript = self.luaPlayerGO:AddComponent("LuaComponent")
	
	playerScript.luaObj = { scriptName = "PlayerController", data = {}}
	-- playerScript.scriptName = "Character"	--- TODO support from engine
	-- playerScript.scale = 0.8

	self:gameObject():GetScene():AddGameObject(self.luaPlayerGO)

	World:Init()
end


function Game:OnDisable()
	if self.luaPlayerGO ~= nil then
		self:gameObject():GetScene():RemoveGameObject(self.luaPlayerGO)
	end
end


function Game:Update()
end

return Game