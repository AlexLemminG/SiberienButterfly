local World = require("World")
local Game = {
	playerGO = nil,
	characterPrefab = nil,
	luaPlayerGO = nil
}
local Component = require("Component")
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local CellAnimType = require("CellAnimType")
setmetatable(Game, Component)
Game.__index = Game

function Game:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

local gridSizeX = 20
local gridSizeY = 20

function Game:GenerateWorldGrid()
	for x = 0, gridSizeX-1, 1 do
		for y = 0, gridSizeY-1, 1 do
			local height = math.random(10) / 40
			local cell = World.items:GetCell({x=x,y=y})
			local rand1 = math.random(100) / 100.0
			if rand1 > 0.9 then
				cell.type = CellType.Wheat
			elseif rand1 > 0.8 then
				cell.type = CellType.Tree
			elseif rand1 > 0.7 then
				cell.type = CellType.Stone
			elseif rand1 > 0.65 then
				cell.type = CellType.FlintStone
			else
				cell.type = CellType.None
			end
			cell.float4 = 0.0
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

	local itemIdx = 1
	local y = 5
	local x = 10
	while CellTypeInv[itemIdx] do
		itemIdx += 1
		y += 1
		if y >= 15 then
			y = 5
			x += 1
		end
		
		local cell = World.items:GetCell({x=x,y=y})
		cell.type = itemIdx
		World.items:SetCell(cell)
	end
end

function Game:OnEnable()
	World:Init()
	math.randomseed(42)
	if not World.items.isInited then
		self:GenerateWorldGrid()
		World.items.isInited = true
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

function Game:ApplyAnimation(grid, cell)
	local animType = cell.animType

	if animType == CellAnimType.WheatGrowing then
		return
	end

	local animPercent = cell.animT / cell.animStopT

	local localMatrix = Matrix4.Identity()

	if animType == CellAnimType.GotHit then
		local scaleY = 1.0 - math.sin(animPercent * math.pi * 1.0) * 0.1
		local scaleXZ = math.sqrt(1.0 / scaleY)
		Mathf.SetScale(localMatrix, vector(scaleXZ, scaleY, scaleXZ))
	elseif animType == CellAnimType.ItemAppear then
		local scaleY = 1.0 + math.cos(animPercent * math.pi * 0.5) * 0.4
		local scaleXZ = math.sqrt(1.0 / scaleY)

		local posY = (1.0 - animPercent) * 0.1
		Mathf.SetScale(localMatrix, vector(scaleXZ, scaleY, scaleXZ))
		Mathf.SetPos(localMatrix, vector(0, posY, 0))
	end
	
	grid:SetCellLocalMatrix(cell.pos, localMatrix)
end

function Game:HandleAnimationFinished(cell, finishedAnimType)
	-- cell.animType is already 0 at this point

	if finishedAnimType == CellAnimType.WheatGrowing then
		if cell.type == CellType.WheatPlanted_0 then
			cell.animType = CellAnimType.WheatGrowing
			cell.animT = 0.0
			cell.animStopT = 1.0 --TODO param
			cell.type = CellType.WheatPlanted_1
		elseif cell.type == CellType.WheatPlanted_1 then
			cell.type = CellType.Wheat
		end
	end
end

function Game:AnimateCells(dt)
	local items = World.items
	local v = Vector2Int:new()
	local dt = Time().deltaTime()
	local cell = GridCell:new()
	for x = 0, gridSizeX-1, 1 do
		for y = 0, gridSizeY-1, 1 do
			v.x = x
			v.y = y
			items:GetCellOut(cell, v)
			if cell.animType == CellAnimType.None then
				continue
			end
			cell.animT = cell.animT + dt

			Game:ApplyAnimation(items, cell)

			if cell.animT >= cell.animStopT then
				local animType = cell.animType
				cell.animType = CellAnimType.None
				self:HandleAnimationFinished(cell, animType)
				Game:ApplyAnimation(items, cell)
			end
			items:SetCell(cell)
		end
	end
end

function Game:Update()
	for i = 1, 1, 1 do
		self:AnimateCells(Time().deltaTime())
	end
	-- self:GrowAllPlants(Time().deltaTime())
end

return Game