local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent

local bodyVelocity = nil
local bodyGyro = nil
local character = nil
local humanoid = nil
local rootPart = nil
local flying = false
local heartbeatConnection = nil
local takeoffStartTime = nil
local TAKEOFF_DELAY = 2.33
local poseRenderStepName = "BalaiFlightPose"

local FLY_SPEED = 60
local UP_SPEED = 60
local ACCELERATION = 3
local DECELERATION = 35
local ENABLE_COLLISION = true
local COLLISION_SKIN = 1
local BODY_COLLISION_RADIUS = 1
local currentVelocity = Vector3.zero
local defaultWalkSpeed = 16
local defaultJumpPower = 50
local defaultGrip = tool.Grip
local rightShoulderMotor = nil
local rightElbowMotor = nil
local originalRightShoulderC0 = nil
local originalRightElbowC0 = nil
local flightCollisionBox = nil
local mountTrack = nil
local flyTrack = nil
local dismountTrack = nil
local idleTrack = nil
local walkTrack = nil
local balaiFlightToggle = ReplicatedStorage:WaitForChild("BalaiFlightToggle")

local BROOM_OFFSET_POS = Vector3.new(0, -1.5, 0) 
local BROOM_OFFSET_ROT = Vector3.new(-90, 0, 0)

local function storeOriginalPose()
	if not character then return end
	rightShoulderMotor = character:FindFirstChild("RightShoulder")
	rightElbowMotor = character:FindFirstChild("RightElbow")
	if rightShoulderMotor and rightShoulderMotor:IsA("Motor6D") then
		originalRightShoulderC0 = rightShoulderMotor.C0
	end
	if rightElbowMotor and rightElbowMotor:IsA("Motor6D") then
		originalRightElbowC0 = rightElbowMotor.C0
	end
end

local function forceFlightPose()
	if not character then return end
	if not rightShoulderMotor then
		rightShoulderMotor = character:FindFirstChild("RightShoulder")
	end
	if not rightElbowMotor then
		rightElbowMotor = character:FindFirstChild("RightElbow")
	end
	if rightShoulderMotor and rightShoulderMotor:IsA("Motor6D") then
		rightShoulderMotor.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(90))
	end
	if rightElbowMotor and rightElbowMotor:IsA("Motor6D") then
		rightElbowMotor.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(90), 0, 0)
	end
end

local function restorePose()
	if rightShoulderMotor and originalRightShoulderC0 then
		rightShoulderMotor.C0 = originalRightShoulderC0
	end
	if rightElbowMotor and originalRightElbowC0 then
		rightElbowMotor.C0 = originalRightElbowC0
	end
	rightShoulderMotor = nil
	rightElbowMotor = nil
	originalRightShoulderC0 = nil
	originalRightElbowC0 = nil
end

local function applyCollision(velocity, dt)
	if not ENABLE_COLLISION or not rootPart or not character then return velocity end
	local speed = velocity.Magnitude
	if speed <= 0.01 then return velocity end
	local origin = rootPart.Position
	local direction = velocity / speed
	local maxDistance = BODY_COLLISION_RADIUS + COLLISION_SKIN + math.min(speed * dt, 2)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local hit = workspace:Raycast(origin, direction, raycastParams, maxDistance)
	if hit then
		local normal = hit.Normal
		local velocityAlongNormal = velocity:Dot(normal)
		if velocityAlongNormal < 0 then
			velocity = velocity - normal * velocityAlongNormal
		end
	end
	return velocity
end

local function stopDefaultToolAnim()
	if not character or not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Name == "ToolNoneAnim" or (track.Animation and track.Animation.AnimationId == "rbxassetid://507768375") then
				track:Stop()
			end
		end
	end
end
local function updateIdleAnimation()
	if not character or not humanoid or flying then return end
	if tool.Parent ~= character then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	stopDefaultToolAnim()

	if humanoid.MoveDirection.Magnitude > 0.1 then
		if idleTrack then
			idleTrack:Stop(0.1)
			idleTrack = nil
		end
		if not walkTrack then
			local walkAnimation = Instance.new("Animation")
			walkAnimation.AnimationId = "rbxassetid://127914304718809"
			walkTrack = animator:LoadAnimation(walkAnimation)
			walkTrack.Looped = true
			walkTrack:Play(0.1)
		end
	else
		if walkTrack then
			walkTrack:Stop(0.1)
			walkTrack = nil
		end
		if not idleTrack then
			local idleAnimation = Instance.new("Animation")
			idleAnimation.AnimationId = "rbxassetid://87112179214061"
			idleTrack = animator:LoadAnimation(idleAnimation)
			idleTrack.Looped = true
			idleTrack:Play(0.1)
		end
	end
