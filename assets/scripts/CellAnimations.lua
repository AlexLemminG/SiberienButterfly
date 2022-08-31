local CellAnimType = require("CellAnimType")
local CellAnimations = {}

function CellAnimations.SetAppearFromGround(cell : GridCell)
	cell.animType = CellAnimType.ItemAppearFromGround
	cell.animT = 0.0
	cell.animStopT = 0.4
end

function CellAnimations.SetAppearFromGroundWithoutXZScale(cell : GridCell)
	cell.animType = CellAnimType.ItemAppearFromGroundWithoutXZScale
	cell.animT = 0.0
	cell.animStopT = 0.4
end

function CellAnimations.SetAppear(cell)
	cell.animType = CellAnimType.ItemAppear
	cell.animT = 0.0
	cell.animStopT = 0.1
end

function CellAnimations.SetAppearWithoutXZScale(cell)
	cell.animType = CellAnimType.ItemAppearWithoutXZScale
	cell.animT = 0.0
	cell.animStopT = 0.1
end

return CellAnimations