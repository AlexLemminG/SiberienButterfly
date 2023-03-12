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
#include <EASTL/sort.h>
#include <EASTL/vector.h>
#include <EASTL/priority_queue.h>
#include "SEngine/Dbg.h"
#include "SEngine/Types/StringView.h"

REGISTER_GAME_SYSTEM(GridSystem);

REFLECT_DEFINE_BEGIN(GridSystem);
REFLECT_METHOD(GetGrid);
REFLECT_METHOD(GetNavigation);
REFLECT_METHOD(GetMeshByCellType);
REFLECT_METHOD(FindNearestPosWithTypes);
REFLECT_METHOD(FindNearestWalkable);
REFLECT_DEFINE_END();

    REFLECT_DEFINE_BEGIN(GridCellIterator);
    REFLECT_METHOD(GetNextCell);
    REFLECT_DEFINE_END();

    REFLECT_DEFINE_BEGIN(GridSettings);
    REFLECT_VAR(mesh);
    REFLECT_DEFINE_END();

REFLECT_DEFINE_COMPONENT_BEGIN(Grid);
REFLECT_METHOD(GetClosestIntPos);
REFLECT_METHOD_EXPLICIT("GetCellWorldCenter", static_cast<Vector3(Grid::*)(const Vector2Int&) const>(&Grid::GetCellWorldCenter));
REFLECT_METHOD(GetCell);
REFLECT_METHOD(SetCellLocalMatrix);
REFLECT_METHOD(GetCellOut);
REFLECT_METHOD(SetCell);
REFLECT_METHOD(SetSize);
REFLECT_METHOD(GetAnimatedCellsIterator);
REFLECT_METHOD(GetTypeIterator);
REFLECT_METHOD(GetTypeWithAnimIterator);
REFLECT_METHOD(FindNearestPosWithType);
REFLECT_METHOD(DbgDrawRad);
REFLECT_VAR(sizeX);
REFLECT_VAR(sizeY);
REFLECT_DEFINE_END_CUSTOM(Grid::SerializeGrid, Grid::DeserializeGrid);

REFLECT_DEFINE_COMPONENT_BEGIN(GridChunkCollider);
REFLECT_DEFINE_END();

REFLECT_DEFINE_BEGIN(GridCellDesc);
REFLECT_VAR(type);
REFLECT_VAR(meshName);
REFLECT_VAR(mesh);
REFLECT_VAR(prefab);
REFLECT_VAR(luaDesc);
REFLECT_DEFINE_END();

REFLECT_DEFINE_COMPONENT_BEGIN(GridDrawer);
REFLECT_VAR(gridCellPrefab);
REFLECT_VAR(useFrustumCulling);
REFLECT_VAR(castsShadows);
REFLECT_DEFINE_END();


REFLECT_DEFINE_COMPONENT_BEGIN(GridCollider);
REFLECT_VAR(chunkPrefab);
REFLECT_DEFINE_END();


REFLECT_DEFINE_BEGIN(NavigationGrid);
REFLECT_METHOD(IsWalkable);
REFLECT_METHOD(CalcPath);
REFLECT_METHOD(PathExists);
REFLECT_VAR(sourceGrids);
REFLECT_DEFINE_END();


REFLECT_DEFINE_BEGIN(GridPath);
REFLECT_VAR(from);
REFLECT_VAR(to);
REFLECT_VAR(isComplete);
REFLECT_VAR(points);
REFLECT_DEFINE_END();

    REFLECT_DEFINE_BEGIN(GridCell);
    REFLECT_VAR(type);
    REFLECT_VAR(pos);
    REFLECT_VAR(z);
    REFLECT_VAR(animType);
    REFLECT_VAR(animT);
    REFLECT_VAR(animStopT);
    REFLECT_VAR(float4);
    REFLECT_DEFINE_END();
    
    REFLECT_DEFINE_BEGIN(GridCellDescLua);
    REFLECT_VAR(prefabName);
    REFLECT_VAR(meshName);
    REFLECT_VAR(collision);
    REFLECT_VAR(extraCollisions);
    REFLECT_VAR(isUtil);
    REFLECT_VAR(isWalkable);
    REFLECT_VAR(forceMakeWalkable);
    REFLECT_DEFINE_END();

    REFLECT_DEFINE_BEGIN(GridCellDescLua_Collision);
    REFLECT_VAR(type);
    REFLECT_VAR(radius);
    REFLECT_VAR(height);
    REFLECT_VAR(size);
    REFLECT_VAR(center);
    REFLECT_DEFINE_END();

void GridSystem::Update() {
    navigation->Update();
}

bool NavigationGrid::PathExists(Vector2Int from, Vector2Int to) const {
    if (sizeX == 0) {
        return false;
    }
    //TODO some common method
    if (from.x < 0 || from.x >= sizeX || from.y < 0 || from.y >= sizeY ||
        to.x < 0 || to.x >= sizeX || to.y < 0 || to.y >= sizeY) {
        return false;
    }
    if (!IsWalkable(from.x, from.y) || !IsWalkable(to.x, to.y)) {
        return false;
    }
    int indexFrom = islandIndex[from.x * sizeX + from.y];
    int indexTo = islandIndex[to.x * sizeX + to.y];

    return indexFrom == indexTo;
}

