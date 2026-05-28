--!strict

local DEFAULT_LENGTH_OPTIONS: Path3DLengthOptions = {
	recordedSplits = 35,
	minimumLength = 0.5,
	minimumSplits = 0,
	minimumSuccesses = 2,
	maximumSplits = 0,
}

local Path3D = {}

local path3dMetatable = {}
local internalDataMetatable = {}

Path3D.Version = "1.1.1"
Path3D.VersionMajor = 1
Path3D.VersionMinor = 1
Path3D.VersionPatch = 1

--Length Options Creation
do
	--[[
	This function validates that each entry in the length options table is correct, throwing an error if any
	  entries are not properly structured
	  
	<strong>lengthOptions</strong>: The length options table to validate
	<strong>errorLevel</strong>: The level that should be passed to the error function
	]]
	function validateLengthOptions(lengthOptions: Path3DLengthOptions?, errorLevel: number): nil
		if typeof(lengthOptions) ~= "table" then
			error("Attempt to use non-Path3DLengthOptions in place of Path3DLengthOptions", errorLevel)
		end

		if lengthOptions.recordedSplits == nil then
			error("Attempt to use Path3DLengthOptions with nil recordedSplits entry", errorLevel)
		end
		if lengthOptions.minimumLength == nil then
			error("Atttempt to use Path3DLengthOptions with nil minimumLength entry", errorLevel)
		end
		if lengthOptions.minimumSuccesses == nil then
			error("Atttempt to use Path3DLengthOptions with nil minimumSuccesses entry", errorLevel)
		end
		if lengthOptions.minimumSplits == nil then
			error("Atttempt to use Path3DLengthOptions with nil minimumSplits entry", errorLevel)
		end
		if lengthOptions.maximumSplits == nil then
			error("Atttempt to use Path3DLengthOptions with nil maximumSplits entry", errorLevel)
		end

		if typeof(lengthOptions.recordedSplits) ~= "number" then
			error(
				"Invalid value for Path3DLengthOptions.recordedSplits, expected number, got "
					.. typeof(lengthOptions.recordedSplits),
				errorLevel
			)
		end
		if typeof(lengthOptions.minimumLength) ~= "number" then
			error(
				"Invalid value for Path3DLengthOptions.minimumLength, expected number, got "
					.. typeof(lengthOptions.minimumLength),
				errorLevel
			)
		end
		if typeof(lengthOptions.minimumSuccesses) ~= "number" then
			error(
				"Invalid value for Path3DLengthOptions.minimumSuccesses, expected number, got "
					.. typeof(lengthOptions.minimumLength),
				errorLevel
			)
		end
		if typeof(lengthOptions.minimumSplits) ~= "number" then
			error(
				"Invalid value for Path3DLengthOptions.minimumSplits, expected number, got "
					.. typeof(lengthOptions.minimumLength),
				errorLevel
			)
		end
		if typeof(lengthOptions.maximumSplits) ~= "number" then
			error(
				"Invalid value for Path3DLengthOptions.maximumSplits, expected number, got "
					.. typeof(lengthOptions.minimumLength),
				errorLevel
			)
		end

		if lengthOptions.recordedSplits <= 0 then
			error(
				"Invalid value for Path3DLengthOptions.recordedSplits, recorded splits must be greater than 0",
				errorLevel
			)
		end
		if math.floor(lengthOptions.recordedSplits) ~= lengthOptions.recordedSplits then
			error(
				"Invalid value for Path3DLengthOptions.recordedSpltis, recorded splits must be a whole integer",
				errorLevel
			)
		end
		if lengthOptions.minimumLength <= 0 then
			error(
				"Invalid value for Path3DLengthOptions.minimumLength, minimum length must be greater than 0",
				errorLevel
			)
		end
		if lengthOptions.minimumSuccesses < 0 then
			error(
				"Invalid value for Path3DLengthOptions.minimumSuccesses, minimum successes must be greater than or equal to 0",
				errorLevel
			)
		end
		if lengthOptions.minimumSplits < 0 then
			error(
				"Invalid value for Path3DLengthOptions.minimumSplits, minimum splits must be greater than or equal to 0",
				errorLevel
			)
		end
		if lengthOptions.maximumSplits < 0 then
			error(
				"Invalid value for Path3DLengthOptions.maximumSplits, maximumSplits must be greater than or equal to 0",
				errorLevel
			)
		end
		if lengthOptions.minimumSplits > lengthOptions.maximumSplits and lengthOptions.maximumSplits ~= 0 then
			error(
				"Invalid value for Path3DLengthOptions.minimumSplits and Path3DLengthOptions.maximumSplits, minimum splits cannot exceed maximum splits",
				errorLevel
			)
		end

		return nil
	end

	--[[
	This function creates a new Path3DLengthOptions object with the given values
	
	<strong>recordedSplits</strong>: The number of splits within each segment to record in order to adjust t values (Defaults to 35)
	<strong>minimumLength</strong>: The minimum distance between the two points that the length evaluator must see before returning (Defaults to 0.5)
	<strong>minimumSuccesses</strong>: The minimum ammount of times that the the evaluator must concurrently find that the two points are closer than the minimumLength (Defaults to 2)
	<strong>minimumSplits</strong>: The minimum recurssion depth that the evaluator must reach (Defaults to 0)
	<strong>maximumSplits</strong>: The maximum recurssion depth that the evaluator can reach, set to 0 to disable (Defaults to 0)
	
	<strong>Return</strong>: A Path3DLengthOptions table with the given options
	]]
	function Path3D.newLengthOptions(
		recordedSplits: number?,
		minimumLength: number?,
		minimumSuccesses: number?,
		minimumSplits: number?,
		maximumSplits: number?
	): Path3DLengthOptions
		local lengthOptions = {
			["recordedSplits"] = recordedSplits or DEFAULT_LENGTH_OPTIONS.recordedSplits,
			["minimumLength"] = minimumLength or DEFAULT_LENGTH_OPTIONS.minimumLength,
			["minimumSuccesses"] = minimumSuccesses or DEFAULT_LENGTH_OPTIONS.minimumSuccesses,
			["minimumSplits"] = minimumSplits or DEFAULT_LENGTH_OPTIONS.minimumSplits,
			["maximumSplits"] = maximumSplits or DEFAULT_LENGTH_OPTIONS.maximumSplits,
		}

		validateLengthOptions(lengthOptions, 3)

		return lengthOptions
	end
end

