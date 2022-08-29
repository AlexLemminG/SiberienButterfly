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

DECLARE_TEXT_ASSET(GridSystem);
DECLARE_TEXT_ASSET(GridSettings);
REGISTER_GAME_SYSTEM(GridSystem);
DECLARE_TEXT_ASSET(GridDrawer);
DECLARE_TEXT_ASSET(Grid);

eastl::shared_ptr<Grid> GridSystem::GetGrid(const eastl::string& name) const {
    for (auto grid : grids) {
        if (grid->gameObject()->tag == name) {
            return grid;
        }
    }
    return nullptr;
}

void GridDrawer::OnEnable() {
}

void GridDrawer::OnDisable() {
    for (auto& r : pooledRenderers) {
        r.OnDisable();
    }
    for (auto* ir : instancedMeshRenderers) {
        ir->Term();
        delete ir;
    }
    instancedMeshRenderers.clear();
    pooledRenderers.clear();
}

// TODO on before camera render actually
void GridDrawer::Update() {
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
    while (pooledRenderers.size() < grid->cells.size()) {
        pooledRenderers.emplace_back(prefabRenderer->mesh, prefabRenderer->material);
    }
    // TODO remove extra

    for (auto* ir : instancedMeshRenderers) {
        ir->instances.clear();
    }

    for (int i = 0; i < grid->cells.size(); i++) {
        const auto& cell = grid->cells[i];
        auto& renderer = pooledRenderers[i];

        const auto& name = gridSystem->GetDesc((GridCellType)cell.type).meshName;

        if (renderer.mesh != nullptr) {
            renderer.OnDisable();
        }
        Matrix4 transformMatrix = Matrix4::Transform(grid->GetCellWorldCenter(cell.pos), Matrix3::Identity(), Vector3_one) * grid->cellsLocalMatrices[i];
        renderer.mesh = nullptr;
        renderer.m_transform->SetMatrix(transformMatrix);
        renderer.mesh = gridSystem->GetDesc((GridCellType)cell.type).mesh;
        if (renderer.mesh) {
            //renderer.OnEnable();
        }

        InstancedMeshRenderer* ir = nullptr;
        for (auto* it : instancedMeshRenderers) {
            if (it->mesh == renderer.mesh) {
                ir = it;
                break;
            }
        }
        if (ir == nullptr) {
            ir = new InstancedMeshRenderer();
            ir->mesh = renderer.mesh;
            ir->material = renderer.material;
            ir->Init();
            this->instancedMeshRenderers.push_back(ir);
        }
        ir->instances.push_back({ transformMatrix });
    }
}

const GridCellDesc& GridSystem::GetDesc(GridCellType type) const {
    for (const auto& desc : settings->cellDescs) {
        if (desc.type == type) {
            return desc;
        }
    }
    GridCellDesc emptyDesc{};
    emptyDesc.mesh = defaultMesh;
    emptyDesc.type = type;

    return emptyDesc;
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

    cellsLocalMatrices.clear();
    cellsLocalMatrices.resize(sizeX*sizeY, Matrix4::Identity());

    if (!isInited) {
        cells.reserve(sizeX * sizeY);
        for (int x = 0; x < sizeX; x++) {
            for (int y = 0; y < sizeY; y++) {
                auto& cell = cells.emplace_back();
                cell.pos.x = x;
                cell.pos.y = y;
                cell.type = (int)GridCellType::NONE;
            }
        }
    }
    else {
        ASSERT(cells.size() == sizeX * sizeY);
    }
    isInited = true;
}
void Grid::OnDisable() {
    auto& grids = GridSystem::Get()->grids;
    grids.erase(eastl::find_if(grids.begin(), grids.end(), [this](auto x) { return x.get() == this; }));
}

bool GridSystem::Init() {
    auto L = LuaSystem::Get()->L;

    Luna::RegisterShared<GridSystem>(L);
    Luna::RegisterShared<Grid>(L);
    Luna::Register<GridCell>(L);

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
            Luna::UnregisterShared<GridSystem>(L);
Luna::UnregisterShared<Grid>(L);
Luna::Unregister<GridCell>(L);
        }
    }

    settings = nullptr;
}


void GridSystem::LoadCellTypes() {
    LuaSystem::Get()->PushModule("CellType");
    auto L = LuaSystem::Get()->L;
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        ASSERT("Failed to load CellType lua module");
        return;
    }
    SerializationContext context{};
    DeserializeFromLuaToContext(L, -1, context);
    this->settings->cellDescs.clear();


    this->defaultMesh = nullptr;
    for (auto mesh : this->settings->mesh->meshes) {
        if (_strcmpi(mesh->name.c_str(), "unknown") == 0) {
            this->defaultMesh = mesh;
            break;
        }
    }

    for (auto c : context.GetChildrenNames()) {
        int i = 0;
        context.Child(c) >> i;
        eastl::string meshName = c;
        eastl::transform(meshName.begin(), meshName.end(), meshName.begin(),
            [](unsigned char c) { return std::tolower(c); });
        if (meshName.size() > 0) {
            meshName[0] = std::toupper(meshName[0]);
        }
        eastl::shared_ptr<Mesh> cellMesh = this->defaultMesh;
        for (auto mesh : this->settings->mesh->meshes) {
            if (_strcmpi(mesh->name.c_str(), meshName.c_str()) == 0) {
                cellMesh = mesh;
                break;
            }
        }
        if (c == "None" || c == "Any") { //TODO lua method to determine if mesh is not required
            cellMesh = nullptr;
            meshName = c;
        }
        else if (cellMesh == this->defaultMesh) {
            LogError("No mesh found for cell type '%s'", c.c_str());
        }
        this->settings->cellDescs.push_back({ (GridCellType)i, meshName, cellMesh });
    }
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

        grid.cells.resize(grid.sizeX * grid.sizeY);

        c4::blob blob(grid.cells.data(), grid.cells.size() * sizeof(decltype(grid.cells)::value_type));

        size_t size = c4::base64_decode(cellsBase64Substr, blob);
        ASSERT(size == grid.cells.size() * sizeof(decltype(grid.cells)::value_type));
    }

}
void Grid::LoadFrom(const Grid& otherGrid) {
    OnDisable();
    
    this->cells = otherGrid.cells;
    this->sizeX = otherGrid.sizeX;
    this->sizeY = otherGrid.sizeY;
    this->isInited = otherGrid.isInited;
    this->modificationsCount++;

    OnEnable();
}
