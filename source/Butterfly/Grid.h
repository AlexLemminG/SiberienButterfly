#pragma once

#include "SEngine/Component.h"
#include "SEngine/Mesh.h"
#include "SEngine/MeshRenderer.h"
#include "SEngine/Transform.h"
#include "SEngine/System.h"
#include "SEngine/GameEvents.h"
#include "SEngine/Types/Vector.h"
#include "SEngine/Types/String.h"
#include "SEngine/Types/UnorderedMap.h"
#include "SEngine/ReflectEnum.h"
#include <functional>

class Grid;
enum class GridCellType : int {
    ZERO,
    NONE,
    GROUND
};
REFLECT_ENUM_DECLARE(GridCellType);

enum class GridCellCollisionType : int {
    ZERO,
    NONE,
    SPHERE_COLLIDER,
    CAPSULE_COLLIDER,
    BOX_COLLIDER
};
REFLECT_ENUM_DECLARE(GridCellCollisionType);

enum class GridCellAnimType : int {
    ZERO,
    NONE
};
REFLECT_ENUM_DECLARE(GridCellAnimType);

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
    GridCellMeshRenderer(se::shared_ptr<Mesh> mesh, se::shared_ptr<Material> material) : GridCellMeshRenderer() {
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

    REFLECT_DECLARE(GridCellDescLua_Collision);
};
struct GridCellDescLua {
    bool isUtil = false;
    bool isWalkable = true;
    bool forceMakeWalkable = false;
    GridCellDescLua_Collision collision;
    se::vector<GridCellDescLua_Collision> extraCollisions;
    se::vector<GridCellDescLua_Collision> allCollisions;
    se::string prefabName;
    se::string meshName;
    REFLECT_DECLARE(GridCellDescLua);
};

enum class WalkableType {
    NOT_WALKABLE,
    WALKABLE,
    FORCE_MAKE_WALKABLE,
};

class GridCellDesc {
   public:
    GridCellType type;
    se::string meshName;
    se::shared_ptr<Mesh> mesh;
    GridCellDescLua luaDesc;
    se::shared_ptr<GameObject> prefab;
    WalkableType walkableType = WalkableType::NOT_WALKABLE;
    GridCellDesc() {}
    GridCellDesc(GridCellType type,
                 const se::string &meshName,
                 const se::shared_ptr<Mesh> &mesh) : type(type), meshName(meshName), mesh(mesh) {}
    GridCellDesc(GridCellType type,
                 const se::string &meshName,
                 const se::shared_ptr<Mesh> &mesh,
                 const GridCellDescLua &luaDesc,
                 const se::shared_ptr<GameObject> &prefab,
                 WalkableType walkableType)
        : type(type), meshName(meshName), mesh(mesh), luaDesc(luaDesc), prefab(prefab), walkableType(walkableType)
    {
    }
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

    REFLECT_DECLARE(GridCell);

    bool operator ==(const GridCell& otherCell) const {
        return std::memcmp(this, &otherCell, sizeof(GridCell)) == 0;
    }
};


struct GridCellIterator {
    using CheckFunc = std::function<bool(const GridCell&)>;
    GridCellIterator() {}
    GridCellIterator(CheckFunc checkFunc, Grid* grid);

    CheckFunc checkFunc;
    //Vector2Int prevCell = Vector2Int(-1, 0);
    int nextCellIdx = 0;
    int totalSize = 0;
    Grid* grid = nullptr;
    bool GetNextCell(GridCell& outCell);
    REFLECT_DECLARE(GridCellIterator);
};
class GridSettings : public Object {
   public:
    se::shared_ptr<FullMeshAsset> mesh;
    se::unordered_map<GridCellType, GridCellDesc> cellDescs;
    REFLECT_DECLARE(GridSettings);
};
class Grid : public Component, public ISerializable {
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

    static Vector2Int GetClosestIntPos(const Vector3& worldPos);
    bool DbgDrawRad(const Vector2Int& originPos, int minRadius, int maxRadius) const;
    Vector3 GetCellWorldCenter(const Vector2Int& cell) const;
    Vector3 GetCellWorldCenterFast(const Vector2Int& cellPos) const {
        return GetCellWorldCenter(GetCellFast(cellPos));
    }
    Vector3 GetCellWorldCenter(const GridCell& cell) const {
        return Vector3{ float(cell.pos.x), cell.z, float(cell.pos.y) };
    }

    void LoadFrom(const Grid& otherGrid);

    se::vector<GridCell> cells;
    se::vector<Matrix4> cellsLocalMatrices;

