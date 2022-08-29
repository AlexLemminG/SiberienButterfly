#include "ButterflyGame.h"
#include "SEngine/LuaSystem.h"
#include "lua.h"
#include "SEngine/Common.h"
#include "SEngine/LuaReflect.h"
#include "SEngine/Resources.h"

REGISTER_GAME_SYSTEM(ButterflyGame);
DECLARE_TEXT_ASSET(SaveData);

static GameEventHandle onBeforeReloadingHandle;
static GameEventHandle onAfterReloadingHandle;
bool ButterflyGame::Init() {
	//TODO auto register
	Luna::RegisterShared<SaveData>(LuaSystem::Get()->L);

	onBeforeReloadingHandle = LuaSystem::Get()->onBeforeScriptsReloading.Subscribe([this]() {SaveToDisk("LuaReloadingSave"); });
	onAfterReloadingHandle = LuaSystem::Get()->onAfterScriptsReloading.Subscribe([this]() {LoadFromDisk("LuaReloadingSave"); });
	return true;
}

void ButterflyGame::Term() {
	LuaSystem::Get()->onBeforeScriptsReloading.Unsubscribe(onBeforeReloadingHandle);
	LuaSystem::Get()->onAfterScriptsReloading.Unsubscribe(onAfterReloadingHandle);
}
static const char* SavePathBase = "SAVES/";

void ButterflyGame::CreateSave(eastl::shared_ptr<SaveData> save) const
{
	if (!save) {
		LogError("Got null save to CreateSave func");
		return;
	}
	*save = SaveData();
	//TODO no hardcode
	save->itemsGrid = *GridSystem::Get()->GetGrid("ItemsGrid");
	save->groundGrid = *GridSystem::Get()->GetGrid("GroundGrid");
	lua_State* L = LuaSystem::Get()->L;

	LuaSystem::Get()->PushModule("Game");
	lua_getfield(L, -1, "CreateSave");
	if (!lua_isnil(L, -1)) {
		//lua_pushvalue(L, -2);
		auto callResult = lua_pcall(L, 0, 1, 0);
		if (callResult != 0) {
			eastl::string error = lua_tostring(L, -1);
			LogError(error.c_str());
			lua_pop(L, 1);
			return;
		}
		else {
			DeserializeFromLuaToContext(L, -1, save->luaData);
			lua_pop(L, 2);
		}
	}
	else {
		lua_pop(L, 2);
		return;
	}

	save->i = 333;
	save->isValid = true;
	Log("Saved");
}

void ButterflyGame::LoadSave(const eastl::shared_ptr<SaveData> save)
{

	if (!save) {
		LogError("Got null save to CreateSave func");
		return;
	}
	lua_State* L = LuaSystem::Get()->L;

	LuaSystem::Get()->PushModule("Game");
	lua_getfield(L, -1, "LoadSave");
	if (!lua_isnil(L, -1)) {
		//lua_pushvalue(L, -2);
		lua_newtable(L);
		MergeToLua(L, save->luaData, -1, "");
		auto callResult = lua_pcall(L, 1, 0, 0);
		if (callResult != 0) {
			eastl::string error = lua_tostring(L, -1);
			LogError(error.c_str());
			lua_pop(L, 1);
			return;
		}
		else {
			//DeserializeFromLuaToContext(L, -1, save->luaData);
			lua_pop(L, 2);
		}
	}
	else {
		lua_pop(L, 2);
		return;
	}

	//TODO not hardcode
	GridSystem::Get()->GetGrid("ItemsGrid")->LoadFrom(save->itemsGrid);
	GridSystem::Get()->GetGrid("GroundGrid")->LoadFrom(save->groundGrid);

	Log("Loaded");
}

bool ButterflyGame::SaveToDisk(const eastl::string& fileName)
{
	//TODO generic save system
	auto save = eastl::make_shared<SaveData>();
	CreateSave(save);
	if (!save->isValid) {
		return false;
	}

	{
		eastl::string savePath = SavePathBase + fileName + ".sav";
		std::ofstream output(savePath.c_str());
		if (!output.is_open()) {
			LogError("Failed to open '%s' for saving", savePath.c_str());
			return false;
		}

		output << Object::Serialize(save);
	}
	return true;
}

bool ButterflyGame::LoadFromDisk(const eastl::string& fileName)
{
	//TODO generic save system
	auto save = eastl::make_shared<SaveData>();

	{
		eastl::string savePath = SavePathBase + fileName + ".sav";

		std::ifstream input(savePath.c_str(), std::ifstream::binary);
		if (!input.is_open()) {
			LogError("Failed to open '%s' for loading", savePath.c_str());
			return false;
		}

		eastl::vector<char> buffer;
		input.seekg(0, input.end);
		std::streamsize size = input.tellg();
		input.seekg(0, std::ios::beg);

		ResizeVectorNoInit(buffer, size);
		input.read((char*)buffer.data(), size);
		auto tree = eastl::make_unique<ryml::Tree>(ryml::parse(c4::csubstr(&buffer[0], buffer.size())));
		//TODO pull some AssetDatabase methods
		auto context = SerializationContext(tree->rootref());
		::Deserialize(context.Child(0), *save);
	}
	LoadSave(save);
	return true;
}