GridPath NavigationGrid::CalcPath(Vector2Int from, Vector2Int to) const {
    GridPath path;
    path.from = from;
    path.to = to;

    if (sizeX == 0) {
        return path;
    }
    if (from.x < 0 || from.x >= sizeX || from.y < 0 || from.y >= sizeY ||
        to.x < 0 || to.x >= sizeX || to.y < 0 || to.y >= sizeY) {
        return path;
    }

    if (to == from) {
        path.isComplete = true;
        path.points.push_back(from);
        return path;
    }


    se::vector<float> costsApprox;
    costsApprox.resize(sizeX * sizeY, -1.f);

    se::vector<float> realCosts;
    realCosts.resize(sizeX * sizeY, -1.f);

    class Compare {
    public:
        int sizeX;
        int sizeY;
        se::vector<float>* costs;
        bool operator()(const Vector2Int& a, const Vector2Int& b) const
        {
            return (*costs)[a.x * sizeY + a.y] > (*costs)[b.x * sizeY + b.y];
        }
    };
    eastl::priority_queue<Vector2Int, eastl::vector<Vector2Int>, Compare> nextCellsToCheck;
    nextCellsToCheck.comp.sizeX = sizeX;
    nextCellsToCheck.comp.sizeY = sizeY;
    nextCellsToCheck.comp.costs = &costsApprox;

    auto approxCostFunc = [](Vector2Int from, Vector2Int to) {
        return Mathf::Abs(from.x - to.x) + Mathf::Abs(from.y - to.y);
    };

    constexpr int maxIterationsCount = 1000;
    int iterationsCount = 0;
    //TODO just use indices everywhere
    auto checkAndAddNewCell = [&](const Vector2Int& cell, float realCost) {
        if (cell.x < 0 || cell.x >= sizeX || cell.y < 0 || cell.y >= sizeY) {
            return;
        }
        int idx = cell.x * sizeY + cell.y;
        if (realCosts[idx] != -1.f) {
            //already added
            return;
        }
        if (!this->IsWalkable(cell.x, cell.y)) {
            return;
        }
        realCosts[idx] = realCost;
        costsApprox[idx] = realCost + approxCostFunc(to, cell);
        nextCellsToCheck.push(cell);
    };

    checkAndAddNewCell(from, 0);
    while (nextCellsToCheck.size() > 0) {
        Vector2Int cell;
        nextCellsToCheck.pop(cell);

        if (cell == to) {
            break;
        }
        iterationsCount++;
        if (iterationsCount >= maxIterationsCount) {
            continue;
        }
        float realCost = realCosts[cell.x * sizeY + cell.y];

        checkAndAddNewCell({ cell.x + 1, cell.y + 1 }, realCost + Mathf::sqrt2);
        checkAndAddNewCell({ cell.x - 1, cell.y - 1 }, realCost + Mathf::sqrt2);
        checkAndAddNewCell({ cell.x - 1, cell.y + 1 }, realCost + Mathf::sqrt2);
        checkAndAddNewCell({ cell.x + 1, cell.y - 1 }, realCost + Mathf::sqrt2);

        checkAndAddNewCell({ cell.x+1, cell.y }, realCost + 1.f);
        checkAndAddNewCell({ cell.x-1, cell.y }, realCost + 1.f);
        checkAndAddNewCell({ cell.x, cell.y+1 }, realCost + 1.f);
        checkAndAddNewCell({ cell.x, cell.y-1 }, realCost + 1.f);
    }

    if (realCosts[to.x * sizeY + to.y] == -1.f) {
        //path not found
        return path;
    }

    //backtracing path
    path.isComplete = true;
    Vector2Int currentCell = to;

    auto getCost = [&](const Vector2Int& cell) {
        if (cell.x < 0 || cell.x >= sizeX || cell.y < 0 || cell.y >= sizeY) {
            return FLT_MAX;
        }
        int idx = cell.x * sizeY + cell.y;
        if (realCosts[idx] != -1.f) {
            return realCosts[idx];
        }
        else {
            return FLT_MAX;
        }
    };

    float currentCellCost = realCosts[currentCell.x * sizeY + currentCell.y];
    const Vector2Int deltas[] = { {-1, -1}, {-1, 1}, {1, -1}, {1, 1}, {-1, 0}, {1, 0}, {0, 1}, {0, -1} };
    path.points.push_back(to);
    while (currentCell != from) {
        float minCost = currentCellCost;
        Vector2Int minCell = currentCell;
        for (const auto& delta : deltas) {
            Vector2Int cell = currentCell + delta;
            float cost = getCost(cell);
            if (cost < minCost) {
                minCost = cost;
                minCell = cell;
            }
        }
        ASSERT(minCell != currentCell);

        currentCellCost = minCost;
        currentCell = minCell;
        path.points.push_back(currentCell);
    }

    eastl::reverse(path.points.begin(), path.points.end());

    return path;
}

void NavigationGrid::UpdateIslands() {
    //TODO just use ints instead of x,y
    this->islandIndex.clear();
    this->islandIndex.resize(sizeX * sizeY, 0);
    int nextFreeIndex = 1;

    auto floodFill = [&](int islandIndex, int x, int y) {
        se::vector<Vector2Int> toVisit;

        auto visit = [&](Vector2Int pos) {
            if (pos.x < 0 || pos.x >= sizeX || pos.y < 0 || pos.y >= sizeY) {
                return;
            }

            int index = pos.x * sizeY + pos.y;
            if (this->islandIndex[index] == 0 && this->walkableCells[index]) {
                this->islandIndex[index] = islandIndex;
                toVisit.push_back(pos);
            }
        };
        visit(Vector2Int(x, y));
        while (toVisit.size() > 0) {
            Vector2Int pos = toVisit.back();
            toVisit.pop_back();

            visit(pos + Vector2Int(0, 1));
            visit(pos + Vector2Int(0, -1));
            visit(pos + Vector2Int(-1, 0));
            visit(pos + Vector2Int(1, 0));

            visit(pos + Vector2Int(-1, -1));
            visit(pos + Vector2Int(-1, 1));
            visit(pos + Vector2Int(1, -1));
            visit(pos + Vector2Int(1, 1));
        }
    };

    for (int x = 0; x < sizeX; x++) {
        for (int y = 0; y < sizeY; y++) {
            int index = x * sizeY + y;
            if (walkableCells[index] && islandIndex[index] == 0) {
                floodFill(nextFreeIndex++, x, y);
            }
        }
    }
}

