local World = require("World")
local GameConsts = require("GameConsts")
local Utils      = require("Utils")
local CellAnimations = require("CellAnimations")
local Game = {
	playerGO = nil,
	characterPrefab = nil,
	luaPlayerGO = nil,
	currentDialog = nil,
	isInited = false,
	gridSizeX = 20,--TODO sync with c++ grid
	gridSizeY = 20,
	newGrowTreePercent = 0.0
}
local Component = require("Component")
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local CellAnimType = require("CellAnimType")
local Actions = require("Actions")
local CharacterCommandFactory = require("CharacterCommandFactory")

-- require("lldebugger").start()

setmetatable(Game, Component)
Game.__index = Game

function Game:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end


function Game:GenerateWorldGrid()
	for x = 0, self.gridSizeX-1, 1 do
		for y = 0, self.gridSizeY-1, 1 do
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

	for x = 3, 4, 1 do
		for y = 0, self.gridSizeY-1, 1 do

			local cell = World.items:GetCell({x=x,y=y})
			cell.type = CellType.None
			cell.z = 0.0
			World.items:SetCell(cell)

			cell = World.ground:GetCell({x=x,y=y})
			cell.type = CellType.Water
			cell.z = 0.0

			World.ground:SetCell(cell)
		end
	end


	local itemIdx = 1
	local y = 5
	local x = 10
	while CellTypeInv[itemIdx] do
		itemIdx = itemIdx + 1
		y = y + 1
		if y >= 15 then
			y = 5
			x = x + 1
		end
		
		local cell = World.items:GetCell({x=x,y=y})
		cell.type = itemIdx
		World.items:SetCell(cell)
	end
end

function CreatePlayerGO()
	local characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	local luaPlayerGO = Instantiate(characterPrefab)
	luaPlayerGO:GetComponent("Transform"):SetPosition(vector(10.0,0.0,10.0))
	luaPlayerGO.tag = "player"
	-- local pointLight = luaPlayerGO:AddComponent("PointLight")
	local playerScript = luaPlayerGO:AddComponent("LuaComponent")
	
	playerScript.luaObj = { scriptName = "PlayerController", data = {}}

	-- playerScript.scriptName = "Character"	--- TODO support from engine
	-- playerScript.scale = 0.8
	return luaPlayerGO
end

function CreateNpcGO()
	local characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	local character = Instantiate(characterPrefab)
	local characterControllerScript = character:AddComponent("LuaComponent")
	characterControllerScript.luaObj = { scriptName = "CharacterController", data = {}}
	character:GetComponent("Transform"):SetPosition(vector(10.0,0.0,10.0))

	return character
end
--TODO Game as not component but just as a module ?
function Game:OnEnable()
	World:Init()
	math.randomseed(42)
	if not Game.isInited then
		self:GenerateWorldGrid()
		Game.isInited = true
	end
	Actions:Init()
	-- print(AssetDatabase)
	-- print(AssetDatabase:Load("prefabs/character.asset"))
	self.characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	self.luaPlayerGO = CreatePlayerGO()
	self:gameObject():GetScene():AddGameObject(self.luaPlayerGO)

	local numNPC = 9
	for i = 1, numNPC, 1 do
		local character = CreateNpcGO()
		self:gameObject():GetScene():AddGameObject(character)
	end
end

function Game.CreateSave()
	print("Creating Lua Save")
	local save = { 
		characters = { }
	}

	for index, character in ipairs(World.characters) do
		table.insert(save.characters, character:SaveState())
	end

	return save
end

function Game.LoadSave(save) : boolean
	print("Loading Lua Save")
	if not save then
		print("Lua loading failed: no save")
		return false
	end

	Game.isInited = true

	for i = #World.characters, 1, -1 do
		SceneManager.GetCurrentScene():RemoveGameObject(World.characters[i]:gameObject())
	end
	for index, savedCharacter in pairs(save.characters) do
		local characterGO = nil
		if index == 1 or index == "1" then
			characterGO = CreatePlayerGO()
		else
			characterGO = CreateNpcGO()
		end
		local characterScript : Character = characterGO:GetComponent("LuaComponent") --TODO GetLuaComponent
		SceneManager.GetCurrentScene():AddGameObject(characterGO)
		characterScript:LoadState(savedCharacter)
	end
	return true
end


function Game:OnDisable()

end

