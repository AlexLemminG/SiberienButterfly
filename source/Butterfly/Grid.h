#pragma once

#include "Component.h"
#include "Mesh.h"
#include "MeshRenderer.h"
#include "Transform.h"
#include "System.h"
#include "GameEvents.h"

enum class GridCellType : int {
    ZERO,
    NONE,
    GROUND
};
REFLECT_ENUM(GridCellType);

class GridCellMeshRenderer : public MeshRendererAbstract {
   public:
    GridCellMeshRenderer() : MeshRendererAbstract() {
        m_transform = &transform;
        SetEnabled(true);
    }
    ~GridCellMeshRenderer() {
        SetEnabled(false);
    }
    GridCellMeshRenderer(std::shared_ptr<Mesh> mesh, std::shared_ptr<Material> material) : GridCellMeshRenderer() {
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

class GridCellDesc {
   public:
    GridCellType type;
    std::string meshName;
    REFLECT_BEGIN(GridCellDesc);
    REFLECT_VAR(type);
    REFLECT_VAR(meshName);
    REFLECT_END();
};

class GridCell {
   public:
    int type = (int)GridCellType::NONE;
    Vector2Int pos;  // TODO only for intermediate form
    float z = 0.f;

    REFLECT_BEGIN(GridCell);
    REFLECT_VAR(type);
    REFLECT_VAR(pos);
    REFLECT_VAR(z);
    REFLECT_END();
};
class GridSettings : public Object {
   public:
    std::shared_ptr<FullMeshAsset> mesh;
    std::vector<GridCellDesc> cellDescs;
    REFLECT_BEGIN(GridSettings);
    REFLECT_VAR(mesh);
    REFLECT_VAR(cellDescs);
    REFLECT_END();
};
class Grid : public Component {
public:
    virtual void OnEnable() override;
    virtual void OnDisable() override;

    GridCell GetCell(Vector2Int pos) const;
    void SetCell(const GridCell& cell);

    Vector2Int GetClosestIntPos(const Vector3& worldPos) const;
    Vector3 GetCellWorldCenter(const Vector2Int& cell) const;

    std::vector<GridCell> cells;

    int sizeX = 20;
    int sizeY = 20;

    REFLECT_BEGIN(Grid);
    REFLECT_METHOD(GetClosestIntPos);
    REFLECT_METHOD(GetCellWorldCenter);
    REFLECT_METHOD(GetCell);
    REFLECT_METHOD(SetCell);
    REFLECT_END();
};

class GridSystem : public GameSystem<GridSystem> {
   public:
    const GridCellDesc& GetDesc(GridCellType type) const;

    bool Init() override;
    void Term() override;

    std::shared_ptr<GridSettings> settings;

    std::vector<std::shared_ptr<Grid>> grids;

    std::shared_ptr<Grid> GetGrid(const std::string& name);

    void LoadCellTypes();

    GameEventHandle onAfterLuaReloaded;

    REFLECT_BEGIN(GridSystem);
    REFLECT_METHOD(GetGrid);
    REFLECT_END();
};

class GridDrawer : public Component {
   public:
    void OnEnable() override;
    void OnDisable() override;
    void Update() override;

   private:
    std::shared_ptr<GameObject> gridCellPrefab;
    std::vector<GridCellMeshRenderer> pooledRenderers;

    REFLECT_BEGIN(GridDrawer);
    REFLECT_VAR(gridCellPrefab);
    REFLECT_END();
};