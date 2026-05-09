local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local CashTemplate = ReplicatedStorage.Shared.Templates.CashPickup

local CASH_LIFETIME = 300
local MoneyDropHandler = {}

function MoneyDropHandler.DropMoney(position: Vector3, amount: number)
	if not amount then
		warn("[MoneyDropHandler.DropMoney] No amount specified")
		return
	end

	local cashObj = CashTemplate:Clone()
	local billBoardTxt = Utility.GetInstance(cashObj, false, "BillboardGui", "TextLabel")
	local alignPos = Utility.GetInstance(cashObj, false, "AlignPosition")
	cashObj:SetAttribute("Cash", amount)
	cashObj.CFrame = CFrame.new(position)
	alignPos.Position = position
	billBoardTxt.Text = `${amount}`
	cashObj.Parent = workspace

	task.delay(CASH_LIFETIME, function()
		if not cashObj then
			return
		end

		cashObj:Destroy()
	end)
end

return MoneyDropHandler
