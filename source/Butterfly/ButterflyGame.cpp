#include "ButterflyGame.h"
#include "LuaSystem.h"
#include "lua.h"
#include "Common.h"
#include "LuaReflect.h"
#include "Resources.h"

REGISTER_GAME_SYSTEM(ButterflyGame);
DECLARE_TEXT_ASSET(SaveData);

bool ButterflyGame::Init() {
	//TODO auto register
	Luna::RegisterShared<SaveData>(LuaSystem::Get()->L);
	return true;
}

void ButterflyGame::Term() {
}
static const char* SavePath = "SAVES/Save.sav";

void ButterflyGame::CreateSave(std::shared_ptr<SaveData> save) const
{

	if (!save) {
		LogError("Got null save to CreateSave func");
		return;
	}
	*save = SaveData();
	lua_State* L = LuaSystem::Get()->L;

	LuaSystem::Get()->PushModule("Game");
	lua_getfield(L, -1, "CreateSave");
	if (!lua_isnil(L, -1)) {
		//lua_pushvalue(L, -2);
		auto callResult = lua_pcall(L, 0, 1, 0);
		if (callResult != 0) {
			std::string error = lua_tostring(L, -1);
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

void ButterflyGame::LoadSave(const std::shared_ptr<SaveData> save)
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
			std::string error = lua_tostring(L, -1);
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

	Log("Loaded");
}

bool ButterflyGame::SaveToDisk()
{
	//TODO generic save system
	auto save = std::make_shared<SaveData>();
	CreateSave(save);
	if (!save->isValid) {
		return false;
	}

	{
		std::ofstream output(SavePath);
		if (!output.is_open()) {
			LogError("Failed to open '%s' for saving", SavePath);
			return false;
		}

		output << Object::Serialize(save);
	}
	return true;
}

bool ButterflyGame::LoadFromDisk()
{
	//TODO generic save system
	auto save = std::make_shared<SaveData>();

	{
		std::ifstream input(SavePath, std::ifstream::binary);
		if (!input.is_open()) {
			LogError("Failed to open '%s' for loading", SavePath);
			return false;
		}

		std::vector<char> buffer;
		input.seekg(0, input.end);
		std::streamsize size = input.tellg();
		input.seekg(0, std::ios::beg);

		ResizeVectorNoInit(buffer, size);
		input.read((char*)buffer.data(), size);
		auto tree =  std::make_unique<ryml::Tree>(ryml::parse(c4::csubstr(&buffer[0], buffer.size())));
		//TODO pull some AssetDatabase methods
		auto context = SerializationContext(tree->rootref());
		::Deserialize(context.Child(0), *save);
	}
	LoadSave(save);
	return true;
}
