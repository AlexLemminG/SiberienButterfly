#include "SpawnOnEnableComponent.h"
#include "SEngine/GameObject.h"
#include "SEngine/Scene.h"
#include "SEngine/ParentedTransform.h"

REFLECT_DEFINE_COMPONENT_BEGIN(SpawnOnEnableComponent);
REFLECT_ATTRIBUTE(ExecuteInEditModeAttribute());
REFLECT_VAR(gameObjectToSpawn);
//REFLECT_VAR(destroyOnDisable);
REFLECT_DEFINE_END();

void SpawnOnEnableComponent::OnEnable() {
	if (gameObjectToSpawn) {
		spawnedGameObject = Instantiate(gameObjectToSpawn);
		auto parented = spawnedGameObject->GetComponent<ParentedTransform>();
		if (parented) {
			parented->SetParent(gameObject()->transform());
		}
		gameObject()->GetScene()->AddGameObject(spawnedGameObject);
	}

}

void SpawnOnEnableComponent::OnDisable() {
	if (destroyOnDisable && spawnedGameObject) {
		gameObject()->GetScene()->RemoveGameObject(spawnedGameObject);
	}
	spawnedGameObject = nullptr;
}
