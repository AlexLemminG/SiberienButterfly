#include "SEngine/Component.h"
#include "SEngine/SMath.h"
#include "SEngine/Transform.h"
#include "SEngine/GameObject.h"
#include "SEngine/STime.h"
#include "SEngine/Physics.h"
#include "SEngine/Common.h"


class TopDownCameraRig : public Component {
public:
	float lerpT = 1.f;
	float collisionLerpT = 10.f;
	Vector3 offset = Vector3_zero;
	se::string targetTag;


	void OnEnable() override;
	void Update() override;

	REFLECT_DECLARE(TopDownCameraRig);

private:
	Vector3 currentPosWithoutCollision;
};
REFLECT_DEFINE_COMPONENT_BEGIN(TopDownCameraRig);
REFLECT_VAR(targetTag);
REFLECT_VAR(lerpT);
REFLECT_VAR(collisionLerpT);
REFLECT_VAR(offset);
REFLECT_DEFINE_END();

void TopDownCameraRig::OnEnable()
{
	auto trans = gameObject()->transform();
	auto target = GameObject::FindWithTag(targetTag);
	if (target) {
		auto targetPos = target->transform()->GetPosition() + offset;
		trans->SetPosition(targetPos);
	}
	currentPosWithoutCollision = trans->GetPosition();
}

void TopDownCameraRig::Update() {
	OPTICK_EVENT();
	auto target = GameObject::FindWithTag(targetTag);
	if (target) {
		auto trans = gameObject()->transform();

		auto targetPos = target->transform()->GetPosition() + offset;

		currentPosWithoutCollision = (Mathf::Lerp(currentPosWithoutCollision, targetPos, Time::deltaTime() * lerpT));
		auto safePos = currentPosWithoutCollision;
		safePos.z = target->transform()->GetPosition().z;

		Ray ray{ safePos, currentPosWithoutCollision - safePos };
		Physics::RaycastHit hit;

		float radius = 0.5f;
		int layerMask = Physics::GetLayerCollisionMask("staticGeom");
		if (Physics::SphereCast(hit, ray, radius, (currentPosWithoutCollision - safePos).Length(), layerMask)) {
			targetPos = hit.GetPoint() + hit.GetNormal() * radius;
			trans->SetPosition(Mathf::Lerp(trans->GetPosition(), targetPos, Time::deltaTime() * collisionLerpT));
		}
		else {
			trans->SetPosition(Mathf::Lerp(trans->GetPosition(), currentPosWithoutCollision, Time::deltaTime() * collisionLerpT));
		}
	}
}