#pragma once

#include "SEngine/System.h"
#include "ryml.hpp"
#include "Grid.h"


class SaveData : public Object{
public:
	bool isValid = false;
	int i = 33;
	SerializationContext luaData{};
	Grid groundGrid;
	Grid itemsGrid;
	Grid markingsGrid;

	REFLECT_BEGIN(SaveData);
	REFLECT_VAR(isValid);
	REFLECT_VAR(itemsGrid);
	REFLECT_VAR(groundGrid);
	REFLECT_VAR(markingsGrid);
	REFLECT_VAR(i);
	REFLECT_VAR(luaData);
	REFLECT_END();
};

class ButterflyGame : public GameSystem<ButterflyGame> {
	virtual bool Init() override;
	virtual void Term() override;

	bool CreateSave(eastl::shared_ptr<SaveData> save) const;
	bool LoadSave(const eastl::shared_ptr<SaveData> save);

	bool SaveToDisk(const eastl::string& fileName);
	bool LoadFromDisk(const eastl::string& fileName);

	REFLECT_BEGIN(ButterflyGame);
	REFLECT_METHOD(SaveToDisk);
	REFLECT_METHOD(LoadFromDisk);
	REFLECT_METHOD(CreateSave);
	REFLECT_METHOD(LoadSave);
	REFLECT_END();
};