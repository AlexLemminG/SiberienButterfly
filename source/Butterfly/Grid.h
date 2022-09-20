#pragma once

#include "SEngine/Component.h"
#include "SEngine/Mesh.h"
#include "SEngine/MeshRenderer.h"
#include "SEngine/Transform.h"
#include "SEngine/System.h"
#include "SEngine/GameEvents.h"
#include "SEngine/Vector.h"

class Grid;
enum class GridCellType : int {
    ZERO,
    NONE,
    GROUND
};
REFLECT_ENUM(GridCellType);

enum class GridCellCollisionType : int {
    ZERO,
    NONE,
    SPHERE_COLLIDER,
    CAPSULE_COLLIDER,
    BOX_COLLIDER
};
REFLECT_ENUM(GridCellCollisionType);

enum class GridCellAnimType : int {
    ZERO,
    NONE
};
REFLECT_ENUM(GridCellAnimType);

class InstancedMeshRenderer;

class GridCellMeshRenderer : public MeshRendererAbstract {
   public:
    GridCellMeshRenderer() : MeshRendererAbstract() {
        m_transform = &transform;
        SetEnabled(true);
    }
    ~GridCellMeshRenderer() {
        SetEnabled(false);
    }
    GridCellMeshRenderer(eastl::shared_ptr<Mesh> mesh, eastl::shared_ptr<Material> material) : GridCellMeshRenderer() {
        this->mesh = mesh;
        this->material = material;
    }
    GridCellMeshRenderer(GridCellMeshRenderer&& other) : GridCellMeshRenderer(other.mesh, other.material) {
        this->transform = other.transform;
    }
    GridCellMeshRenderer(const GridCellMeshRenderer& other) : GridCellMeshRenderer(other.mesh, other.material) {
        this->transform = other.transform;
    }
    Transform transform;
};

struct GridCellDescLua_Collision {
    int type = (int)GridCellCollisionType::NONE;
    float radius = 0.f;
    float height = 0.f;
    Vector3 size = Vector3_zero;
    Vector3 center = Vector3_zero;

    REFLECT_BEGIN(GridCellDescLua_Collision);
    REFLECT_VAR(type);
    REFLECT_VAR(radius);
    REFLECT_VAR(height);
    REFLECT_VAR(size);
    REFLECT_VAR(center);
    REFLECT_END();
};
struct GridCellDescLua {
    bool isUtil = false;
    GridCellDescLua_Collision collision;
    eastl::vector<GridCellDescLua_Collision> extraCollisions;
    eastl::vector<GridCellDescLua_Collision> allCollisions;
    eastl::string prefabName;
    REFLECT_BEGIN(GridCellDescLua);
    REFLECT_VAR(prefabName);
    REFLECT_VAR(collision);
    REFLECT_VAR(extraCollisions);
    REFLECT_VAR(isUtil);
    REFLECT_END();
};

class GridCellDesc {
   public:
    GridCellType type;
    eastl::string meshName;
    eastl::shared_ptr<Mesh> mesh;
    GridCellDescLua luaDesc;
    eastl::shared_ptr<GameObject> prefab;
    REFLECT_DECLARE(GridCellDesc);
};

class GridCell {
   public:
    int type = (int)GridCellType::NONE;
    Vector2Int pos;  // TODO only for intermediate form
    float z = 0.f;
    int animType = (int)GridCellAnimType::NONE;
    float animT = 0.f;
    float animStopT = 0.f;
    float float4 = 0.f;

    REFLECT_BEGIN(GridCell);
    REFLECT_VAR(type);
    REFLECT_VAR(pos);
    REFLECT_VAR(z);
    REFLECT_VAR(animType);
    REFLECT_VAR(animT);
    REFLECT_VAR(animStopT);
    REFLECT_VAR(float4);
    REFLECT_END();

    bool operator ==(const GridCell& otherCell) const {
        return std::memcmp(this, &otherCell, sizeof(GridCell)) == 0;
    }
};


struct GridCellIterator {
    using CheckFunc = bool(const GridCell&);
    GridCellIterator() {}
    GridCellIterator(CheckFunc* checkFunc, Grid* grid) :checkFunc(checkFunc), grid(grid) {}

    CheckFunc* checkFunc = nullptr;
    Vector2Int prevCell = Vector2Int(-1, 0);
    Grid* grid = nullptr;
    bool GetNextCell(GridCell& outCell);
    REFLECT_BEGIN(GridCellIterator);
    REFLECT_METHOD(GetNextCell);
    REFLECT_END();
};
class GridSettings : public Object {
   public:
    eastl::shared_ptr<FullMeshAsset> mesh;
    eastl::unordered_map<GridCellType, GridCellDesc> cellDescs;
    REFLECT_BEGIN(GridSettings);
    REFLECT_VAR(mesh);
    REFLECT_END();
};
class Grid : public Component {
public:
    virtual void OnEnable() override;
    virtual void OnDisable() override;
    virtual void Update() override;

