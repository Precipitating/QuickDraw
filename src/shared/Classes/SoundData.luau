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
	BulletMiss = {
		SoundId = "rbxassetid://125069334192045",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},
	UnjamWeapon = {
		SoundId = "rbxassetid://96208385832784",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 6,
	},

	-- Music
	MainTheme = {
		SoundId = "rbxassetid://140307073043749",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	ArmoryTheme = {
		SoundId = "rbxassetid://94622244823914",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	DoctorTheme = {
		SoundId = "rbxassetid://133661921560682",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	MercenaryTheme = {
		SoundId = "rbxassetid://123247253659161",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	BankTheme = {
		SoundId = "rbxassetid://101633026754083",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	TrainTheme = {
		SoundId = "rbxassetid://108544978969359",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	CaveTheme = {
		SoundId = "rbxassetid://137658646948907",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},
	AbandonedTownTheme = {
		SoundId = "rbxassetid://133631639970771",
		Volume = 0.7,
		PlaybackSpeed = 1,
		Group = "Music",
		Looped = true,
	},

	--Human
	LimbDismember = {
		SoundId = "rbxassetid://140443303137571",
		Volume = 1,
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
	GrappleHook = {
		SoundId = "rbxassetid://118662377115778",
		Volume = 2,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	HookGrenadeLand = {
		SoundId = "rbxassetid://101646201420499",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	--

	-- Trap Data
	BearTrapPlaced = {
		SoundId = "rbxassetid://9126278027",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	BearTrapActivated = {
		SoundId = "rbxassetid://99109622391662",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	TripMinePlaced = {
		SoundId = "rbxassetid://122782690363016",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	TripMineActivated = {
		SoundId = "rbxassetid://133384716023284",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	RopeTrapPlaced = {
		SoundId = "rbxassetid://123350827153183",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	RopeTrapActivated = {
		SoundId = "rbxassetid://86165035080520",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	--
	WinchesterLoadBullet = {
		SoundId = "rbxassetid://75139130130084",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	WinchesterShot = {
		SoundId = "rbxassetid://75965425749742",
		Volume = 0.7,
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

	CannonReload = {
		SoundId = "rbxassetid://204039974",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	CannonShot = {
		SoundId = "rbxassetid://140683456896595",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	GatlingShot = {
		SoundId = "rbxassetid://87594026554349",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	GatlingReload = {
		SoundId = "rbxassetid://18835944702",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	--
	Headshot = {
		SoundId = "rbxassetid://132435334799057",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
		PoolSize = 3,
	},
	AddMoney = {
		SoundId = "rbxassetid://139922061047157",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "UI",
		PoolSize = 3,
	},
	BountyClaimed = {
		SoundId = "rbxassetid://100295010445316",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "UI",
		PoolSize = 2,
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
	SpecialShopGreeting = {
		SoundId = "rbxassetid://94212318976458",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	SpecialShopExit = {
		SoundId = "rbxassetid://97942745564233",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	BankGreeting = {
		SoundId = "rbxassetid://105250576858171",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	BankExit = {
		SoundId = "rbxassetid://124774610485067",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	MercGreeting = {
		SoundId = "rbxassetid://138522653077230",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	MercBuy = {
		SoundId = "rbxassetid://83486610413630",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},
	MercExit = {
		SoundId = "rbxassetid://72247137958194",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
		PoolSize = 1,
	},

	-- Ranged Sniper AI
	RangedAIAttack1Sniper = {
		SoundId = "rbxassetid://91004211172905",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack2Sniper = {
		SoundId = "rbxassetid://103394204160530",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack3Sniper = {
		SoundId = "rbxassetid://85256539261027",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff1Sniper = {
		SoundId = "rbxassetid://86287484064562",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff2Sniper = {
		SoundId = "rbxassetid://136531213004679",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff3Sniper = {
		SoundId = "rbxassetid://73868325417106",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar1Sniper = {
		SoundId = "rbxassetid://136403756554183",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar2Sniper = {
		SoundId = "rbxassetid://101594553347016",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar3Sniper = {
		SoundId = "rbxassetid://129013076301243",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAILostSight1Sniper = {
		SoundId = "rbxassetid://122246927608111",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	-- Ranged Basic AI
	RangedAIAttack1Basic = {
		SoundId = "rbxassetid://73542666227767",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack2Basic = {
		SoundId = "rbxassetid://127774610119067",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack3Basic = {
		SoundId = "rbxassetid://125280104379682",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff1Basic = {
		SoundId = "rbxassetid://126114496073105",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff2Basic = {
		SoundId = "rbxassetid://91135560219092",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff3Basic = {
		SoundId = "rbxassetid://107233344748256",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar1Basic = {
		SoundId = "rbxassetid://122189299597247",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar2Basic = {
		SoundId = "rbxassetid://109645327135032",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar3Basic = {
		SoundId = "rbxassetid://126673224914495",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAILostSight1Basic = {
		SoundId = "rbxassetid://86979303092619",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	-- Shotgunner AI
	RangedAIAttack1Shotgunner = {
		SoundId = "rbxassetid://113866621593157",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack2Shotgunner = {
		SoundId = "rbxassetid://109695085606228",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack3Shotgunner = {
		SoundId = "rbxassetid://124037743927155",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff1Shotgunner = {
		SoundId = "rbxassetid://120023968862448",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff2Shotgunner = {
		SoundId = "rbxassetid://115393292812816",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff3Shotgunner = {
		SoundId = "rbxassetid://105418091303400",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar1Shotgunner = {
		SoundId = "rbxassetid://120239904391897",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar2Shotgunner = {
		SoundId = "rbxassetid://73486286408877",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar3Shotgunner = {
		SoundId = "rbxassetid://110930795054627",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAILostSight1Shotgunner = {
		SoundId = "rbxassetid://116588024527765",
		Volume = 3,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},

	-- Grenadier
	RangedAIAttack1Grenadier = {
		SoundId = "rbxassetid://75975571335133",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack2Grenadier = {
		SoundId = "rbxassetid://104640133337510",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIAttack3Grenadier = {
		SoundId = "rbxassetid://118375270857264",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff1Grenadier = {
		SoundId = "rbxassetid://134213852287429",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff2Grenadier = {
		SoundId = "rbxassetid://124614146560041",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAIBackOff3Grenadier = {
		SoundId = "rbxassetid://137447112370301",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar1Grenadier = {
		SoundId = "rbxassetid://132421594283493",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar2Grenadierc = {
		SoundId = "rbxassetid://72758385810042",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},
	RangedAITooFar3Grenadier = {
		SoundId = "rbxassetid://117670246128566",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},

	-- Buffalos
	AnimalAIAttackBuffalo = {
		SoundId = "rbxassetid://106573922556824",
		Volume = 2,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	BuffaloHit = {
		SoundId = "rbxassetid://74149238738530",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	BuffaloDead = {
		SoundId = "rbxassetid://9113626404",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	-- Medic
	MedicBuy = {
		SoundId = "rbxassetid://103766849742433",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},

	-- Main Menu
	LetsGo = {
		SoundId = "rbxassetid://128947678356340",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "Voiceline",
	},

	-- Looting
	TumbleWeedPickup = {
		SoundId = "rbxassetid://9114518070",
		Volume = 5,
		PlaybackSpeed = 1,
		Group = "SFX",
	},
	GenericPickup = {
		SoundId = "rbxassetid://106586585181583",
		Volume = 2,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	-- Material SFX
	GlassSmash = {
		SoundId = "rbxassetid://83597774521615",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	-- Tombstone
	SandDig = {
		SoundId = "rbxassetid://103746325474402",
		Volume = 2,
		PlaybackSpeed = 1,
		Looped = true,
		Group = "SFX",
	},
	SandPickup = {
		SoundId = "rbxassetid://122165369916243",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	-- Ore
	OreDrill = {
		SoundId = "rbxassetid://199754867",
		Volume = 2,
		PlaybackSpeed = 1,
		Looped = true,
		Group = "SFX",
	},

	--
	ImpactHit = {
		SoundId = "rbxassetid://140626490819228",
		Volume = 2,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	-- Quests

	QuestComplete = {
		SoundId = "rbxassetid://129864648066823",
		Volume = 1,
		PlaybackSpeed = 1,
		Group = "SFX",
	},

	SmokeDetector = {
		SoundId = "rbxassetid://135543502679167",
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
