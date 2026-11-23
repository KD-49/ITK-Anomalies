--!strict
-- R6AvatarBuilder.luau
-- Utilitas untuk membangun model Avatar R6 manusia lengkap secara prosedural
-- (Head dengan SpecialMesh + Decal wajah, Torso, Left/Right Arm, Left/Right Leg, Motor6D joints, dan Humanoid).

local R6AvatarBuilder = {}

function R6AvatarBuilder.Build(shirtColor: Color3): Model
	local npc = Instance.new("Model")
	npc.Name = "VisitorR6"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Anchored = true
	hrp.Parent = npc

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = shirtColor
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = false
	torso.Anchored = false
	torso.Parent = npc

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Color = Color3.fromRGB(245, 205, 175)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Anchored = false
	head.Parent = npc

	local specialMesh = Instance.new("SpecialMesh")
	specialMesh.MeshType = Enum.MeshType.Head
	specialMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	specialMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Color = shirtColor
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.Anchored = false
	leftArm.Parent = npc

	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Color = shirtColor
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.Anchored = false
	rightArm.Parent = npc

	local pantsColor = Color3.fromRGB(35, 40, 52)
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Color = pantsColor
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.CanCollide = false
	leftLeg.Anchored = false
	leftLeg.Parent = npc

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Color = pantsColor
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.CanCollide = false
	rightLeg.Anchored = false
	rightLeg.Parent = npc

	-- Motor6D joints standar R6 agar tangan dan kaki dapat berayun saat berjalan
	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = hrp
	rootJoint.Part1 = torso
	rootJoint.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	rootJoint.C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	rootJoint.Parent = hrp

	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	neck.Parent = torso

	local leftShoulder = Instance.new("Motor6D")
	leftShoulder.Name = "Left Shoulder"
	leftShoulder.Part0 = torso
	leftShoulder.Part1 = leftArm
	leftShoulder.C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftShoulder.C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftShoulder.Parent = torso

	local rightShoulder = Instance.new("Motor6D")
	rightShoulder.Name = "Right Shoulder"
	rightShoulder.Part0 = torso
	rightShoulder.Part1 = rightArm
	rightShoulder.C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightShoulder.C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightShoulder.Parent = torso

	local leftHip = Instance.new("Motor6D")
	leftHip.Name = "Left Hip"
	leftHip.Part0 = torso
	leftHip.Part1 = leftLeg
	leftHip.C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftHip.C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftHip.Parent = torso

	local rightHip = Instance.new("Motor6D")
	rightHip.Name = "Right Hip"
	rightHip.Part0 = torso
	rightHip.Part1 = rightLeg
	rightHip.C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightHip.C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightHip.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.PlatformStand = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.Parent = npc

	npc.PrimaryPart = hrp
	return npc
end

return R6AvatarBuilder
