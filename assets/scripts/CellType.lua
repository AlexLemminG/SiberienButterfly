--!strict

local CellType = {
    None = 1,
    Any = 2,
    Ground = 3,
    GroundWithGrass = 4,
    GroundPrepared = 5,
    Sphere = 6,
    Tree = 7,
    Wheat = 8,
    WheatCollected_1 = 9,
    WheatCollected_2 = 10,
    WheatCollected_3 = 11,
    WheatCollected_4 = 12,
    WheatCollected_5 = 13,
    WheatCollected_6 = 14,
    WheatPlanted_0 = 15,
    WheatPlanted_1 = 16,
    Wood = 17,
    Fence = 18,
    Stone = 19,
    Campfire = 20,
    CampfireWithWood = 21,
    CampfireWithWoodFired = 22,
    FlintStone = 23,
    Flour = 24,
    Stove = 25,
    StoveWithWood = 26,
    StoveWithWoodFired = 27,
    Bread_1 = 28,
    Bread_2 = 29,
    Bread_3 = 30,
    Bread_4 = 31,
    Bread_5 = 32,
    Bread_6 = 33,
    Bread_Any = 34,
    WheatCollected_Any = 35,
    WheatCollected_AnyNotFull = 36,
    Stove_Any = 37,
    Campfire_Any = 38,
    Fence_Any = 39,
    FenceX = 40,
    FenceZ = 41,
    FenceXZ = 42,
    Water = 43,
    TreeSprout = 44,
    WoodenBridge = 45,
    Bush = 46,
    BushWithBerries = 47,
    Eatable_Any = 48,
    Bed = 49,
    BedOccupied = 50,
    Wool = 51,
    GroundWithEatenGrass = 52,
    FlagRed = 53,
    FlagBlue = 54,
    FlagGreen = 55,
    --empty for future flags --TODO *flag emoji*
    MarkingRed = 62,
    --empty for future markings --TODO *markings emoji?*
}

return CellType
