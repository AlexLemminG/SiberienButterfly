#include "Grid.h"
#include "GameObject.h"
#include "Scene.h"
#include "Asserts.h"
#include "LuaReflect.h"
#include "LuaSystem.h"
#include "Resources.h"
#include "../../engine/source/libs/luau/VM/src/ltable.h"

DECLARE_TEXT_ASSET(GridSystem);
DECLARE_TEXT_ASSET(GridSettings);
REGISTER_GAME_SYSTEM(GridSystem);
DECLARE_TEXT_ASSET(GridDrawer);
DECLARE_TEXT_ASSET(Grid);

std::shared_ptr<Grid> GridSystem::GetGrid(const std::string& name) {
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
    pooledRenderers.clear();
}

// TODO on before camera render actually
void GridDrawer::Update() {
    auto grid = gameObject()->GetComponent<Grid>();
    if (grid == nullptr) {
        LogError("no Grid with gridDrawer");
        return;
    }
    auto gridSystem = GridSystem::Get();
    auto prefabRenderer = gridCellPrefab->GetComponent<MeshRenderer>();
    while (pooledRenderers.size() < grid->cells.size()) {
        pooledRenderers.emplace_back(prefabRenderer->mesh, prefabRenderer->material);
    }
    // TODO remove extra

    for (int i = 0; i < grid->cells.size(); i++) {
        const auto& cell = grid->cells[i];
        auto& renderer = pooledRenderers[i];

        const auto& name = gridSystem->GetDesc((GridCellType)cell.type).meshName;

        if (renderer.mesh != nullptr) {
            renderer.OnDisable();
        }
        renderer.mesh = nullptr;
        renderer.m_transform->SetPosition(grid->GetCellWorldCenter(cell.pos));
        for (const auto& mesh : gridSystem->settings->mesh->meshes) {
            if (mesh->name == name) {
                renderer.mesh = mesh;
                // HACK to add to renderers list
                renderer.OnEnable();
                break;
            }
        }
    }
}

const GridCellDesc& GridSystem::GetDesc(GridCellType type) const {
    for (const auto& desc : settings->cellDescs) {
        if (desc.type == type) {
            return desc;
        }
    }
    static const GridCellDesc emptyDesc{};

    return emptyDesc;
}

void Grid::OnEnable() {
    std::shared_ptr<Grid> thisShared;
    for (auto c : gameObject()->components) {
        if (c.get() == this) {
            thisShared = std::dynamic_pointer_cast<Grid>(c);
            break;
        }
    }
    ASSERT(thisShared);
    GridSystem::Get()->grids.push_back(thisShared);

    for (int x = 0; x < sizeX; x++) {
        for (int y = 0; y < sizeY; y++) {
            auto& cell = cells.emplace_back();
            cell.pos.x = x;
            cell.pos.y = y;
            cell.type = (int)GridCellType::NONE;
        }
    }
}
void Grid::OnDisable() {
    auto& grids = GridSystem::Get()->grids;
    grids.erase(std::find_if(grids.begin(), grids.end(), [this](auto x) { return x.get() == this; }));
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
    context.isLua = true;
    DeserializeFromLuaToContext(L, -1, context);
    this->settings->cellDescs.clear();
    for (auto c : context.GetChildrenNames()) {
        int i = 0;
        context.Child(c) >> i;
        std::string meshName = c;
        std::transform(meshName.begin(), meshName.end(), meshName.begin(),
            [](unsigned char c) { return std::tolower(c); });
        if (meshName.size() > 0) {
            meshName[0] = std::toupper(meshName[0]);
        }
        this->settings->cellDescs.push_back({(GridCellType)i, meshName});
    }
}


Vector3 Grid::GetCellWorldCenter(const Vector2Int& pos) const {
    auto cell = GetCell(pos);
    return Vector3{float(cell.pos.x), cell.z, float(cell.pos.y)};
}

Vector2Int Grid::GetClosestIntPos(const Vector3& worldPos) const {
    return Vector2Int{Mathf::RoundToInt(worldPos.x), Mathf::RoundToInt(worldPos.z)};
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
    }
}