local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(ReplicatedStorage.Packages.DataService).server
local ServerData = require(script.Parent.ServerData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local SpawnHandler = require(ServerScriptService.Server.SpawnHandler.SpawnHandler)
local PlayerCharacters = {}
type HumanPlayer = ClassTypes.HumanPlayer
Players.CharacterAutoLoads = false

local function SpawnPlayerIn(player: Player)
	repeat
		local success, _ = pcall(function()
			player:LoadCharacterAsync()
		end)
	until success or (not player or not player.Parent)

	SpawnHandler:SpawnPlayer(player.Character)
end
local function InitializePlayer(player: Player, character: Model)
	local humanClass: HumanPlayer = PlayerManager:AddHumanClass(player)
	local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local bounty = ServerData.GetBounty(player)
	if not humanoid then
		error(`Missing humanoid for {player.DisplayName}`)
	end

	CollectionService:AddTag(character, "Player")
	if bounty > 0 then
		CollectionService:AddTag(character, "Wanted")
	end
	humanoid.WalkSpeed = 6

	PlayerCharacters[player] = humanClass

	-- ragdoll
	humanoid.Died:Connect(function()
		ServerData.SaveWeaponEquipped(player, "Revolver")
		humanClass:DropMoney()
		humanClass:OnDeath()
		PlayerCharacters[player] = nil
		task.wait(3)
		if not player then
			return
		end
		SpawnPlayerIn(player)
	end)
	-- remove class if they leave
	humanoid.Destroying:Connect(function()
		humanClass:Destroy()
	end)

	-- task.wait(2)
	-- humanClass:DestroyLimb("LeftUpperArm")
	-- humanClass:DestroyLimb("LeftUpperLeg")
	-- humanClass:DestroyLimb("RightUpperLeg")
end

return {
	Players.PlayerAdded:Connect(function(player: Player)
		ServerData.WaitForPlayerData(player)
		ServerData:SetupLeaderboard(player)
		ServerData:SetupDataServiceEvents(player)
		CollectionService:AddTag(player, "FirstLoad")

		player.CharacterAdded:Connect(function(character)
			InitializePlayer(player, character)
		end)
		SpawnPlayerIn(player)
	end),

	DataService:addPlayerRemovingCallback(function(player: Player, data: any): ()
		-- Perform any cleanup or save operations here
		local humanClass = PlayerCharacters[player]
		if not player then
			return
		end

		if humanClass.InCombat then
			ServerData.UpdateCombatLogged(player, true)
			ServerData.SaveWeaponEquipped(player, "Revolver")
			ServerData.SetBounty(player, 0)
			ServerData.SetMoney(player, 0)
			print(`{player.Name} combat logged`)
			return
		end

		if humanClass.CurrentGun then
			ServerData.SaveWeaponEquipped(player, humanClass.CurrentGun.GunName)
		end

		if humanClass.CurrentThrowable then
			ServerData.SaveThrowableEquipped(
				player,
				humanClass.CurrentThrowable.Name,
				humanClass.CurrentThrowable.CurrentAmmo
			)
		else
			data.equippedThrowable = nil
		end

		ServerData.SetMoney(player, ServerData.GetMoney(player))

		PlayerCharacters[player] = nil
		print(player.Name .. " is leaving with data:", data)
	end),
}
