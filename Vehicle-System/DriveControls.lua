local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local seatBase = workspace:WaitForChild("DriveSeat"):WaitForChild("SeatBase", 10)
local bodyVelocity = seatBase:WaitForChild("DriveVelocity", 10)
local bodyGyro = seatBase:WaitForChild("DriveGyro", 10)
local seat = seatBase:WaitForChild("Seat", 10)

local wheelG = workspace:WaitForChild("Roue avantgauche", 10)
local wheelD = workspace:WaitForChild("Roue avantdroite", 10)
local wheelRG = workspace:WaitForChild("Roue arrieregauche", 10)
local wheelRD = workspace:WaitForChild("Roue arrieredroite", 10)

local audiModel = workspace:WaitForChild("Audi RS5", 10)
local audiBody = audiModel and audiModel:WaitForChild("Body", 10)
local audiGlass = audiBody and audiBody:FindFirstChild("Glass")

local wheelGOffset = wheelG and (seatBase.CFrame:ToObjectSpace(wheelG.CFrame)) or CFrame.new()
local wheelDOffset = wheelD and (seatBase.CFrame:ToObjectSpace(wheelD.CFrame)) or CFrame.new()
local wheelRGOffset = wheelRG and (seatBase.CFrame:ToObjectSpace(wheelRG.CFrame)) or CFrame.new()
local wheelRDOffset = wheelRD and (seatBase.CFrame:ToObjectSpace(wheelRD.CFrame)) or CFrame.new()
local audiBodyOffset = audiBody and (seatBase.CFrame:ToObjectSpace(audiBody.CFrame)) or CFrame.new()
local audiGlassOffset = audiGlass and (seatBase.CFrame:ToObjectSpace(audiGlass.CFrame)) or CFrame.new()

local steeringAngle = 0
local maxSteeringAngle = math.rad(30)
local steeringSpeed = 2

local PlayerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedGUI"
screenGui.Parent = PlayerGui

local speedFrame = Instance.new("Frame")
speedFrame.Name = "SpeedFrame"
speedFrame.Size = UDim2.new(0, 200, 0, 50)
speedFrame.Position = UDim2.new(0.5, -100, 1, -70)
speedFrame.AnchorPoint = Vector2.new(0.5, 1)
speedFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
speedFrame.BackgroundTransparency = 0.5
speedFrame.Parent = screenGui

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Size = UDim2.new(1, 0, 1, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.Font = Enum.Font.SourceSansBold
speedLabel.TextSize = 24
speedLabel.Text = "0 km/h"
speedLabel.Parent = speedFrame

screenGui.Enabled = false

local maxSpeed = 60
local turnSpeed = 2
local acceleration = 12
local deceleration = 18
local currentSpeed = 0

local keys = {
	Z = false,
	Q = false,
	S = false,
	D = false,
}

local function isSeated()
	return humanoid.SeatPart == seat
end

local function updateMovement(dt)
	if not isSeated() then
		currentSpeed = 0
		bodyVelocity.Velocity = Vector3.new(0, bodyVelocity.Velocity.Y, 0)
		screenGui.Enabled = false
		return
	end
	screenGui.Enabled = true

	local targetSpeed = 0
	if keys.Z then
		targetSpeed = maxSpeed
	elseif keys.S then
		targetSpeed = -maxSpeed
	end

	if targetSpeed ~= 0 then
		local sameDirection = (targetSpeed > 0 and currentSpeed >= 0) or (targetSpeed < 0 and currentSpeed <= 0)
		local rate = sameDirection and acceleration or deceleration
		local diff = targetSpeed - currentSpeed
		local step = math.clamp(diff, -rate * dt, rate * dt)
		currentSpeed = currentSpeed + step
	else
		if currentSpeed > 0 then
			currentSpeed = math.max(0, currentSpeed - deceleration * dt)
		elseif currentSpeed < 0 then
			currentSpeed = math.min(0, currentSpeed + deceleration * dt)
		end
	end

	local turn = keys.Q and 1 or (keys.D and -1 or 0)

	local targetSteering = 0
	if keys.Q then targetSteering = maxSteeringAngle end
	if keys.D then targetSteering = -maxSteeringAngle end
	local steeringDiff = targetSteering - steeringAngle
	local steeringStep = math.clamp(steeringDiff, -steeringSpeed * dt, steeringSpeed * dt)
	steeringAngle = steeringAngle + steeringStep

	if turn ~= 0 then
		local currentCF = bodyGyro.CFrame
		local newCF = currentCF * CFrame.Angles(0, turn * turnSpeed * dt, 0)
		bodyGyro.CFrame = newCF
	else
		bodyGyro.CFrame = seatBase.CFrame
	end

	if wheelG then
		local worldPos = seatBase.CFrame * wheelGOffset.Position
		local originalRot = seatBase.CFrame.Rotation * wheelGOffset.Rotation
		wheelG.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, steeringAngle, 0) * originalRot
	end
	if wheelD then
		local worldPos = seatBase.CFrame * wheelDOffset.Position
		local originalRot = seatBase.CFrame.Rotation * wheelDOffset.Rotation
		wheelD.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, steeringAngle, 0) * originalRot
	end

	if wheelRG then
		local worldPos = seatBase.CFrame * wheelRGOffset.Position
		local originalRot = seatBase.CFrame.Rotation * wheelRGOffset.Rotation
		wheelRG.CFrame = CFrame.new(worldPos) * originalRot
	end
	if wheelRD then
		local worldPos = seatBase.CFrame * wheelRDOffset.Position
		local originalRot = seatBase.CFrame.Rotation * wheelRDOffset.Rotation
		wheelRD.CFrame = CFrame.new(worldPos) * originalRot
	end

	if audiBody then
		audiBody.CFrame = seatBase.CFrame * audiBodyOffset
	end
	if audiGlass then
		audiGlass.CFrame = seatBase.CFrame * audiGlassOffset
	end

	local direction = seatBase.CFrame.LookVector
	local horizontalVelocity = direction * currentSpeed
	bodyVelocity.Velocity = Vector3.new(horizontalVelocity.X, bodyVelocity.Velocity.Y, horizontalVelocity.Z)
	speedLabel.Text = string.format("%.0f km/h", math.abs(currentSpeed) * 3.6)
end

RunService.Heartbeat:Connect(updateMovement)

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	local key = input.KeyCode.Name
	if key == "Z" then keys.Z = true end
	if key == "S" then keys.S = true end
	if key == "Q" then keys.Q = true end
	if key == "D" then keys.D = true end
end

local function onInputEnded(input, gameProcessed)
	local key = input.KeyCode.Name
	if key == "Z" then keys.Z = false end
	if key == "S" then keys.S = false end
	if key == "Q" then keys.Q = false end
	if key == "D" then keys.D = false end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
end)
