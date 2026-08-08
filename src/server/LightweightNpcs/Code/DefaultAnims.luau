local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}

local NpcAnimationTypes = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcAnimationTypes)

function module:GetDefaultAnimations(): NpcAnimationTypes.FinalAnimTable
	--Extra fields supported:
	--speed (defaults to 1) - scales up the animation
	--characterWalkSpeed - whatever walk speed animation is tuned for in studs per second.

	local animNames: NpcAnimationTypes.SourceAnimTable = {
		["idle"] = {
			{ id = "http://www.roblox.com/asset/?id=12521158637", weight = 1 },
		},
		["walk"] = {
			{ id = "http://www.roblox.com/asset/?id=110034364860119", weight = 10, characterWalkSpeed = 6 },
		},
		["run"] = {
			{ id = "http://www.roblox.com/asset/?id=82474325722923", weight = 10, characterWalkSpeed = 20 },
		},

		["jump"] = {
			{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 },
		},
		["fall"] = {
			{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 },
		},
		["crawlidle"] = {
			{ id = "http://www.roblox.com/asset/?id=122940383806072", weight = 10 },
		},
		["crawlwalk"] = {
			{ id = "http://www.roblox.com/asset/?id=109814683228688", weight = 10 },
		},
	}

	return NpcAnimationTypes:BuildFinalAnimationTable(animNames)
end

return module