--Anchor Tables Creation
do
	--[[
	This function creates a new anchor table with the provided prior control point, anchor point, and next control point. An important detail to note is that although anchorPoint is expressed as an offset from the path's center, priorControlPoint and nextControlPoint are offsets from the anchor point.
	
	<strong>priorControlPoint</strong>: The offset of the prior control point from the anchor point. Leave as nil if there is no prior control point
	<strong>anchorPoint</strong>: The offset of the anchor point from the path's center
	<strong>nextControlPoint</strong>: The offset of the next control point from the anchor point. Leave as nil if there is no next control point
	
	<strong>Return</strong>: An anchor table with the given prior and next control points, as well as the given anchor point
	]]
	function Path3D.newAnchorTable(
		priorControlPoint: Vector3?,
		anchorPoint: Vector3,
		nextControlPoint: Vector3?
	): Path3DAnchorTable
		if priorControlPoint ~= nil and typeof(priorControlPoint) ~= "Vector3" then
			error(
				"Attempt to create Path3DAnchorTable with non-Vector3 prior control point offset (Expected Vector3 or nil, got "
					.. typeof(priorControlPoint)
					.. ")",
				2
			)
		end

		if typeof(anchorPoint) ~= "Vector3" then
			error(
				"Attempt to create Path3DAnchorTable with non-Vector3 anchor offset (Expected Vector3, got "
					.. typeof(anchorPoint)
					.. ")",
				2
			)
		end

		if nextControlPoint ~= nil and typeof(nextControlPoint) ~= "Vector3" then
			error(
				"Attempt to create Path3DAnchorTable with non-Vector3 next control point offset (Expected Vector3 or nil, got "
					.. typeof(nextControlPoint)
					.. ")",
				2
			)
		end

		return {
			["priorControlPoint"] = priorControlPoint,
			["anchor"] = anchorPoint,
			["nextControlPoint"] = nextControlPoint,
		}
	end
end

