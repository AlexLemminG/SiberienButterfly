#pragma once

#include "SEngine/Component.h"

//HACK hacky way to go around gameObject hierarchy not implemented
class SpawnOnEnableComponent : public Component{
	eastl::shared_ptr<GameObject> gameObjectToSpawn;
	bool destroyOnDisable = true;

	virtual void OnEnable() override;
	virtual void OnDisable() override;
	REFLECT_DECLARE(SpawnOnEnableComponent);
	eastl::shared_ptr<GameObject> spawnedGameObject;
};