--Made by DoYouLikeWafflesOrNo

--!native
--< Services

local SplineClass = {}
SplineClass.__index = SplineClass

--< Types

export type SplineSettings = {
	Tension: number?,
	Looped: boolean?,
}

export type Spline = {
	-- Values
	Points: { Vector3 },
	Settings: SplineSettings,
	Looped: boolean,
	Length: number,
	ID: number,

	-- Functions
	GetPosition: (self: Spline, alpha: number, isLength: boolean?) -> Vector3,
	GetCFrame: (self: Spline, alpha: number, isLength: boolean?) -> CFrame,
	SetPoint: (self: Spline, point: Vector3 | Instance | CFrame, index: number) -> nil,
	InsertPoint: (self: Spline, point: Vector3 | Instance | CFrame, index: number?) -> nil,
	RemovePoint: (self: Spline, index: number) -> nil,
	DrawDebug: (self: Spline, samples: number) -> nil,
	RemoveDebug: (self: Spline) -> nil,
	Destroy: (self: Spline) -> nil,
}

export type SplineClass = {
	new: (Points: { Vector3 | Instance | CFrame }, Settings: SplineSettings?) -> Spline,
}

--< Values

local DEFAULT_DEBUG_SAMPLES = 250
local ID = 0

local EPS = 1e-9

local GL5_X = {
	0,
	-0.5384693101056831,
	0.5384693101056831,
	-0.9061798459386640,
	0.9061798459386640,
}

local GL5_W = {
	0.5688888888888889,
	0.4786286704993665,
	0.4786286704993665,
	0.2369268850561891,
	0.2369268850561891,
}

--< Functions

--Basic bernstein function to get the position at a given alpha
local function getBernsteinPosition(p1, p2, p3, p4, t)
	local t2 = t * t
	local t3 = t2 * t

	local b1 = -t3 + 3 * t2 - 3 * t + 1
	local b2 = 3 * t3 - 6 * t2 + 3 * t
	local b3 = -3 * t3 + 3 * t2
	local b4 = t3

	return p1 * b1 + p2 * b2 + p3 * b3 + p4 * b4
end

--Derivative of the getBernsteinPosition function to get the velocity
local function getBernsteinDerivative(p1, p2, p3, p4, t)
	local t2 = t * t
	local omt = 1 - t -- one minus t
	local omt2 = omt * omt --omt times 2

	local term1 = (p2 - p1) * (3 * omt2)
	local term2 = (p3 - p2) * (6 * omt * t)
	local term3 = (p4 - p3) * (3 * t2)

	return (term1 + term2 + term3)
end

--Second derivative (not used rn)
local function getBernsteinSecondDerivative(p1, p2, p3, p4, t)
	local omt = 1 - t

	local term1 = (p3 - 2 * p2 + p1) * (6 * omt)
	local term2 = (p4 - 2 * p3 + p2) * (6 * t)

	return term1 + term2
end

local function createPart(Properties)
	local newPart = Instance.new("Part")
	newPart.Size = Properties.Size or Vector3.one
	newPart.CFrame = Properties.CFrame or CFrame.new()
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.Material = Enum.Material.Neon
	newPart.Color = Properties.Color or Color3.new(1, 0, 0)
	newPart.Parent = Properties.Parent or workspace
	newPart.Transparency = Properties.Transparency or 0.5
	return newPart
end

----
-- Alpha based curve calculation functions
----

local function getSpeed(p1, p2, p3, p4, t)
	return getBernsteinDerivative(p1, p2, p3, p4, t).Magnitude
end

--Gets arc length of a curve by using Gauss method
local function getArcLength(p1, p2, p3, p4, a, b)
	if a == b then
		return 0
	end

	local half = (b - a) * 0.5
	local center = (a + b) * 0.5

	local sum = 0

	for i = 1, #GL5_X do
		local t = center + half * GL5_X[i]
		sum += GL5_W[i] * getSpeed(p1, p2, p3, p4, t)
	end

	return half * sum
end

local function getCurveLength(p1, p2, p3, p4)
	return getArcLength(p1, p2, p3, p4, 0, 1)
end