--Constructors
do
	--fromPathString
	do
		--[[
		This function parses a given string to extract a Vector3 starting at the given index, returning false if it
		  was unable to
		
		<strong>stringToParse</strong>: The string to parse for a Vector3
		<strong>init</strong>: Where in the string to start parsing for a Vector3
		
		<strong>Return</strong>: The next properly formatted Vector3 in the given string starting the given index,
		  or false if it was unable to parse it
		]]
		local function parseVector3(stringToParse: string, init: number): (Vector3 | boolean, number?)
			local parseIndex = init
			local xString = ""
			while parseIndex <= string.len(stringToParse) do
				local checkChar = string.sub(stringToParse, parseIndex, parseIndex)

				parseIndex += 1
				if checkChar == "," then
					break
				end

				xString = xString .. checkChar
			end

			if tonumber(xString) == nil then
				return false, nil
			end

			local yString = ""
			while parseIndex <= string.len(stringToParse) do
				local checkChar = string.sub(stringToParse, parseIndex, parseIndex)

				parseIndex += 1

				if checkChar == "," then
					break
				end

				yString = yString .. checkChar
			end

			if tonumber(yString) == nil then
				return false, nil
			end

			local zString = ""
			while parseIndex <= string.len(stringToParse) do
				local checkChar = string.sub(stringToParse, parseIndex, parseIndex)

				if checkChar == " " or checkChar == "/" then
					break
				end

				zString = zString .. checkChar
				parseIndex += 1
			end

			if tonumber(zString) == nil then
				return false, nil
			end

			return Vector3.new(tonumber(xString), tonumber(yString), tonumber(zString)), parseIndex
		end

		--[[
		This function parses the given path string, returning an array of anchor points and their control points in
		  order.
		
		<strong>pathString</strong>: The path string to parse
		
		<strong>Return</strong>: An array of anchor points and their control point
		]]
		local function parsePathString(pathString: string): { Path3DAnchorTable }
			local returnArray: { Path3DAnchorTable } = {}

			local i = 3
			while i <= string.len(pathString) do --Since we'll need to change i during this loop
				local controlPointIndentifier = string.sub(pathString, i, i)

				if tonumber(controlPointIndentifier) == nil then
					error(
						"Malformed path string provded to Path3D.fromPathString (Control point identifier at index "
							.. i
							.. " is not a number)",
						3
					)
				end
				controlPointIndentifier = tonumber(controlPointIndentifier) :: number

				if
					controlPointIndentifier < 0 --This isn't possible
					or controlPointIndentifier > 3
				then
					error(
						"Malformed path string provded to Path3D.fromPathString (Control point identifier at index "
							.. i
							.. " is not in the range of 0-3)",
						3
					)
				end

				local anchorTable = {}
				if controlPointIndentifier == 0 then
					local anchorPos, anchorParseEndIndex = parseVector3(pathString, i + 2)

					if anchorPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for anchor offset at index "
								.. i
								.. ")",
							3
						)
					end
					anchorPos = anchorPos :: Vector3
					anchorParseEndIndex = anchorParseEndIndex :: number

					i = anchorParseEndIndex + 1
					anchorTable.anchor = anchorPos
				elseif controlPointIndentifier == 1 then
					local priorControlPointPos, priorControlPointParseEndIndex = parseVector3(pathString, i + 2)

					if priorControlPointPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for prior control point offset at index "
								.. i
								.. ")",
							3
						)
					end
					priorControlPointPos = priorControlPointPos :: Vector3
					priorControlPointParseEndIndex = priorControlPointParseEndIndex :: number

					local anchorPos, anchorParseEndIndex = parseVector3(pathString, priorControlPointParseEndIndex + 1)

					if anchorPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for anchor offset at index "
								.. (priorControlPointParseEndIndex + 1)
								.. ")",
							3
						)
					end
					anchorPos = anchorPos :: Vector3
					anchorParseEndIndex = anchorParseEndIndex :: number

					i = anchorParseEndIndex + 1
					anchorTable.priorControlPoint = priorControlPointPos + anchorPos
					anchorTable.anchor = anchorPos
				elseif controlPointIndentifier == 2 then
					local anchorPos, anchorParseEndIndex = parseVector3(pathString, i + 2)

					if anchorPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for anchor offset at index "
								.. i
								.. ")",
							3
						)
					end
					anchorPos = anchorPos :: Vector3
					anchorParseEndIndex = anchorParseEndIndex :: number

					local nextControlPointPos, nextControlPointParseEndIndex =
						parseVector3(pathString, anchorParseEndIndex + 1)

					if nextControlPointPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for next control point offset at index "
								.. (anchorParseEndIndex + 1)
								.. ")",
							3
						)
					end
					nextControlPointPos = nextControlPointPos :: Vector3
					nextControlPointParseEndIndex = nextControlPointParseEndIndex :: number

					i = nextControlPointParseEndIndex + 1
					anchorTable.nextControlPoint = nextControlPointPos + anchorPos
					anchorTable.anchor = anchorPos
				else
					local priorControlPointPos, priorControlPointParseEndIndex = parseVector3(pathString, i + 2)

					if priorControlPointPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for prior control point offset at index "
								.. i
								.. ")",
							3
						)
					end
					priorControlPointPos = priorControlPointPos :: Vector3
					priorControlPointParseEndIndex = priorControlPointParseEndIndex :: number

					local anchorPos, anchorParseEndIndex = parseVector3(pathString, priorControlPointParseEndIndex + 1)

					if anchorPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for anchor offset at index "
								.. (priorControlPointParseEndIndex + 1)
								.. ")",
							3
						)
					end
					anchorPos = anchorPos :: Vector3
					anchorParseEndIndex = anchorParseEndIndex :: number

					local nextControlPointPos, nextControlPointParseEndIndex =
						parseVector3(pathString, anchorParseEndIndex + 1)

					if nextControlPointPos == false then
						error(
							"Malformed path string provded to Path3D.fromPathString (Malformed Vector3 for next control point offset at index "
								.. (anchorParseEndIndex + 1)
								.. ")",
							3
						)
					end
					nextControlPointPos = nextControlPointPos :: Vector3
					nextControlPointParseEndIndex = nextControlPointParseEndIndex :: number

					i = nextControlPointParseEndIndex + 1
					anchorTable.priorControlPoint = priorControlPointPos + anchorPos
					anchorTable.anchor = anchorPos
					anchorTable.nextControlPoint = nextControlPointPos + anchorPos
				end

				anchorTable = anchorTable :: Path3DAnchorTable
				table.insert(returnArray, anchorTable)
			end

			return returnArray
		end

		--[[
		This function constructs a new Path3D instance from the provided path string. Formatting information regarding the path string can be found in the Path3D DevForum post
		
		<strong>pathString</strong>: The path string representing the desried path, generated either by hand or by the Path3D Editor
		<strong>position</strong>: The location of the pivot point of the Path3D
		<strong>lengthOption</strong>: The options regarding how the length of the Path3D should be evaluated
		
		<strong>Return</strong>: A Path3D of the given path string
		]]
		function Path3D.fromPathString(
			pathString: string,
			position: Vector3?,
			lengthOptions: Path3DLengthOptions?
		): Path3D
			if lengthOptions == nil then
				lengthOptions = DEFAULT_LENGTH_OPTIONS
			end

			validateLengthOptions(lengthOptions, 3)
			lengthOptions = lengthOptions :: Path3DLengthOptions

			if position == nil then
				position = Vector3.new(0, 0, 0)
			end

			if typeof(position) ~= "Vector3" then
				error(
					"Attempt to invoke Path3D.fromPathString with non-Vector3 position. (Expected Vector3 or nil, got "
						.. typeof(position)
						.. ")",
					2
				)
			end

			if typeof(pathString) ~= "string" then
				error(
					"Attempt to invoke Path3D.fromPathString with non-string path string. (Expected string, got "
						.. typeof(pathString)
						.. ")",
					2
				)
			end

			local self = {}

			self._internalData = {}

			self._internalData.anchorTables = parsePathString(pathString)

			if #self._internalData.anchorTables <= 1 then
				error("Attempt to create Path3D with less than two anchor points", 2)
			end

			local segmentLengths, splitTAdjustments = getPathLength(self._internalData.anchorTables, lengthOptions)
			self._internalData.segmentLengths = segmentLengths
			self._internalData.splitTAdjustments = splitTAdjustments
			setmetatable(self._internalData, internalDataMetatable)

			self.Length = 0
			for _, lengthOfSegment in ipairs(self._internalData.segmentLengths) do
				self.Length += lengthOfSegment
			end

			self.Position = position

			self.__type = "Path3D"
			self.ClassName = "Path3D"

			setmetatable(self, path3dMetatable)

			self = self :: Path3D
			return self
		end
	end

	--fromAnchorTables
	do
		--[[
		This function checks to see whether or not the given table is a properly formatted Path3DAnchorTable,
		  throwing an error if it isn't
		
		<strong>anchorTable</strong>: The anchor table to check the formatting of	
		<strong>index</strong>: The anchor table's index in the parameters 
		]]
		local function validateAnchorTable(anchorTable: Path3DAnchorTable, index: number): nil
			if typeof(anchorTable) ~= "table" then
				error(
					"Anchor table "
						.. index
						.. " passed to Path3D.fromAnchorTables() is not a table (Expected table, got "
						.. typeof(anchorTable)
						.. ")",
					3
				)
			end

			if typeof(anchorTable.anchor) ~= "Vector3" then
				error(
					"anchor property of anchor table "
						.. index
						.. " passed to Path3D.fromAnchorTables() is not a Vector3 (Expected Vector3, got "
						.. typeof(anchorTable.anchor)
						.. ")",
					3
				)
			end

			if anchorTable.priorControlPoint ~= nil and typeof(anchorTable.priorControlPoint) ~= "Vector3" then
				error(
					"priorControlPoint property of anchor table "
						.. index
						.. " passed to Path3D.fromanchorTables() is not a Vector3 (Expected Vector3 or nil, got "
						.. typeof(anchorTable.priorControlPoint)
						.. ")",
					3
				)
			end

			if anchorTable.nextControlPoint ~= nil and typeof(anchorTable.nextControlPoint) ~= "Vector3" then
				error(
					"nextControlPoint property of anchor table "
						.. index
						.. " passed to Path3D.fromanchorTables() is not a Vector3 (Expected Vector3 or nil, got "
						.. typeof(anchorTable.priorControlPoint)
						.. ")",
					3
				)
			end

			return nil
		end

		--[[
		This function constructs a new Path3D instance from the provided anchor tables. Use Path3D.newAnchorTable() to create a new anchor table
		
		<strong>anchorTables</strong>: The anchor tables for each of the control points in the Path3D
		<strong>position</strong>: The location of the pivot point of the Path3D
		<strong>lengthOption</strong>: The options regarding how the length of the Path3D should be evaluated
		
		<strong>Return</strong>: A Path3D of the given path string
		]]
		function Path3D.fromAnchorTables(...): Path3D
			local passedArguments = { ... }
			local anchorTables: { Path3DAnchorTable } = {}
			local position: Vector3
			local lengthOptions: Path3DLengthOptions

			local checkIndex = 1
			for i, argument in ipairs(passedArguments) do
				checkIndex = i

				if typeof(argument) == "Vector3" then
					position = argument
					break
				end

				--Just a super simple way to check if this is the length options table since any nil parameters
				--  are removed when passed to variadic functions
				if typeof(argument) == "table" and argument.recordedSplits ~= nil then
					lengthOptions = argument
					break
				end

				table.insert(anchorTables, argument)
			end

			if checkIndex + 1 <= #passedArguments and lengthOptions == nil then
				lengthOptions = passedArguments[checkIndex + 1]
				checkIndex += 1
			end

			if checkIndex + 1 <= #passedArguments then
				error("Trailing arguments past length options table passed to Path3D.fromAnchorTables()", 2)
			end

			if #anchorTables <= 1 then
				error("Attempt to create Path3D with less than two anchor points", 2)
			end

			for index, anchorTable in ipairs(anchorTables) do
				validateAnchorTable(anchorTable, index)
			end

			if lengthOptions == nil then
				lengthOptions = DEFAULT_LENGTH_OPTIONS
			end

			validateLengthOptions(lengthOptions, 3)

			if position == nil then
				position = Vector3.new(0, 0, 0)
			end

			if typeof(position) ~= "Vector3" then
				error(
					"Attempt to invoke Path3D.fromPathAnchorTables with non-Vector3 position. (Expected Vector3 or nil, got "
						.. typeof(position)
						.. ")",
					2
				)
			end

			local self = {}

			self._internalData = {}

			self._internalData.anchorTables = anchorTables
			local segmentLengths, splitTAdjustments = getPathLength(anchorTables, lengthOptions)
			self._internalData.segmentLengths = segmentLengths
			self._internalData.splitTAdjustments = splitTAdjustments
			setmetatable(self._internalData, internalDataMetatable)

			self.Length = 0
			for _, lengthOfSegment in ipairs(self._internalData.segmentLengths) do
				self.Length += lengthOfSegment
			end

			self.Position = position

			self.__type = "Path3D"
			self.ClassName = "Path3D"

			setmetatable(self, path3dMetatable)

			self = self :: Path3D
			return self
		end
	end
