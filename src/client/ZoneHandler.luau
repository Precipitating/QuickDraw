local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Utility.PlayerContext)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local QuickZone = require(ReplicatedStorage.Shared.QuickZone)
local WindConstants = require(ReplicatedStorage.Shared.Wind.WindConstants)
local WindLines = require(ReplicatedStorage.Shared.Wind.WindLines)
local WindShake = require(ReplicatedStorage.Shared.Wind.WindShake)
local Zone, Group, Observer = QuickZone.Zone, QuickZone.Group, QuickZone.Observer

local ZoneHandler = {}
local function SetupZone(
	tagName: string,
	musicName: string,
	zoneType: {}?,
	onEnterLogic: () -> ()?,
	onExitLogic: () -> ()?
)
	local observer = Observer.new({

		zones = {
			Zone.fromTag(tagName, {
				isDynamic = zoneType and zoneType["MovingPlatform"],
				autoSync = zoneType and zoneType["MovingPlatform"],
			}),
		},
		groups = { Group.localPlayer() },
	})

	observer:onEnter(function(entity, zone)
		print(entity.Name .. " entered " .. zone:getId())
		SoundManager.PlayKeyed("Music", musicName, { FadeIn = 1, FadeOut = 1 })

		if zoneType and zoneType["MovingPlatform"] then
			PlayerContext.StayOnMovingPlatform(zone["reference"])
		end

		if onEnterLogic then
			onEnterLogic()
		end

		WindLines:Cleanup()
		WindShake:Pause()
	end)

	observer:onExit(function(entity, zone)
		SoundManager.PlayKeyed("Music", "MainTheme", { FadeIn = 1, FadeOut = 1 })

		if zoneType and zoneType["MovingPlatform"] then
			PlayerContext.janitor:Remove("MovingPlatformConn")
		end
		WindLines:Init({
			Direction = WindConstants.WindDirection,
			Speed = WindConstants.WindSpeed,
			Lifetime = WindConstants.WindLifetime,
			SpawnRate = WindConstants.WindSpawnRate,
		})
		WindShake:Resume()

		if onExitLogic then
			onExitLogic()
		end
		print(entity.Name .. " exited " .. zone:getId())
	end)
end

function ZoneHandler:InitializeMusicZones()
	SetupZone("ArmoryAudioZone", "ArmoryTheme")
	SetupZone("DoctorAudioZone", "DoctorTheme")
	SetupZone("MercenaryAudioZone", "MercenaryTheme")
	SetupZone("BankAudioZone", "BankTheme")
	SetupZone("TrainAudioZone", "BankTheme", { MovingPlatform = true })
	SetupZone("CaveAudioZone", "CaveTheme", nil, function()
		local humanoid: Humanoid? = PlayerContext and PlayerContext.Humanoid
		if humanoid then
			humanoid.MaxSlopeAngle = 89
		end
	end, function()
		local humanoid: Humanoid? = PlayerContext and PlayerContext.Humanoid
		if humanoid then
			humanoid.MaxSlopeAngle = 50
		end
	end)
end

function ZoneHandler:Initialize()
	self:InitializeMusicZones()
end

return ZoneHandler
