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
		SoundId = "rbxassetid://128043849198610",
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
}

-- Default group volumes
SoundData.GroupDefaults = {
	Master = 1.0,
	Music = 0.7,
	SFX = 1.0,
	UI = 0.8,
	Ambient = 0.5,
}

return SoundData