function Game:ApplyAnimation(grid, cell)
	local animType = cell.animType

	if animType == CellAnimType.WheatGrowing or animType == CellAnimType.TreeSproutGrowing then
		return
	end

	local animPercent = cell.animT / cell.animStopT

	local localMatrix = Matrix4.Identity()

	if animType == CellAnimType.GotHit then
		local scaleY = 1.0 - math.sin(animPercent * math.pi * 1.0) * 0.1
		local scaleXZ = math.sqrt(1.0 / scaleY)
		Mathf.SetScale(localMatrix, vector(scaleXZ, scaleY, scaleXZ))
	elseif animType == CellAnimType.ItemAppear or animType == CellAnimType.ItemAppearWithoutXZScale then
		local scaleY = 1.0 + math.cos(animPercent * math.pi * 0.5) * 0.4
		local scaleXZ = math.sqrt(1.0 / scaleY)
		if animType == CellAnimType.ItemAppearWithoutXZScale then
			scaleXZ = 1.0
		end

		local posY = (1.0 - animPercent) * 0.1
		Mathf.SetScale(localMatrix, vector(scaleXZ, scaleY, scaleXZ))
		Mathf.SetPos(localMatrix, vector(0, posY, 0))
	elseif animType == CellAnimType.ItemAppearFromGround or animType == CellAnimType.ItemAppearFromGroundWithoutXZScale then
		local scaleY = 1.0 - math.cos(animPercent * math.pi * 0.5) * 0.4
		local scaleXZ = math.sqrt(1.0 / scaleY) * (0.8 + animPercent) / 1.8
		if animType == CellAnimType.ItemAppearFromGroundWithoutXZScale then
			scaleXZ = 1.0
		end

		local posY = (-1.0 + animPercent) * 0.1
		Mathf.SetScale(localMatrix, vector(scaleXZ, scaleY, scaleXZ))
		Mathf.SetPos(localMatrix, vector(0, posY, 0))
	end
	
	grid:SetCellLocalMatrix(cell.pos, localMatrix)
end


function Game:HandleAnimationFinished(cell, finishedAnimType)
	-- cell.animType is already 0 at this point

	local isAppearAnim = finishedAnimType == CellAnimType.ItemAppear or finishedAnimType == CellAnimType.ItemAppearWithoutXZScale or finishedAnimType == CellAnimType.ItemAppearFromGround or finishedAnimType == CellAnimType.ItemAppearFromGroundWithoutXZScale

	if finishedAnimType == CellAnimType.WheatGrowing then
		if cell.type == CellType.WheatPlanted_0 then
			CellAnimations.SetAppearFromGroundWithoutXZScale(cell)
			cell.type = CellType.WheatPlanted_1
		elseif cell.type == CellType.WheatPlanted_1 then
			CellAnimations.SetAppearFromGroundWithoutXZScale(cell)
			cell.type = CellType.Wheat
		end
	elseif finishedAnimType == CellAnimType.TreeSproutGrowing then
		cell.type = CellType.Tree
		CellAnimations.SetAppearFromGround(cell)
	elseif isAppearAnim then
		if cell.type == CellType.TreeSprout then
			cell.animType = CellAnimType.TreeSproutGrowing
			cell.animT = 0.0
			cell.animStopT = GameConsts.treeSproutToTreeGrowthTime
		elseif cell.type == CellType.WheatPlanted_0 then
			cell.animType = CellAnimType.WheatGrowing
			cell.animT = 0.0
			cell.animStopT = GameConsts.wheatGrowthTime0
		elseif cell.type == CellType.WheatPlanted_1 then
			cell.animType = CellAnimType.WheatGrowing
			cell.animT = 0.0
			cell.animStopT = GameConsts.wheatGrowthTime1
		end
	end
end

function Game:AnimateCells(dt)
	local items = World.items
	local v = Vector2Int:new()
	local dt = Time.deltaTime()
	local cell = GridCell:new()
	for x = 0, self.gridSizeX-1, 1 do
		for y = 0, self.gridSizeY-1, 1 do
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

function Game:GrowNewTrees(deltaTime : number)
	local secondsPerMinute = 60.0
	local numToAppear = GameConsts.newTreeApearProbabilityPerCellPerMinute * deltaTime / secondsPerMinute * self.gridSizeX * self.gridSizeY
	
	self.newGrowTreePercent = self.newGrowTreePercent + numToAppear
	while self.newGrowTreePercent > 1 do
		self.newGrowTreePercent = self.newGrowTreePercent - 1

		--TODO GetRandomPoint function
		--TODO is it within range ?
		local xPos = math.ceil(Random.Range(0, self.gridSizeX - 1.0))
		local yPos = math.ceil(Random.Range(0, self.gridSizeY - 1.0))

		local cellPos = Vector2Int.new(0,0)
		local canGrow = true
		for x = xPos-1, xPos+1, 1 do
			for y = yPos-1, yPos+1, 1 do
				cellPos.x = x
				cellPos.y = y

				local itemsCell = World.items:GetCell(cellPos)
				if itemsCell.type ~= CellType.None then
					canGrow = false
					break
				end
			end
			if not canGrow then
				break
			end
		end
		if not canGrow then
			continue
		end

		cellPos.x = xPos
		cellPos.y = yPos
				
		local groundCell = World.ground:GetCell(cellPos)
		if groundCell.type ~= CellType.Ground and groundCell.type ~= CellType.GroundWithGrass then
			continue
		end
		
		local itemsCell = World.items:GetCell(cellPos)
		itemsCell.type = CellType.TreeSprout
		CellAnimations.SetAppearFromGround(itemsCell)
		World.items:SetCell(itemsCell)
	end