void NavigationGrid::Update() {
    //TODO separate init method
    sourceGrids = GridSystem::Get()->grids;
    int newSizeX = -1;
    int newSizeY = -1;
    for (auto grid : this->sourceGrids) {
        if (newSizeX == -1) {
            newSizeX = grid->sizeX;
            newSizeY = grid->sizeY;
        }
        else {
            ASSERT(newSizeX == grid->sizeX);
            ASSERT(newSizeY == grid->sizeY);
        }
    }
    
    if (newSizeX != sizeX || newSizeY != sizeY) {
        this->sizeX = newSizeX;
        this->sizeY = newSizeY;
        this->walkableCells.clear();
        this->walkableCells.resize(sizeX * sizeY);
        this->islandIndex.clear();
        this->islandIndex.resize(sizeX * sizeY);

        for (int x = 0; x < sizeX; x++) {
            for (int y = 0; y < sizeY; y++) {
                this->walkableCells[x * sizeY + y] = CalcIsWalkable(x, y);
            }
        }
        UpdateIslands();
        return;
    }

    bool hasChanges = false;
    for (auto g : sourceGrids) {
        for (auto i : g->changedIndices) {
            int x = i / sizeY;
            int y = i % sizeX;
            bool wasWalkable = this->walkableCells[i];
            this->walkableCells[i] = CalcIsWalkable(x, y);
            if (!hasChanges && this->walkableCells[i] != wasWalkable) {
                hasChanges = true;
            }
        }
    }

    if (hasChanges) {
        //TODO way to not fully update them with each update
        UpdateIslands();
    }
}

se::shared_ptr<NavigationGrid> GridSystem::GetNavigation() const {
    return navigation;
}

bool NavigationGrid::CalcIsWalkable(int x, int y) const {
    WalkableType result = WalkableType::WALKABLE;
    for (auto g : sourceGrids) {
        auto type = (GridCellType)(g->GetCell({ x,y }).type);
        const auto& desc = GridSystem::Get()->GetDesc(type);
        auto walkableType = desc.walkableType;
        switch (walkableType)
        {
        case WalkableType::NOT_WALKABLE:
            if (result == WalkableType::WALKABLE) {
                result = WalkableType::NOT_WALKABLE;
            }
            break;
        case WalkableType::WALKABLE:

            break;
        case WalkableType::FORCE_MAKE_WALKABLE:
            result = WalkableType::FORCE_MAKE_WALKABLE;
            break;
        default:
            ASSERT(false);
            break;
        }
    }
    return result != WalkableType::NOT_WALKABLE;
}

bool NavigationGrid::IsWalkable(int x, int y) const {
    if (x >= 0 && x < sizeX && y >= 0 && y < sizeY) {
        return this->walkableCells[x * sizeY + y];
    }
    return false;
}

GridCellIterator::GridCellIterator(CheckFunc checkFunc, Grid* grid) :checkFunc(checkFunc), grid(grid), totalSize(grid->sizeX* grid->sizeY) {}

bool GridCellIterator::GetNextCell(GridCell& outCell) {
    ASSERT(grid);
    ASSERT(checkFunc);
    for (; nextCellIdx < totalSize;) {
        const GridCell& cell = grid->cells[nextCellIdx++];
        if (checkFunc(cell)) {
            outCell = cell;
            return true;
        }
    }
    return false;
}

GridCellIterator Grid::GetTypeIterator(int cellType) {
    return GridCellIterator([cellType](const GridCell& cell) 
        { 
            return cell.type == cellType; 
        }, this);
}

GridCellIterator Grid::GetTypeWithAnimIterator(int cellType, int animType) {
    return GridCellIterator([cellType, animType](const GridCell& cell) { return cell.type == cellType && cell.animType == animType; }, this);
}

GridCellIterator Grid::GetAnimatedCellsIterator() {
    return GridCellIterator([](const GridCell& cell) { return cell.animType > (int)GridCellAnimType::NONE; }, this);
}


se::shared_ptr<Grid> GridSystem::GetGrid(const se::string& name) const {
    for (auto grid : grids) {
        if (grid->gameObject()->tag == name) {
            return grid;
        }
    }
    return nullptr;
}

template<typename T>
static void Unique(se::vector<T>& v) {
    if (v.size() < 2) {
        return;
    }
    int i1 = 0;
    int i2 = 1;
    for (; i2 < v.size();i2++) {
        if (v[i1] != v[i2]) {
            v[i1+1] = v[i2];
            i1++;
        }
    }
    v.resize(i1+1);
}

