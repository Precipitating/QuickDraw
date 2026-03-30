local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local AI = require(script.Parent.AI)
local AISignals = require(script.Parent.AISignals)
local PatrolData = require(script.Parent.PatrolData)
return {
	AISignals.HandleTargetDead:Connect(function(AIClass, target: BasePart | Model)
		local isHuman = if target:isA("Model") and target:FindFirstChild("Humanoid")
			then target:FindFirstChild("Humanoid")
			else nil

		local humanClass = PlayerManager:GetHumanClass(isHuman)
		if humanClass and humanClass.Dead then
			CollectionService:RemoveTag(target, "NPC")
			CollectionService:RemoveTag(target, "Player")
			AI.ChangeState(AIClass, "Patrol", PatrolData["Test"])
			return
		end

		if not target or not target.Parent then
			AI.ChangeState(AIClass, "Seek")
			return
		end
	end),
}
