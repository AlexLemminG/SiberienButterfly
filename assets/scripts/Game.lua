
local Game = {
	playerGO = nil,
	selectionGO = nil,
	grid = nil
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
end


function Game:OnDisable()
	if self.selectionGO ~= nil then
		self:gameObject():GetScene():RemoveGameObject(self.selectionGO)
	end
end


function Game:Update()
	local selectionTrans = self.selectionGO:GetComponent("Transform")
	local playerTrans = self.playerGO:GetComponent("Transform")
	
	local cellPos = self.grid:GetClosestIntPos(playerTrans:GetPosition())
	local pos = self.grid:GetCellWorldCenter(cellPos)
	
	pos = pos + vector(0,0.0,0)
	selectionTrans:SetPosition(pos)

	if Input():GetKeyDown("Space") then
		print("Jump")
		local cell = self.grid:GetCell(cellPos)
		cell.type = (cell.type + 1) % 2
		self.grid:SetCell(cell)
	end
	-- print(Grid(), " ", self.grid)

	-- print("h")
end

return Game