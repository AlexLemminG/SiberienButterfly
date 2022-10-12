local GameConsts = {
    maxWheatStackSize = 6,
    maxBreadStackSize = 6,
    hungerPerSecond = 1 / 60 / 3,
    hungerInSleepMultipler = 0.1,
    healthLossFromHungerPerSecond = 1 / 60 / 3,
    healthLossFromHungerInSleepMultiplier = 0.1,
    healthIncWithoutHungerPerSecond = 1 / 60 / 6,
    newTreeApearProbabilityPerCellPerMinute = 0.1, --TODOQ Is it really probability
    treeSproutToTreeGrowthTime = 60.0,
    wheatGrowthTime0 = 30.0,
    wheatGrowthTime1 = 30.0,
    bushBerriesGrowthTime = 30.0,
    dayDurationSeconds = 600.0,
    goodConditionsToSpawnCharacterDuration = 30.0,
    grassGrowingDurationSeconds = 200.0,

    goToSleepDayTimePercent = 0.8,
    wakeUpDayTimePercent = 0.2,
    goToSleepImmediatelyTimePercent = 0.9,
    goToCampfireDayTimePercent = 0.6
}

return GameConsts
