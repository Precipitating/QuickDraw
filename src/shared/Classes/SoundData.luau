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
		PoolSize = 3,
	},
	Headshot = {
		SoundId = "rbxassetid://132435334799057",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 3,
	},
	AddMoney = {
		SoundId = "rbxassetid://139922061047157",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "UI",
		PoolSize = 3,
	},
	Error = {
		SoundId = "rbxassetid://140650754692075",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "UI",
		PoolSize = 3,
	},
	Purchase = {
		SoundId = "rbxassetid://134952684776633",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "UI",
		PoolSize = 3,
	},
	ShopGreeting = {
		SoundId = "rbxassetid://109511115443460",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	ShopExit = {
		SoundId = "rbxassetid://136198373467944",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},

	-- Ranged AI
	RangedAIAttack1 = {
		SoundId = "rbxassetid://91004211172905",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack2 = {
		SoundId = "rbxassetid://103394204160530",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack3 = {
		SoundId = "rbxassetid://85256539261027",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff1 = {
		SoundId = "rbxassetid://86287484064562",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff2 = {
		SoundId = "rbxassetid://136531213004679",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff3 = {
		SoundId = "rbxassetid://73868325417106",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar1 = {
		SoundId = "rbxassetid://136403756554183",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar2 = {
		SoundId = "rbxassetid://101594553347016",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar3 = {
		SoundId = "rbxassetid://129013076301243",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAILostSight1 = {
		SoundId = "rbxassetid://122246927608111",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
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