void Grid::Update() {
    OPTICK_EVENT();
    //TODO ensure this is happening before everything else
    ASSERT(this->cellsPrev.size() == this->cells.size());
    ASSERT(this->cellsLocalMatricesPrev.size() == this->cellsLocalMatrices.size());

    eastl::sort(changedIndices.begin(), changedIndices.end());
    Unique(changedIndices);

    auto gc = gameObject()->GetComponent<GridCollider>();
    if (gc) {
        gc->_Update();
    }
    auto gd = gameObject()->GetComponent<GridDrawer>();
    if (gd) {
        gd->_Update();
    }
    
    bool a = false;
    if (a) {
        {
            OPTICK_EVENT("update cellsLocalMatricesPrev");
            int matricesSize = sizeof(Matrix4) * this->cellsLocalMatricesPrev.size();
            memcpy(this->cellsLocalMatricesPrev.data(), this->cellsLocalMatrices.data(), matricesSize);
        }

        {
            OPTICK_EVENT("update cellsPrev");
            int cellsSize = sizeof(GridCell) * this->cells.size();
            memcpy(this->cellsPrev.data(), this->cells.data(), cellsSize);
        }
    }
    else {
        for (int i : changedIndices) {
            cellsPrev[i] = cells[i];
            cellsLocalMatricesPrev[i] = cellsLocalMatrices[i];
        }
    }
    changedIndices.clear();
}

void GridCollider::_Update() {
    OPTICK_EVENT();
    auto grid = gameObject()->GetComponent<Grid>();
    if (grid == nullptr) {
        LogError("no Grid with GridCollider");
        return;
    }
    if (!chunkPrefab) {
        LogError("no ChunkPrefab set in GridCollider");
        return;
    }
    if (lastModificationsCount == grid->GetTypeModificationsCount()) {
        return;
    }
    bool fullUpdate = false;
    if (chunks.size() != grid->chunksCountX * grid->chunksCountY || lastFullyClearedCount != grid->GetFullyClearedCount()) {
        fullUpdate = true;
        lastFullyClearedCount = grid->GetFullyClearedCount();
        for (auto c : chunks) {
            gameObject()->GetScene()->RemoveGameObject(c->gameObject());
        }
        chunks.clear();
        for (int iX = 0; iX < grid->chunksCountX; iX++) {
            for (int iY = 0; iY < grid->chunksCountY; iY++) {
                auto go = Instantiate(chunkPrefab);
                gameObject()->GetScene()->AddGameObject(go);
                chunks.push_back(go->GetComponent<GridChunkCollider>());
            }
        }
        ASSERT(grid->changedIndices.size() == grid->cells.size());
    }
    lastModificationsCount = grid->GetTypeModificationsCount();
    auto gridSystem = GridSystem::Get();

    for (auto chunk : chunks) {
        if (chunk->gridColliders.size() != grid->cellsPerChunkX * grid->cellsPerChunkY) {
            //TODO grid cells are only updated if cellsPrev differ
            for (auto colliders : chunk->gridColliders) {
                for (auto collider : colliders) {
                    gameObject()->RemoveComponent(collider);
                }
            }
            chunk->gridColliders.clear();
            chunk->gridColliders.resize(grid->cellsPerChunkX * grid->cellsPerChunkY, {});
        }
    }
    for (int i : grid->changedIndices) {
        const auto& cell = grid->cells[i];
        const auto& cellPrev = grid->cellsPrev[i];
        if (cellPrev.type == cell.type && !fullUpdate) {
            //TODO check location
            continue;
        }
        int iChunk = grid->GetChunkIndex(cell.pos);
        auto& chunk = chunks[iChunk];
        int iInChunk = grid->GetIndexInChunk(cell.pos);
        if (chunk) {
            for(auto& collider : chunk->gridColliders[iInChunk]){
                chunk->gameObject()->RemoveComponent(collider);
            }
            chunk->gridColliders[iInChunk].clear();
            chunk->changed = true;
        }
        
        const auto& desc = gridSystem->GetDesc((GridCellType)cell.type);
        for (const auto& collision : desc.luaDesc.allCollisions) {
            se::shared_ptr<Collider> colliderCurrent;
            if (collision.type == (int)GridCellCollisionType::SPHERE_COLLIDER) {
                auto collider = se::make_shared<SphereCollider>();
                collider->radius = collision.radius;
                collider->center = grid->GetCellWorldCenter(cell.pos) + collision.center;
                colliderCurrent = collider;
            }
            else if (collision.type == (int)GridCellCollisionType::CAPSULE_COLLIDER) {
                auto collider = se::make_shared<CapsuleCollider>();
                collider->radius = collision.radius;
                collider->height = collision.height;
                collider->center = grid->GetCellWorldCenter(cell.pos) + collision.center;
                colliderCurrent = collider;
            }
            else if (collision.type == (int)GridCellCollisionType::BOX_COLLIDER) {
                auto collider = se::make_shared<BoxCollider>();
                collider->size = collision.size;
                collider->center = grid->GetCellWorldCenter(cell.pos) + collision.center;
                colliderCurrent = collider;
            }
            if (colliderCurrent) {
                chunk->gridColliders[iInChunk].push_back(colliderCurrent);
                chunk->gameObject()->AddComponent(colliderCurrent);
                chunk->changed = true;

            }
        }
    }
    for (auto c : chunks) {
        if (!c->changed) {
            continue;
        }
        auto rb = c->gameObject()->GetComponent<RigidBody>();
        rb->SetEnabled(false);
        rb->SetEnabled(true);
        c->changed = false;
    }
}
void GridDrawer::OnEnable() {
}

