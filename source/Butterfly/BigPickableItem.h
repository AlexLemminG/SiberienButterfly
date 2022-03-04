#pragma once

#include "Object.h"

class PlayerController;

class BigPickableItem : public Object {
public:
	void OnPicked(std::shared_ptr<PlayerController> player);
};