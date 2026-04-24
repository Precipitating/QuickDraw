local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	ConnectGunSignal = Signal.new(),
	DisconnectGun = Signal.new(),
	PlayerHit = Signal.new(),
	InflictLimbDamage = Signal.new(),
	NormalLimbDamage = Signal.new(),
	StoppedReloading = Signal.new(),
}
