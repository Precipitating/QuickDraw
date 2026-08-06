local LimbsEnum = {
	Head = 1,
	UpperTorso = 2,
	LowerTorso = 3,

	LeftUpperArm = 4,
	LeftLowerArm = 5,
	LeftHand = 6,
	RightUpperArm = 7,
	RightLowerArm = 8,
	RightHand = 9,

	LeftUpperLeg = 10,
	LeftLowerLeg = 11,
	LeftFoot = 12,
	RightUpperLeg = 13,
	RightLowerLeg = 14,
	RightFoot = 15,
}

-- generate the reverse (number -> name) entries
for name, id in LimbsEnum do
	LimbsEnum[id] = name
end

return LimbsEnum