    GridCell GetCell(Vector2Int pos) const;
    const GridCell& GetCellFast(Vector2Int pos) const {
        return cells[pos.x * sizeY + pos.y];
    }
    void GetCellOut(GridCell& outCell, Vector2Int pos) const;
    void SetCell(const GridCell& cell);
    void SetCellLocalMatrix(const Vector2Int& pos, const Matrix4& matrix);

    Vector2Int GetClosestIntPos(const Vector3& worldPos) const;
    Vector3 GetCellWorldCenter(const Vector2Int& cell) const;
    Vector3 GetCellWorldCenterFast(const Vector2Int& cellPos) const {
        return GetCellWorldCenter(GetCellFast(cellPos));
    }
    Vector3 GetCellWorldCenter(const GridCell& cell) const {
        return Vector3{ float(cell.pos.x), cell.z, float(cell.pos.y) };
    }

    void LoadFrom(const Grid& otherGrid);

    eastl::vector<GridCell> cells;
    eastl::vector<Matrix4> cellsLocalMatrices;

    eastl::vector<GridCell> cellsPrev;
    eastl::vector<Matrix4> cellsLocalMatricesPrev;

    GridCellIterator GetAnimatedCellsIterator();

    int sizeX = 20;
    int sizeY = 20;

    int GetModificationsCount()const {
        return modificationsCount;
    }
    int GetTypeModificationsCount()const {
        return typeModificationsCount;
    }
    bool FindNearestPosWithType(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius, int itemType) const;

    static void SerializeGrid(SerializationContext& context, const Grid& grid);
    static void DeserializeGrid(const SerializationContext& context, Grid& grid);

    void SetSize(int sizeX, int sizeY);

    bool isInited = false;
private:
    int modificationsCount = 0;
    int typeModificationsCount = 0;

    REFLECT_COMPONENT_BEGIN(Grid);
    REFLECT_METHOD(GetClosestIntPos);
    REFLECT_METHOD_EXPLICIT("GetCellWorldCenter", static_cast<Vector3(Grid::*)(const Vector2Int&) const>(&Grid::GetCellWorldCenter));
    REFLECT_METHOD(GetCell);
    REFLECT_METHOD(SetCellLocalMatrix);
    REFLECT_METHOD(GetCellOut);
    REFLECT_METHOD(SetCell);
    REFLECT_METHOD(SetSize);
    REFLECT_METHOD(GetAnimatedCellsIterator);
    REFLECT_METHOD(FindNearestPosWithType);
    REFLECT_VAR(sizeX);
    REFLECT_VAR(sizeY);
    REFLECT_END_CUSTOM(Grid::SerializeGrid, Grid::DeserializeGrid);
};

class GridSystem : public GameSystem<GridSystem> {
   public:
    const GridCellDesc& GetDesc(GridCellType type) const;

    bool Init() override;
    void Term() override;

    eastl::shared_ptr<GridSettings> settings;

    eastl::vector<eastl::shared_ptr<Grid>> grids;
    eastl::shared_ptr<Mesh> defaultMesh;

    eastl::shared_ptr<Grid> GetGrid(const eastl::string& name) const;

    void LoadCellTypes();

    eastl::shared_ptr<Mesh> GetMeshByCellType(int cellType) const;

    GameEventHandle onAfterLuaReloaded;
    GameEventHandle onAfterAssetDatabaseReloaded;

    bool FindNearestPosWithTypes(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius, int itemType, int groundType) const;

    REFLECT_BEGIN(GridSystem);
    REFLECT_METHOD(GetGrid);
    REFLECT_METHOD(GetMeshByCellType);
    REFLECT_METHOD(FindNearestPosWithTypes);
    REFLECT_END();
};

class GridDrawer : public Component {
   public:
    void OnEnable() override;
    void OnDisable() override;
    void Update() override;

    void OnValidate() override;

    bool useFrustumCulling = false;
    bool castsShadows = true;

   private:
    eastl::shared_ptr<GameObject> gridCellPrefab;
    //eastl::vector<GridCellMeshRenderer> pooledRenderers;
    eastl::unordered_map<GridCellType, InstancedMeshRenderer*> instancedMeshRenderers;
    eastl::vector<eastl::shared_ptr<GameObject>> gameObjects;
    
    int lastModificationsCount = -1;
    eastl::vector<int> instanceIndices;

    REFLECT_DECLARE(GridDrawer);
};

class GridCollider : public Component {
public:
    void OnEnable() override;
    void OnDisable() override;
    void Update() override;

private:
    int lastModificationsCount = -1;
    eastl::vector<eastl::shared_ptr<class Collider>> gridColliders;
    REFLECT_COMPONENT_BEGIN(GridCollider);
    REFLECT_END();
};