end

--Internal Data Metatable
do
	internalDataMetatable.__newindex = function()
		error(
			"Attempt to write to internal Path3D data (Don't do this! If you have to modify a Path3D instance, please create a new one instead)",
			2
		)
	end

	internalDataMetatable.__metatable = {}
end

--Meta Methods
do
	path3dMetatable.__index = path3dMetatable
	path3dMetatable.__metatable = {}

	--[[
	This function prevents the user from setting any proprties of the Path3D object, immediately throwing an
	  error unless they are setting the Position property
	]]
	path3dMetatable.__newindex = function(modifiedTable, newIndex, newValue)
		if newIndex == "Position" then
			if typeof(newValue) ~= "Vector3" then
				error("Unable to assign property Position of Path3D. Vector3 expected, got " .. typeof(newValue))
			end
			rawset(modifiedTable, "Position", newValue)
		end

		-- This could result in `tostring(newIndex)` being replaced with 'nil', but if someone's doing something
		--   where that is a possibility, then they're using the module wrong, as the only property they should
		--   be setting is 'Position', which is a string key, which will never return `nil` from `tostring()`
		error("Attempt to set set property " .. tostring(newIndex) .. " of Path3D", 2)
	end

	--[[
	This method causes any tostring operations on the table to return Path3D
	]]
	path3dMetatable.__tostring = function()
		return "Path3D"
	end
end

