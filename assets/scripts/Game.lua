local World = require("World")
local GameConsts = require("GameConsts")
local Utils      = require("Utils")
local CellAnimations = require("CellAnimations")
local WorldQuery     = require("WorldQuery")
local DayTime        = require("DayTime")
local CellTypeUtils  = require("CellTypeUtils")

local Game = {
	scene = nil,
	playerGO = nil,
	characterPrefab = nil,
	currentDialog = nil,
	isInited = false,
	gridSizeX = 20,
	gridSizeY = 20,
	newGrowTreePercent = 0.0,
	dayTime = 0.3,
	dayDeltaTime = 0.0,
	dayCount = 1,
	goodConditionsToSpawnCharacterDuration = 0.0,
	avgHunger = 0.0,
	avgHealth = 0.0,
	newNpcPercent = 0.0,
	isPause = false,
	
	dbgTimeScaleI = 0,
	dbgTimeScale = 1.0,
}
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local CellAnimType = require("CellAnimType")
local Actions = require("Actions")
local GameDbg = require("GameDbg")

function Game:GenerateWorldGrid()
	World.items:SetSize(self.gridSizeX, self.gridSizeY)
	World.ground:SetSize(self.gridSizeX, self.gridSizeY)
	World.markings:SetSize(self.gridSizeX, self.gridSizeY)
	
	local probabilitiesItems = {}
	probabilitiesItems[CellType.Wheat] = 1
	probabilitiesItems[CellType.Tree] = 1
	probabilitiesItems[CellType.Stone] = 0.5
	probabilitiesItems[CellType.FlintStone] = 0.1
	probabilitiesItems[CellType.BushWithBerries] = 0.1
	probabilitiesItems[CellType.None] = 10
	-- probabilities[CellType.CampfireWithWoodFired] = 10

	local probabilitiesItemsSum = 0
	for key, value in pairs(probabilitiesItems) do
		probabilitiesItemsSum = probabilitiesItemsSum + value
	end
	
	local probabilitiesGround = {}
	probabilitiesGround[CellType.GroundWithGrass] = 9
	probabilitiesGround[CellType.Ground] = 1
	-- probabilities[CellType.CampfireWithWoodFired] = 10

	local probabilitiesGroundSum = 0
	for key, value in pairs(probabilitiesGround) do
		probabilitiesGroundSum = probabilitiesGroundSum + value
	end

	function GetWeightedRandom(weights, weightsSum)
		local r = math.random() * weightsSum
		local w = 0
		local lastKey = nil
		for key, value in pairs(weights) do
			w = w + value
			if w > r then
				return key
			end
			lastKey = key
		end
		return lastKey
	end

	local cellPos = Vector2Int.new()
	for x = 0, self.gridSizeX-1, 1 do
		for y = 0, self.gridSizeY-1, 1 do
			cellPos.x = x
			cellPos.y = y
			local height = math.random(10) / 40
			local cell = World.items:GetCell(cellPos)
			local rand1 = math.random(100) / 100.0

			cell.type = GetWeightedRandom(probabilitiesItems, probabilitiesItemsSum)
			
			cell.float4 = 0.0
			cell.z = height
			World.items:SetCell(cell)

			cell = World.ground:GetCell(cellPos)
			cell.z = height
			cell.type = GetWeightedRandom(probabilitiesGround, probabilitiesGroundSum)
			World.ground:SetCell(cell)

			cell = World.markings:GetCell(cellPos)
			cell.z = height
			cell.type = CellType.None
			World.markings:SetCell(cell)
		end
	end

	-- river
	for x = 3, 4, 1 do
		for y = 0, self.gridSizeY-1, 1 do
			cellPos.x = x
			cellPos.y = y
			local cell = World.items:GetCell(cellPos)
			cell.type = CellType.None
			cell.z = 0.0
			World.items:SetCell(cell)

			cell = World.ground:GetCell(cellPos)
			cell.type = CellType.Water
			cell.z = 0.0
			World.ground:SetCell(cell)
			
			cell = World.markings:GetCell(cellPos)
			cell.z = 0.0
			World.markings:SetCell(cell)
		end
	end

	
	local generateAllItems = true
	if generateAllItems then
		local itemIdx = 1
		local y = 5
		local x = 10
		for name, itemIdx in pairs(CellType) do
			-- itemIdx = itemIdx + 1
			if (not CellTypeUtils.IsFlag(itemIdx)) and itemIdx ~= CellType.Scissors then continue end
			y = y + 1
			if y >= 15 then
				y = 5
				x = x + 1
			end
			cellPos.x = x
			cellPos.y = y
			
			local cell = World.items:GetCell(cellPos)
			cell.type = itemIdx
			World.items:SetCell(cell)
		end
	end
end

