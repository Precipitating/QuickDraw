local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
SoundManager.Init()
SoundManager.PlayKeyed("Music", "MainTheme", { FadeIn = 0.5 })

require(script.Sound.ClientSoundHandler)
require(script.Utility.PlayerContext)
require(script.Gun.ClientGunHandler)
require(script.PlayerEvents).Initialize()
