local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ServerData = require(script.Parent.ServerData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local BountyPosterHandler = {}

local Active = false
local PosterTemplate = ReplicatedStorage.Shared.Templates.BountyPoster
local PosterLocations = ReplicatedStorage.Shared.BountyPosterPositions
local StoredPosters = {}

local function SetAvatarThumbnail(imageLabel: ImageLabel, userId: number)
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
	end)
	if ok and content then
		imageLabel.Image = content
	else
		warn(`Failed to fetch avatar thumbnail for {userId}: {content}`)
	end
end

local function GetPosterRefs(posterClone: Model)
	if not posterClone then
		return
	end

	local gui = Utility.GetInstance(posterClone, false, "BountyGUI")
	if not gui then
		return
	end

	local imageLabel: ImageLabel? = Utility.GetInstance(gui, false, "ImageLabel")
	local nameLabel: TextLabel? = Utility.GetInstance(gui, false, "Name")
	local bountyLabel: TextLabel? = Utility.GetInstance(gui, false, "Bounty")

	return gui, imageLabel, nameLabel, bountyLabel
end

-- Extracted: both branches did identical label writes, now one place
local function ApplyPosterData(posterClone: Model, player: Player, bounty: number): boolean
	local _, imageLabel, nameLabel, bountyLabel = GetPosterRefs(posterClone)
	if not imageLabel or not nameLabel or not bountyLabel then
		warn("Bounty poster missing label references")
		return false
	end

	nameLabel.Text = player.DisplayName
	bountyLabel.Text = `${bounty}`
	task.spawn(SetAvatarThumbnail, imageLabel, player.UserId)

	return true
end

function BountyPosterHandler:Start()
	Active = true
	local posterLocs = PosterLocations:GetChildren()

	task.spawn(function()
		while Active do
			task.wait(5)

			for _, player in Players:GetPlayers() do
				local bounty = ServerData.GetBounty(player)
				if bounty <= 0 then
					continue
				end

				local posterLoc = posterLocs[RandomModule.GetRandomIntBetween(1, #posterLocs)]
				local existing = StoredPosters[posterLoc]

				if existing and existing.Parent then
					-- Poster still alive in the world, just refresh its data
					ApplyPosterData(existing, player, bounty)
				else
					if existing then
						existing:Destroy()
					end

					local clone = PosterTemplate:Clone()
					clone:PivotTo(posterLoc.WorldCFrame)
					clone.Parent = workspace
					StoredPosters[posterLoc] = clone

					ApplyPosterData(clone, player, bounty)
				end
			end
		end
	end)
end

function BountyPosterHandler:Stop()
	Active = false
	for _, poster in StoredPosters do
		if poster and poster.Parent then
			poster:Destroy()
		end
	end
	table.clear(StoredPosters)
end

return BountyPosterHandler