local function getTAtArcLength(p1, p2, p3, p4, targetLength, totalLength)
	if totalLength <= EPS then
		return 0
	end

	targetLength = math.clamp(targetLength, 0, totalLength)

	--If length is too low then return the start of spline
	if targetLength <= EPS then
		return 0
	end

	--If length is too high then return end of spline
	if math.abs(targetLength - totalLength) <= EPS then
		return 1
	end

	--Approximate t to a point where the distance is close to the localDistance (Newton-Raphson)
	local t = targetLength / totalLength
	local low = 0
	local high = 1

	for _ = 1, 12 do
		--Get the current length an error rate
		local currentLength = getArcLength(p1, p2, p3, p4, 0, t)
		local error = currentLength - targetLength

		--If error is small enough then return the final value
		if math.abs(error) < 1e-5 then
			return math.clamp(t, 0, 1)
		end

		--Adjust new high's an lows
		if error > 0 then
			high = t
		else
			low = t
		end

		--Get derivative magnitude of the curve
		local speed = getSpeed(p1, p2, p3, p4, t)

		--If speed is too low readjust t
		if speed <= EPS then
			t = (low + high) * 0.5
		else
			--If speed is normal then guess t again
			local newT = t - error / speed

			if newT <= low or newT >= high or newT ~= newT then
				t = (low + high) * 0.5
			else
				t = newT
			end
		end
	end

	return math.clamp(t, 0, 1)
end

local function cleanupPoint(point: Vector3 | Instance | CFrame)
	if typeof(point) == "Instance" and point:IsA("BasePart") then
		return point.Position
	elseif typeof(point) == "CFrame" then
		return point.Position
	elseif typeof(point) == "Vector3" then
		return point
	end

	error(
		`Tried to insert a point in a spline with a type that isn't supported: '{tostring(point)}' ({typeof(point)})`,
		3
	)
end

----
-- Helper functions
---

