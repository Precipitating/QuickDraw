local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- physics state
local velocity = Vector2.new(0, 0)
local gravity = 1.5
local bounce = 0.8
local recoilStrength = 0.5

-- player/ui
local player = Players.LocalPlayer
local playerGUI = player:WaitForChild("PlayerGui")

local loadingScreen = ReplicatedFirst:WaitForChild("LoadingScreen"):Clone()
loadingScreen.Parent = playerGUI

local bg = loadingScreen:WaitForChild("BG")
local loadingLabel = bg:WaitForChild("LoadingLabel")

local revolver = bg:WaitForChild("Gun")
local revolverShot = revolver:WaitForChild("Shoot")
local muzzleFlash: ImageLabel = revolver:WaitForChild("MuzzleFlash")
local loadCountLabel = bg:WaitForChild("LoadCount")

local pos = Vector2.new(revolver.Position.X.Scale, revolver.Position.Y.Scale)
local fireTimer = 0
local fireRate = 2

-- helpers
local function GetImageHalfSizeScale()
	local size = revolver.AbsoluteSize
	local parentSize = revolver.Parent.AbsoluteSize
	return Vector2.new((size.X / parentSize.X) / 2, (size.Y / parentSize.Y) / 2)
end

----------------------------------------------------
-- SHOOT (deterministic single impulse)
----------------------------------------------------
local function Shoot()
	muzzleFlash.Visible = true

	-- rotate first so direction matches visual state
	revolver.Rotation -= 20

	local angle = math.rad(revolver.Rotation)
	local dir = Vector2.new(math.cos(angle), math.sin(angle))

	velocity -= dir.Unit * recoilStrength

	revolverShot:Play()

	task.delay(0.1, function()
		muzzleFlash.Visible = false
	end)
end

-------------------------------------
-- PHYSICS LOOP (RenderStepped ONLY)
----------------------------------------------------
local gunConn = RunService.RenderStepped:Connect(function(dt)
	local half = GetImageHalfSizeScale()

	fireTimer += dt
	if fireTimer >= fireRate then
		fireTimer -= fireRate
		Shoot()
	end
	-- gravity
	velocity = velocity + Vector2.new(0, gravity * dt)

	-- LEFT / RIGHT collision
	if pos.X <= half.X then
		pos = Vector2.new(half.X, pos.Y)
		velocity = Vector2.new(math.abs(velocity.X) * bounce, velocity.Y)
	elseif pos.X >= 1 - half.X then
		pos = Vector2.new(1 - half.X, pos.Y)
		velocity = Vector2.new(-math.abs(velocity.X) * bounce, velocity.Y)
	end

	-- TOP / BOTTOM collision
	if pos.Y <= half.Y then
		pos = Vector2.new(pos.X, half.Y)
		velocity = Vector2.new(velocity.X, math.abs(velocity.Y) * bounce)
	elseif pos.Y >= 1 - half.Y then
		pos = Vector2.new(pos.X, 1 - half.Y)
		velocity = Vector2.new(velocity.X, -math.abs(velocity.Y) * bounce - 0.2)
	end

	-- integrate motion
	pos = pos + velocity * dt
	revolver.Position = UDim2.fromScale(pos.X, pos.Y)
end)

----------------------------------------------------
-- PRELOAD
----------------------------------------------------
local assets = game:GetDescendants()

for idx, asset in ipairs(assets) do
	ContentProvider:PreloadAsync({ asset })
	loadCountLabel.Text = `{idx}/{#assets}`
end

gunConn:Disconnect()
loadingScreen:Destroy()
----------------------------------------------------
-- FINISH TAG
----------------------------------------------------
CollectionService:AddTag(player, "ClientLoaded")
