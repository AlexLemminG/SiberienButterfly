#include "PlayerController.h"

#include "SEngine/GameObject.h"
#include "SEngine/Transform.h"
#include "SEngine/Input.h"
#include "SEngine/STime.h"
#include "SEngine/Camera.h"
#include "SEngine/Dbg.h"
#include "SEngine/Physics.h"
#include "SEngine/RigidBody.h"
#include "SEngine/Scene.h"
#include "SEngine/GameObject.h"
#include "SEngine/SceneManager.h"
#include "SEngine/MeshRenderer.h"
#include "SEngine/Sound.h"
#include "SEngine/Animation.h"
#include "SEngine/Light.h"
#include "SEngine/Mesh.h"
#include "SEngine/ParentedTransform.h"
#include "Grid.h"
#include "SEngine/BoxCollider.h"

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
    if (Input::GetKeyDown(SDL_Scancode::SDL_SCANCODE_F)) {
        auto apple = Scene::Get()->FindGameObjectByTag("apple");
        if (apple != nullptr) {
            if (hasItem) {
                apple->GetComponent<ParentedTransform>()->SetParent(nullptr);
                apple->transform()->SetPosition(gameObject()->transform()->GetPosition() + gameObject()->transform()->GetForward() * 1.5f);
                apple->transform()->SetEulerAngles(Vector3_zero);
            } else {
                int idx = 0;
                const auto& bones = gameObject()->GetComponent<MeshRenderer>()->mesh->bones;
                for (auto bone : bones) {
                    if (bone.name == "ItemAttachPoint") {
                        idx = bone.idx;
                        break;
                    }
                }
                apple->GetComponent<ParentedTransform>()->SetParentAsBone(gameObject()->GetComponent<MeshRenderer>(), idx);
            }
            hasItem = !hasItem;
            auto animator = gameObject()->GetComponent<Animator>();
            animator->SetAnimation(hasItem ? standAnimationWithItem : standAnimation);
        }
    }
    speed = hasItem ? speedWithItem : defaultSpeed;
    if (Input::GetKey(SDL_Scancode::SDL_SCANCODE_LSHIFT)) {
        speed *= 3.f;
    }

    auto ray = Camera::GetMain()->ScreenPointToRay(Input::GetMousePosition());
    auto plane = Plane(Vector3_zero, Vector3_up);
    float distance;
    if (plane.Raycast(ray, distance)) {
        Vector3 pos = ray.GetPoint(distance);
        Vector3 minPos = Vector3(Mathf::Floor(pos.x), Mathf::Floor(pos.y), Mathf::Floor(pos.z));

        AABB box = AABB(minPos, minPos + Vector3_one);
        // Dbg::Draw(box);
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
    vel.x = Mathf::Lerp(vel.x, deltaPos.x, 0.8f);
    vel.z = Mathf::Lerp(vel.z, deltaPos.z, 0.8f);
    vel.y = Mathf::Min(vel.y, 0.f);

    rigidBody->SetLinearVelocity(vel);

    auto animator = gameObject()->GetComponent<Animator>();
    float currentSpeed = vel.Length();
    if (currentSpeed > 0.1f) {
        animator->speed = 1.8f;
        animator->SetAnimation(hasItem ? runAnimationWithItem : runAnimation);
    } else {
        animator->speed = 1.0f;
        animator->SetAnimation(hasItem ? standAnimationWithItem : standAnimation);
    }
}

void PlayerController::UpdateLook() {
    Matrix4 matrix = rigidBody->GetTransform();

    Vector3 lookDir = rigidBody->GetLinearVelocity();
    lookDir.y = 0.f;

    if (lookDir.Length() < 0.01f) {
        return;
    }

    SetRot(matrix, Quaternion::LookAt(lookDir, Vector3_up));
    rigidBody->SetAngularVelocity(Vector3_zero);
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

REFLECT_DEFINE(PlayerController);