void GridDrawer::OnDisable() {
    //for (auto& r : pooledRenderers) {
    //    r.OnDisable();
    //}
    for (auto& irs : instancedMeshRenderers) {
        for (auto& ir : irs.second) {
            ir.second->Term();
            delete ir.second;
        }
    }
    instancedMeshRenderers.clear();
    instanceIndices.clear();
    //pooledRenderers.clear();
}

int Grid::GetIndexInChunk(const Vector2Int& pos) const {
    return pos.x % cellsPerChunkX + (pos.y % cellsPerChunkY) * cellsPerChunkX;
}

int Grid::GetChunkIndex(const Vector2Int& pos) const {
    return pos.x / cellsPerChunkX + pos.y / cellsPerChunkY * chunksCountX;
}


// TODO on before camera render actually
void GridDrawer::_Update() {
    OPTICK_EVENT();
    auto grid = gameObject()->GetComponent<Grid>();
    if (grid == nullptr) {
        LogError("no Grid with gridDrawer");
        return;
    }
    if (lastModificationsCount == grid->GetModificationsCount()) {
        ASSERT(lastFullyClearedCount == grid->GetFullyClearedCount());
        return;
    }
    lastModificationsCount = grid->GetModificationsCount();
    auto gridSystem = GridSystem::Get();
    auto prefabRenderer = gridCellPrefab->GetComponent<MeshRenderer>();
    //while (pooledRenderers.size() < grid->cells.size()) {
    //    pooledRenderers.emplace_back(prefabRenderer->mesh, prefabRenderer->material);
    //}
    // TODO remove extra

    //for (auto& ir : instancedMeshRenderers) {
        //ir.second->Clear();
    //}
    auto scene = gameObject()->GetScene();

    bool isFullUpdate = false;
    if (instanceIndices.size() != grid->cells.size() || lastFullyClearedCount != grid->GetFullyClearedCount()) {
        isFullUpdate = true;
        lastFullyClearedCount = grid->GetFullyClearedCount();
        for (auto& go : gameObjects) {
            if (go) {
                scene->RemoveGameObject(go);
            }
        }
        gameObjects.clear();

        for (auto& irs : instancedMeshRenderers) {
            for (auto& ir : irs.second) {
                ir.second->Clear();
            }
        }
        instanceIndices.clear();
        instanceIndices.resize(grid->cells.size(), -1);
        
        //TODO not exacly if have repeating indices
        ASSERT(grid->changedIndices.size() == grid->cells.size());
    }

    for (int i : grid->changedIndices) {
        const auto& cell = grid->cells[i];
        const auto& cellPrev = grid->cellsPrev[i];
        const auto& cellLocalMatrix = grid->cellsLocalMatrices[i];
        const auto& cellLocalMatrixPrev = grid->cellsLocalMatricesPrev[i];
        if (cell.type == cellPrev.type && cellLocalMatrix == cellLocalMatrixPrev && !isFullUpdate) {
            continue;
        }

        int chunkIndex = grid->GetChunkIndex(cell.pos);
        auto& instancedMeshRenderers = this->instancedMeshRenderers[chunkIndex];
        if (cell.type != cellPrev.type && cellPrev.type != (int)GridCellType::NONE) {
            int prevIndex = instanceIndices[i];
            if (prevIndex != -1) {
                InstancedMeshRenderer* irPrev = nullptr;

                auto it2 = instancedMeshRenderers.find((GridCellType)cellPrev.type);
                if (it2 != instancedMeshRenderers.end()) {
                    irPrev = it2->second;
                    irPrev->RemoveInstance(prevIndex);
                }
                else {
                    const auto& desc = gridSystem->GetDesc((GridCellType)cellPrev.type);
                    if (desc.prefab) {
                        //TODO
                        scene->RemoveGameObject(gameObjects[prevIndex]);
                        gameObjects[prevIndex] = nullptr;
                    }
                    //nothing to do
                }
                instanceIndices[i] = -1;
            }
        }
        if (cell.type == (int)GridCellType::NONE) {
            continue;
        }
        InstancedMeshRenderer* ir = nullptr;
        auto it = instancedMeshRenderers.find((GridCellType)cell.type);
        if (it != instancedMeshRenderers.end()) {
            ir = it->second;
        }
        else {
            const auto& desc = gridSystem->GetDesc((GridCellType)cell.type);
            if (desc.prefab) {
                auto matrix = grid->cellsLocalMatrices[i];
                matrix.GetColumn(3) += Vector4(grid->GetCellWorldCenter(cell), 0);
                se::shared_ptr<GameObject> go;
                if (cell.type == cellPrev.type && !isFullUpdate) {
                    go = gameObjects[instanceIndices[i]];
                    go->transform()->SetMatrix(matrix);
                }
                else {
                    go = Instantiate(desc.prefab);
                    int index = -1;
                    for (int j = 0; j < gameObjects.size(); j++) {
                        if (gameObjects[j] == nullptr) {
                            index = j;
                        }
                    }
                    if (index == -1) {
                        index = gameObjects.size();
                        gameObjects.push_back(nullptr);
                    }
                    gameObjects[index] = go;
                    instanceIndices[i] = index;
                    go->transform()->SetMatrix(matrix);
                    scene->AddGameObject(go);
                }
                continue;
            }
            ir = new InstancedMeshRenderer();
            ir->mesh = desc.mesh;
            ir->material = prefabRenderer->material;
            ir->Init(gameObject()->GetScene());
            ir->SetFrustumCullingEnabled(this->useFrustumCulling);
            ir->SetCastShadowsEnabled(this->castsShadows);
            instancedMeshRenderers[(GridCellType)cell.type] = ir;
        }
        InstancedMeshRenderer::InstanceInfo* instance;
        if (cell.type == cellPrev.type && !isFullUpdate) {
            instance = &ir->GetInstanceByIndex(instanceIndices[i]);
            //instance->transform = grid->cellsLocalMatrices[i];
            instance->transform = Matrix4::ToAffineTransform(grid->cellsLocalMatrices[i]);
        }
        else {
            instance = &ir->EmplaceBackOutIndex(instanceIndices[i], Matrix4::ToAffineTransform(grid->cellsLocalMatrices[i]));
        }
        Vector3 offset = grid->GetCellWorldCenter(cell);
        SetPos(instance->transform, GetPos(instance->transform) + offset);
    }
}
void GridDrawer::OnValidate() {
    for (auto& irs : this->instancedMeshRenderers) {
        for (auto& ir : irs.second) {
            ir.second->SetFrustumCullingEnabled(this->useFrustumCulling);
            ir.second->SetCastShadowsEnabled(this->castsShadows);
        }
    }
}

