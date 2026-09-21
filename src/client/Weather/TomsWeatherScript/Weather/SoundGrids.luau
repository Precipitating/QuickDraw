local function GenerateCubeVectors(radius, height, exponent, threshold)
	if not threshold then threshold = 0.6 end
	if not exponent then exponent = 1 end
	
	local vectors = {Vector3.new(0,0,0)}
	local maximumMagnitude = 0
	for x=-radius,radius do
		for z = -radius,radius do
			local yRadius = math.abs(x)+math.abs(z) > radius-0.02 and 0 or radius
			for y = 0,yRadius do
				if x == 0 and y == 0 and z == 0 then continue end
				local X = x<0 and -(-x)^exponent or x^exponent
				local Y = y<0 and -(-y)^exponent or y^exponent
				local Z = z<0 and -(-z)^exponent or z^exponent
				local newVector = Vector3.new(X,Y,Z)
				table.insert(vectors, newVector)
				if newVector.Magnitude > maximumMagnitude then
					maximumMagnitude = newVector.Magnitude
				end
			end
		end
	end
	local Cutoff = maximumMagnitude * threshold
	for i,Vector in vectors do
		if Vector.Magnitude > Cutoff then
			table.remove(vectors, i)
		end
	end
	for i,Vector in vectors do
		vectors[i] = Vector/maximumMagnitude
	end
	for i,Vector in vectors do
		vectors[i] = Vector3.new(Vector.X, Vector.Y*height, Vector.Z)
	end
	
	return vectors
end
local grids = {}

grids["Custom-19"] = { -- 20
	Vector3.new(0, 0, 0),
	Vector3.new(0.2, 0, 0),
	Vector3.new(-0.2, 0, 0),
	Vector3.new(0, 0, 0.2),
	Vector3.new(0, 0, -0.2),

	Vector3.new(0.5, 0, 0),
	Vector3.new(0.25, 0, 0.433013),
	Vector3.new(-0.25, 0, 0.433013),
	Vector3.new(-0.5, 0, 0),
	Vector3.new(-0.25, 0, -0.433013),
	Vector3.new(0.25, 0, -0.433013),

	Vector3.new(0.75, 0, 0),
	Vector3.new(0.574533, 0, 0.482091),
	Vector3.new(0.130236, 0, 0.738606),
	Vector3.new(-0.375, 0, 0.649519),
	Vector3.new(-0.704770, 0, 0.256515),
	Vector3.new(-0.704770, 0, -0.256515),
	Vector3.new(-0.375, 0, -0.649519),
	Vector3.new(0.130236, 0, -0.738606),
	Vector3.new(0.574533, 0, -0.482091),
}
grids["Custom-32"] = { -- 33
	Vector3.new(0, 0.3, 0),
	
	Vector3.new(0, 0, 0),
	Vector3.new(-0.14, 0, 0),
	Vector3.new(0.14, 0, 0),
	Vector3.new(0, 0, -0.14),
	Vector3.new(0, 0, 0.14),
	Vector3.new(0,0.14,0),

	Vector3.new(0.204663, 0, -0.282018),
	Vector3.new(0.331462, 0, 0.107501),
	Vector3.new(0, 0, 0.348455),
	Vector3.new(-0.331343, 0, 0.107856),
	Vector3.new(-0.20497, 0, -0.281794),

	Vector3.new(0, 0.224445, -0.397704),
	Vector3.new(-0.397704, 0.224445, 0),
	Vector3.new(0, 0.224445, 0.397704),
	Vector3.new(0.397704, 0.224445, 0),

	Vector3.new(0, 0, -0.57),
	Vector3.new(-0.403051, 0.106168, -0.403051),
	Vector3.new(-0.57, 0, 0),
	Vector3.new(-0.403051, 0.106168, 0.403051),
	Vector3.new(0, 0, 0.57),
	Vector3.new(0.403051, 0.106168, 0.403051),
	Vector3.new(0.57, 0, 0),
	Vector3.new(0.403051, 0.106168, -0.403051),

	Vector3.new(0.253017, 0.101105, -0.780139),
	Vector3.new(-0.25386, 0, -0.779865),
	Vector3.new(-0.663772, 0.101105, -0.481707),
	Vector3.new(-0.820143, 0, 0),
	Vector3.new(-0.66325, 0.101105, 0.482426),
	Vector3.new(-0.253017, 0, 0.780139),
	Vector3.new(0.25386, 0.101105, 0.779865),
	Vector3.new(0.663772, 0, 0.481707),
	Vector3.new(0.820143, 0.101105, 0),
	Vector3.new(0.663249, 0, -0.482426),
}

grids["Min-1"] = {
	Vector3.new(0,0,0)
}
grids["Min-5"] = {
	Vector3.new(0,0,0),
	Vector3.new(0.2,0,0),
	Vector3.new(-0.2,0,0),
	Vector3.new(0,0,0.2),
	Vector3.new(0,0,-0.2)
}

local Cubed = GenerateCubeVectors(2, 0.4, 1, 0.6)
grids["Cubed-"..#Cubed] = GenerateCubeVectors(2, 0.3, 1, 0.6)

return grids