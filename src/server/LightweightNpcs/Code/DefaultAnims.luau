local module = {}

local NpcAnimationTypes = require(game.ReplicatedFirst.LightweightNpcsClient.Code.NpcAnimationTypes)

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
	}

	return NpcAnimationTypes:BuildFinalAnimationTable(animNames)
end

return module