    se::vector<GridCell> cellsPrev;
    se::vector<Matrix4> cellsLocalMatricesPrev;

    GridCellIterator GetAnimatedCellsIterator();
    GridCellIterator GetTypeIterator(int cellType);
    GridCellIterator GetTypeWithAnimIterator(int cellType, int animType);

    int sizeX = 20;
    int sizeY = 20;

    int cellsPerChunkX = 16;
    int cellsPerChunkY = 16;

    int chunksCountX = 0;
    int chunksCountY = 0;

    int GetChunkIndex(const Vector2Int& pos) const;
    int GetIndexInChunk(const Vector2Int& pos) const;

    int GetModificationsCount()const {
        return modificationsCount;
    }
    int GetFullyClearedCount()const {
        return fullyClearedCount;
    }
    int GetTypeModificationsCount()const {
        return typeModificationsCount;
    }
    //TODO flip min/max order
    bool FindNearestPosWithType(Vector2Int& outPos, const Vector2Int& originPos, int minRadius, int maxRadius, int itemType) const;

    void Serialize(SerializationContext& context) const override;
    void Deserialize(const SerializationContext& context) override;

    void SetSize(int sizeX, int sizeY);

    bool isInited = false;

    se::vector<int> changedIndices;
private:
    int modificationsCount = 0;
    int fullyClearedCount = 0;
    int typeModificationsCount = 0;

    REFLECT_DECLARE(Grid);
};

struct GridPath {
    Vector2Int from;
    Vector2Int to;
    bool isComplete = false;
    se::vector<Vector2Int> points;

    REFLECT_DECLARE(GridPath);
};

class NavigationGrid : public Object {
public:
    bool IsWalkable(int x, int y) const;
    void Update();

    bool PathExists(Vector2Int from, Vector2Int to) const;
    GridPath CalcPath(Vector2Int from, Vector2Int to) const;

    void UpdateIslands();
private:
    bool CalcIsWalkable(int x, int y) const;
    int sizeX;
    int sizeY;
    se::vector<int> islandIndex;
    se::vector<bool> walkableCells; //TODO more packed then bool vector
    se::vector<se::shared_ptr<Grid>> sourceGrids;

    REFLECT_DECLARE(NavigationGrid);
};

class GridSystem : public GameSystem<GridSystem> {
   public:
    const GridCellDesc& GetDesc(GridCellType type) const;

    bool Init() override;
    void Update() override;
    void Term() override;

    se::shared_ptr<GridSettings> settings;

    se::shared_ptr<NavigationGrid> navigation;
    se::vector<se::shared_ptr<Grid>> grids;
    se::shared_ptr<Mesh> defaultMesh;

    se::shared_ptr<Grid> GetGrid(const se::string& name) const;
    se::shared_ptr<NavigationGrid> GetNavigation() const;

    void LoadCellTypes();

    se::shared_ptr<Mesh> GetMeshByCellType(int cellType) const;

    GameEventHandle onAfterLuaReloaded;
    GameEventHandle onAfterAssetDatabaseReloaded;

    bool FindNearestPosWithTypes(Vector2Int& outPos, const Vector2Int& originPos, int minRadius, int maxRadius, int itemType, int groundType, int markingType) const;
    bool FindNearestWalkable(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius) const;

    int cellTypeAny = 0;

    REFLECT_DECLARE(GridSystem);
};

class GridDrawer : public Component {
   public:
    void OnEnable() override;
    void OnDisable() override;
    void _Update() ;

    void OnValidate() override;

    bool useFrustumCulling = false;
    bool castsShadows = true;

   private:
    se::shared_ptr<GameObject> gridCellPrefab;
    //eastl::vector<GridCellMeshRenderer> pooledRenderers;
    se::unordered_map<int, se::unordered_map<GridCellType, InstancedMeshRenderer*>> instancedMeshRenderers;
    se::vector<se::shared_ptr<GameObject>> gameObjects;
    
    int lastModificationsCount = -1;
    int lastFullyClearedCount = -1;
    se::vector<int> instanceIndices;

    REFLECT_DECLARE(GridDrawer);
};

class GridChunkCollider : public Component {

public:
    bool changed = false;
    se::vector<se::vector<se::shared_ptr<class Collider>>> gridColliders;
    REFLECT_DECLARE(GridChunkCollider);
};

class GridCollider : public Component {
public:
    void _Update();

private:
    int lastModificationsCount = -1;
    int lastFullyClearedCount = -1;
    se::shared_ptr<GameObject> chunkPrefab;
    se::vector<se::shared_ptr<GridChunkCollider>> chunks;
    
    REFLECT_DECLARE(GridCollider);
};