const GridCellDesc& GridSystem::GetDesc(GridCellType type) const {
    auto it = settings->cellDescs.find(type);
    if (it != settings->cellDescs.end()) {
        return it->second;
    }
    //TODO adding desc in a const getter + returning everything by ref is a really really bad idea
    //but I am a comment and not a cop so go on
    settings->cellDescs[type] = GridCellDesc( type, "UnknownType", defaultMesh );
    return GetDesc(type);
}

void Grid::OnEnable() {
    GridSystem::Get()->grids.push_back(Component::ToShared(this));


    if (!isInited) {
        SetSize(sizeX, sizeY);
    }
    else {
        ASSERT(cells.size() == sizeX * sizeY);
        ASSERT(cellsLocalMatrices.size() == sizeX * sizeY);
    }
    chunksCountX = ((sizeX + cellsPerChunkX - 1) / cellsPerChunkX);
    chunksCountY = ((sizeY + cellsPerChunkY - 1) / cellsPerChunkY);

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
    cellsPrev = cells;

    cellsLocalMatrices.clear();
    cellsLocalMatrices.resize(sizeX * sizeY, Matrix4::Identity());
    cellsLocalMatricesPrev = cellsLocalMatrices;

    chunksCountX = ((sizeX + cellsPerChunkX - 1) / cellsPerChunkX);
    chunksCountY = ((sizeY + cellsPerChunkY - 1) / cellsPerChunkY);

    changedIndices.clear();
    for (int i = 0; i < cells.size(); i++) {
        changedIndices.push_back(i);
    }
    fullyClearedCount++;//TODO not only here?
}

void Grid::OnDisable() {
    auto& grids = GridSystem::Get()->grids;
    grids.erase(eastl::find_if(grids.begin(), grids.end(), [this](auto x) { return x.get() == this; }));
}

bool GridSystem::Init() {

    settings = AssetDatabase::Get()->Load<GridSettings>("grid.asset");  // TODO make visible from inspector

    if (!settings) {
        return false;
    }

    navigation = se::make_shared<NavigationGrid>();

    this->onAfterLuaReloaded = LuaSystem::Get()->onAfterScriptsReloading.Subscribe([this]() { LoadCellTypes(); });
    this->onAfterAssetDatabaseReloaded = AssetDatabase::Get()->onLoadPersistentAssetsRequest.Subscribe([this]() {LoadCellTypes(); });
    LoadCellTypes();

    return true;
}

void GridSystem::Term() {
    AssetDatabase::Get()->onLoadPersistentAssetsRequest.Unsubscribe(this->onAfterAssetDatabaseReloaded);

    settings = nullptr;
}

//TODO move out of here
static int   Stricmp(const char* str1, const char* str2)         { int d; while ((d = toupper(*str2) - toupper(*str1)) == 0 && *str1) { str1++; str2++; } return d; }

void GridSystem::LoadCellTypes() {
    auto* LuaSystem = LuaSystem::Get();
    LuaSystem->PushModule("CellTypeDesc");
    LuaSystem->PushModule("CellType");
    auto* L = LuaSystem->L;
    if (lua_isnil(L, -1)) {
        lua_pop(L, 2);
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
    int isize = sizeof(SerializationContext);

    this->defaultMesh = nullptr;
    ASSERT(this->settings->mesh);
    for (auto mesh : this->settings->mesh->meshes) {
        if (Stricmp(mesh->name.c_str(), "unknown") == 0) {
            this->defaultMesh = mesh;
            break;
        }
    }

    this->cellTypeAny = -1;

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

        if (c == se::string("Any")) {
            ASSERT(this->cellTypeAny == -1);
            this->cellTypeAny = i;
        }

        //no mesh for util
        se::string meshName = c;
        se::shared_ptr<Mesh> cellMesh = this->defaultMesh;
        if (!luaDesc.meshName.empty()) {
            meshName = luaDesc.meshName;
        }
        if (luaDesc.isUtil) {
            meshName = "None";
            cellMesh = nullptr;
        }
        else {
            se::string_utils::ToLowerInplace(meshName);
            if (meshName.size() > 0) {
                meshName[0] = std::toupper(meshName[0]);
            }
            for (auto mesh : this->settings->mesh->meshes) {
                if (Stricmp(mesh->name.c_str(), meshName.c_str()) == 0) {
                    cellMesh = mesh;
                    break;
                }
            }
            if (cellMesh == this->defaultMesh) {
                LogError("No mesh found for cell type '%s'", c.c_str());
            }
        }
        se::shared_ptr<GameObject> prefab;
        if (!luaDesc.prefabName.empty()) {
            prefab = AssetDatabase::Get()->Load<GameObject>(luaDesc.prefabName);
            if (!prefab) {
                LogWarning("Failed to find prefab '%s' for cellType '%s'", luaDesc.prefabName.c_str(), c.c_str());
            }
        }

        this->settings->cellDescs[(GridCellType)i] = GridCellDesc((GridCellType)i, meshName, cellMesh, luaDesc, prefab,
                                 luaDesc.forceMakeWalkable ? WalkableType::FORCE_MAKE_WALKABLE : (luaDesc.isWalkable ? WalkableType::WALKABLE : WalkableType::NOT_WALKABLE));
    }
    lua_pop(L, 2);

    ASSERT(this->cellTypeAny != -1);
}


