
#include "Main.h"
#include <iostream>
#include "SEngine/Engine.h"
#include "SEngine/Serialization.h"
#include "SEngine/Component.h"
#include "SEngine/System.h"
#include "SEngine/Common.h"


REGISTER_GAME_SYSTEM(Sys);
DEFINE_LIBRARY(GameLib);

bool Sys::Init() {
	std::cout << "General kenobi!" << std::endl;
	return true;
}

bool GameLib::Init(Engine* engine) {
	OPTICK_EVENT();
	if (!GameLibrary::Init(engine)) {
		return false;
	}
	std::cout << "Hello there" << std::endl;
	return true;
}
