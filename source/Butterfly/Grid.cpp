#include "Grid.h"
#include "SEngine/GameObject.h"
#include "SEngine/Scene.h"
#include "SEngine/Asserts.h"
#include "SEngine/LuaReflect.h"
#include "SEngine/LuaSystem.h"
#include "SEngine/Resources.h"
#include "SEngine/InstancedMeshRenderer.h"
#include "SEngine/RigidBody.h"
#include "../../engine/source/libs/luau/VM/src/ltable.h"
#include "SEngine/Collider.h"
#include "SEngine/BoxCollider.h"

DECLARE_TEXT_ASSET(GridSystem);
DECLARE_TEXT_ASSET(GridSettings);
REGISTER_GAME_SYSTEM(GridSystem);
DECLARE_TEXT_ASSET(GridCollider);
DECLARE_TEXT_ASSET(GridDrawer);
DECLARE_TEXT_ASSET(Grid);


REFLECT_DEFINE_COMPONENT_BEGIN(GridDrawer);
REFLECT_VAR(gridCellPrefab);
REFLECT_VAR(useFrustumCulling);
REFLECT_DEFINE_END(GridDrawer);

bool GridCellIterator::GetNextCell(GridCell& outCell) {
    ASSERT(grid);
    ASSERT(checkFunc);
    GridCell cell;
    for (int x = prevCell.x + 1; x < grid->sizeX; x++) {
        cell = grid->GetCellFast(Vector2Int(x, prevCell.y));
        if (checkFunc(cell)) {
            outCell = cell;
            prevCell = Vector2Int(x, prevCell.y);
            return true;
        }
    }
    for (int y = prevCell.y + 1; y < grid->sizeY; y++) {
        for (int x = 0; x < grid->sizeX; x++) {
            cell = grid->GetCellFast(Vector2Int(x, y));
            if (checkFunc(cell)) {
                outCell = cell;
                prevCell = Vector2Int(x, y);
                return true;
            }
        }
    }
    return false;
}

GridCellIterator Grid::GetAnimatedCellsIterator() {
    return GridCellIterator([](const GridCell& cell) { return cell.animType > (int)GridCellAnimType::NONE; }, this);
}


eastl::shared_ptr<Grid> GridSystem::GetGrid(const eastl::string& name) const {
    for (auto grid : grids) {
        if (grid->gameObject()->tag == name) {
            return grid;
        }
    }
    return nullptr;
}
void GridCollider::OnEnable() {

}
void GridCollider::OnDisable() {

}
void GridCollider::Update() {
    OPTICK_EVENT();
    auto grid = gameObject()->GetComponent<Grid>();
    if (grid == nullptr) {
        LogError("no Grid with gridDrawer");
        return;
    }
    if (lastModificationsCount == grid->GetTypeModificationsCount()) {
        return;
    }
    lastModificationsCount = grid->GetTypeModificationsCount();
    auto gridSystem = GridSystem::Get();


    while(auto collider = gameObject()->GetComponent<Collider>()) {
        gameObject()->RemoveComponent(collider);
    }

    for (int i = 0; i < grid->cells.size(); i++) {
        const auto& cell = grid->cells[i];
        const auto& desc = gridSystem->GetDesc((GridCellType)cell.type);
        for (const auto& collision : desc.luaDesc.allCollisions) {
            if (collision.type == (int)GridCellCollisionType::SPHERE_COLLIDER) {
                auto collider = eastl::make_shared<SphereCollider>();
                collider->radius = collision.radius;
                collider->center = grid->GetCellWorldCenter(cell.pos) + collision.center;
                gameObject()->AddComponent(collider);
            }
            else if (collision.type == (int)GridCellCollisionType::CAPSULE_COLLIDER) {
                auto collider = eastl::make_shared<CapsuleCollider>();
                collider->radius = collision.radius;
                collider->height = collision.height;
                collider->center = grid->GetCellWorldCenter(cell.pos) + collision.center;
                gameObject()->AddComponent(collider);
            }
            else if (collision.type == (int)GridCellCollisionType::BOX_COLLIDER) {
                auto collider = eastl::make_shared<BoxCollider>();
                collider->size = collision.size;
                collider->center = grid->GetCellWorldCenter(cell.pos) + collision.center;
                gameObject()->AddComponent(collider);
            }
        }
    }
    auto rb = gameObject()->GetComponent<RigidBody>();
    rb->SetEnabled(false);
    rb->SetEnabled(true);
}
void GridDrawer::OnEnable() {
}

void GridDrawer::OnDisable() {
    //for (auto& r : pooledRenderers) {
    //    r.OnDisable();
    //}
    for (auto& ir : instancedMeshRenderers) {
        ir.second->Term();
        delete ir.second;
    }
    instancedMeshRenderers.clear();
    //pooledRenderers.clear();
}