function CreatePlayerGO()
	local characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	local luaPlayerGO = Instantiate(characterPrefab)
	luaPlayerGO:GetComponent("Transform"):SetPosition(vector(Game.gridSizeX / 2.0,0.0,Game.gridSizeY / 2.0))
	luaPlayerGO.tag = "player"
	-- local pointLight = luaPlayerGO:AddComponent("PointLight")
	local playerScript = luaPlayerGO:AddComponent("LuaComponent")
	
	playerScript.scriptName = "PlayerController"

	SceneManager.GetCurrentScene():AddGameObject(luaPlayerGO)
	-- playerScript.scriptName = "Character"	--- TODO support from engine
	-- playerScript.scale = 0.8
	return luaPlayerGO
end

function LoadNpcGO(savedState) : GameObject|nil
	local type = savedState.type

	if not type then
		type = "Character"
	end

	local characterGO = nil
	if type == "Character" then
		characterGO = Game.CreateNpcGO()
	elseif type == "Sheep" then
		characterGO = CreateSheepGO()
	else
		LogError("Unknown npc type%s", type)
		return nil
	end

	local characterScript : Character = characterGO:GetComponent("LuaComponent") --TODO GetLuaComponent
	characterScript:LoadState(savedState)

	return characterGO
end

function Game.CreateNpcGO()
	local characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	local character = Instantiate(characterPrefab)
	local characterControllerScript = character:AddComponent("LuaComponent")
	characterControllerScript.scriptName = "CharacterController"
	characterControllerScript.type = "Character"
	character:GetComponent("Transform"):SetPosition(vector(Game.gridSizeX / 2.0,0.0,Game.gridSizeY / 2.0))

	SceneManager.GetCurrentScene():AddGameObject(character)
	return character
end

function CreateSheepGO()
	local characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	local character = Instantiate(characterPrefab)
	character:GetComponent("Transform"):SetPosition(vector(Game.gridSizeX / 2.0,0.0,Game.gridSizeY / 2.0))
	local characterComponent = character:GetComponent("LuaComponent")
	characterComponent.baseModelFile = "models/Sheep.blend"
	characterComponent.maxSpeed = 1.0
	characterComponent.type = "Sheep"
	
	local characterControllerScript = character:AddComponent("LuaComponent")
	characterControllerScript.scriptName = "SheepCharacterController"

	SceneManager.GetCurrentScene():AddGameObject(character)
	return character
end

--TODO Game as not component but just as a module ?
function Game:OnEnable()
	local coeffs = self.scene.sphericalHarmonics.coeffs
	self.sh = SphericalHarmonics.new()
	self.sh.coeffs = coeffs
	self.scene.sphericalHarmonics = self.sh
	
	math.randomseed(42)
	World:Init()
	if not Game.isInited then
		self:GenerateWorldGrid()
		Game.isInited = true
	end
	Actions:Init()
	-- print(AssetDatabase)
	-- print(AssetDatabase:Load("prefabs/character.asset"))
	
	self.characterPrefab = AssetDatabase:Load("prefabs/character.asset")

	Game.Cleanup()

	local luaPlayerGO = CreatePlayerGO()

	local numNPC = 1
	for i = 1, numNPC, 1 do
		self.CreateNpcGO()
	end
	CreateSheepGO()
end

