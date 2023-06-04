#pragma once

#include "SEngine/System.h"
#include "ryml.hpp"
#include "Grid.h"
#include "SEngine/SerializationContext.h"


class SaveData : public Object{
public:
	bool isValid = false;
	int i = 33;
	SerializationContext luaData{};
	Grid groundGrid;
	Grid itemsGrid;
	Grid markingsGrid;

	REFLECT_DECLARE(SaveData);
};

class ButterflyGame : public GameSystem<ButterflyGame> {
	virtual bool Init() override;
	virtual void Term() override;

	bool CreateSave(se::shared_ptr<SaveData> save) const;
	bool LoadSave(const se::shared_ptr<SaveData> save);

	bool SaveToDisk(const se::string& fileName);
	bool LoadFromDisk(const se::string& fileName);

	REFLECT_DECLARE(ButterflyGame);
};