local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local ClientThrowableHandler = {}
ClientThrowableHandler.networker = Networker.new("ThrowableNetwork", ClientThrowableHandler)
ClientThrowableHandler.janitor = Janitor.new()

local ThrowableEquipConn = nil
local ThrowableDisconnectConn = nil

function ClientThrowableHandler:Throw(throwable: Tool)
	local cameraLookVector = workspace.CurrentCamera.CFrame.LookVector
	local thrown = self.networker:fetch("ThrowProjectile", cameraLookVector)

	return thrown
end

function ClientThrowableHandler:ConnectThrowable(throwable: Tool?)
	print("Connecting Throwable")

	if not throwable then
		error("Can't connect throwable, tool reference not valid!")
	end

	if ThrowableEquipConn and ThrowableDisconnectConn then
		ThrowableEquipConn:Disconnect()
		ThrowableDisconnectConn:Disconnect()
	end

	ThrowableEquipConn = throwable.Equipped:Connect(function(_: Mouse)
		self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
		end))

		self.janitor:Add(throwable.Activated:Connect(function()
			if PlayerContext.Humanoid.Health <= 0 then
				return
			end

			self:Throw(throwable)
		end))
	end)

	ThrowableDisconnectConn = throwable.Unequipped:Connect(function()
		print("Disconnecting throwable connections!")
		self.janitor:Cleanup()
	end)
end

return ClientThrowableHandler