function Game.Cleanup()
	for i = #World.charactersIncludingDead, 1, -1 do
		SceneManager.GetCurrentScene():RemoveGameObject(World.charactersIncludingDead[i]:gameObject())
	end
	Game.isInited = false
	assert(World.playerCharacter == nil, "Player is not removed while cleaning up")
	assert(#World.charactersIncludingDead == 0, "Not all characters are removed while cleaning up")
	assert(#World.characters == 0, "Not all characters are removed while cleaning up")
end

function Game.CreateSave()
	local save = { 
		characters = { }
	}

	for index, character in ipairs(World.charactersIncludingDead) do
		table.insert(save.characters, character:SaveState())
	end
	save.dayTime = Game.dayTime
	save.dayCount = Game.dayCount
	save.playerIndex = Utils.ArrayIndexOf(World.charactersIncludingDead, World.playerCharacter)

	return save
end

function Game.LoadSave(save) : boolean
	if not save then
		LogError("Lua loading failed: no save")
		return false
	end

	Game.isInited = true

	Game.Cleanup()

	if save.characters then
		local playerIndex = save.playerIndex or -1
		for index, savedCharacter in pairs(save.characters) do
			local characterGO = nil
			if index == playerIndex then
				characterGO = CreatePlayerGO()
				local characterScript : Character = characterGO:GetComponent("LuaComponent") --TODO GetLuaComponent
				characterScript:LoadState(savedCharacter)
			else
				characterGO = LoadNpcGO(savedCharacter)
			end
		end
	else
		LogWarning("No characters in save")
	end
	if World.playerCharacter == nil then
		LogWarning("Player is not created from save")
	end

	Game.dayTime = save.dayTime
	Game.dayCount = save.dayCount or 1
	
	return true
end


function Game:OnDisable()
	Game.Cleanup()
end

function Game:ApplyAnimation(grid, cell)
	local animType = cell.animType

	if animType == CellAnimType.WheatGrowing or animType == CellAnimType.TreeSproutGrowing or 
		not(animType == CellAnimType.GotHit or animType == CellAnimType.ItemAppearFromGround or animType == CellAnimType.ItemAppearFromGroundWithoutXZScale or animType == CellAnimType.ItemAppear or animType == CellAnimType.ItemAppearWithoutXZScale)
	then
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
	elseif finishedAnimType == CellAnimType.BushBerriesGrowing then
		CellAnimations.SetAppear(cell)
		cell.type = CellType.BushWithBerries
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
		elseif cell.type == CellType.Bush then
			cell.animType = CellAnimType.BushBerriesGrowing
			cell.animT = 0.0
			cell.animStopT = GameConsts.bushBerriesGrowthTime
		end
	elseif finishedAnimType == CellAnimType.GrassGrowing then
		if cell.type == CellType.Ground or cell.type == CellType.GroundWithEatenGrass then
			cell.type = CellType.GroundWithGrass
		end
	end
end

function Game:AnimateCells(dt)
	local v = Vector2Int:new()
	local cell = GridCell:new()

	local grids = {World.items, World.ground}
	for index, grid in ipairs(grids) do
		local iterator = grid:GetAnimatedCellsIterator()
		while iterator:GetNextCell(cell) do
			cell.animT = math.min(cell.animT + dt, cell.animStopT)
	
			self:ApplyAnimation(grid, cell)
	
			if cell.animT >= cell.animStopT then
				local animType = cell.animType
				cell.animType = CellAnimType.None
				self:HandleAnimationFinished(cell, animType)
				--TODO force set matrix here
				self:ApplyAnimation(grid, cell)
			end
			grid:SetCell(cell)
		end
	end
end

function Game:FillGroundWithGrass(deltaTime : number)
	local ground = World.ground
	local cell = GridCell:new()
	local iterator = ground:GetTypeWithAnimIterator(CellType.Ground, CellAnimType.None)
	while iterator:GetNextCell(cell) do
		cell.animType = CellAnimType.GrassGrowing
		cell.animT = 0.0
		cell.animStopT = GameConsts.grassGrowingDurationSeconds
		ground:SetCell(cell)
	end
	
	iterator = ground:GetTypeWithAnimIterator(CellType.GroundWithEatenGrass, CellAnimType.None)
	while iterator:GetNextCell(cell) do
		cell.animType = CellAnimType.GrassGrowing
		cell.animT = 0.0
		cell.animStopT = GameConsts.eatenGrassGrowingDurationSeconds
		ground:SetCell(cell)
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
		if math.random() > 0.5 then
			itemsCell.type = CellType.WheatPlanted_0
		end
		CellAnimations.SetAppearFromGround(itemsCell)
		World.items:SetCell(itemsCell)
	end
end

function Game.DbgDrawPath(path)
	if path and path.isComplete then
		for i = 1, path.points:size(), 1 do
			local pointInt2D = path.points[i]
			local point = World.ground:GetCellWorldCenter(pointInt2D)
			--print(point)
			Dbg.DrawPoint(point, 0.25 * (path.points:size() - i) / path.points:size())
		end
	end
end

function Game:UpdateDayTime(dt : float)
	self.dayDeltaTime = dt / GameConsts.dayDurationSeconds
	self.dayTime = self.dayTime + self.dayDeltaTime
	if self.dayTime > 1.0 then
		self.dayTime = self.dayTime - 1.0
		self.dayCount = self.dayCount + 1
	end

	function LerpHarmonicsCoeffs(a, b, t)
		--dunno better way to create new array of colors
		--TODO this is potential freed memory access?
		local result = SphericalHarmonics.new().coeffs
		for i = 1, 9, 1 do
			result[i] = Color.Lerp(a[i], b[i], t)
		end
		return result
	end

	local dayHarmonics = AssetDatabase:Load("SphericalHarmonics/env.asset$day")
	local nightHarmonics = AssetDatabase:Load("SphericalHarmonics/env.asset$night")
	local night2Harmonics = AssetDatabase:Load("SphericalHarmonics/env.asset$night2")
	local morningHarmonics = AssetDatabase:Load("SphericalHarmonics/env.asset$morning")
	local eveningHarmonics = AssetDatabase:Load("SphericalHarmonics/env.asset$evening")
	local newCoeffs = {}
	LerpHarmonicsCoeffs(dayHarmonics.coeffs, nightHarmonics.coeffs, self.dayTime)
	local morningTime = 6/24
	local dayTime = 12/24
	local eveningTime = 18/24
	local nightTime = 21/24
	local nightTime2 = 3/24
	if self.dayTime >= morningTime and self.dayTime <= dayTime then
		local t = Mathf.InverseLerp(morningTime, dayTime, self.dayTime)
		newCoeffs = LerpHarmonicsCoeffs(morningHarmonics.coeffs, dayHarmonics.coeffs, t)

	elseif self.dayTime >= dayTime and self.dayTime <= eveningTime then
		local t = Mathf.InverseLerp(dayTime, eveningTime, self.dayTime)
		newCoeffs = LerpHarmonicsCoeffs(dayHarmonics.coeffs, eveningHarmonics.coeffs, t)

	elseif self.dayTime >= eveningTime and self.dayTime <= nightTime then
		local t = Mathf.InverseLerp(eveningTime, nightTime, self.dayTime)
		newCoeffs = LerpHarmonicsCoeffs(eveningHarmonics.coeffs, nightHarmonics.coeffs, t)

	elseif self.dayTime >= nightTime2 and self.dayTime <= morningTime then
		local t = Mathf.InverseLerp(nightTime2, morningTime, self.dayTime)
		newCoeffs = LerpHarmonicsCoeffs(night2Harmonics.coeffs, morningHarmonics.coeffs, t)
		
	elseif self.dayTime >= nightTime or self.dayTime <= nightTime2 then
		local t = 0
		if self.dayTime >= nightTime then
			t = Mathf.InverseLerp(nightTime, 1 + nightTime2, self.dayTime)
		else
			t = Mathf.InverseLerp(nightTime-1, nightTime2, self.dayTime)
		end
		newCoeffs = LerpHarmonicsCoeffs(nightHarmonics.coeffs, night2Harmonics.coeffs, t)

	else
		LogWarning("Broken time")
	end
	self.sh.coeffs = newCoeffs

	local light = self.scene:FindGameObjectByTag("DirLight")
	if light then
		local dirLight = light:GetComponent("DirLight")
		dirLight.color = newCoeffs[1]
	end
	local camera = self.scene:FindGameObjectByTag("camera")
	if camera then
		local cameraCamera = camera:GetComponent("Camera")
		--cameraCamera.clearColor = newCoeffs[1]
	end

	-- imgui.Begin("DayTime")
	-- local hour = math.floor(self.dayTimePercent * 24)
	-- local minute = math.floor((self.dayTimePercent*24 - hour) * 60)
	-- if hour < 10 then hour = "0"..hour end
	-- if minute < 10 then minute = "0"..minute end
	-- imgui.TextUnformatted(""..hour..":"..minute)
	-- imgui.End()
end

function CalcHumansFromWheatCell()
	local wheatFromCell = 2
	local wheatFromCellAfterReplanting = 1
	local hungerPerWheatCellPerDay = wheatFromCellAfterReplanting / GameConsts.wheatGrowthTimeTotal * GameConsts.dayDurationSeconds
	hungerPerWheatCellPerDay *= GameConsts.hungerLossFromFood
	local hungerPerDay = GameConsts.hungerPerSecond * GameConsts.dayDurationSeconds

	return hungerPerWheatCellPerDay / hungerPerDay
end

function Game:MainLoop()
	-- print(CalcHumansFromWheatCell())
	local dt = Time.fixedDeltaTime()

	local timeScale = 1.0
	local playerSleeps = World.playerCharacter and (World.playerCharacter.isSleeping)
	local playerIsDead = World.playerCharacter and (World.playerCharacter.isDead)
	local everyoneSleeps = true
	for index, character in ipairs(World.characters) do
		if not character.isSleeping then
			everyoneSleeps = false
			break
		end
	end
	--TODO Time.setTimeScale ?
	if playerSleeps or playerIsDead then
		if everyoneSleeps then
			timeScale = 100.0
		else
			if not playerIsDead then
				timeScale = 5.0
			end
		end
	end
	dt = dt * timeScale

	self:AnimateCells(dt)

	self:GrowNewTrees(dt)

	self:FillGroundWithGrass(dt)

	--TODO dead not needed usually
	for index, character in ipairs(World.charactersIncludingDead) do
		if character.characterController then
			character.characterController.updateOrderIndex = index
		end
		local hungerSpeed = GameConsts.hungerPerSecond
		local healthLossSpeed = GameConsts.healthLossFromHungerPerSecond
		if character.isSleeping then
			hungerSpeed = hungerSpeed * GameConsts.hungerInSleepMultipler
			healthLossSpeed = healthLossSpeed * GameConsts.healthLossFromHungerInSleepMultiplier
		end
		if character:IsFreezing() then
			hungerSpeed = hungerSpeed * GameConsts.hungerWhenFreezingMultiplier
			healthLossSpeed = healthLossSpeed * GameConsts.healthLossFromHungerWhenFreezingMultiplier
		end
		character.hunger = math.clamp(character.hunger + dt * hungerSpeed, 0.0, 1.0)
		if character.hunger == 1.0 then
			character.health = math.clamp(character.health - dt * healthLossSpeed, 0.0, 1.0)
		else
			character.health = math.clamp(character.health + dt * GameConsts.healthIncWithoutHungerPerSecond, 0.0, 1.0)
		end
	end
	for i = #World.characters, 1, -1 do
		local character = World.characters[i]
		if character.health == 0.0 then
			character:Die()
		end
	end
	
	self:UpdateDayTime(dt)
	
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
	self.avgHunger = avgHunger
	self.avgHealth = avgHealth

	--TODO consts
	if self.avgHealth > 0.5 and avgHunger < 0.7 then
		self.goodConditionsToSpawnCharacterDuration = self.goodConditionsToSpawnCharacterDuration + dt
	else
		--TODO speed const
		self.goodConditionsToSpawnCharacterDuration = math.max(self.goodConditionsToSpawnCharacterDuration - dt * 0.25, 0.0)
	end
	self.newNpcPercent = self.goodConditionsToSpawnCharacterDuration / GameConsts.goodConditionsToSpawnCharacterDuration
	if self.goodConditionsToSpawnCharacterDuration > GameConsts.goodConditionsToSpawnCharacterDuration then
		self.goodConditionsToSpawnCharacterDuration = 0.0
		self.CreateNpcGO()
	end
end

function Game:DrawStats(character : Character)
	if not character then
		LogError("Trying to draw nil character")
		return
	end
	local isPlayer = character == World.playerCharacter
	
	local screenSize = Graphics:GetGameViewSize()
	local screenPos = Graphics:GetGameViewPos()
	
	imgui.SetNextWindowSize(200,100)
	if isPlayer then
		imgui.SetNextWindowPos(screenPos.x + 0, screenPos.y + screenSize.y, imgui.constant.Cond.Always, 0,1.0)
	else
		imgui.SetNextWindowPos(screenPos.x + screenSize.x, screenPos.y + screenSize.y, imgui.constant.Cond.Always, 1.0,1.0)
	end
	imgui.SetNextWindowBgAlpha(0.1)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar + winFlags.NoInputs)
	imgui.Begin("Character stats "..tostring(isPlayer), nil, flags)

	local text = string.format("Name: %s\nHunger: %.3f \nHealth: %.3f \nWarmth: %.3f", character.name, character.hunger, character.health, character:GetWarmthImmediate())
	imgui.TextUnformatted(text)
	imgui.End()
end

function Game:DrawWorldStats()
	local screenSize = Graphics:GetGameViewSize()
	local screenPos = Graphics:GetGameViewPos()

	imgui.SetNextWindowSize(300,250)
	imgui.SetNextWindowPos(screenPos.x + 30, screenPos.y + 350, imgui.constant.Cond.Always, 0.0,0.5)
	imgui.SetNextWindowBgAlpha(0.0)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar + winFlags.NoInputs + winFlags.NoScrollbar)
	imgui.Begin("World Stats", nil, flags)
	imgui.SetWindowFontScale(1.5)

	local text = ""
	text = string.format("Population: %d\n", #World.characters)
	if #World.characters > 0 then
		text = text..string.format("Avg Hunger: %.3f\nAvg Health: %.3f\nNew Npc: %.1f%s\n", self.avgHunger, self.avgHealth, self.newNpcPercent * 100.0, "%")
	end
	
	local hour = math.floor(self.dayTime * 24)
	local minute = math.floor((self.dayTime*24 - hour) * 60)
	if hour < 10 then hour = "0"..hour end
	if minute < 10 then minute = "0"..minute end
	text = text.."Day: "..self.dayCount.."\n"
	text = text.."Time: "..hour..":"..minute.."\n"

	local playerPos = nil
	local playerIntPos = nil
	if World.playerCharacter then 
		playerPos = World.playerCharacter:GetPosition() 
		playerIntPos = World.playerCharacter:GetIntPos()
	else 
		playerPos = Vector3.new() 
		playerIntPos = Vector2Int.new()
	end
	text = text..string.format("playerPos: %.1f %.1f\n", playerPos.x, playerPos.z)
	
	text = text..string.format("isWalkable: %s\n", tostring(World.navigation:IsWalkable(playerIntPos.x, playerIntPos.y)))
	text = text..string.format("dbgMode: %s\n", tostring(GameDbg.isOn))

	imgui.TextUnformatted(text)
	imgui.End()
end

local function GetUISprite(x, y)
	local sprite = Sprite.new()
	local uvMin = sprite.uvMin
	local uvMax = sprite.uvMax
	local countX = 20
	local countY = 9
	sprite.texture = AssetDatabase:Load("textures/tiles.png")
	uvMin.x = 1.0 / countX * x
	uvMin.y = 1.0 / countY * y
	uvMax.x = uvMin.x + 1.0 / countX
	uvMax.y = uvMin.y + 1.0 / countY
	sprite.uvMin = uvMin
	sprite.uvMax = uvMax

	return sprite
end

function Game:DrawHealthAndHungerUI(character : Character, onRightSideOfScreen : boolean)
	local scale = 5.0
	imgui.SetNextWindowBgAlpha(0.0)
	local screenSize = Graphics:GetGameViewSize()
	local screenPos = Graphics:GetGameViewPos()
	imgui.SetNextWindowSize(250,350)
	local windowPosX = 20
	local windowAlignX = 0
	if onRightSideOfScreen then
		--TODO more simmetrical pos for onRightSizeOfScreen
		windowAlignX = 1.0
		windowPosX = screenSize.x - windowPosX
	end
	windowPosX = screenPos.x + windowPosX
	imgui.SetNextWindowPos(windowPosX,screenPos.y + 20, imgui.constant.Cond.Always, windowAlignX, 0.0)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar + winFlags.NoInputs)

	imgui.Begin("HealthAndHungerUI"..tostring(onRightSideOfScreen), nil, flags)
	--imgui.Dummy(0,-100)
	imgui.SetCursorPosY(imgui.GetCursorPosY() - 15 * scale)
	local CalcSpriteOffset = function(value, maxCount, currentCount)
		local isFullHeart = value * maxCount - currentCount + 1 > 0.5
		local isHalfHeart = value * maxCount - currentCount + 1 > 0.0
		if isFullHeart then
			return 2
		elseif isHalfHeart then
			return 1
		end
		return 0
	end

	local heartsCountMax = 3
	--TODO mirror sprites and order for onRightSizeOfScreen
	for i = 1, heartsCountMax, 1 do
		if i ~= 1 then imgui.SameLine(0,0) imgui.Dummy(-3 * scale ,0) imgui.SameLine(0,0) end
		local offset = CalcSpriteOffset(character.health, heartsCountMax, i)
		if character.hunger == 1.0 then
			local healthLostSpeed = 1.0 
			if character:IsFreezing() then
				healthLostSpeed = healthLostSpeed * GameConsts.healthLossFromHungerWhenFreezingMultiplier
			end
			if character.isSleeping then
				healthLostSpeed = healthLostSpeed * GameConsts.healthLossFromHungerInSleepMultiplier
			end
			local isFirstNonZeroHeart = offset > 0 and (i == heartsCountMax or CalcSpriteOffset(character.health, heartsCountMax, i+1) == 0)
			if isFirstNonZeroHeart and math.fmod(Time.time() * healthLostSpeed, 1.0) > 0.5 then
				if offset > 0 then 
					offset = offset - 1
				end
			end
		end
		local sprite = GetUISprite(2 + offset, 5)
		--TODO imgui func to accept sprite + scale
		imgui.Image(sprite:ToImguiId(), sprite:GetWidth() * scale, sprite:GetHeight() * scale, sprite.uvMin.x, sprite.uvMin.y, sprite.uvMax.x, sprite.uvMax.y)
	end
	
	imgui.SetCursorPosY(imgui.GetCursorPosY() - 15 * scale)
	local hungerCountMax = 3
	for i = 1, hungerCountMax, 1 do
		if i ~= 1 then imgui.SameLine(0,0) imgui.Dummy(-3 * scale ,0) imgui.SameLine(0,0) end
		local sprite = GetUISprite(5 + CalcSpriteOffset(1.0 - character.hunger, hungerCountMax, i), 5)
		imgui.Image(sprite:ToImguiId(), sprite:GetWidth() * scale, sprite:GetHeight() * scale, sprite.uvMin.x, sprite.uvMin.y, sprite.uvMax.x, sprite.uvMax.y)
	end
	
	imgui.SetCursorPosY(imgui.GetCursorPosY() - 15 * scale)
	if character:IsFreezing() then
		local sprite = GetUISprite(18, 7)
		imgui.Image(sprite:ToImguiId(), sprite:GetWidth() * scale, sprite:GetHeight() * scale, sprite.uvMin.x, sprite.uvMin.y, sprite.uvMax.x, sprite.uvMax.y)
	end

	imgui.End()
