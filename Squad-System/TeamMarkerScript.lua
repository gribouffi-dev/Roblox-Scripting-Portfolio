local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local squadUpdateEvent = ReplicatedStorage:WaitForChild("SquadUpdate", 5)

local markers = {}

local function createMarker(player)
	if markers[player.UserId] then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TeamMarker_" .. player.UserId
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(20, 20)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.MaxDistance = 200
	billboard.Parent = script.Parent -- PlayerGui

	local point = Instance.new("Frame")
	point.Size = UDim2.fromScale(1, 1)
	point.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	point.BorderSizePixel = 0
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Position = UDim2.fromScale(0.5, 0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = point
	point.Parent = billboard

	markers[player.UserId] = billboard

	local function attachToCharacter(character)
		if not character then return end
		local head = character:WaitForChild("Head", 5)
		if head then
			billboard.Adornee = head
		end
	end

	if player.Character then
		attachToCharacter(player.Character)
	end
	player.CharacterAdded:Connect(attachToCharacter)
end

local function removeMarker(player)
	local marker = markers[player.UserId]
	if marker then
		marker:Destroy()
		markers[player.UserId] = nil
	end
end

local function updateMarkers(squadData)
	if not squadData or not squadData.Members then
		for userId, marker in pairs(markers) do
			marker:Destroy()
		end
		markers = {}
		return
	end

	local activeUserIds = {}
	for _, member in ipairs(squadData.Members) do
		activeUserIds[member.UserId] = true
	end

	for userId, marker in pairs(markers) do
		if not activeUserIds[userId] then
			marker:Destroy()
			markers[userId] = nil
		end
	end

	for _, member in ipairs(squadData.Members) do
		local player = Players:GetPlayerByUserId(member.UserId)
		if player then
			if not markers[player.UserId] then
				createMarker(player)
			end
		end
	end
end

squadUpdateEvent.OnClientEvent:Connect(updateMarkers)

Players.PlayerRemoving:Connect(function(player)
	removeMarker(player)
end)