// TODO on before camera render actually
void GridDrawer::Update() {
    OPTICK_EVENT();
    auto grid = gameObject()->GetComponent<Grid>();
    if (grid == nullptr) {
        LogError("no Grid with gridDrawer");
        return;
    }
    if (lastModificationsCount == grid->GetModificationsCount()) {
        return;
    }
    lastModificationsCount = grid->GetModificationsCount();
    auto gridSystem = GridSystem::Get();
    auto prefabRenderer = gridCellPrefab->GetComponent<MeshRenderer>();
    //while (pooledRenderers.size() < grid->cells.size()) {
    //    pooledRenderers.emplace_back(prefabRenderer->mesh, prefabRenderer->material);
    //}
    // TODO remove extra

    for (auto& ir : instancedMeshRenderers) {
        ir.second->instances.resize(0);
    }

    for (int i = 0; i < grid->cells.size(); i++) {
        const auto& cell = grid->cells[i];

        InstancedMeshRenderer* ir = nullptr;
        auto it = instancedMeshRenderers.find((GridCellType)cell.type);
        if (it != instancedMeshRenderers.end()) {
            ir = it->second;
        }
        else {
            ir = new InstancedMeshRenderer();
            ir->mesh = gridSystem->GetDesc((GridCellType)cell.type).mesh;
            ir->material = prefabRenderer->material;
            ir->Init(gameObject()->GetScene());
            ir->useFrustumCulling = this->useFrustumCulling;
            this->instancedMeshRenderers.emplace((GridCellType)cell.type, ir);
        }
        auto& instance = ir->instances.emplace_back(grid->cellsLocalMatrices[i]);
        instance.transform.GetColumn(3) += Vector4(grid->GetCellWorldCenter(cell), 0);
        //auto cellPos = grid->GetCellWorldCenter(cell);
        //instance.transform.GetColumn(3).x += cellPos.x;
        //instance.transform.GetColumn(3).y += cellPos.y;
        //instance.transform.GetColumn(3).z += cellPos.z;
    }
}
void GridDrawer::OnValidate() {
    for (auto& ir : this->instancedMeshRenderers) {
        ir.second->useFrustumCulling = this->useFrustumCulling;
    }
}

const GridCellDesc& GridSystem::GetDesc(GridCellType type) const {
    auto it = settings->cellDescs.find(type);
    if (it != settings->cellDescs.end()) {
        return it->second;
    }
    //TODO adding desc in a const getter + returning everything by ref is a really really bad idea
    //but I am a comment and not a cop so go on
    settings->cellDescs.emplace(type, GridCellDesc{ type, "UnknownType", defaultMesh });
    return GetDesc(type);
}

void Grid::OnEnable() {
    eastl::shared_ptr<Grid> thisShared;
    for (auto c : gameObject()->components) {
        if (c.get() == this) {
            thisShared = eastl::dynamic_pointer_cast<Grid>(c);
            break;
        }
    }
    ASSERT(thisShared);
    GridSystem::Get()->grids.push_back(thisShared);


    if (!isInited) {
        SetSize(sizeX, sizeY);
    }
    else {
        ASSERT(cells.size() == sizeX * sizeY);
        ASSERT(cellsLocalMatrices.size() == sizeX * sizeY);
    }
    isInited = true;
}

void Grid::SetSize(int sizeX, int sizeY) {
    this->sizeX = sizeX;
    this->sizeY = sizeY;
    cells.clear();
    //TODO resize + [] instead of emplace_back
    cells.reserve(sizeX * sizeY);
    for (int x = 0; x < sizeX; x++) {
        for (int y = 0; y < sizeY; y++) {
            auto& cell = cells.emplace_back();
            cell.pos.x = x;
            cell.pos.y = y;
            cell.type = (int)GridCellType::NONE;
        }
    }
    cells.shrink_to_fit();

    cellsLocalMatrices.clear();
    cellsLocalMatrices.resize(sizeX * sizeY, Matrix4::Identity());
}

void Grid::OnDisable() {
    auto& grids = GridSystem::Get()->grids;
    grids.erase(eastl::find_if(grids.begin(), grids.end(), [this](auto x) { return x.get() == this; }));
}

bool GridSystem::Init() {
    auto L = LuaSystem::Get()->L;

    LuaReflect::RegisterShared<GridSystem>(L);
    LuaReflect::RegisterShared<Grid>(L);
    LuaReflect::Register<GridCell>(L);
    LuaReflect::Register<GridCellIterator>(L);

    settings = AssetDatabase::Get()->Load<GridSettings>("grid.asset");  // TODO make visible from inspector



    if (!settings) {
        return false;
    }

    this->onAfterLuaReloaded = LuaSystem::Get()->onAfterScriptsReloading.Subscribe([this]() { LoadCellTypes(); });
    LoadCellTypes();

    return true;
}

