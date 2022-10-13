local DayTime = {
    dayDurationInSeconds = 600
}

--time is measured in percent of the day from [0;1) [00:00, 24:00)

--TODO assert everything
local realWorldSecondsInDay = 3600 * 24
local realWorldMinutesInDay = 60 * 24
local realWorldMinutesInHour = 60

--TODO support luau style return
---@return number, number
function DayTime.ToHoursAndMinutes(time)
    local t = time - math.floor(time)

    local minutes = math.min(math.floor(t * realWorldMinutesInDay), realWorldMinutesInDay - 1)

    local hours = math.floor(minutes / realWorldMinutesInHour)

    minutes = minutes - hours * realWorldMinutesInHour

    return hours, minutes
end

function DayTime.FromHoursAndMinutes(hours, minutes) : number
    return (hours * realWorldMinutesInHour + minutes) / realWorldMinutesInDay
end

function DayTime.IsBetween(time, aTime, bTime) : boolean
    if aTime <= bTime then
        return aTime <= time and time <= bTime
    else
        return aTime <= time or time <= bTime
    end
end

return DayTime
