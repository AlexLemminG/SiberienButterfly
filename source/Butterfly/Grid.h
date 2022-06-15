#pragma once

#include "Component.h"
#include "Mesh.h"
#include "MeshRenderer.h"

enum GridCellType
{
	NONE,
	GROUND
};
REFLECT_ENUM(GridCellType);


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
	GridCellType type;
	Vector2Int pos; // TODO only for intermediate form
};

class Grid : public Component{
public:
	static Grid* Get() { return mainGrid; }

	std::shared_ptr<FullMeshAsset> mesh;
	std::vector<GridCellDesc> cellDescs;

	const GridCellDesc& GetDesc(GridCellType type) const;

	void OnEnable() override;
	void OnDisable() override;

	Vector3 GetCellWorldCenter(const Vector2Int& cell) const;

	std::vector<GridCell> cells;
	static Grid* mainGrid;
	REFLECT_BEGIN(Grid);
	REFLECT_VAR(mesh);
	REFLECT_VAR(cellDescs);
	REFLECT_END();
};

class GridDrawer : public Component {
public:
	void OnEnable() override;
	void OnDisable() override;
	void Update() override;

private:
	std::shared_ptr<GameObject> gridCellPrefab;
	std::vector<std::shared_ptr<MeshRenderer>> pooledRenderers;
	std::shared_ptr<Grid> grid;

	REFLECT_BEGIN(GridDrawer);
	REFLECT_VAR(gridCellPrefab);
	REFLECT_END();
};