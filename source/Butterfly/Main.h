#pragma once

#include <iostream>
#include "SEngine/System.h"

class GameLib : public GameLibrary {
	virtual bool Init(Engine* engine) override;
	void Term() { GameLibrary::Term(); }
	INNER_LIBRARY();
};

class Sys : public GameSystem<Sys> {
	bool Init()override;
};