void GridSystem::Term() {
    auto luaSystem = LuaSystem::Get();
    if (luaSystem) {
        luaSystem->onAfterScriptsReloading.Unsubscribe(this->onAfterLuaReloaded);
        auto L = LuaSystem::Get()->L;
        if (L) {
            LuaReflect::UnregisterShared<GridSystem>(L);
            LuaReflect::UnregisterShared<Grid>(L);
            LuaReflect::Unregister<GridCell>(L);
            LuaReflect::Unregister<GridCellIterator>(L);
        }
    }

    settings = nullptr;
}


void GridSystem::LoadCellTypes() {
    LuaSystem::Get()->PushModule("CellTypeDesc");
    LuaSystem::Get()->PushModule("CellType");
    auto L = LuaSystem::Get()->L;
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        ASSERT("Failed to load CellType lua module");
        return;
    }
    if (lua_isnil(L, -2)) {
        lua_pop(L, 2);
        ASSERT("Failed to load CellTypeDesc lua module");
        return;
    }
    SerializationContext contextCellType{};
    LuaReflect::DeserializeFromLuaToContext(L, -1, contextCellType);
    SerializationContext _contextCellTypeDesc{};
    LuaReflect::DeserializeFromLuaToContext(L, -2, _contextCellTypeDesc);
    this->settings->cellDescs.clear();
    const SerializationContext& contextCellTypeDesc = _contextCellTypeDesc;


    this->defaultMesh = nullptr;
    for (auto mesh : this->settings->mesh->meshes) {
        if (_strcmpi(mesh->name.c_str(), "unknown") == 0) {
            this->defaultMesh = mesh;
            break;
        }
    }

    for (auto c : contextCellType.GetChildrenNames()) {
        GridCellDescLua luaDesc;
        auto descContext = contextCellTypeDesc.Child(c);
        if (descContext.IsDefined()) {
            ::Deserialize(descContext, luaDesc);
            luaDesc.allCollisions = luaDesc.extraCollisions;
            luaDesc.allCollisions.push_back(luaDesc.collision);
        }

        int i = 0;
        contextCellType.Child(c) >> i;

        //no mesh for util
        eastl::string meshName = c;
        eastl::shared_ptr<Mesh> cellMesh = this->defaultMesh;
        if (luaDesc.isUtil) {
            meshName = "None";
            cellMesh = nullptr;
        }
        else {
            eastl::transform(meshName.begin(), meshName.end(), meshName.begin(),
                [](unsigned char c) { return std::tolower(c); });
            if (meshName.size() > 0) {
                meshName[0] = std::toupper(meshName[0]);
            }
            for (auto mesh : this->settings->mesh->meshes) {
                if (_strcmpi(mesh->name.c_str(), meshName.c_str()) == 0) {
                    cellMesh = mesh;
                    break;
                }
            }
            if (cellMesh == this->defaultMesh) {
                LogError("No mesh found for cell type '%s'", c.c_str());
            }
        }

        auto desc = GridCellDesc{ (GridCellType)i, meshName, cellMesh, luaDesc };

        this->settings->cellDescs.emplace(desc.type, desc);
    }
    lua_pop(L, 2);
}


Vector3 Grid::GetCellWorldCenter(const Vector2Int& pos) const {
    auto cell = GetCell(pos);
    return Vector3{ float(cell.pos.x), cell.z, float(cell.pos.y) };
}

Vector2Int Grid::GetClosestIntPos(const Vector3& worldPos) const {
    return Vector2Int{ Mathf::RoundToInt(worldPos.x), Mathf::RoundToInt(worldPos.z) };
}

GridCell Grid::GetCell(Vector2Int pos) const {
    if (pos.x >= 0 && pos.x < sizeX && pos.y >= 0 && pos.y < sizeY) {
        return cells[pos.x * sizeY + pos.y];
    }
    GridCell cell;
    cell.pos = pos;
    return cell;
}

void Grid::SetCell(const GridCell& cell) {
    if (cell.pos.x >= 0 && cell.pos.x < sizeX && cell.pos.y >= 0 && cell.pos.y < sizeY) {
        const auto& prevCell = cells[cell.pos.x * sizeY + cell.pos.y];
        if (prevCell.type != cell.type) {
            typeModificationsCount++;
        }
        cells[cell.pos.x * sizeY + cell.pos.y] = cell;
        modificationsCount++;
    }
}