end

function Game:MainLoop()
	local dt = Time.deltaTime()

	self:AnimateCells(dt)

	self:GrowNewTrees(dt)

	for index, character in ipairs(World.characters) do
		character.hunger = math.clamp(character.hunger + dt * GameConsts.hungerPerSecond, 0.0, 1.0)
		if character.hunger == 1.0 then
			character.health = math.clamp(character.health - dt * GameConsts.healthLossFromHungerPerSecond, 0.0, 1.0)
		end
	end
	for i = #World.characters, 1, -1 do
		local character = World.characters[i]
		if character.health == 0.0 then
			character:Die()
		end
	end
end

function Game:DrawStats(character : Character)
	local isPlayer = character == World.characters[1]
	
	local screenSize = Graphics:GetScreenSize()
	
	imgui.SetNextWindowSize(200,100)
	if isPlayer then
		imgui.SetNextWindowPos(0, screenSize.y, imgui.constant.Cond.Always, 0,1.0)
	else
		imgui.SetNextWindowPos(screenSize.x, screenSize.y, imgui.constant.Cond.Always, 1.0,1.0)
	end
	imgui.SetNextWindowBgAlpha(0.1)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar + winFlags.NoInputs)
	imgui.Begin("Character stats "..tostring(isPlayer), nil, flags)

	local text = string.format("Name: %s\nHunger: %.3f \nHealth: %.3f", character.name, character.hunger, character.health)
	imgui.TextUnformatted(text)
	imgui.End()
end

function Game:DrawWorldStats()
	local screenSize = Graphics:GetScreenSize()

	imgui.SetNextWindowSize(200,150)
	imgui.SetNextWindowPos(0, screenSize.y / 2, imgui.constant.Cond.Always, 0.0,0.5)
	imgui.SetNextWindowBgAlpha(0.1)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar + winFlags.NoInputs)
	imgui.Begin("World Stats", nil, flags)

	local avgHealth = 0.0
	local avgHunger = 0.0
	if #World.characters > 0 then
		for index, character in ipairs(World.characters) do
			avgHealth = avgHealth + character.health
			avgHunger = avgHunger + character.hunger
		end
		avgHealth = avgHealth / #World.characters
		avgHunger = avgHunger / #World.characters
	end
	local text = string.format("Avg Hunger: %.3f\nAvg Health: %.3f", avgHunger, avgHealth)
	imgui.TextUnformatted(text)
	imgui.End()
end

function Game:DrawUI()
	self:DrawStats(World.characters[1])
	if self.currentDialog then
		self.currentDialog:Draw()
	end
	self:DrawWorldStats()
end