end

function DrawPauseMenu()
	local windowWidth = 200
	local windowHeight = 100
	imgui.SetNextWindowSize(windowWidth,windowHeight)
	local screenSize = Graphics:GetGameViewSize()
	local screenPos = Graphics:GetGameViewPos()
	imgui.SetNextWindowPos(screenPos.x + screenSize.x / 2.0, screenPos.y + screenSize.y / 2.0, imgui.constant.Cond.Always, 0.5,0.5)
	imgui.SetNextWindowBgAlpha(0.8)
	local winFlags = imgui.constant.WindowFlags
	local flags = bit32.bor(winFlags.NoTitleBar, winFlags.NoInputs)

	imgui.Begin("PauseMenu", true, flags)
	local text = "PAUSE"
	local sizeX, sizeY = imgui.CalcTextSize(text)
	imgui.SetCursorPosX((windowWidth - sizeX) * 0.5)
	imgui.SetCursorPosY((windowHeight - sizeY) * 0.5)
	imgui.TextUnformatted(text)

	imgui.End()
end

function Game:DrawUI()
	if World.playerCharacter then
		self:DrawHealthAndHungerUI(World.playerCharacter, false)
	end
	self:DrawWorldStats()
	if self.isPause then
		DrawPauseMenu()
	else
		if self.currentDialog then
			self.currentDialog:Draw()
		end
	end
