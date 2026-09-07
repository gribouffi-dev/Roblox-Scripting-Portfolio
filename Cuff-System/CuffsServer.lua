local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CuffsRemote = ReplicatedStorage:FindFirstChild("CuffsRemote")
local JailPromptRemote = ReplicatedStorage:FindFirstChild("JailPrompt")
local JailSubmitRemote = ReplicatedStorage:FindFirstChild("JailSubmit")
local JailStatusRemote = ReplicatedStorage:FindFirstChild("JailStatus")

local DETAIN_DISTANCE = 10
local DRAG_DISTANCE = 4
local MAX_JAIL_MINUTES = 1440 -- 1 day

local activeDrags = {}
local latestDragDir = {}
local latestDragPos = {}
local jailTimers = {}

local function applyDetainedState(player)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
end

local function createDragBody(target)
	local character = target.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local body = root:FindFirstChild("DragBody")
	if not body then
		body = Instance.new("BodyPosition")
		body.Name = "DragBody"
		body.MaxForce = Vector3.new(100000, 100000, 100000)
		body.D = 100
		body.P = 50000
		body.Parent = root
	end
	local gyro = root:FindFirstChild("DragGyro")
	if not gyro then
		gyro = Instance.new("BodyGyro")
		gyro.Name = "DragGyro"
		gyro.MaxTorque = Vector3.new(400000, 400000, 400000)
		gyro.D = 200
		gyro.P = 10000
		gyro.Parent = root
	end
	return body
end

local function removeDragBody(target)
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local body = root:FindFirstChild("DragBody")
		if body then body:Destroy() end
		local gyro = root:FindFirstChild("DragGyro")
		if gyro then gyro:Destroy() end
	end
end

local function stopDrag(targetUserId)
	local entry = activeDrags[targetUserId]
	if not entry then return end
	removeDragBody(entry.target)
	activeDrags[targetUserId] = nil
end

local function teleportToPrison(player)
	local prison = workspace:FindFirstChild("Prison")
	if not prison then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	root.CFrame = prison.CFrame + Vector3.new(0, 4, 0)
	return true
end

local function applyJailedState(player)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
end

local function releaseJailed(player)
	if player:GetAttribute("Jailed") ~= true then return false end
	local userId = player.UserId
	if jailTimers[userId] then
		jailTimers[userId]:Cancel()
		jailTimers[userId] = nil
	end
	player:SetAttribute("Jailed", false)
	player:SetAttribute("JailReason", nil)
	player:SetAttribute("JailEndTime", nil)
	player:SetAttribute("JailedBy", nil)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = player:GetAttribute("OriginalWalkSpeed") or 16
			humanoid.JumpPower = player:GetAttribute("OriginalJumpPower") or 50
		end
	end
	player:SetAttribute("OriginalWalkSpeed", nil)
	player:SetAttribute("OriginalJumpPower", nil)
	JailStatusRemote:FireClient(player, "", os.time())
	return true
end

local function jailPlayer(target, officer, reason, durationMinutes)
	if target:GetAttribute("Jailed") == true then return false end

	stopDrag(target.UserId)

	local endTime = os.time() + math.floor(durationMinutes) * 60
	target:SetAttribute("Jailed", true)
	target:SetAttribute("JailReason", reason)
	target:SetAttribute("JailEndTime", endTime)
	target:SetAttribute("JailedBy", officer.UserId)

	teleportToPrison(target)
	applyJailedState(target)
	JailStatusRemote:FireClient(target, reason, endTime)

	local userId = target.UserId
	if jailTimers[userId] then
		jailTimers[userId]:Cancel()
	end
	jailTimers[userId] = task.delay(math.floor(durationMinutes) * 60, function()
		if target:GetAttribute("Jailed") == true then
			releaseJailed(target)
		end
		jailTimers[userId] = nil
	end)
	return true
end

