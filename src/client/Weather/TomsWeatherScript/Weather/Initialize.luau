local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Atmosphere = Lighting:WaitForChild("Atmosphere")
local Weather = require(script.Parent)
local WeatherRemote = ReplicatedStorage.Shared.Remote.ChangeWeatherRemote
local CurrentWeather = nil
local TRANSITION_TIME = 3
local DEFAULT_LIGHTING = {
	Brightness = 3,
	ExposureCompensation = 0,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	ClockTime = 14.5,
}
local DEFAULT_ATMOSPHERE = {
	Density = 0.4,
	Offset = 0.25,
	Glare = 0,
}
local SAND_STORM_ATMOSPHERE = {
	Density = 0.7,
	Offset = 0.25,
	Glare = 0,
}
local RAIN_LIGHTING = {
	Brightness = 1,
	ExposureCompensation = -0.7,
	EnvironmentDiffuseScale = 0.3,
	EnvironmentSpecularScale = 0.3,
}

local function AtmosphereTransition(weatherName: string)
	local tweenInfo = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local chosenData = nil

	if weatherName == "Sandstorm" then
		chosenData = SAND_STORM_ATMOSPHERE
	else
		chosenData = DEFAULT_ATMOSPHERE
	end

	local tween = TweenService:Create(Atmosphere, tweenInfo, {
		Density = chosenData.Density,
		Offset = chosenData.Offset,
		Glare = chosenData.Glare,
	})

	tween:Play()
end
local function LightingTransition(weatherName: string)
	local tweenInfo = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local chosenData = nil

	if string.find(string.lower(weatherName), "rain") then
		chosenData = RAIN_LIGHTING
	else
		chosenData = DEFAULT_LIGHTING
	end

	local tween = TweenService:Create(Lighting, tweenInfo, {
		Brightness = chosenData.Brightness,
		ExposureCompensation = chosenData.ExposureCompensation,
		EnvironmentDiffuseScale = chosenData.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = chosenData.EnvironmentSpecularScale,
	})

	tween:Play()
end

local function SetWeather(weatherName: string)
	CurrentWeather = weatherName
	Weather:Disable()
	LightingTransition(weatherName)
	AtmosphereTransition(weatherName)
	if weatherName == "None" then
		return
	end
	Weather:SetWeather(weatherName)
	Weather:SetSoundVolume(1)
	Weather:Enable()
end

return function()
	if CurrentWeather then
		SetWeather(CurrentWeather)
	end

	WeatherRemote.OnClientEvent:Connect(function(weatherName: string)
		if not weatherName then
			return
		end

		if CurrentWeather and CurrentWeather == weatherName then
			return
		end

		SetWeather(weatherName)
	end)
end
