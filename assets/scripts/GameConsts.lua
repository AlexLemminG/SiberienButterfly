local DayTime = require "DayTime"

local GameConsts = {
    maxWheatStackSize = 6,
    maxBreadStackSize = 6,

    hungerPerSecond = (10 / 3) / DayTime.dayDurationInSeconds,
    hungerInSleepMultipler = 0.1,
    healthLossFromHungerPerSecond = (10 / 3) / DayTime.dayDurationInSeconds,
    healthLossFromHungerInSleepMultiplier = 0.1,
    healthIncWithoutHungerPerSecond = (10 / 6) / DayTime.dayDurationInSeconds,
    newTreeApearProbabilityPerCellPerMinute = 0.1, --TODO Is it really probability?
    treeSproutToTreeGrowthTime = 60.0,
    wheatGrowthTimeTotal = DayTime.dayDurationInSeconds / 10,
    bushBerriesGrowthTime = DayTime.dayDurationInSeconds / 20,
    dayDurationSeconds = DayTime.dayDurationInSeconds,
    goodConditionsToSpawnCharacterDuration = DayTime.dayDurationInSeconds / 20,
    grassGrowingDurationSeconds = DayTime.dayDurationInSeconds / 3,
    eatenGrassGrowingDurationSeconds = DayTime.dayDurationInSeconds / 10,

    goToSleepDayTime = DayTime.FromHoursAndMinutes(22, 00),
    wakeUpDayTime = DayTime.FromHoursAndMinutes(6, 00),
    goToSleepImmediatelyDayTime = DayTime.FromHoursAndMinutes(23, 00),
    goToCampfireDayTimePercent = DayTime.FromHoursAndMinutes(18, 00)
}

GameConsts.wheatGrowthTime0 = GameConsts.wheatGrowthTimeTotal / 2
GameConsts.wheatGrowthTime1 = GameConsts.wheatGrowthTimeTotal / 2

return GameConsts
