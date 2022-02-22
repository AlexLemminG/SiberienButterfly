#pragma once

#include "Component.h"
#include "MeshRenderer.h"
#include "Sound.h"

class RigidBody;
class PostProcessingEffect;

class PlayerController : public Component {
public:
	void OnEnable()override;
	void FixedUpdate() override;
	void Update() override;
private:

	void UpdateMovement();
	void UpdateLook();
	void Jump();
	bool CanJump();
	bool IsOnGround() { return true; } //TODO

	float speed = 1.f;
	float jumpVelocity = 10.f;
	float lastJumpTime = 0.f;
	float jumpDelay = 0.25f;
	float jumpPushImpulse = 100.f;
	float jumpPushRadius = 5.f;

	REFLECT_BEGIN(PlayerController);
	REFLECT_VAR(speed);
	REFLECT_VAR(jumpVelocity);
	REFLECT_VAR(jumpPushImpulse);
	REFLECT_VAR(jumpPushRadius);
	REFLECT_END();

	std::shared_ptr<RigidBody> rigidBody = nullptr;
	float defaultSpeed = 1.f;
};