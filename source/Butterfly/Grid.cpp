#include "Grid.h"
#include "GameObject.h"
#include "Scene.h"
#include "Asserts.h"
#include "LuaReflect.h"
#include "LuaSystem.h"
#include "Resources.h"
#include "../../engine/source/libs/luau/VM/src/ltable.h"

DECLARE_TEXT_ASSET(Grid);
DECLARE_TEXT_ASSET(GridSettings);
REGISTER_GAME_SYSTEM(Grid);
DECLARE_TEXT_ASSET(GridDrawer);

void GridDrawer::OnEnable() {
}

void GridDrawer::OnDisable() {
	for (auto& r : pooledRenderers) {
		r.OnDisable();
	}
	pooledRenderers.clear();
}


//TODO on before camera render actually
void GridDrawer::Update() {
	auto* grid = Grid::Get();
	auto prefabRenderer = gridCellPrefab->GetComponent <MeshRenderer>();
	while (pooledRenderers.size() < grid->cells.size()) {
		pooledRenderers.emplace_back(prefabRenderer->mesh, prefabRenderer->material);
	}
	//TODO remove extra

	for (int i = 0; i < grid->cells.size(); i++) {
		const auto& cell = grid->cells[i];
		auto& renderer = pooledRenderers[i];

		const auto& name = grid->GetDesc((GridCellType)cell.type).meshName;

		renderer.mesh = nullptr;
		renderer.m_transform->SetPosition(grid->GetCellWorldCenter(cell.pos));
		for (const auto& mesh : grid->settings->mesh->meshes) {
			if (mesh->name == name) {
				renderer.mesh = mesh;
				//HACK to add to renderers list
				renderer.OnDisable();
				renderer.OnEnable();
				break;
			}
		}
	}
}

const GridCellDesc& Grid::GetDesc(GridCellType type) const {
	for (const auto& desc : settings->cellDescs) {
		if (desc.type == type) {
			return desc;
		}
	}
	static const GridCellDesc emptyDesc{};
	return emptyDesc;
}

bool Grid::Init() {
	auto L = LuaSystem::Get()->L;

	Luna::RegisterShared<Grid>(L);
	Luna::Register<GridCell>(L);


	for (int x = 0; x < sizeX; x++) {
		for (int y = 0; y < sizeY; y++) {
			auto& cell = cells.emplace_back();
			cell.pos.x = x;
			cell.pos.y = y;
			cell.type = (int)GridCellType::GROUND;
		}
	}

	settings = AssetDatabase::Get()->Load<GridSettings>("grid.asset");//TODO make visible from inspector

	if (!settings) {
		return false;
	}
	return true;
}

void Grid::Term() {
	settings = nullptr;
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
	}
}