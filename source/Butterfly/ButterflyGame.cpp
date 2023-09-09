#include "ButterflyGame.h"
#include "SEngine/LuaSystem.h"
#include "lua.h"
#include "SEngine/Common.h"
#include "SEngine/LuaReflect.h"
#include "SEngine/Resources.h"
#include "SEngine/Profiler.h"

REGISTER_GAME_SYSTEM(ButterflyGame);

//TODO save random

static GameEventHandle onBeforeReloadingHandle;
static GameEventHandle onAfterReloadingHandle;
bool ButterflyGame::Init() {
	//TODO auto register
	LuaReflect::RegisterShared<SaveData>(LuaSystem::Get()->L);
	//TODO game is running(not in edit mode check)
	onBeforeReloadingHandle = LuaSystem::Get()->onBeforeScriptsReloading.Subscribe([this]() {SaveToDisk("LuaReloadingSave"); });
	onAfterReloadingHandle = LuaSystem::Get()->onAfterScriptsReloading.Subscribe([this]() {LoadFromDisk("LuaReloadingSave"); });
	return true;
}

void ButterflyGame::Term() {
	LuaSystem::Get()->onBeforeScriptsReloading.Unsubscribe(onBeforeReloadingHandle);
	LuaSystem::Get()->onAfterScriptsReloading.Unsubscribe(onAfterReloadingHandle);
}
static const char* SavePathBase = "SAVES/"; // TODO path from engine

bool ButterflyGame::CreateSave(se::shared_ptr<SaveData> save) const
{
	PROFILER_SCOPE();
	if (!save) {
		LogError("Got null save to CreateSave func");
		return false;
	}
	*save = SaveData();
	//TODO no hardcode
	save->itemsGrid = *GridSystem::Get()->GetGrid("ItemsGrid");
	save->groundGrid = *GridSystem::Get()->GetGrid("GroundGrid");
	save->markingsGrid = *GridSystem::Get()->GetGrid("MarkingsGrid");
	lua_State* L = LuaSystem::Get()->L;

	LuaSystem::Get()->PushModule("Game");
	if (lua_isnil(L, -1)) {
		LogError("CreateSave: module 'Game' is nil");
		lua_pop(L, 1);//module
		return false;
	}
	//TODO create LuaReflect::CallLuaFunction method
	lua_getfield(L, -1, "CreateSave");
	Vector2Int f;
	if (!lua_isnil(L, -1)) {
		//lua_pushvalue(L, -2);
		int callResult;
		{
			PROFILER_SCOPE_NAMED("Lua Game:CreateSave");
			callResult = lua_pcall(L, 0, 1, 0);
		}
		if (callResult != 0) {
			se::string error = se::string(lua_tostring(L, -1));
			LogError(error.c_str());
			lua_pop(L, 2);//module + message
			return true;
		}
		else {
			LuaReflect::DeserializeFromLuaToContext(L, -1, save->luaData);
			lua_pop(L, 2);//module+return result
		}
	}
	else {
		lua_pop(L, 2);//module+function
		return false;
	}

	save->i = 333;
	save->isValid = true;
	Log("Saved");
	return true;
}

bool ButterflyGame::LoadSave(const se::shared_ptr<SaveData> save)
{
	PROFILER_SCOPE();
	if (!save) {
		LogError("Got null save to CreateSave func");
		return false;
	}

	//TODO not hardcode
	GridSystem::Get()->GetGrid("ItemsGrid")->LoadFrom(save->itemsGrid);
	GridSystem::Get()->GetGrid("GroundGrid")->LoadFrom(save->groundGrid);
	GridSystem::Get()->GetGrid("MarkingsGrid")->LoadFrom(save->markingsGrid);

	lua_State* L = LuaSystem::Get()->L;

	LuaSystem::Get()->PushModule("Game");
	if (lua_isnil(L, -1)) {
		LogError("LoadSave: module 'Game' is nil");
		lua_pop(L, 1);//module
		return false;
	}
	lua_getfield(L, -1, "LoadSave");

	if (lua_isnil(L, -1) || !lua_isfunction(L, -1)) {
		LogError("LoadSave: module 'Game' is nil");
		lua_pop(L, 2);//module+function
		return false;
	}

	lua_newtable(L);
	LuaReflect::MergeToLua(L, save->luaData, -1, "");
	int callResult;
	{
		PROFILER_SCOPE_NAMED("Lua Game:LoadSave");
		callResult = lua_pcall(L, 1, 1, 0);
	}
	if (callResult != 0) {
		se::string error = se::string(lua_tostring(L, -1));
		lua_pop(L, 2); //module + error
		LogError(error.c_str());
		return false;
	}
	bool loadResult = lua_toboolean(L, -1);
	lua_pop(L, 2);//module+bool
	if (!loadResult) {
		LogError("LoadingError in lua");
		return false;
	}

	Log("Loaded");
	return true;
}

	REFLECT_DEFINE_BEGIN(ButterflyGame);
	REFLECT_METHOD(SaveToDisk);
	REFLECT_METHOD(LoadFromDisk);
	REFLECT_METHOD(CreateSave);
	REFLECT_METHOD(LoadSave);
	REFLECT_DEFINE_END();

	REFLECT_DEFINE_BEGIN(SaveData);
	REFLECT_VAR(isValid);
	REFLECT_VAR(itemsGrid);
	REFLECT_VAR(groundGrid);
	REFLECT_VAR(markingsGrid);
	REFLECT_VAR(i);
	REFLECT_VAR(luaData);
	REFLECT_DEFINE_END();

bool ButterflyGame::SaveToDisk(const se::string& fileName)
{
	//TODO generic save system
	auto save = se::make_shared<SaveData>();
	CreateSave(save);
	if (!save->isValid) {
		return false;
	}

	{
		se::string savePath = (se::string(SavePathBase) + fileName).append(".sav");
		std::ofstream output(savePath.c_str());
		if (!output.is_open()) {
			LogError("Failed to open '%s' for saving", savePath.c_str());
			return false;
		}

		output << Object::Serialize(save).GetYamlNode();
	}
	return true;
}

bool ButterflyGame::LoadFromDisk(const se::string& fileName)
{
	//TODO generic save system
	auto save = se::make_shared<SaveData>();

	{
		se::string savePath = (se::string(SavePathBase) + fileName).append(".sav");

		std::ifstream input(savePath.c_str(), std::ifstream::binary);
		if (!input.is_open()) {
			LogError("Failed to open '%s' for loading", savePath.c_str());
			return false;
		}

		se::vector<char> buffer;
		input.seekg(0, input.end);
		std::streamsize size = input.tellg();
		input.seekg(0, std::ios::beg);

		ResizeVectorNoInit(buffer, size);
		input.read((char*)buffer.data(), size);
		auto tree = se::make_unique<ryml::Tree>(ryml::parse(c4::csubstr(&buffer[0], buffer.size())));
		//TODO pull some AssetDatabase methods
		auto context = SerializationContext(tree->rootref());
		::Deserialize(context.Child(0), *save);
	}
	
	return LoadSave(save);
}