end

local function startFlying()
	if idleTrack then
		idleTrack:Stop()
		idleTrack = nil
	end
	if walkTrack then
		walkTrack:Stop()
		walkTrack = nil
	end
	if not character or not humanoid or not rootPart then return end
	flying = true
	takeoffStartTime = time()
	defaultWalkSpeed = humanoid.WalkSpeed
	defaultJumpPower = humanoid.JumpPower
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	storeOriginalPose()
	
	balaiFlightToggle:FireServer(true)

	local rightShoulder = character:FindFirstChild("RightShoulder")
	local rightElbow = character:FindFirstChild("RightElbow")
	local leftShoulder = character:FindFirstChild("LeftShoulder")
	local leftElbow = character:FindFirstChild("LeftElbow")

	if rightShoulder and rightShoulder:IsA("Motor6D") then
		rightShoulder.C0 = CFrame.new(1, 0.5, 0)
	end
	if rightElbow and rightElbow:IsA("Motor6D") then
		rightElbow.C0 = CFrame.new(0, -1, 0)
	end
	if leftShoulder and leftShoulder:IsA("Motor6D") then
		leftShoulder.C0 = CFrame.new(-1, 0.5, 0)
	end
	if leftElbow and leftElbow:IsA("Motor6D") then
		leftElbow.C0 = CFrame.new(0, -1, 0)
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local mountAnimation = Instance.new("Animation")
	mountAnimation.AnimationId = "rbxassetid://86414541806173"
	mountTrack = animator:LoadAnimation(mountAnimation)
	mountTrack.Looped = false
	mountTrack:Play()

	mountTrack.Stopped:Connect(function()
		local flyAnimation = Instance.new("Animation")
		flyAnimation.AnimationId = "rbxassetid://89373421529607"
		flyTrack = animator:LoadAnimation(flyAnimation)
		flyTrack.Looped = true
		flyTrack:Play()
	end)

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = rootPart

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(40000, 40000, 40000)
	bodyGyro.CFrame = rootPart.CFrame
	bodyGyro.Parent = rootPart

	flightCollisionBox = Instance.new("Part")
	flightCollisionBox.Name = "FlightCollisionBox"
	flightCollisionBox.Size = Vector3.new(2.5, 5, 2.5)
	flightCollisionBox.Transparency = 1
	flightCollisionBox.CanCollide = true
	flightCollisionBox.Anchored = false
	flightCollisionBox.Massless = true
	flightCollisionBox.CanQuery = false
	flightCollisionBox.CastShadow = false
	flightCollisionBox.Parent = character

	local hitboxWeld = Instance.new("Weld")
	hitboxWeld.Part0 = rootPart
	hitboxWeld.Part1 = flightCollisionBox
	hitboxWeld.C0 = CFrame.new(0, -0.5, 0)
	hitboxWeld.Parent = flightCollisionBox

	task.spawn(function()
		task.wait(0.1)
		stopDefaultToolAnim()
	end)

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if not flying or not bodyVelocity or not bodyGyro or not humanoid or not rootPart then return end
		if takeoffStartTime and (time() - takeoffStartTime) < TAKEOFF_DELAY then
			bodyVelocity.Velocity = Vector3.zero
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then return end

		local rightShoulder = character:FindFirstChild("RightShoulder")
		local rightElbow = character:FindFirstChild("RightElbow")
		local leftShoulder = character:FindFirstChild("LeftShoulder")
		local leftElbow = character:FindFirstChild("LeftElbow")
		
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.C0 = CFrame.new(1, 0.5, 0)
		end
		if rightElbow and rightElbow:IsA("Motor6D") then
			rightElbow.C0 = CFrame.new(0, -1, 0)
		end
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.C0 = CFrame.new(-1, 0.5, 0)
		end
		if leftElbow and leftElbow:IsA("Motor6D") then
			leftElbow.C0 = CFrame.new(0, -1, 0)
		end

		local forward = camera.CFrame.LookVector
		local right = camera.CFrame.RightVector

		if forward.Magnitude > 0.01 then
			bodyGyro.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forward.Unit)
		end

		local input = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then input = input + Vector3.new(0, 0, 1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then input = input + Vector3.new(0, 0, -1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then input = input + Vector3.new(-1, 0, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then input = input + Vector3.new(1, 0, 0) end

		local targetVelocity = Vector3.zero
		if input.Magnitude > 0 then
			local dir = (forward * input.Z + right * input.X)
			dir = dir.Unit
			targetVelocity = dir * FLY_SPEED
		elseif humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
			local dir = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Unit
			targetVelocity = dir * FLY_SPEED
			local cameraLookY = camera.CFrame.LookVector.Y
			if math.abs(cameraLookY) > 0.1 then
				targetVelocity = targetVelocity + Vector3.new(0, cameraLookY * UP_SPEED, 0)
			end
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			targetVelocity = targetVelocity + Vector3.new(0, -UP_SPEED, 0)
		end

		local rate = if targetVelocity.Magnitude > currentVelocity.Magnitude then ACCELERATION else DECELERATION
		currentVelocity = currentVelocity:Lerp(targetVelocity, math.min(1, rate * dt))
		currentVelocity = applyCollision(currentVelocity, dt)
		bodyVelocity.Velocity = currentVelocity
	end)
end

local function stopFlying()
	local wasFlying = flying
	flying = false
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if mountTrack then
		mountTrack:Stop()
		mountTrack = nil
	end
	if flyTrack then
		flyTrack:Stop()
		flyTrack = nil
	end
	
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
	if flightCollisionBox then
		flightCollisionBox:Destroy()
		flightCollisionBox = nil
	end

	if wasFlying then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local dismountAnimation = Instance.new("Animation")
			dismountAnimation.AnimationId = "rbxassetid://75872528348613"
			dismountTrack = animator:LoadAnimation(dismountAnimation)
			dismountTrack.Looped = false
			dismountTrack:Play()
			
			dismountTrack.Stopped:Connect(function()
				dismountTrack = nil
				balaiFlightToggle:FireServer(false)
				restorePose()
			end)
		end
	else
		balaiFlightToggle:FireServer(false)
		restorePose()
	end

	if humanoid then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		humanoid.WalkSpeed = defaultWalkSpeed
		humanoid.JumpPower = defaultJumpPower
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	if idleTrack then
		idleTrack:Stop()
		idleTrack = nil
	end
	if walkTrack then
		walkTrack:Stop()
		walkTrack = nil
	end
end

local idleConnection = nil

local function startIdleConnection()
	if idleConnection then return end
	if not character or not humanoid then return end
	
	idleConnection = RunService.Heartbeat:Connect(function()
		if character and humanoid and not flying and tool.Parent == character then
			updateIdleAnimation()
		end
	end)
end

local function onCharacterAdded(char)
	character = char
	humanoid = char:WaitForChild("Humanoid", 5)
	rootPart = char:WaitForChild("HumanoidRootPart", 5)
	
	if idleConnection then
		idleConnection:Disconnect()
		idleConnection = nil
	end
	
	startIdleConnection()
	
	if tool.Parent == character then
		flying = false
	else
		stopFlying()
	end
end

tool.Equipped:Connect(function()
	startIdleConnection()
	updateIdleAnimation()
end)

tool.Unequipped:Connect(function()
	stopFlying()
	if idleTrack then
		idleTrack:Stop()
		idleTrack = nil
	end
	if walkTrack then
		walkTrack:Stop()
		walkTrack = nil
	end
end)

local function listenToFlyButton()
	local gui = player:WaitForChild("PlayerGui", 10)
	if not gui then return end
	local equipGui = gui:WaitForChild("EquipBalaiGui", 10)
	if not equipGui then return end
	local flightToggle = equipGui:WaitForChild("BalaiFlightToggle", 10)
	if not flightToggle then return end
	flightToggle.Event:Connect(function()
		if not tool.Parent or tool.Parent ~= character then
			return
		end
		if flying then
			stopFlying()
		else
			startFlying()
		end
	end)
end

task.spawn(listenToFlyButton)

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
