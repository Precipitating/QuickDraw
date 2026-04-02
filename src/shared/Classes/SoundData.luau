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
	RevolverReload = {
		SoundId = "rbxassetid://3292840510",
		Volume = 1,
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
		PoolSize = 6,
	},

	BulletHitGroan = {
		SoundId = "rbxassetid://1489934368",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},
	BoneSnap = {
		SoundId = "rbxassetid://137260412436272",
		Volume = 4,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
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
	MolotovLand = {
		SoundId = "rbxassetid://3105090678",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	MolotovFire = {
		SoundId = "rbxassetid://2770705399",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},
	ThrowProjectile = {
		SoundId = "rbxassetid://101808428209321",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	WinchesterLoadBullet = {
		SoundId = "rbxassetid://75139130130084",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	WinchesterShot = {
		SoundId = "rbxassetid://75965425749742",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},
	WinchesterReload = {
		SoundId = "rbxassetid://122039660768000",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	CoachReload = {
		SoundId = "rbxassetid://142429556",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	CoachShot = {
		SoundId = "rbxassetid://122456779862107",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	CoachClick = {
		SoundId = "rbxassetid://321719832",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	Headshot = {
		SoundId = "rbxassetid://132435334799057",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	AddMoney = {
		SoundId = "rbxassetid://139922061047157",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "UI",
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