Vector3 Grid::GetCellWorldCenter(const Vector2Int& pos) const {
    auto cell = GetCell(pos);
    return Vector3{ float(cell.pos.x), cell.z, float(cell.pos.y) };
}

Vector2Int Grid::GetClosestIntPos(const Vector3& worldPos) {
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
        int index = cell.pos.x * sizeY + cell.pos.y;
        const auto& prevCell = cells[index];
        if (prevCell.type != cell.type) {
            typeModificationsCount++;
        }
        cells[index] = cell;
        changedIndices.push_back(index);
        modificationsCount++;
    }
}

void Grid::SetCellLocalMatrix(const Vector2Int& pos, const Matrix4& matrix) {
    if (pos.x >= 0 && pos.x < sizeX && pos.y >= 0 && pos.y < sizeY) {
        int index = pos.x * sizeY + pos.y;
        cellsLocalMatrices[index] = matrix;
        changedIndices.push_back(index);
        modificationsCount++;//TODO callback to update single instance matrix
    }
}

se::shared_ptr<Mesh> GridSystem::GetMeshByCellType(int cellType) const {
    return GetDesc((GridCellType)cellType).mesh;
}


void Grid::GetCellOut(GridCell& outCell, Vector2Int pos) const {
    outCell = GetCell(pos);
}

template<class CheckFunc>
static bool FindNearestPosWithPredecate(Vector2Int& outPos, const Vector2Int& originPos, int minRadius, int maxRadius, CheckFunc checkFunc)
{
    OPTICK_EVENT();
    minRadius = Mathf::Max(0, minRadius);
    if (minRadius == 0 && checkFunc(originPos)) {
        outPos = originPos;
        return true;
    }
    if (maxRadius < minRadius) {
        return false;
    }

    //PERF try quadtree in emergency situation
    int max_count = (maxRadius * 2 + 1) * (maxRadius * 2 + 1);

    Vector2Int current_pos = originPos;
    int current_radius = 1;
    int t = 1;

    //TODO check that it works
    int deltaStartRadius = Mathf::Max(0, minRadius-1);
    current_radius += deltaStartRadius;
    t += (minRadius - 1) * 2;
    current_pos.x -= deltaStartRadius;
    current_pos.y += deltaStartRadius;

    if (minRadius > 0 && current_radius <= maxRadius) {
        current_pos.y -= t;
        if (checkFunc(current_pos)) {
            outPos = current_pos;
            return true;
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
    //finish line
    for (int i = 0; i < t-1; i++) {
        current_pos.y -= 1;
        if (checkFunc(current_pos)) {
            outPos = current_pos;
            return true;
        }
    }

    return false;
}

bool GridSystem::FindNearestWalkable(Vector2Int& outPos, const Vector2Int& originPos, int maxRadius) const
{
    return FindNearestPosWithPredecate(outPos, originPos, 0, maxRadius, [this](const Vector2Int& pos) {
        return navigation->IsWalkable(pos.x, pos.y);
        });
}

bool GridSystem::FindNearestPosWithTypes(Vector2Int& outPos, const Vector2Int& originPos, int minRadius, int maxRadius, int itemType, int groundType, int markingType) const
{
    auto* itemsGrid = this->GetGrid("ItemsGrid").get();
    auto* groundGrid = this->GetGrid("GroundGrid").get();
    auto* markingsGrid = this->GetGrid("MarkingsGrid").get();

    ASSERT(itemsGrid && groundGrid && markingsGrid);
    if (groundType == cellTypeAny && markingType == cellTypeAny && itemType == cellTypeAny) {
        //TODO warning or assert
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [itemsGrid, itemType, this](const Vector2Int& pos) {
            return true;
            });
    }
    else if (groundType != cellTypeAny && markingType != cellTypeAny && itemType != cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return itemsGrid->GetCell(pos).type == itemType && groundGrid->GetCell(pos).type == groundType && markingsGrid->GetCell(pos).type == markingType;
            });
    }
    else if (groundType == cellTypeAny && markingType != cellTypeAny && itemType != cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return itemsGrid->GetCell(pos).type == itemType && markingsGrid->GetCell(pos).type == markingType;
            });
    }
    else if (groundType != cellTypeAny && markingType == cellTypeAny && itemType != cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return itemsGrid->GetCell(pos).type == itemType && groundGrid->GetCell(pos).type == groundType;
            });
    }
    else if (groundType != cellTypeAny && markingType != cellTypeAny && itemType == cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return groundGrid->GetCell(pos).type == groundType && markingsGrid->GetCell(pos).type == markingType;
            });
    }
    else if (groundType == cellTypeAny && markingType == cellTypeAny && itemType != cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return itemsGrid->GetCell(pos).type == itemType;
            });
    }
    else if (groundType == cellTypeAny && markingType != cellTypeAny && itemType == cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return markingsGrid->GetCell(pos).type == markingType;
            });
    }
    else if (groundType != cellTypeAny && markingType == cellTypeAny && itemType == cellTypeAny) {
        return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [&](const Vector2Int& pos) {
            return groundGrid->GetCell(pos).type == groundType;
            });
    }
    ASSERT(false);
    return false;
}