--Bezier Curve Evaluation
do
	--[[
	All of these functions use simplified versions of their Bezier curve formulas which make absolutely no
	  sense if you don't understand where they came from. If you're trying to figure out how Bezier curves work,
	  don't look at these, instead I'd recommend a video by Guidev which does an amazing job explaining where
	  these formulas come from. Thanks to Wikipedia for these versions of the formulas
	
	https://www.youtube.com/watch?v=pnYccz1Ha34
	]]

	--[[
	This function takes in the p0 and p1 of a linear bezier curve and how far along that curve to evaluate it
	  at, then returns where that point is
	
	<strong>t</strong>: Where along the curve to evaluate it
	<strong>p0</strong>: The first anchor point
	<strong>p1</strong>: The last anchor point
	
	<strong>Return</strong>: The position along the curve given by t
	]]
	function evaluateLinearBezierCurve(t: number, p0: Vector3, p1: Vector3): Vector3
		return Vector3.new((1 - t) * p0.X + t * p1.X, (1 - t) * p0.Y + t * p1.Y, (1 - t) * p0.Z + t * p1.Z)
	end

	--[[
	This function takes in the p0, p1 and p2 of a quadratic bezier curve and how far along that curve to evaluate
	  it at, then returns where that point is
	
	<strong>t</strong>: Where along the curve to evaluate it
	<strong>p0</strong>: The first anchor point
	<strong>p1</strong>: The first control point
	<strong>p2</strong>: The last anchor point
	
	<strong>Return</strong>: The position along the curve given by t
	]]
	function evaluateQuadraticBezierCurve(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
		return Vector3.new(
			p1.X + (1 - t) ^ 2 * (p0.X - p1.X) + t ^ 2 * (p2.X - p1.X),
			p1.Y + (1 - t) ^ 2 * (p0.Y - p1.Y) + t ^ 2 * (p2.Y - p1.Y),
			p1.Z + (1 - t) ^ 2 * (p0.Z - p1.Z) + t ^ 2 * (p2.Z - p1.Z)
		)
	end

	--[[
	This function takes in the p0, p1, p2, and p3 of a cubic bezier curve and how far along that curve to evaluate
	  it at, then returns where that point is
	
	<strong>t</strong>: Where along the curve to evaluate it
	<strong>p0</strong>: The first anchor point
	<strong>p1</strong>: The first control point
	<strong>p2</strong>: The second control point
	<strong>p3</strong>: The last anchor point
	
	<strong>Return</strong>: The position along the curve given by t
	]]
	function evaluateCubicBezierCurve(t: number, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3): Vector3
		return Vector3.new(
			(1 - t) ^ 3 * p0.X + 3 * (1 - t) ^ 2 * t * p1.X + 3 * (1 - t) * t ^ 2 * p2.X + t ^ 3 * p3.X,
			(1 - t) ^ 3 * p0.Y + 3 * (1 - t) ^ 2 * t * p1.Y + 3 * (1 - t) * t ^ 2 * p2.Y + t ^ 3 * p3.Y,
			(1 - t) ^ 3 * p0.Z + 3 * (1 - t) ^ 2 * t * p1.Z + 3 * (1 - t) * t ^ 2 * p2.Z + t ^ 3 * p3.Z
		)
	end

	--[[
	This function takes in two anchor tables and where to evaluate along their curve, then returns the point
	  at that percentage along the curve formed by the two anchors and their control points
	
	<strong>t</strong>: The percentage along the curve to evaluate at
	<strong>firstAnchorTable</strong>: The first anchor point's anchor table
	<strong>secondAnchorTable</strong>: The second anchor point's anchor table
	
	<strong>Return</strong>: The position of the given point along the given curve
	]]
	function evaluateAnchorTablesCurve(
		t: number,
		firstAnchorTable: Path3DAnchorTable,
		secondAnchorTable: Path3DAnchorTable
	): Vector3
		if firstAnchorTable.nextControlPoint and secondAnchorTable.priorControlPoint then
			return evaluateCubicBezierCurve(
				t,
				firstAnchorTable.anchor,
				firstAnchorTable.nextControlPoint,
				secondAnchorTable.priorControlPoint,
				secondAnchorTable.anchor
			)
		elseif firstAnchorTable.nextControlPoint then
			return evaluateQuadraticBezierCurve(
				t,
				firstAnchorTable.anchor,
				firstAnchorTable.nextControlPoint,
				secondAnchorTable.anchor
			)
		elseif secondAnchorTable.priorControlPoint then
			return evaluateQuadraticBezierCurve(
				t,
				firstAnchorTable.anchor,
				secondAnchorTable.priorControlPoint,
				secondAnchorTable.anchor
			)
		else
			return evaluateLinearBezierCurve(t, firstAnchorTable.anchor, secondAnchorTable.anchor)
		end
	end
end

--Length Evaluation
do
	--[[
	This function recurssively splits the given curve in half, evaluating the length between each segment until
	  all of the conditions in the lengthOptions are satisfied, at which point it will return the sum of all the
	  distances between each point
	  
	<strong>firstAnchorTable</strong>: The starting anchor's anchor table
	<strong>secondAnchorTable</strong>: The ending anchor's anchor table
	<strong>startPoint</strong>: Where along the curve to start the distance check
	<strong>endPoint</strong>: Where along the curve to end the distance check
	<strong>lengthOptions</strong>: The length options for evaluating the length of the curve
	<strong>successes</strong>: The amount of concurrent splits that have been less than the minimum distance
	<strong>recursionDepth</strong>: How deep into the recursion we currently are
	
	<strong>Return</strong>: The distance between the two point on the curve
	]]
	local function recurssiveLengthEvaluation(
		firstAnchorTable: Path3DAnchorTable,
		secondAnchorTable: Path3DAnchorTable,
		startPoint: number,
		endPoint: number,
		lengthOptions: Path3DLengthOptions,
		successes: number,
		recursionDepth: number
	): number
		if recursionDepth < lengthOptions.minimumSplits then
			return recurssiveLengthEvaluation(
				firstAnchorTable,
				secondAnchorTable,
				startPoint,
				(startPoint + endPoint) / 2,
				lengthOptions,
				0,
				recursionDepth + 1
			) + recurssiveLengthEvaluation(
				firstAnchorTable,
				secondAnchorTable,
				(startPoint + endPoint) / 2,
				endPoint,
				lengthOptions,
				0,
				recursionDepth + 1
			)
		end

		local startPointPos = evaluateAnchorTablesCurve(startPoint, firstAnchorTable, secondAnchorTable)
		local endPointPos = evaluateAnchorTablesCurve(endPoint, firstAnchorTable, secondAnchorTable)

		local distanceBetweenPoints = math.sqrt(
			(startPointPos.X - endPointPos.X) ^ 2
				+ (startPointPos.Y - endPointPos.Y) ^ 2
				+ (startPointPos.Z - endPointPos.Z) ^ 2
		)

		if
			(recursionDepth >= lengthOptions.maximumSplits and lengthOptions.maximumSplits ~= 0)
			or (distanceBetweenPoints <= lengthOptions.minimumLength and successes >= lengthOptions.minimumSuccesses)
		then
			return distanceBetweenPoints
		end

		if distanceBetweenPoints < lengthOptions.minimumLength then
			return recurssiveLengthEvaluation(
				firstAnchorTable,
				secondAnchorTable,
				startPoint,
				(startPoint + endPoint) / 2,
				lengthOptions,
				successes + 1,
				recursionDepth + 1
			) + recurssiveLengthEvaluation(
				firstAnchorTable,
				secondAnchorTable,
				(startPoint + endPoint) / 2,
				endPoint,
				lengthOptions,
				successes + 1,
				recursionDepth + 1
			)
		end

		return recurssiveLengthEvaluation(
			firstAnchorTable,
			secondAnchorTable,
			startPoint,
			(startPoint + endPoint) / 2,
			lengthOptions,
			0,
			recursionDepth + 1
		) + recurssiveLengthEvaluation(
			firstAnchorTable,
			secondAnchorTable,
			(startPoint + endPoint) / 2,
			endPoint,
			lengthOptions,
			0,
			recursionDepth + 1
		)
	end

	--[[
	This function evaluates and returns the length of each split in each segment of a Path3D
	
	<strong>Return 1</strong>: An array of the lengths of each segment
	<strong>Return 2</strong>: An array with each index representing a segment, containing an array of the
	  actual t values for each split in the segment i order to establish a linear distribution of t values
	]]
	function getPathLength(
		anchorTables: { Path3DAnchorTable },
		lengthOptions: Path3DLengthOptions
	): ({ number }, { { number } })
		local segmentLengths = {}
		local allSplitTValues = {}

		for anchorTableIndex = 1, #anchorTables - 1, 1 do
			local currentAnchorTable = anchorTables[anchorTableIndex]
			local nextAnchorTable = anchorTables[anchorTableIndex + 1]

			local splitTValues = {}

			local currentSegmentLength = 0
			for splitIndex = 1, lengthOptions.recordedSplits, 1 do
				currentSegmentLength += recurssiveLengthEvaluation(
					currentAnchorTable,
					nextAnchorTable,
					splitIndex / lengthOptions.recordedSplits,
					(splitIndex + 1) / lengthOptions.recordedSplits,
					lengthOptions,
					0,
					0
				)

				splitTValues[splitIndex] = currentSegmentLength
			end

			segmentLengths[anchorTableIndex] = currentSegmentLength

			for i, v in ipairs(splitTValues) do
				splitTValues[i] = v / currentSegmentLength
			end

			allSplitTValues[anchorTableIndex] = splitTValues
		end

		return segmentLengths, allSplitTValues
	end
end

--Get Unadjusted Position on Curve
do
	--[[
	This function returns where in the world the given point along the Path3D is without applying the adjustments to ensure t values are linearly distributed. Note that this may cause a "slowing down" on corners, and a "speeding up" along straight segments of the Path3D
	
	<strong>t</strong>: A number from 0-1 representing where along the Path3D the point should be sampled at
	
	<strong>Return</strong>: A Vector3 at the given point along the Path3D
	]]
	function path3dMetatable.GetUnadjustedPositionOnCurve(self: Path3D, t: number): Vector3
		self = self :: Path3DInternal
		if typeof(t) ~= "number" then
			error(
				"Unable to invoke Path3D:GetUnadjustedPositionOnCurve with given t value, expected number, got "
					.. typeof(t)
			)
		end
		if t < 0 then
			error("Attempt to call Path3D:GetUnadjustedPositionOnCurve with t value less than 0")
		elseif t > 1 then
			error("Attempt to call Path3D:GetUnadjustedPositionOnCurve with t value greater than 1")
		end

		if t == 1 then --Edge case for when we get to the last curve in the Path
			return self._internalData.anchorTables[#self._internalData.anchorTables].anchor + self.Position
		end

		local distanceAlongPath = self.Length * t

		local segmentToEvaluate = 1
		local distanceAlongSegment = distanceAlongPath

		for i, segmentLength in ipairs(self._internalData.segmentLengths) do
			segmentToEvaluate = i

			if segmentLength > distanceAlongSegment then
				break
			end

			distanceAlongSegment -= segmentLength
		end

		local segmentT = distanceAlongSegment / self._internalData.segmentLengths[segmentToEvaluate]
		local startAnchorTable = self._internalData.anchorTables[segmentToEvaluate]
		local endAnchorTable = self._internalData.anchorTables[segmentToEvaluate + 1]

		return evaluateAnchorTablesCurve(segmentT, startAnchorTable, endAnchorTable) + self.Position
	end
end

--Get Position On Curve
do
	--[[
	This function returns where in the world the given point along the Path3D is. This function adjusts the given t value to be linearly distributed along the curve
	
	<strong>t</strong>: A number from 0-1 representing where along the Path3D the point should be sampled at
	
	<strong>Return</strong>: A Vector3 at the given point along the Path3D
	]]
	function path3dMetatable.GetPositionOnCurve(self: Path3D, t: number): Vector3
		self = self :: Path3DInternal
		if typeof(t) ~= "number" then
			error("Unable to invoke Path3D:GetPositionOnCurve with given t value, expected number, got " .. typeof(t))
		end
		if t < 0 then
			error("Attempt to call Path3D:GetPositionOnCurve with t value less than 0")
		elseif t > 1 then
			error("Attempt to call Path3D:GetPositionOnCurve with t value greater than 1")
		end

		if t == 1 then --Edge case for when we get to the last curve in the Path
			return self._internalData.anchorTables[#self._internalData.anchorTables].anchor + self.Position
		end

		local distanceAlongPath = self.Length * t

		local segmentToEvaluate = 1
		local distanceAlongSegment = distanceAlongPath
		for i, segmentLength in ipairs(self._internalData.segmentLengths) do
			segmentToEvaluate = i

			if segmentLength > distanceAlongSegment then
				break
			end

			distanceAlongSegment -= segmentLength
		end

		--The distibution of t values along Bezier curves is not linear, if they were, rawSegmentT would be the
		--  segment's t value, but because they're not we compare it to the previously computed t adjustments
		--  for this segment, then map it so that it is linear
		local rawSegmentT = distanceAlongSegment / self._internalData.segmentLengths[segmentToEvaluate]

		local adjustmentIndex = 1
		for i, adjustedT in ipairs(self._internalData.splitTAdjustments[segmentToEvaluate]) do
			if rawSegmentT < adjustedT then
				adjustmentIndex = i - 1
				break
			end
		end

		local splitStartT = self._internalData.splitTAdjustments[segmentToEvaluate][adjustmentIndex] or 0
		local splitEndT = self._internalData.splitTAdjustments[segmentToEvaluate][adjustmentIndex + 1]

		local splitCompletionPercent = (rawSegmentT - splitStartT) / (splitEndT - splitStartT)

		local tPerAdjustmentIndex = 1 / #self._internalData.splitTAdjustments[segmentToEvaluate]

		local adjustedSegmentT = adjustmentIndex * tPerAdjustmentIndex + splitCompletionPercent * tPerAdjustmentIndex

		local startAnchorTable = self._internalData.anchorTables[segmentToEvaluate]
		local endAnchorTable = self._internalData.anchorTables[segmentToEvaluate + 1]

		return evaluateAnchorTablesCurve(adjustedSegmentT, startAnchorTable, endAnchorTable) + self.Position
	end
end

--Get Rotation On Curve
do
	--[[
	This function returns a CFrame with no translation looking "forwards" along the Path3D. This could also be thought of as getting the tangent along the curve. This function adjusts the given t value to be linearly distributed along the curve
	
	<strong>t</strong>: A number from 0-1 representing where along the Path3D the rotation should be sampled at
	
	<strong>Return</strong>: A CFrame looking "forwards" along the Path3D
	]]
	function path3dMetatable.GetRotationOnCurve(self: Path3D, t: number): CFrame
		self = self :: Path3DInternal
		if typeof(t) ~= "number" then
			error("Unable to invoke Path3D:GetPositionOnCurve with given t value, expected number, got " .. typeof(t))
		end
		if t < 0 then
			error("Attempt to call Path3D:GetPositionOnCurve with t value less than 0")
		elseif t > 1 then
			error("Attempt to call Path3D:GetPositionOnCurve with t value greater than 1")
		end

		if t == 1 then --Edge case for when we get to the last curve in the Path
			local lastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables]
			local secondLastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables - 1]
			if lastAnchorTable.priorControlPoint then
				return CFrame.lookAt(lastAnchorTable.priorControlPoint, lastAnchorTable.anchor).Rotation
			else
				return CFrame.lookAt(secondLastAnchorTable.anchor, lastAnchorTable.anchor).Rotation
			end
		end

		local distanceAlongPath = self.Length * t

		local segmentToEvaluate = 1
		local distanceAlongSegment = distanceAlongPath
		for i, segmentLength in ipairs(self._internalData.segmentLengths) do
			segmentToEvaluate = i

			if segmentLength > distanceAlongSegment then
				break
			end

			distanceAlongSegment -= segmentLength
		end

		--The distibution of t values along Bezier curves is not linear, if they were, rawSegmentT would be the
		--  segment's t value, but because they're not we compare it to the previously computed t adjustments
		--  for this segment, then map it so that it is linear
		local rawSegmentT = distanceAlongSegment / self._internalData.segmentLengths[segmentToEvaluate]

		local adjustmentIndex = 1
		for i, adjustedT in ipairs(self._internalData.splitTAdjustments[segmentToEvaluate]) do
			if rawSegmentT < adjustedT then
				adjustmentIndex = i - 1
				break
			end
		end

		local splitStartT = self._internalData.splitTAdjustments[segmentToEvaluate][adjustmentIndex] or 0
		local splitEndT = self._internalData.splitTAdjustments[segmentToEvaluate][adjustmentIndex + 1]

		local splitCompletionPercent = (rawSegmentT - splitStartT) / (splitEndT - splitStartT)

		local tPerAdjustmentIndex = 1 / #self._internalData.splitTAdjustments[segmentToEvaluate]

		local adjustedSegmentT = adjustmentIndex * tPerAdjustmentIndex + splitCompletionPercent * tPerAdjustmentIndex

		local startAnchorTable = self._internalData.anchorTables[segmentToEvaluate]
		local endAnchorTable = self._internalData.anchorTables[segmentToEvaluate + 1]

		local q0: Vector3
		local q1: Vector3
		if startAnchorTable.nextControlPoint and endAnchorTable.priorControlPoint then
			q0 = evaluateQuadraticBezierCurve(
				adjustedSegmentT,
				startAnchorTable.anchor,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint
			)
			q1 = evaluateQuadraticBezierCurve(
				adjustedSegmentT,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint,
				endAnchorTable.anchor
			)
		elseif startAnchorTable.nextControlPoint then
			q0 = evaluateLinearBezierCurve(adjustedSegmentT, startAnchorTable.anchor, startAnchorTable.nextControlPoint)
			q1 = evaluateLinearBezierCurve(adjustedSegmentT, startAnchorTable.nextControlPoint, endAnchorTable.anchor)
		elseif endAnchorTable.priorControlPoint then
			q0 = evaluateLinearBezierCurve(adjustedSegmentT, startAnchorTable.anchor, endAnchorTable.priorControlPoint)
			q1 = evaluateLinearBezierCurve(adjustedSegmentT, endAnchorTable.priorControlPoint, endAnchorTable.anchor)
		else
			q0 = startAnchorTable.anchor
			q1 = endAnchorTable.anchor
		end

		local returnValue = CFrame.lookAt(q0, q1).Rotation

		return CFrame.lookAt(q0, q1).Rotation
	end
end

--Get Unadjusted Rotation On Curve
do
	--[[
	This function returns a CFrame with no translation looking "forwards" along the Path3D. This could also be thought of as getting the tangent along the curve.
	
	<strong>t</strong>: A number from 0-1 representing where along the Path3D the rotation should be sampled at
	
	<strong>Return</strong>: A CFrame looking "forwards" along the Path3D
	]]
	function path3dMetatable.GetUnadjustedRotationOnCurve(self: Path3D, t: number): CFrame
		self = self :: Path3DInternal
		if typeof(t) ~= "number" then
			error(
				"Unable to invoke Path3D:GetUnadjustedPositionOnCurve with given t value, expected number, got "
					.. typeof(t)
			)
		end
		if t < 0 then
			error("Attempt to call Path3D:GetUnadjustedPositionOnCurve with t value less than 0")
		elseif t > 1 then
			error("Attempt to call Path3D:GetUnadjustedPositionOnCurve with t value greater than 1")
		end

		if t == 1 then --Edge case for when we get to the last curve in the Path
			local lastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables]
			local secondLastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables - 1]
			if lastAnchorTable.priorControlPoint then
				return CFrame.lookAt(lastAnchorTable.priorControlPoint, lastAnchorTable.anchor).Rotation
			else
				return CFrame.lookAt(secondLastAnchorTable.anchor, lastAnchorTable.anchor).Rotation
			end
		end

		local distanceAlongPath = self.Length * t

		local segmentToEvaluate = 1
		local distanceAlongSegment = distanceAlongPath
		for i, segmentLength in ipairs(self._internalData.segmentLengths) do
			segmentToEvaluate = i

			if segmentLength > distanceAlongSegment then
				break
			end

			distanceAlongSegment -= segmentLength
		end

		local segmentT = distanceAlongSegment / self._internalData.segmentLengths[segmentToEvaluate]
		local startAnchorTable = self._internalData.anchorTables[segmentToEvaluate]
		local endAnchorTable = self._internalData.anchorTables[segmentToEvaluate + 1]

		local q0: Vector3
		local q1: Vector3
		if startAnchorTable.nextControlPoint and endAnchorTable.priorControlPoint then
			q0 = evaluateQuadraticBezierCurve(
				segmentT,
				startAnchorTable.anchor,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint
			)
			q1 = evaluateQuadraticBezierCurve(
				segmentT,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint,
				endAnchorTable.anchor
			)
		elseif startAnchorTable.nextControlPoint then
			q0 = evaluateLinearBezierCurve(segmentT, startAnchorTable.anchor, startAnchorTable.nextControlPoint)
			q1 = evaluateLinearBezierCurve(segmentT, startAnchorTable.nextControlPoint, endAnchorTable.anchor)
		elseif endAnchorTable.priorControlPoint then
			q0 = evaluateLinearBezierCurve(segmentT, startAnchorTable.anchor, endAnchorTable.priorControlPoint)
			q1 = evaluateLinearBezierCurve(segmentT, endAnchorTable.priorControlPoint, endAnchorTable.anchor)
		else
			q0 = startAnchorTable.anchor
			q1 = endAnchorTable.anchor
		end

		return CFrame.lookAt(q0, q1).Rotation
	end