void Grid::SetCellLocalMatrix(const Vector2Int& pos, const Matrix4& matrix) {
    if (pos.x >= 0 && pos.x < sizeX && pos.y >= 0 && pos.y < sizeY) {
        cellsLocalMatrices[pos.x * sizeY + pos.y] = matrix;
        modificationsCount++;//TODO callback to update single instance matrix
    }
}

eastl::shared_ptr<Mesh> GridSystem::GetMeshByCellType(int cellType) const {
    return GetDesc((GridCellType)cellType).mesh;
}


void Grid::GetCellOut(GridCell& outCell, Vector2Int pos) const {
    outCell = GetCell(pos);
}

template<class CheckFunc>
static bool FindNearestPosWithPredecate(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius, CheckFunc checkFunc)
{
    OPTICK_EVENT();
    if (checkFunc(originPos)) {
        outPos = originPos;
        return true;
    }

    //PERF try quadtree in emergency situation
    int max_count = (maxRadius * 2 + 1) * (maxRadius * 2 + 1);

    Vector2Int current_pos = originPos;
    int current_radius = 1;
    int t = 1;
    while (current_radius <= maxRadius) {
        for (int i = 0; i < t; i++) {
            current_pos.y -= 1;
            if (checkFunc(current_pos)) {
                outPos = current_pos;
                return true;
            }
        }
        for (int i = 0; i < t; i++) {
            current_pos.x += 1;
            if (checkFunc(current_pos)) {
                outPos = current_pos;
                return true;
            }
        }
        t++;
        for (int i = 0; i < t; i++) {
            current_pos.y += 1;
            if (checkFunc(current_pos)) {
                outPos = current_pos;
                return true;
            }
        }
        for (int i = 0; i < t; i++) {
            current_pos.x -= 1;
            if (checkFunc(current_pos)) {
                outPos = current_pos;
                return true;
            }
        }
        t++;
        current_radius++;
    }
    return false;
}

bool GridSystem::FindNearestPosWithTypes(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius, int itemType, int groundType) const
{
    auto* itemsGrid = this->GetGrid("ItemsGrid").get();
    auto* groundGrid = this->GetGrid("GroundGrid").get();

    ASSERT(itemsGrid && groundGrid);

    return FindNearestPosWithPredecate(outPos, originPos, maxRadius, [itemsGrid, groundGrid, itemType, groundType](const Vector2Int& pos) {
        return itemsGrid->GetCell(pos).type == itemType && groundGrid->GetCell(pos).type == groundType;
        });
}

bool Grid::FindNearestPosWithType(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius, int itemType) const {
    return FindNearestPosWithPredecate(outPos, originPos, maxRadius, [this, itemType](const Vector2Int& pos) {return GetCell(pos).type == itemType; });
}

void Grid::SerializeGrid(SerializationContext& context, const Grid& grid)
{
    ::Serialize(context.Child("sizeX"), grid.sizeX);
    ::Serialize(context.Child("sizeY"), grid.sizeY);
    ::Serialize(context.Child("isInited"), grid.isInited);
    
    c4::cblob blob;
    blob.buf = (c4::cbyte*)grid.cells.data();
    blob.len = grid.cells.size() * sizeof(decltype(grid.cells)::value_type);
    eastl::string buffer = eastl::string(((4 * blob.len / 3) + 3) & ~3, '\0');
    c4::substr bufferSubstr(buffer.data(), buffer.size());
    size_t size = ryml::base64_encode(bufferSubstr, blob);
    ASSERT(size == buffer.size());

    context.Child("cells") << buffer;
}

void Grid::DeserializeGrid(const SerializationContext& context, Grid& grid)
{
    ::Deserialize(context.Child("sizeX"), grid.sizeX);
    ::Deserialize(context.Child("sizeY"), grid.sizeY);
    ::Deserialize(context.Child("isInited"), grid.isInited);

    if (grid.isInited) {
        eastl::string cellsBase64;
        ::Deserialize(context.Child("cells"), cellsBase64);


        c4::csubstr cellsBase64Substr(cellsBase64.c_str(), cellsBase64.size());

        grid.SetSize(grid.sizeX, grid.sizeY);

        c4::blob blob(grid.cells.data(), grid.cells.size() * sizeof(decltype(grid.cells)::value_type));

        size_t size = c4::base64_decode(cellsBase64Substr, blob);
        ASSERT(size == grid.cells.size() * sizeof(decltype(grid.cells)::value_type));
    }

}
void Grid::LoadFrom(const Grid& otherGrid) {
    OnDisable();
    
    this->cells = otherGrid.cells;
    this->cellsLocalMatrices = otherGrid.cellsLocalMatrices;
    this->sizeX = otherGrid.sizeX;
    this->sizeY = otherGrid.sizeY;
    this->isInited = otherGrid.isInited;
    this->modificationsCount++;
    this->typeModificationsCount++;

    OnEnable();
}