CuffsRemote.OnServerEvent:Connect(function(player, action, arg1, arg2)
	if action == "drag" then
		local cameraPos = arg1
		local cameraDir = arg2
		if typeof(cameraPos) ~= "Vector3" or typeof(cameraDir) ~= "Vector3" then return end
		if cameraPos.Magnitude > 10000 then return end
		if cameraDir.Magnitude < 0.01 or cameraDir.Magnitude > 1000 then return end
		local x, y, z = cameraDir.X, cameraDir.Y, cameraDir.Z
		if x ~= x or y ~= y or z ~= z then return end
		if x == math.huge or x == -math.huge or y == math.huge or y == -math.huge or z == math.huge or z == -math.huge then return end
		latestDragDir[player.UserId] = cameraDir.Unit
		latestDragPos[player.UserId] = cameraPos
		return
	end

	if action == "unequip" then
		for targetUserId, entry in pairs(activeDrags) do
			if entry.officer == player then
				stopDrag(targetUserId)
			end
		end
		latestDragDir[player.UserId] = nil
		latestDragPos[player.UserId] = nil
		return
	end

	if action == "release" then
		local targetUserId2 = arg1
		if typeof(targetUserId2) ~= "number" then return end
		local target2 = Players:GetPlayerByUserId(targetUserId2)
		if not target2 then return end
		if target2:GetAttribute("Detained") ~= true then return end
		if target2:GetAttribute("DetainedBy") ~= player.UserId then return end

		target2:SetAttribute("Detained", false)
		target2:SetAttribute("DetainedBy", nil)

		local character = target2.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = target2:GetAttribute("OriginalWalkSpeed") or 16
				humanoid.JumpPower = target2:GetAttribute("OriginalJumpPower") or 50
			end
		end
		target2:SetAttribute("OriginalWalkSpeed", nil)
		target2:SetAttribute("OriginalJumpPower", nil)

		stopDrag(targetUserId2)
		print("[CUFFS] Target released: " .. target2.Name)
		return
	end

	local targetUserId = action
	if typeof(targetUserId) ~= "number" then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then print("[CUFFS] Invalid target") return end
	if player == target then print("[CUFFS] Cannot detain self") return end
	if target:GetAttribute("Detained") == true then print("[CUFFS] Already detained") return end

	local officerCharacter = player.Character
	local targetCharacter = target.Character
	if not officerCharacter or not targetCharacter then return end

	local equippedTool = officerCharacter:FindFirstChildOfClass("Tool")
	if not equippedTool or equippedTool.Name ~= "Handcuffs" then
		print("[CUFFS] Handcuffs not equipped")
		return
	end

	local officerRoot = officerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not officerRoot or not targetRoot then return end

	local distance = (officerRoot.Position - targetRoot.Position).Magnitude
	if distance > DETAIN_DISTANCE then print("[CUFFS] Target too far") return end

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if humanoid then
		target:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
		target:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
	end

	target:SetAttribute("Detained", true)
	target:SetAttribute("DetainedBy", player.UserId)
	applyDetainedState(target)
	createDragBody(target)
	activeDrags[target.UserId] = {officer = player, target = target}
	latestDragDir[player.UserId] = officerRoot.CFrame.LookVector
	print("[CUFFS] Target detained: " .. target.Name)

	-- Afficher le menu de jail à l'officier
	JailPromptRemote:FireClient(player, target.UserId, target.Name)
end)

JailSubmitRemote.OnServerEvent:Connect(function(officer, targetUserId, reason, durationMinutes)
	if typeof(targetUserId) ~= "number" then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then return end
	if target == officer then return end
	if target:GetAttribute("Detained") ~= true then return end
	if target:GetAttribute("DetainedBy") ~= officer.UserId then return end
	if target:GetAttribute("Jailed") == true then return end

	local officerCharacter = officer.Character
	local targetCharacter = target.Character
	if not officerCharacter or not targetCharacter then return end

	local equippedTool = officerCharacter:FindFirstChildOfClass("Tool")
	if not equippedTool or equippedTool.Name ~= "Handcuffs" then return end

	local officerRoot = officerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not officerRoot or not targetRoot then return end
	if (officerRoot.Position - targetRoot.Position).Magnitude > DETAIN_DISTANCE then return end

	if typeof(reason) ~= "string" then return end
	reason = string.gsub(reason, "^%s+", "")
	reason = string.gsub(reason, "%s+$", "")
	if #reason == 0 or #reason > 200 then return end

	if typeof(durationMinutes) ~= "number" then return end
	if durationMinutes ~= durationMinutes then return end
	if durationMinutes <= 0 or durationMinutes > MAX_JAIL_MINUTES then return end

	jailPlayer(target, officer, reason, math.floor(durationMinutes))
end)

RunService.Heartbeat:Connect(function()
	for targetUserId, entry in pairs(activeDrags) do
		local officer = entry.officer
		local target = entry.target
		if not officer or not target then
			stopDrag(targetUserId)
			continue
		end
		if target:GetAttribute("Detained") ~= true then
			stopDrag(targetUserId)
			continue
		end
		if target:GetAttribute("Jailed") == true then
			stopDrag(targetUserId)
			continue
		end
		local officerCharacter = officer.Character
		local targetCharacter = target.Character
		if not officerCharacter or not targetCharacter then
			stopDrag(targetUserId)
			continue
		end
		local officerRoot = officerCharacter:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not officerRoot or not targetRoot then
			stopDrag(targetUserId)
			continue
		end
		local dir = latestDragDir[officer.UserId] or officerRoot.CFrame.LookVector
		local basePos = latestDragPos[officer.UserId] or officerRoot.Position
		local body = targetRoot:FindFirstChild("DragBody")
		if not body then
			body = createDragBody(target)
			if not body then continue end
		end
		local targetPos = basePos + dir * DRAG_DISTANCE - Vector3.new(0, 1, 0)
		body.Position = targetPos
		local gyro = targetRoot:FindFirstChild("DragGyro")
		if gyro then
			gyro.CFrame = CFrame.lookAt(targetRoot.Position, targetRoot.Position + dir)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		if player:GetAttribute("Jailed") == true then
			teleportToPrison(player)
			applyJailedState(player)
			JailStatusRemote:FireClient(player, player:GetAttribute("JailReason"), player:GetAttribute("JailEndTime"))
		elseif player:GetAttribute("Detained") == true then
			applyDetainedState(player)
			if activeDrags[player.UserId] then
				createDragBody(player)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	latestDragDir[player.UserId] = nil
	latestDragPos[player.UserId] = nil
	if jailTimers[player.UserId] then
		jailTimers[player.UserId]:Cancel()
		jailTimers[player.UserId] = nil
	end
	for targetUserId, entry in pairs(activeDrags) do
		if entry.officer == player or entry.target == player then
			stopDrag(targetUserId)
		end
	end
end)