function Game:BeginDialog(characterA : Character, characterB : Character)
	self.currentDialog = {
		characterA = characterA,
		characterB = characterB,
		selectedOptionIndex = 1,

		selectedOptionIndices = {},

		firstOptionItem = nil,
		secondOptionItem = nil
	}

	local hiddenItems = {}
	for i = CellType.Bread_1, CellType.Bread_1 + GameConsts.maxBreadStackSize - 1, 1 do
		hiddenItems[i] = true
	end
	for i = CellType.WheatCollected_1, CellType.WheatCollected_1 + GameConsts.maxWheatStackSize - 2, 1 do
		hiddenItems[i] = true
	end
	

	function self.currentDialog:Draw()
		local options = { }
		local optionItems = {}
		if not self.firstOptionItem then
			for cellTypeName, cellType in pairs(CellType) do
				if hiddenItems[cellType] then
					continue
				end
				for index, rule in ipairs(Actions:GetAllCombineRules(cellType, CellType.Any, CellType.Any)) do
					table.insert(options, CellTypeInv[cellType])
					optionItems[CellTypeInv[cellType]] = cellType
					break
				end
			end

			optionItems["Back"] = nil
			table.insert(options, "Back")
		elseif not self.secondOptionItem then
			local added = {}
			for index, rule in ipairs(Actions:GetAllCombineRules(self.firstOptionItem, CellType.Any, CellType.Any)) do
				if not added[rule.itemType] and not hiddenItems[rule.itemType] then
					added[rule.itemType] = true
					table.insert(options, CellTypeInv[rule.itemType])
					optionItems[CellTypeInv[rule.itemType]] = rule.itemType
				end
			end

			optionItems["Back"] = nil
			table.insert(options, "Back")
		else
			local added = {}
			for index, rule in ipairs(Actions:GetAllCombineRules(self.firstOptionItem, self.secondOptionItem, CellType.Any)) do
				if not added[rule.groundType] and not hiddenItems[rule.groundType] then
					added[rule.groundType] = true
					table.insert(options, CellTypeInv[rule.groundType])
					optionItems[CellTypeInv[rule.groundType]] = rule.groundType
				end
			end

			optionItems["Back"] = nil
			table.insert(options, "Back")
		end

		self.selectedOptionIndex = math.clamp(self.selectedOptionIndex, 1, #options)

		local selectedOption = options[self.selectedOptionIndex] --TODO nil check

		local screenSize = Graphics:GetScreenSize()
		imgui.SetNextWindowSize(400,250)
		imgui.SetNextWindowPos(screenSize.x / 2.0, screenSize.y / 2.0 + 400, imgui.constant.Cond.Always, 0.5,0.5)
		imgui.SetNextWindowBgAlpha(1.0)
		local winFlags = imgui.constant.WindowFlags
		local flags = 0--bit32.bor(winFlags.NoDrag)

		imgui.Begin("Dialog", nil, flags)
		imgui.TextUnformatted("DIALOG:")
		--print(self.characterA.GetHumanName, self.characterB.GetHumanName)
		local text = ""
		imgui.TextUnformatted(self.characterA:GetHumanName() .. " talks to " .. self.characterB:GetHumanName())
		for index, value in ipairs({self.firstOptionItem, self.secondOptionItem}) do
			if value then
				text = text.." "..CellTypeInv[value]
			end
		end
		imgui.TextUnformatted(text)
		
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
			local input = Input
			if input:GetKeyDown("S") then
				self.selectedOptionIndex = self.selectedOptionIndex + 1
			end
			if input:GetKeyDown("W") then
				self.selectedOptionIndex = self.selectedOptionIndex - 1
			end
			local acceptPressed = input:GetKeyDown("Space")
			if input:GetKeyDown("Escape") then
				acceptPressed = true
				selectedOption = "Back"
			end
			if acceptPressed then
				print("Selected ", selectedOption)
				local selectedItem = optionItems[selectedOption]
				if not self.firstOptionItem then
					if selectedItem then
						table.insert(self.selectedOptionIndices, self.selectedOptionIndex)
						self.selectedOptionIndex = 1
						self.firstOptionItem = selectedItem
					else
						Game:EndDialog()
					end
				elseif not self.secondOptionItem then
					if selectedItem then
						table.insert(self.selectedOptionIndices, self.selectedOptionIndex)
						self.selectedOptionIndex = 1
						self.secondOptionItem = selectedItem
					else
						self.firstOptionItem = nil
						self.selectedOptionIndex = self.selectedOptionIndices[#self.selectedOptionIndices]
						table.remove(self.selectedOptionIndices, #self.selectedOptionIndices)
					end
				else
					if selectedItem then
						table.insert(self.selectedOptionIndices, self.selectedOptionIndex)
						self.selectedOptionIndex = 1
						local rules = Actions:GetAllCombineRules(self.firstOptionItem, self.secondOptionItem, selectedItem)
						if not rules or #rules == 0 then
							LogError(string.format("could not find combine rule for %s %s %s", CellTypeInv[self.firstOptionItem], CellTypeInv[self.secondOptionItem], CellTypeInv[selectedItem] ))
						else
							self.characterB.characterController.command = CharacterCommandFactory.CreateFromMultipleRules(rules)
						end
						Game:EndDialog()
					else
						self.secondOptionItem = nil
						self.selectedOptionIndex = self.selectedOptionIndices[#self.selectedOptionIndices]
						table.remove(self.selectedOptionIndices, #self.selectedOptionIndices)
					end
				end

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

	local input = Input
	if input:GetKeyDown("0") then
		local loaded = ButterflyGame:LoadFromDisk("Save")
	elseif input:GetKeyDown("9") then
		ButterflyGame:SaveToDisk("Save")
	end
end

return Game