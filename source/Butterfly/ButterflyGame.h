#pragma once

#include "System.h"
#include "ryml.hpp"
#include "Grid.h"


class SaveData : public Object{
public:
	bool isValid = false;
	int i = 33;
	SerializationContext luaData{};
	Grid groundGrid;
	Grid itemsGrid;

	REFLECT_BEGIN(SaveData);
	REFLECT_VAR(isValid);
	REFLECT_VAR(itemsGrid);
	REFLECT_VAR(groundGrid);
	REFLECT_VAR(i);
	REFLECT_VAR(luaData);
	REFLECT_END();
};

class ButterflyGame : public GameSystem<ButterflyGame> {
	virtual bool Init() override;
	virtual void Term() override;

	void CreateSave(std::shared_ptr<SaveData> save) const;
	void LoadSave(const std::shared_ptr<SaveData> save);

	bool SaveToDisk(const std::string& fileName);
	bool LoadFromDisk(const std::string& fileName);

	REFLECT_BEGIN(ButterflyGame);
	REFLECT_METHOD(SaveToDisk);
	REFLECT_METHOD(LoadFromDisk);
	REFLECT_METHOD(CreateSave);
	REFLECT_METHOD(LoadSave);
	REFLECT_END();
};