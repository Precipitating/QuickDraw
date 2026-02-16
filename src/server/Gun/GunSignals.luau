local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	ConnectGunSignal = Signal.new(),
	FireMuzzleFlash = Signal.new(),
	DisplayBulletHole = Signal.new(),
	PlayerHit = Signal.new(),
}
