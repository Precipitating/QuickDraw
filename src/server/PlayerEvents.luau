local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Server = require(ReplicatedStorage.Shared.Vetra.VetraNet.Server)
local ServerData = require(script.Parent.ServerData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

type HumanPlayer = ClassTypes.HumanPlayer
Players.CharacterAutoLoads = false

local function SpawnPlayerIn(player: Player)
	repeat
		local success, _ = pcall(function()
			player:LoadCharacterAsync()
		end)
	until success
end
local function InitializePlayer(player: Player, character: Model)
	local humanClass: HumanPlayer = PlayerManager:AddHumanClass(player)
	local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local bounty = ServerData:GetBounty(player)
	if not humanoid then
		error(`Missing humanoid for {player.DisplayName}`)
	end

	CollectionService:AddTag(character, "Player")
	if bounty > 0 then
		CollectionService:AddTag(character, "Wanted")
	end
	humanoid.WalkSpeed = 6

	-- ragdoll
	humanoid.Died:Connect(function()
		humanClass:OnDeath()
		task.wait(3)
		SpawnPlayerIn(player)
	end)
	-- remove class if they leave
	humanoid.Destroying:Connect(function()
		humanClass:Destroy()
	end)
end

return {

	Players.PlayerAdded:Connect(function(player: Player)
		ServerData.WaitForPlayerData(player)
		ServerData:SetupLeaderboard(player)
		ServerData:SetupDataServiceEvents(player)
		player.CharacterAdded:Connect(function(character)
			InitializePlayer(player, character)
		end)

		SpawnPlayerIn(player)

		player.CharacterRemoving:Connect(function(character: Model)
			local humanoid = character:FindFirstChild("Humanoid")

			if not humanoid then
				warn("[CharacterRemoving] Can't save weapon data, humanoid missing")
				return
			end

			-- MOST LIKELY LEFT THE GAME
			if humanoid.Health > 0 then
				local humanClass: HumanPlayer = PlayerManager:GetHumanClass(humanoid)
				if not humanClass then
					return
				end

				if humanClass.InCombat then
					ServerData.UpdateCombatLogged(player, true)
					ServerData.SaveWeaponEquipped(player, "Revolver")
					ServerData.SaveThrowableEquipped(player, "Dynamite", 1)
					ServerData.SetBounty(player, 0)
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
				end

				return
			end
		end)
	end),
}