end

--Get CFrame On Curve
do
	--[[
	This function returns a CFrame at the given point looking "forwards" along the Path3D. This function adjusts the given t value to be linearly distributed along the curve
	
	<strong>t</strong>: A number from 0-1 representing where along the Path3D the point should be sampled at
	
	<strong>Return</strong>: A CFrame at the given point looking "forwards" along the Path3D
	]]
	function path3dMetatable.GetCFrameOnCurve(self: Path3D, t: number): CFrame
		self = self :: Path3DInternal
		if typeof(t) ~= "number" then
			error("Unable to invoke Path3D:GetPositionOnCurve with given t value, expected number, got " .. typeof(t))
		end
		if t < 0 then
			error("Attempt to call Path3D:GetPositionOnCurve with t value less than 0")
		elseif t > 1 then
			error("Attempt to call Path3D:GetPositionOnCurve with t value greater than 1")
		end

		if t == 1 then --Edge case for when we get to the last curve in the Path
			local lastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables]
			local secondLastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables - 1]
			if lastAnchorTable.priorControlPoint then
				return CFrame.new(lastAnchorTable.anchor + self.Position)
					* CFrame.lookAt(lastAnchorTable.priorControlPoint, lastAnchorTable.anchor).Rotation
			else
				return CFrame.new(lastAnchorTable.anchor + self.Position)
					* CFrame.lookAt(secondLastAnchorTable.anchor, lastAnchorTable.anchor).Rotation
			end
		end

		local distanceAlongPath = self.Length * t

		local segmentToEvaluate = 1
		local distanceAlongSegment = distanceAlongPath
		for i, segmentLength in ipairs(self._internalData.segmentLengths) do
			segmentToEvaluate = i

			if segmentLength > distanceAlongSegment then
				break
			end

			distanceAlongSegment -= segmentLength
		end

		--The distibution of t values along Bezier curves is not linear, if they were, rawSegmentT would be the
		--  segment's t value, but because they're not we compare it to the previously computed t adjustments
		--  for this segment, then map it so that it is linear
		local rawSegmentT = distanceAlongSegment / self._internalData.segmentLengths[segmentToEvaluate]

		local adjustmentIndex = 1
		for i, adjustedT in ipairs(self._internalData.splitTAdjustments[segmentToEvaluate]) do
			if rawSegmentT < adjustedT then
				adjustmentIndex = i - 1
				break
			end
		end

		local splitStartT = self._internalData.splitTAdjustments[segmentToEvaluate][adjustmentIndex] or 0
		local splitEndT = self._internalData.splitTAdjustments[segmentToEvaluate][adjustmentIndex + 1]

		local splitCompletionPercent = (rawSegmentT - splitStartT) / (splitEndT - splitStartT)

		local tPerAdjustmentIndex = 1 / #self._internalData.splitTAdjustments[segmentToEvaluate]

		local adjustedSegmentT = adjustmentIndex * tPerAdjustmentIndex + splitCompletionPercent * tPerAdjustmentIndex

		local startAnchorTable = self._internalData.anchorTables[segmentToEvaluate]
		local endAnchorTable = self._internalData.anchorTables[segmentToEvaluate + 1]

		local q0: Vector3
		local q1: Vector3
		if startAnchorTable.nextControlPoint and endAnchorTable.priorControlPoint then
			q0 = evaluateQuadraticBezierCurve(
				adjustedSegmentT,
				startAnchorTable.anchor,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint
			)
			q1 = evaluateQuadraticBezierCurve(
				adjustedSegmentT,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint,
				endAnchorTable.anchor
			)
		elseif startAnchorTable.nextControlPoint then
			q0 = evaluateLinearBezierCurve(adjustedSegmentT, startAnchorTable.anchor, startAnchorTable.nextControlPoint)
			q1 = evaluateLinearBezierCurve(adjustedSegmentT, startAnchorTable.nextControlPoint, endAnchorTable.anchor)
		elseif endAnchorTable.priorControlPoint then
			q0 = evaluateLinearBezierCurve(adjustedSegmentT, startAnchorTable.anchor, endAnchorTable.priorControlPoint)
			q1 = evaluateLinearBezierCurve(adjustedSegmentT, endAnchorTable.priorControlPoint, endAnchorTable.anchor)
		else
			q0 = startAnchorTable.anchor
			q1 = endAnchorTable.anchor
		end

		return CFrame.new(evaluateLinearBezierCurve(adjustedSegmentT, q0, q1) + self.Position)
			* CFrame.lookAt(q0, q1).Rotation
	end
