local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local SpawnLocations = ReplicatedStorage.Shared.Templates.SpawnLocations
local SpawnHandler = {}
local ActiveJailCountdowns = {}
local CHECK_RADIUS = 30
local JAIL_TIME = 60

local function NormalSpawn(characterModel: Model?)
	if not characterModel then
		warn("Can't spawn, character model missing")
		return
	end
	local safeLocations = {}
	local spawnLocations = SpawnLocations:GetChildren()

	for _, spawn in spawnLocations do
		local partsNearSpawn = workspace:GetPartBoundsInRadius(spawn.Position, CHECK_RADIUS)
		local occupied = false

		for _, part in partsNearSpawn do
			if not part:IsA("MeshPart") then
				continue
			end
			if part.Parent and CollectionService:HasTag(part.Parent, "Player") then
				if not CollectionService:HasTag(part, "Dead") and not CollectionService:HasTag(part.Parent, "Dead") then
					warn(`Player found on {spawn.Name}, ignoring.`)
					occupied = true
					break
				end
			end
		end

		if not occupied then
			table.insert(safeLocations, spawn)
		end
	end

	if #safeLocations <= 0 then
		warn("All spawns occupied, falling back to random spawn")
		characterModel:PivotTo(spawnLocations[math.random(1, #spawnLocations)].CFrame)
		return
	end

	characterModel:PivotTo(safeLocations[RandomModule.GetRandomIntBetween(1, #safeLocations)].CFrame)
end
local function ToggleJailedGUI(player: Player?, active: boolean)
	if not player then
		return
	end
	local playerGUI = player.PlayerGui
	local jailedGUI: ScreenGui? = playerGUI:FindFirstChild("JailedGUI")
	if not jailedGUI then
		warn("Missing JailedGUI reference")
		return
	end

	-- Disable GUI
	if not active then
		jailedGUI.Enabled = active
		return
	end

	-- Enable GUI
	local textLabel: TextLabel? = jailedGUI:FindFirstChildOfClass("TextLabel")
	if textLabel then
		textLabel.Text = `JAILED FOR {JAIL_TIME} SECONDS`
	end

	jailedGUI.Enabled = active
end

function SpawnHandler:ResetTimerIfJailed(player: Player?)
	if not player then
		return
	end

	local hasActiveDelay = ActiveJailCountdowns[player]
	if hasActiveDelay then
		warn("Reset jail timer")
		task.cancel(hasActiveDelay)
		ActiveJailCountdowns[player] = nil
	end
end

local function JailSpawn(player: Player?, characterModel: Model?)
	if not player then
		warn("Can't spawn to jail, player ref missing")
		return
	end
	if not characterModel then
		warn("Can't spawn, character model missing")
		return
	end
	local JailSpawns = CollectionService:GetTagged("JailSpawn")

	if not JailSpawns or #JailSpawns <= 0 then
		warn("Jail spawns dont exist")
		return
	end

	local chosenSpawn = JailSpawns[RandomModule.GetRandomIntBetween(1, #JailSpawns)]
	ToggleJailedGUI(player, true)
	local chosenSpawnCFrame = chosenSpawn.CFrame

	characterModel:PivotTo(chosenSpawnCFrame)

	SpawnHandler:ResetTimerIfJailed(player)

	ActiveJailCountdowns[player] = task.delay(JAIL_TIME, function()
		local exitPos = chosenSpawn:WaitForChild("JailExit", 10)
		if not exitPos then
			warn("Missing Exit Pos for jail")
			return
		end
		CollectionService:RemoveTag(player, "Jailed")
		ToggleJailedGUI(player, false)
		ActiveJailCountdowns[player] = nil
		characterModel:PivotTo(exitPos.CFrame)
	end)
end

function SpawnHandler:SpawnPlayer(player: Player, loadCharacter: boolean?)
	if loadCharacter then
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)

		if not ok then
			error(err)
		end
	end

	local characterModel = player.Character
	if not characterModel then
		warn("Can't teleport player to spawn, missing model")
		return
	end

	if CollectionService:HasTag(player, "Jailed") then
		warn("Jail spawn")
		JailSpawn(player, characterModel)
	else
		NormalSpawn(characterModel)
	end
end

return SpawnHandler
