local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundData = require(ReplicatedStorage.Shared.Classes.SoundData)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local QuickZone = require(ReplicatedStorage.Shared.QuickZone)
local Zone, Group, Observer = QuickZone.Zone, QuickZone.Group, QuickZone.Observer
local ZoneHandler = {}
local function SetupZone(tagName: string, musicName: string)
	local observer = Observer.new({
		zones = { Zone.fromTag(tagName) },
		groups = { Group.localPlayer() },
	})

	observer:onEnter(function(entity, zone)
		print(entity.Name .. " entered " .. zone:getId())
		SoundManager.PlayKeyed("Music", musicName, { FadeIn = 0.5 })
	end)

	observer:onExit(function(entity, zone)
		SoundManager.PlayKeyed("Music", "MainTheme", { FadeIn = 0.5 })
		print(entity.Name .. " exited " .. zone:getId())
	end)
end
function ZoneHandler:InitializeMusicZones()
	SetupZone("ArmoryAudioZone", "ArmoryTheme")
	SetupZone("DoctorAudioZone", "DoctorTheme")
	SetupZone("MercenaryAudioZone", "MercenaryTheme")
	SetupZone("BankAudioZone", "BankTheme")
end

function ZoneHandler:Initialize()
	self:InitializeMusicZones()
end

return ZoneHandler
