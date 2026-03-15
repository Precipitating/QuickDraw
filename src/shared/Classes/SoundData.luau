local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local SoundData = {}

SoundData.Sounds = {
	-- Revolver Sounds
	RevolverShot = {
		SoundId = "rbxassetid://134309742536448",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},
	RevolverClick = {
		SoundId = "rbxassetid://71403239537586",
		Volume = 0.5,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},

	MainTheme = {
		SoundId = "rbxassetid://140307073043749",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},

	--Human
	LimbDismember = {
		SoundId = "rbxassetid://140443303137571",
		Volume = 4,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	BulletHitGroan = {
		SoundId = "rbxassetid://1489934368",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	BoneSnap = {
		SoundId = "rbxassetid://137260412436272",
		Volume = 4,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	Roll = {
		SoundId = "rbxassetid://8042841372",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	DynamiteFuse = {
		SoundId = "rbxassetid://126320753231712",
		Volume = 3,
		PlaybackSpeed = 7 / ThrowableData["Dynamite"].DetonationTime,
		Group = "SFX",
	},
	DynamiteExplosion = {
		SoundId = "rbxassetid://138278545827368",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
}

-- Default group volumes
SoundData.GroupDefaults = {
	Master = 1.0,
	Music = 0.7,
	SFX = 1.0,
	UI = 0.8,
	Ambient = 0.5,
}

return table.freeze(SoundData)