end

function Game:BeginDialog(characterA : Character, characterB : Character)
	self.currentDialog = {
		characterA = characterA,
		characterB = characterB,
		selectedOptionIndex = 1,

		optionsStack = {},

		data = nil,
	}
	
	local CommandType = {
		Prepare = "Prepare",
		Bring = "Bring",
		Put = "Put",
		Pack = "Pack"
	}

	--TODO naming
	local allCommands = {}

	function GetOrCreate(option, name) 
		if not option.children then
			option.children = {}
		end
		for i, v in option.children do
			if v.name == name then
				return v
			end
		end
		local result = option.children[name]
		if not result then
			result = {}
			result.name = name
			table.insert(option.children, result)
		end
		return result
	end
	
	local CharacterControllerBase = require("CharacterControllerBase")
	for i, rule in ipairs(Actions:GetAllCombineRules(CellType.Any,CellType.Any,CellType.Any)) do
		local ruleDialog = rule:GetDialog()
		local sub = allCommands
		for i, d in ipairs(ruleDialog) do
			sub = GetOrCreate(sub, d)
		end
		if not sub.rules then sub.rules = {} end
		table.insert(sub.rules, rule)
	end
	function RulesToCommand(option) 
		if option.children then
			for i, child in ipairs(option.children) do
				RulesToCommand(child)
			end
		end
		if option.rules then
			option.command = CharacterControllerBase.CreateCommandFromRules(option.rules)
			option.rules = nil
		end
	end
	RulesToCommand(allCommands)
	
	for i, cellType in pairs(CellType) do
		if CellTypeUtils.IsPickable(cellType) then
			for flagType = CellTypeUtils.FlagFirst(), CellTypeUtils.FlagLast(), 1 do
				local sub = GetOrCreate(allCommands, CommandType.Bring)
				sub = GetOrCreate(sub, CellTypeUtils.GetHumanReadableName(cellType))
				sub = GetOrCreate(sub, "To")
				sub = GetOrCreate(sub, CellTypeUtils.GetHumanReadableName(flagType))
				if not sub.bringCellTypes then sub.bringCellTypes = {} end
				table.insert(sub.bringCellTypes, cellType)
				sub.flagType = flagType
			end
		end
	end
	function BringCellTypesToCommand(option) 
		if option.children then
			for i, child in ipairs(option.children) do
				BringCellTypesToCommand(child)
			end
		end
		if option.bringCellTypes then
			if option.command then
				LogError("Already has command")
			end
			option.command = CharacterControllerBase.CreateBringCommand(option.bringCellTypes, option.flagType)
			option.bringCellTypes = nil
		end
	end
	BringCellTypesToCommand(allCommands)

	function Postprocess(commands)
		if not commands.children then
				return
		end
		for i,v in commands.children do
			Postprocess(v)
		end
		table.sort(commands.children, function(a,b) return a.name < b.name end)
		
		--TODO less hardcode
		if #commands.children == 1 and commands.children[1].name == "Any" or commands.children[1].name == "None" then
			commands.command = commands.children[1].command
			commands.children = commands.children[1].children
		end	

	end

	Postprocess(allCommands)

	self.currentDialog.data = allCommands

	function self.currentDialog:Draw()

		local depth = 0
		local currentOptions = self.data.children
		for index, value in ipairs(self.optionsStack) do
			currentOptions = currentOptions[value].children
		end
		
		self.selectedOptionIndex = math.clamp(self.selectedOptionIndex, 1, #currentOptions)

		local selectedOption = currentOptions[self.selectedOptionIndex] --TODO nil check

		local screenSize = Graphics:GetGameViewSize()
		local screenPos = Graphics:GetGameViewPos()
		imgui.SetNextWindowSize(400,250)
		imgui.SetNextWindowPos(screenPos.x + screenSize.x / 2.0, screenPos.y + screenSize.y / 2.0 + 400, imgui.constant.Cond.Always, 0.5,0.5)
		imgui.SetNextWindowBgAlpha(1.0)
		local winFlags = imgui.constant.WindowFlags
		local flags = 0--bit32.bor(winFlags.NoDrag)

		imgui.Begin("Dialog", nil, flags)
		imgui.TextUnformatted("DIALOG:")
		imgui.TextUnformatted(self.characterA:GetHumanName() .. " talks to " .. self.characterB:GetHumanName())
		
		local text = ""
		imgui.TextUnformatted(text)
		
		for index, option in ipairs(currentOptions) do
			local isSelected = index == self.selectedOptionIndex
			local optionText = option.name
			if isSelected then
				optionText = "[*] "..optionText
			else
				optionText = "[ ] "..optionText
			end
			imgui.TextUnformatted(optionText)
			if isSelected then
				imgui.SetScrollHere(0.5)
			end
		end
		imgui.End()

		if self.updateInput then
			local input = Input
			if input:GetButtonDown("UI_MoveDown") then
				self.selectedOptionIndex = self.selectedOptionIndex + 1
			end
			if input:GetButtonDown("UI_MoveUp") then
				self.selectedOptionIndex = self.selectedOptionIndex - 1
			end
			local acceptPressed = input:GetButtonDown("UI_Select")
			if input:GetButtonDown("UI_Back") then
				acceptPressed = true
				selectedOption = "Back"
			end
			if acceptPressed then
				print("Selected ", selectedOption)

				if selectedOption == "Back" then
					if #self.optionsStack == 0 then
						Game:EndDialog()
					else
						self.selectedOptionIndex = self.optionsStack[#self.optionsStack]
						table.remove(self.optionsStack, #self.optionsStack)
					end
				else
					table.insert(self.optionsStack, self.selectedOptionIndex)
					self.selectedOptionIndex = 1
					if selectedOption.command then
						self.characterB.characterController:SetCommand(selectedOption.command)
						Game:EndDialog()
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
	GameDbg:Update()

	local input = Input
	if input:GetButtonDown("PauseMenu") then
		if not (self.currentDialog and not self.isPause) then
			self.isPause = not self.isPause
		end
	end

	self:DrawUI()

	if input:GetKeyDown("0") then
		local loaded = ButterflyGame:LoadFromDisk("Save")
	elseif input:GetKeyDown("9") then
		ButterflyGame:SaveToDisk("Save")
	end
	if input:GetKeyDown("8") then
		ButterflyGame:SaveToDisk("Save")
		local loaded = ButterflyGame:LoadFromDisk("Save")
		ButterflyGame:SaveToDisk("Save")	
		local loaded = ButterflyGame:LoadFromDisk("Save")
	end

	if input:GetKeyDown("PageDown") then 
		self.dbgTimeScaleI = self.dbgTimeScaleI - 1
		self.dbgTimeScale = math.exp(self.dbgTimeScaleI * 0.4)
		print("TimeScale: ", self.dbgTimeScale)
	end
	if input:GetKeyDown("PageUp") then 
		self.dbgTimeScaleI = self.dbgTimeScaleI + 1
		self.dbgTimeScale = math.exp(self.dbgTimeScaleI * 0.4)
		print("TimeScale: ", self.dbgTimeScale)
	end

	--TODO pause rest of the game as well (component Update methods)
	if self.isPause then
		Time.setTimeScale(0.0)
		return
	else
		Time.setTimeScale(self.dbgTimeScale)
	end
end

function Game:FixedUpdate()
	self:MainLoop()
end

function Game:GetAmbientTemperature() : number
	--TODO consts
	if self.dayTime > DayTime.FromHoursAndMinutes(22,00) then
		return 0.0
	end
	if self.dayTime < DayTime.FromHoursAndMinutes(6,30) then
		return 0.0
	end
	return 1.0
end

function Game:GetTemperatureAt(intPos : Vector2Int) : number
	local ambientTemperature = self:GetAmbientTemperature()
	local temperature = ambientTemperature

	local nearestCampfirePos = WorldQuery:FindNearestItem(CellType.CampfireWithWoodFired, intPos, 3)
	if nearestCampfirePos then
		--TODO not 1.0
		temperature = temperature + 1.0
	end
	
	--TODO cell temp
	return temperature
end

return Game