function SplineClass:_buildCurve(i: number)
	local Points = self.Points

	local P_prev = Points[(i - 2) % #Points + 1]
	local P0 = Points[(i - 1) % #Points + 1]
	local P1 = Points[i % #Points + 1]
	local P_next = Points[(i + 1) % #Points + 1]

	--print(Points)

	local tangent0 = (P1 - P_prev) * (self.Tension / 6)
	local tangent1 = (P_next - P0) * (self.Tension / 6)

	local p0 = P0
	local p1 = P0 + tangent0
	local p2 = P1 - tangent1
	local p3 = P1

	local curveLength = getCurveLength(p0, p1, p2, p3)
	local curve = {
		p0,
		p1,
		p2,
		p3,
		curveLength,
	}

	self.bezierCurves[i] = curve
	return curve
end

function SplineClass:_rebuildPoints(index, add)
	local rebuilt = {}

	for i = index - (2 + add), index + 1 do
		local curveIndex = i % #self.Points + 1
		local curve = self.bezierCurves[curveIndex]

		if rebuilt[curveIndex] then
			continue
		else
			rebuilt[curveIndex] = true
		end

		if curve then
			self.Length -= curve[5]
		end

		SplineClass._buildCurve(self, curveIndex)

		self.Length += self.bezierCurves[curveIndex][5]
	end

	if not self.Looped then
		self.Length -= self.bezierCurves[#self.Points][5]
		self.bezierCurves[#self.Points] = nil
	end
end

function SplineClass:_getCurveLocalT(targetDistance)
	local accumulatedDistance = 0

	if self.Length <= EPS then
		local curve = self.bezierCurves[1]
		return 0, curve
	end

	--TODO: Transform this into binary search (maybe?)
	for _, curve in self.bezierCurves do
		local curveLength = curve[5]
		local nextDistance = accumulatedDistance + curveLength

		if targetDistance <= nextDistance then
			local localDistance = targetDistance - accumulatedDistance

			local localT = getTAtArcLength(curve[1], curve[2], curve[3], curve[4], localDistance, curveLength)

			return localT, curve
		end

		accumulatedDistance = nextDistance
	end

	local curve = self.bezierCurves[#self.bezierCurves]
	return 1, curve
end

----
-- Main functions
----

function SplineClass:GetPosition(alpha, isLength)
	local targetDistance

	if isLength then
		alpha = math.clamp(alpha, 0, self.Length)
		targetDistance = alpha
	else
		alpha = math.clamp(alpha, 0, 1)
		targetDistance = alpha * self.Length
	end

	local localT, curve = self._getCurveLocalT(self, targetDistance)

	local position = getBernsteinPosition(curve[1], curve[2], curve[3], curve[4], localT)

	return position
end

function SplineClass:GetCFrame(alpha, isLength)
	local targetDistance

	if isLength then
		alpha = math.clamp(alpha, 0, self.Length)
		targetDistance = alpha
	else
		alpha = math.clamp(alpha, 0, 1)
		targetDistance = alpha * self.Length
	end

	local localT, curve = self._getCurveLocalT(self, targetDistance)

	local position = getBernsteinPosition(curve[1], curve[2], curve[3], curve[4], localT)

	local derivative = getBernsteinDerivative(curve[1], curve[2], curve[3], curve[4], localT)

	local direction = derivative.Unit

	return CFrame.lookAt(position, position + direction, Vector3.yAxis)
end

function SplineClass:DrawDebug(samples: number)
	local debugFolderName = `_DEBUG_SPLINE_{self.ID}`
	local debugFolder = workspace:FindFirstChild(debugFolderName) or Instance.new("Folder")
	debugFolder.Name = debugFolderName
	debugFolder.Parent = workspace
	debugFolder:ClearAllChildren()

	samples = samples or DEFAULT_DEBUG_SAMPLES
	local lastPosition = nil

	for i = 0, samples do
		local alpha = i / samples
		local position = self:GetPosition(alpha)

		createPart({
			Size = vector.create(1, 1, 1),
			CFrame = CFrame.new(position),
			Parent = debugFolder,
		})

		if lastPosition then
			local direction = position - lastPosition
			local dist = direction.Magnitude

			if dist > 0 then
				createPart({
					Size = vector.create(0.25, 0.25, dist),
					CFrame = CFrame.lookAt(lastPosition + direction * 0.5, position),
					Parent = debugFolder,
					Color = Color3.new(0, 1, 0),
				})
			end
		end

		createPart({
			Size = vector.create(0.5, 0.5, 1),
			CFrame = self:GetCFrame(alpha) * CFrame.new(0, 0, -0.5),
			Parent = debugFolder,
			Color = Color3.new(0, 0, 1),
		})

		lastPosition = position
	end
end

function SplineClass:RemoveDebug()
	local debugFolderName = `_DEBUG_SPLINE_{self.ID}`
	local debugFolder = workspace:FindFirstChild(debugFolderName)

	if debugFolder then
		debugFolder:Destroy()
	end
end

function SplineClass:SetPoint(point: Vector3 | Instance | CFrame, index: number)
	point = cleanupPoint(point)

	self.Points[index] = point

	self._rebuildPoints(self, index, 0)
end

function SplineClass:InsertPoint(point: Vector3 | Instance | CFrame, index: number?)
	point = cleanupPoint(point)
	index = index or #self.Points + 1

	table.insert(self.Points, index, point)

	self._rebuildPoints(self, index, 1)
end

function SplineClass:RemovePoint(index: number)
	index = index or #self.Points + 1

	table.remove(self.Points, index)

	self._rebuildPoints(self, index, -1)
end

function SplineClass:Destroy()
	if self.bezierCurves then
		table.clear(self.bezierCurves)
	end

	if self.Points then
		table.clear(self.Points)
	end

	if self.segmentCache then
		table.clear(self.segmentCache)
	end

	table.clear(self)
	self = nil
end

--< Main

function SplineClass.new(Points: { Vector3 | Instance | CFrame }, Settings: SplineSettings)
	local self = setmetatable({}, SplineClass)

	--<< SETTINGS

	self.Points = table.clone(Points) :: { Vector3 }
	self.Settings = Settings or {} :: {}
	self.bezierCurves = {} :: { [number]: { Vector3 } }
	self.Tension = self.Settings.Tension or 1
	self.Looped = (self.Settings.Looped ~= nil) and self.Settings.Looped or false
	self.ID = ID
	self.Length = 0

	--<< SETUP

	--< Cleanup points to position
	for i, v in self.Points do
		self.Points[i] = cleanupPoint(v)
	end

	--< Build bezier curves
	for i = 1, #self.Points do
		self:_buildCurve(i)
	end

	--< If spline isnt looped, delete last curve
	if not self.Looped then
		self.bezierCurves[#self.Points] = nil
	end

	--< Add up all curves
	for _, curve in self.bezierCurves do
		self.Length += curve[5]
	end

	ID += 1
	return self
end

--End

return SplineClass :: SplineClass
