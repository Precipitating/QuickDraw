local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PopupGUI = require(script.Parent.GUI.PopupGUI)
local ServerData = require(script.Parent.ServerData)

local PurchaseHistory = DataStoreService:GetDataStore("PurchaseHistory")

local ProductFunctions = {}
local PurchaseHandler = {}

-- currency
ProductFunctions[3594526331] = function(_, player)
	ServerData.UpdateBank(player, 1250)
	PopupGUI:NewPopup(player, 3, `Added 1250 to bank!`)
	return true
end
ProductFunctions[3594526330] = function(_, player)
	ServerData.UpdateBank(player, 2500)
	PopupGUI:NewPopup(player, 3, `Added 2500 to bank!`)
	return true
end
ProductFunctions[3594526329] = function(_, player)
	ServerData.UpdateBank(player, 5000)
	PopupGUI:NewPopup(player, 3, `Added 5000 to bank!`)
	return true
end
ProductFunctions[3594526328] = function(_, player)
	ServerData.UpdateBank(player, 10000)
	PopupGUI:NewPopup(player, 3, `Added 10000 to bank!`)
	return true
end

local function ProcessReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local key = `{userId}_{receiptInfo.PurchaseId}`
	local player = Players:GetPlayerByUserId(userId)

	local wasFirstPurchase = false

	local success, errMsg = pcall(function()
		PurchaseHistory:UpdateAsync(key, function(alreadyPurchased)
			if alreadyPurchased then
				return true
			end

			wasFirstPurchase = true
			return true
		end)
	end)

	if not success then
		error(errMsg)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- grant ONLY once
	if wasFirstPurchase and player then
		local handler = ProductFunctions[productId]
		local ok, errorMsg = pcall(handler, receiptInfo, player)
		if not ok then
			warn(errorMsg)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = ProcessReceipt

return PurchaseHandler