end

--Get Unadjusted CFrame On Curve
do
	--[[
	This function returns a CFrame with no translation looking "forwards" along the Path3D. This could also be thought of as getting the tangent along the curve.
	
	<strong>t</strong>: A number from 0-1 representing where along the Path3D the rotation should be sampled at
	
	<strong>Return</strong>: A CFrame looking "forwards" along the Path3D
	]]
	function path3dMetatable.GetUnadjustedCFrameOnCurve(self: Path3D, t: number): CFrame
		self = self :: Path3DInternal
		if typeof(t) ~= "number" then
			error(
				"Unable to invoke Path3D:GetUnadjustedPositionOnCurve with given t value, expected number, got "
					.. typeof(t)
			)
		end
		if t < 0 then
			error("Attempt to call Path3D:GetUnadjustedPositionOnCurve with t value less than 0")
		elseif t > 1 then
			error("Attempt to call Path3D:GetUnadjustedPositionOnCurve with t value greater than 1")
		end

		if t == 1 then --Edge case for when we get to the last curve in the Path
			local lastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables]
			local secondLastAnchorTable = self._internalData.anchorTables[#self._internalData.anchorTables - 1]
			if lastAnchorTable.priorControlPoint then
				return CFrame.new(lastAnchorTable.anchor + self.Position)
					* CFrame.lookAt(lastAnchorTable.priorControlPoint, lastAnchorTable.anchor).Rotation
			else
				return CFrame.new(lastAnchorTable.anchor + self.Position)
					* CFrame.lookAt(secondLastAnchorTable.anchor, lastAnchorTable.anchor).Rotation
			end
		end

		local distanceAlongPath = self.Length * t

		local segmentToEvaluate = 1
		local distanceAlongSegment = distanceAlongPath
		for i, segmentLength in ipairs(self._internalData.segmentLengths) do
			segmentToEvaluate = i

			if segmentLength > distanceAlongSegment then
				break
			end

			distanceAlongSegment -= segmentLength
		end

		local segmentT = distanceAlongSegment / self._internalData.segmentLengths[segmentToEvaluate]
		local startAnchorTable = self._internalData.anchorTables[segmentToEvaluate]
		local endAnchorTable = self._internalData.anchorTables[segmentToEvaluate + 1]

		local q0: Vector3
		local q1: Vector3
		if startAnchorTable.nextControlPoint and endAnchorTable.priorControlPoint then
			q0 = evaluateQuadraticBezierCurve(
				segmentT,
				startAnchorTable.anchor,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint
			)
			q1 = evaluateQuadraticBezierCurve(
				segmentT,
				startAnchorTable.nextControlPoint,
				endAnchorTable.priorControlPoint,
				endAnchorTable.anchor
			)
		elseif startAnchorTable.nextControlPoint then
			q0 = evaluateLinearBezierCurve(segmentT, startAnchorTable.anchor, startAnchorTable.nextControlPoint)
			q1 = evaluateLinearBezierCurve(segmentT, startAnchorTable.nextControlPoint, endAnchorTable.anchor)
		elseif endAnchorTable.priorControlPoint then
			q0 = evaluateLinearBezierCurve(segmentT, startAnchorTable.anchor, endAnchorTable.priorControlPoint)
			q1 = evaluateLinearBezierCurve(segmentT, endAnchorTable.priorControlPoint, endAnchorTable.anchor)
		else
			q0 = startAnchorTable.anchor
			q1 = endAnchorTable.anchor
		end

		return CFrame.new(evaluateLinearBezierCurve(segmentT, q0, q1) + self.Position) * CFrame.lookAt(q0, q1).Rotation
	end
end

--Get Segment Lengths
do
	--[[
	This function returns the lengths of each segment of the Path3D
	
	<strong>Return</strong>: An array of the lengths of each of the segments
	]]
	function path3dMetatable:GetSegmentLengths(): { number }
		return table.clone(self._internalData.segmentLengths)
	end
end

--Get Anchor Tables
do
	--[[
	This function returns an array of copies of all of the anchor tables used by the Path3D. An anchor table
	  holds the offset of the anchor point from the pivot point, and the offset of any control points from the
	  anchor point
	
	<strong>Return</strong>: An array of Path3DAnchorTables for each of the anchor points in the Path3D
	]]
	function path3dMetatable.GetAnchorTables(self: Path3DInternal): { Path3DAnchorTable }
		local returnArray = {}

		for i, referenceTable in ipairs(self._internalData.anchorTables) do
			returnArray[i] = table.clone(referenceTable)
		end

		return returnArray
	end
end

export type Path3D = {
	Length: number,
	Position: Vector3,
	__type: "Path3D",
	ClassName: "Path3D",
	_internalData: { anchorTables: { Path3DAnchorTable }, segmentLengths: { number }, splitTAdjustments: { { number } } },
	GetPositionOnCurve: typeof(path3dMetatable.GetPositionOnCurve),
	GetUnadjustedPositionOnCurve: typeof(path3dMetatable.GetUnadjustedPositionOnCurve),
	GetSegmentLengths: (self: Path3D) -> { number },
	GetAnchorTables: (self: Path3D) -> { Path3DAnchorTable },
	GetUnadjustedRotationOnCurve: typeof(path3dMetatable.GetUnadjustedRotationOnCurve),
	GetRotationOnCurve: typeof(path3dMetatable.GetRotationOnCurve),
	GetUnadjustedCFrameOnCurve: typeof(path3dMetatable.GetUnadjustedCFrameOnCurve),
	GetCFrameOnCurve: typeof(path3dMetatable.GetCFrameOnCurve),
}

type Path3DInternal = Path3D & {
	_internalData: {
		anchorTables: Path3DAnchorTable,
		segmentLengths: { number },
		splitTAdjustments: { number },
	},
}

export type Path3DLengthOptions = {
	recordedSplits: number,
	minimumLength: number,
	minimumSuccesses: number,
	minimumSplits: number,
	maximumSplits: number,
}

export type Path3DAnchorTable = {
	priorControlPoint: Vector3?,
	anchor: Vector3,
	nextControlPoint: Vector3?,
}

return Path3D
