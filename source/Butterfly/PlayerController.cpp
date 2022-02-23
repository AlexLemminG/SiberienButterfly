#include "PlayerController.h"

#include "GameObject.h"
#include "Transform.h"
#include "Input.h"
#include "STime.h"
#include "Camera.h"
#include "Dbg.h"
#include "Physics.h"
#include "RigidBody.h"
#include "Scene.h"
#include "GameObject.h"
#include "SceneManager.h"
#include "MeshRenderer.h"
#include "Sound.h"
#include "Light.h"
#include <BoxCollider.h>

void PlayerController::OnEnable() {
	rigidBody = gameObject()->GetComponent<RigidBody>();
	defaultSpeed = speed;
}


void PlayerController::Update() {

	if (CanJump()) {
		if (Input::GetKeyDown(SDL_Scancode::SDL_SCANCODE_SPACE)) {
			Jump();
		}
	}

	if (Input::GetKey(SDL_Scancode::SDL_SCANCODE_LSHIFT)) {
		speed = defaultSpeed * 3.f;
	}
	else {
		speed = defaultSpeed;
	}


	auto ray = Camera::GetMain()->ScreenPointToRay(Input::GetMousePosition());
	auto plane = Plane(Vector3_zero, Vector3_up);
	float distance;
	if (plane.Raycast(ray, distance)) {
		Vector3 pos = ray.GetPoint(distance);
		Vector3 minPos = Vector3(Mathf::Floor(pos.x), Mathf::Floor(pos.y), Mathf::Floor(pos.z));

		AABB box = AABB(minPos, minPos + Vector3_one);
		Dbg::Draw(box);
	}
}

void PlayerController::FixedUpdate() {
	UpdateMovement();
	UpdateLook();

	if (rigidBody) {
		float gravityMultiplier = 1.f;
		float upVel = rigidBody->GetLinearVelocity().y;
		if (upVel < 0.f) {
			gravityMultiplier = Mathf::Lerp(1.f, 2.f, -upVel / 1.f);
		}
		rigidBody->OverrideWorldGravity(Physics::GetGravity() * gravityMultiplier);
	}
	rigidBody->SetAngularFactor(Vector3(0, 1, 0));

}

void PlayerController::UpdateMovement() {
	if (!rigidBody) {
		return;
	}
	rigidBody->Activate();

	Vector3 deltaPos = Vector3_zero;
	if (Input::GetKey(SDL_Scancode::SDL_SCANCODE_W)) {
		deltaPos += Vector3_forward;
	}
	if (Input::GetKey(SDL_Scancode::SDL_SCANCODE_S)) {
		deltaPos -= Vector3_forward;
	}
	if (Input::GetKey(SDL_Scancode::SDL_SCANCODE_A)) {
		deltaPos -= Vector3_right;
	}
	if (Input::GetKey(SDL_Scancode::SDL_SCANCODE_D)) {
		deltaPos += Vector3_right;
	}
	deltaPos = Mathf::ClampLength(deltaPos, 1.f);

	deltaPos *= speed;
	//*Time::deltaTime();

	auto camera = Camera::GetMain();
	if (camera) {
		auto cameraTransform = camera->gameObject()->GetComponent<Transform>();

		Plane groundPlane = Plane(Vector3_zero, Vector3_up);
		Vector3 camForward = groundPlane.ProjectVector(cameraTransform->GetForward());
		if (camForward.LengthSquared() < Mathf::epsilon) {
			camForward = groundPlane.ProjectVector(cameraTransform->GetUp());
		}
		camForward.Normalize();
		Vector3 camRight = Vector3(camForward.z, 0.f, -camForward.x);


		deltaPos = camRight * deltaPos.x + camForward * deltaPos.z;
	}

	auto vel = rigidBody->GetLinearVelocity();
	vel.x = deltaPos.x;
	vel.z = deltaPos.z;

	rigidBody->SetLinearVelocity(vel);
}


void PlayerController::UpdateLook() {
	Matrix4 matrix = rigidBody->GetTransform();

	Vector3 lookDir = rigidBody->GetLinearVelocity();
	lookDir.y = 0.f;

	if (lookDir.Length() < 0.01f) {
		return;
	}

	SetRot(matrix, Quaternion::LookAt(lookDir, Vector3_up));

	rigidBody->SetTransform(matrix);

}

void PlayerController::Jump() {
	if (!rigidBody) {
		return;
	}
	if (!CanJump()) {
		return;
	}

	lastJumpTime = Time::time();

	auto vel = rigidBody->GetLinearVelocity();
	vel.y = jumpVelocity;
	rigidBody->SetLinearVelocity(vel);

}

bool PlayerController::CanJump() {
	if (Time::time() - lastJumpTime < jumpDelay) {
		return false;
	}
	if (!IsOnGround()) {
		return false;
	}
	return true;
}


DECLARE_TEXT_ASSET(PlayerController);
