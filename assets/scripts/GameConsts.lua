local DayTime = require "DayTime"

local GameConsts = {
    maxWheatStackSize = 6,
    maxBreadStackSize = 6,

    hungerPerSecond = (3.0) / DayTime.dayDurationInSeconds,
    hungerInSleepMultipler = 0.1,
    healthLossFromHungerPerSecond = (1 / 3) / DayTime.dayDurationInSeconds,
    healthLossFromHungerInSleepMultiplier = 0.1,
    healthIncWithoutHungerPerSecond = (1 / 6) / DayTime.dayDurationInSeconds,
    newTreeApearProbabilityPerCellPerMinute = 0.1, --TODO Is it really probability?
    treeSproutToTreeGrowthTime = 60.0,
    wheatGrowthTimeTotal = DayTime.dayDurationInSeconds / 5.0,
    bushBerriesGrowthTime = DayTime.dayDurationInSeconds * 10,
    dayDurationSeconds = DayTime.dayDurationInSeconds,
    goodConditionsToSpawnCharacterDuration = DayTime.dayDurationInSeconds / 5,
    grassGrowingDurationSeconds = DayTime.dayDurationInSeconds * 1,
    eatenGrassGrowingDurationSeconds = DayTime.dayDurationInSeconds / 3,
    healthLossFromHungerWhenFreezingMultiplier = 2.0,
    hungerWhenFreezingMultiplier = 2.0,
    hungerLossFromFood = 0.333,
    woolGrowPerSecond = 1.0 / DayTime.dayDurationInSeconds,

    goToSleepDayTime = DayTime.FromHoursAndMinutes(22, 00),
    wakeUpDayTime = DayTime.FromHoursAndMinutes(6, 00),
    goToSleepImmediatelyDayTime = DayTime.FromHoursAndMinutes(23, 00),
    goToCampfireDayTimePercent = DayTime.FromHoursAndMinutes(20, 00)
}

GameConsts.wheatGrowthTime0 = GameConsts.wheatGrowthTimeTotal / 2
GameConsts.wheatGrowthTime1 = GameConsts.wheatGrowthTimeTotal / 2

return GameConsts
