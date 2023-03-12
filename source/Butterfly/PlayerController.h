#pragma once

#include "SEngine/Component.h"
#include "SEngine/MeshRenderer.h"
#include "SEngine/Sound.h"

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
	float speedWithItem = 1.f;
	float jumpVelocity = 10.f;
	float lastJumpTime = 0.f;
	float jumpDelay = 0.25f;
	float jumpPushImpulse = 100.f;
	float jumpPushRadius = 5.f;
	bool hasItem = false;

	REFLECT_DECLARE(PlayerController);

	se::shared_ptr<RigidBody> rigidBody = nullptr;
	se::shared_ptr<MeshAnimation> runAnimation;
	se::shared_ptr<MeshAnimation> standAnimation;
	se::shared_ptr<MeshAnimation> runAnimationWithItem;
	se::shared_ptr<MeshAnimation> standAnimationWithItem;
	float defaultSpeed = 1.f;
};