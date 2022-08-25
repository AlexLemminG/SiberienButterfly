local World = require("World")
local Game = {
	playerGO = nil,
	characterPrefab = nil,
	luaPlayerGO = nil,
	currentDialog = nil
}
local Component = require("Component")
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local CellAnimType = require("CellAnimType")
local Actions = require("Actions")

-- require("lldebugger").start()

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
	Actions:Init()
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

	local numNPC = 1
	for i = 1, numNPC, 1 do
		local character = Instantiate(self.characterPrefab)
		local characterControllerScript = character:AddComponent("LuaComponent")
		characterControllerScript.luaObj = { scriptName = "CharacterController", data = {}}
		character:GetComponent("Transform"):SetPosition(vector(10.0,0.0,10.0))
		self:gameObject():GetScene():AddGameObject(character)
	end

end


function Game:OnDisable()
	for index, character in ipairs(World.characters) do
		self:gameObject():GetScene():RemoveGameObject(character:gameObject())
	end
	-- self:gameObject():GetScene():RemoveGameObject(self.luaPlayerGO)
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

function Game:MainLoop()
	local dt = Time().deltaTime()

	self:AnimateCells(dt)

	for index, character in ipairs(World.characters) do
		character.hunger = math.clamp(character.hunger + Time().deltaTime() / 100.0, 0.0, 1.0)
	end
end

function Game:DrawUI()
	local screenSize = Graphics():GetScreenSize()
	
	self.ui_selection = 0

	imgui.SetNextWindowSize(200,100)
	imgui.SetNextWindowPos(0, screenSize.y, imgui.constant.Cond.Always, 0,1.0)
	imgui.SetNextWindowBgAlpha(0.1)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar + winFlags.NoInputs)
	imgui.Begin("Lua UI", nil, flags)

	local player = World.characters[1]
	local text = string.format("Hunger: %.3f \nHealth: %.3f", player.hunger, player.health)
	imgui.TextUnformatted(text)

	if self.currentDialog then
		self.currentDialog:Draw()
	end

	imgui.End()
end

function Game:BeginDialog(characterA, characterB)
	self.currentDialog = {
		characterA = characterA,
		characterB = characterB,
		selectedOptionIndex = 1
	}

	function self.currentDialog:Draw()
		local options = { "Go eat bread", "Close" }

		self.selectedOptionIndex = math.clamp(self.selectedOptionIndex, 1, #options)

		local selectedOption = options[self.selectedOptionIndex] --TODO nil check

		local screenSize = Graphics():GetScreenSize()
		imgui.SetNextWindowSize(400,250)
		imgui.SetNextWindowPos(screenSize.x / 2.0, screenSize.y / 2.0 + 400, imgui.constant.Cond.Always, 0.5,0.5)
		imgui.SetNextWindowBgAlpha(1.0)
		local winFlags = imgui.constant.WindowFlags
		local flags = bit32.bor(winFlags.NoInputs)

		imgui.Begin("Dialog", nil, flags)
		imgui.TextUnformatted("DIALOG:")
		--print(self.characterA.GetHumanName, self.characterB.GetHumanName)
		imgui.TextUnformatted(self.characterA:GetHumanName() .. " talks to " .. self.characterB:GetHumanName())		
		
		for index, option in ipairs(options) do
			local optionText = option
			if index == self.selectedOptionIndex then
				optionText = "[*] "..option
			else
				optionText = "[ ] "..option
			end
			imgui.TextUnformatted(optionText)
		end
		imgui.End()

		
		if self.updateInput then
			local input = Input()
			if input:GetKeyDown("S") then
				self.selectedOptionIndex = self.selectedOptionIndex + 1
			end
			if input:GetKeyDown("W") then
				self.selectedOptionIndex = self.selectedOptionIndex - 1
			end
			if input:GetKeyDown("Space") then
				print("Selected ", selectedOption)
				self.characterB.characterController.playerAssignedRule = Actions:GetCombineRule(nil, CellType.None, CellType.Bread_1, CellType.None)
				Game:EndDialog()
			end
		end
		self.updateInput = true
	end
end

function Game:EndDialog() --TODO pass DialogHandle and end one particular dialog
	self.currentDialog = nil
end

function Game:Update()
	for i = 1, 1, 1 do
		self:MainLoop()
	end

	self:DrawUI()
end

return Game