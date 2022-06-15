#include "Grid.h"
#include "GameObject.h"
#include "Scene.h"

DECLARE_TEXT_ASSET(Grid);
DECLARE_TEXT_ASSET(GridDrawer);

Grid* Grid::mainGrid = nullptr;

void GridDrawer::OnEnable() {
	grid = gameObject()->GetComponent<Grid>();
}

void GridDrawer::OnDisable() {
	for (auto& r : pooledRenderers) {
		Scene::Get()->RemoveGameObject(r->gameObject());
	}
	pooledRenderers.clear();
}

//TODO on before camera render actually
void GridDrawer::Update() {
	while (pooledRenderers.size() < grid->cells.size()) {
		auto cell = Instantiate(gridCellPrefab);
		Scene::Get()->AddGameObjectImmediately(cell);
		pooledRenderers.push_back(cell->GetComponent<MeshRenderer>());
	}
	//TODO remove extra

	for (int i = 0; i < grid->cells.size(); i++) {
		const auto& cell = grid->cells[i];
		auto& renderer = pooledRenderers[i];

		const auto& name = grid->GetDesc(cell.type).meshName;

		renderer->mesh = nullptr;
		renderer->m_transform->SetPosition(grid->GetCellWorldCenter(cell.pos));
		for (const auto& mesh : grid->mesh->meshes) {
			if (mesh->name == name) {
				renderer->mesh = mesh;
				break;
			}
		}
	}
}

const GridCellDesc& Grid::GetDesc(GridCellType type) const {
	for (const auto& desc : cellDescs) {
		if (desc.type == type) {
			return desc;
		}
	}
	static const GridCellDesc emptyDesc{};
	return emptyDesc;
}

void Grid::OnEnable() {
	mainGrid = this;
	
	int sizeX = 20;
	int sizeY = 20;

	for (int x = 0; x < sizeX; x++) {
		for (int y = 0; y < sizeY; y++) {
			auto& cell = cells.emplace_back();
			cell.pos.x = x;
			cell.pos.y = y;
			cell.type = GridCellType::GROUND;
		}
	}
}

void Grid::OnDisable() {
	mainGrid = nullptr;
}

Vector3 Grid::GetCellWorldCenter(const Vector2Int& cell) const {
	return Vector3{ float(cell.x), 0.0f, float(cell.y) };
}