bool Grid::FindNearestPosWithType(Vector2Int& outPos, const Vector2Int& originPos, int minRadius, int maxRadius, int itemType) const {
    return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [this, itemType](const Vector2Int& pos) {return GetCell(pos).type == itemType; });
}


bool Grid::DbgDrawRad(const Vector2Int& originPos, int minRadius, int maxRadius) const {
    Vector2Int outPos;
    return FindNearestPosWithPredecate(outPos, originPos, minRadius, maxRadius, [this](const Vector2Int& pos) {Dbg::Draw(Sphere(GetCellWorldCenter(pos), 0.1f)); return false; });
}


//TODO move all base64 stuff out of here
static const se::string base64_chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789+/";

static inline bool is_base64(unsigned char c) {
    return (isalnum(c) || (c == '+') || (c == '/'));
}

static se::string base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len) {
    se::string   ret;
    int           i = 0;
    int           j = 0;
    unsigned char char_array_3[3];
    unsigned char char_array_4[4];

    while (in_len--) {
        char_array_3[i++] = *(bytes_to_encode++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for (i = 0; (i < 4); i++)
                ret.append(base64_chars[char_array_4[i]]);
            i = 0;
        }
    }

    if (i) {
        for (j = i; j < 3; j++)
            char_array_3[j] = '\0';

        char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);

        for (j = 0; (j < i + 1); j++)
            ret.append(base64_chars[char_array_4[j]]);

        while ((i++ < 3))
            ret.append('=');
    }

    return ret;
}

static se::string base64_decode(se::string const& encoded_string) {
    int           in_len = static_cast<int>(encoded_string.size());
    int           i      = 0;
    int           j      = 0;
    int           in_    = 0;
    unsigned char char_array_4[4], char_array_3[3];
    se::string   ret;

    while (in_len-- && (encoded_string[in_] != '=') && is_base64(encoded_string[in_])) {
        char_array_4[i++] = encoded_string[in_];
        in_++;
        if (i == 4) {
            for (i = 0; i < 4; i++)
                char_array_4[i] = static_cast<unsigned char>(se::string_view(base64_chars.c_str()).find(char_array_4[i]));

            char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
            char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
            char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

            for (i = 0; (i < 3); i++)
                ret.append(char_array_3[i]);
            i = 0;
        }
    }

    if (i) {
        for (j = i; j < 4; j++)
            char_array_4[j] = 0;

        for (j = 0; j < 4; j++)
            char_array_4[j] = static_cast<unsigned char>(se::string_view(base64_chars.c_str()).find(char_array_4[j]));

        char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
        char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
        char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

        for (j = 0; (j < i - 1); j++)
            ret.append(char_array_3[j]);
    }

    return ret;
}

void Grid::SerializeGrid(SerializationContext& context, const Grid& grid)
{
    ::Serialize(context.Child("sizeX"), grid.sizeX);
    ::Serialize(context.Child("sizeY"), grid.sizeY);
    ::Serialize(context.Child("isInited"), grid.isInited);
    
    // c4::cblob blob;
    // blob.buf = (c4::cbyte*)grid.cells.data();
    // blob.len = grid.cells.size() * sizeof(decltype(grid.cells)::value_type);
    // se::string buffer = se::string(((4 * blob.len / 3) + 3) & ~3, '\0');
    // c4::substr bufferSubstr(buffer.data(), buffer.size());
    auto buffer = base64_encode((unsigned char const*)grid.cells.data(), grid.cells.size() * sizeof(decltype(grid.cells)::value_type));
    // TODO ASSERT(size == buffer.length());

    context.Child("cells") << buffer;
}

void Grid::DeserializeGrid(const SerializationContext& context, Grid& grid)
{
    ::Deserialize(context.Child("sizeX"), grid.sizeX);
    ::Deserialize(context.Child("sizeY"), grid.sizeY);
    ::Deserialize(context.Child("isInited"), grid.isInited);

    if (grid.isInited) {
        se::string cellsBase64;
        ::Deserialize(context.Child("cells"), cellsBase64);

        grid.SetSize(grid.sizeX, grid.sizeY);

        auto str = base64_decode(cellsBase64);
        auto size = str.size();
        ASSERT(size == grid.cells.size() * sizeof(decltype(grid.cells)::value_type));
        memcpy(grid.cells.data(), str.c_str(), grid.cells.size() * sizeof(decltype(grid.cells)::value_type));
    }

}
void Grid::LoadFrom(const Grid& otherGrid) {
    OnDisable();
    
    this->SetSize(otherGrid.sizeX, otherGrid.sizeY);
    this->cells = otherGrid.cells;
    this->cellsPrev = otherGrid.cells;
    this->cellsLocalMatrices = otherGrid.cellsLocalMatrices;
    this->cellsLocalMatricesPrev = otherGrid.cellsLocalMatrices;
    this->isInited = otherGrid.isInited;
    this->modificationsCount++;
    this->typeModificationsCount++;

    OnEnable();
}
