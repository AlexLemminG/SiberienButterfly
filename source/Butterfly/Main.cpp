
#include "Main.h"
#include <iostream>
#include "Engine.h"
#include "Serialization.h"
#include "Component.h"
#include "System.h"


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
