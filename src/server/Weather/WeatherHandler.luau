local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local WeatherRemote = ReplicatedStorage.Shared.Remote.ChangeWeatherRemote
local Weather = {}
local Active = true
local TIME_BEFORE_CHANGE = 300
WEATHER_LIST = {
	"Sandstorm",
	"LightRain",
	"HeavyRain",
	"None",
}

function Weather:ChangeWeather(weatherName: string)
	Utility.Warn(`Weather changed to {weatherName}`)
	WeatherRemote:FireAllClients(weatherName)
end

function Weather:ChangeActiveState(active: boolean)
	Active = active
end

function Weather:Initialize()
	while Active do
		task.wait(TIME_BEFORE_CHANGE)
		self:ChangeWeather(WEATHER_LIST[RandomModule.GetRandomIntBetween(1, #WEATHER_LIST)])
	end
end

return Weather
