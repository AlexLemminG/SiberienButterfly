
#include "Main.h"
#include <iostream>
#include "SEngine/Engine.h"
#include "SEngine/Serialization.h"
#include "SEngine/Component.h"
#include "SEngine/System.h"
#include "SEngine/Common.h"
#include "SEngine/LibraryDefinition.h"
#include "SEngine/Profiler.h"

REGISTER_GAME_SYSTEM(Sys);
DEFINE_LIBRARY(GameLib);

bool Sys::Init() {
	std::cout << "General kenobi!" << std::endl;
	return true;
}

bool GameLib::Init(Engine* engine) {
	PROFILER_SCOPE();
	if (!GameLibrary::Init(engine)) {
		return false;
	}
	std::cout << "Hello there" << std::endl;
	return true;
}
