local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote events
local inviteRequestEvent = ReplicatedStorage:FindFirstChild("SquadInviteRequest") or Instance.new("RemoteEvent")
inviteRequestEvent.Name = "SquadInviteRequest"
inviteRequestEvent.Parent = ReplicatedStorage

local inviteResponseEvent = ReplicatedStorage:FindFirstChild("SquadInviteResponse") or Instance.new("RemoteEvent")
inviteResponseEvent.Name = "SquadInviteResponse"
inviteResponseEvent.Parent = ReplicatedStorage

local squadUpdateEvent = ReplicatedStorage:FindFirstChild("SquadUpdate") or Instance.new("RemoteEvent")
squadUpdateEvent.Name = "SquadUpdate"
squadUpdateEvent.Parent = ReplicatedStorage

local invitePromptEvent = ReplicatedStorage:FindFirstChild("SquadInvitePrompt") or Instance.new("RemoteEvent")
invitePromptEvent.Name = "SquadInvitePrompt"
invitePromptEvent.Parent = ReplicatedStorage

local leaveRequestEvent = ReplicatedStorage:FindFirstChild("SquadLeaveRequest") or Instance.new("RemoteEvent")
leaveRequestEvent.Name = "SquadLeaveRequest"
leaveRequestEvent.Parent = ReplicatedStorage

local waypointRequestEvent = ReplicatedStorage:FindFirstChild("SquadWaypointRequest") or Instance.new("RemoteEvent")
waypointRequestEvent.Name = "SquadWaypointRequest"
waypointRequestEvent.Parent = ReplicatedStorage

local waypointUpdateEvent = ReplicatedStorage:FindFirstChild("SquadWaypointUpdate") or Instance.new("RemoteEvent")
waypointUpdateEvent.Name = "SquadWaypointUpdate"
waypointUpdateEvent.Parent = ReplicatedStorage

-- Squad management
local squads = {}
local playerSquadMap = {}
local pendingInvitations = {}
local nextSquadId = 1

local function getSquadData(squad)
	local data = {
		LeaderUserId = squad.leader.UserId,
		Members = {}
	}
	for _, member in ipairs(squad.members) do
		table.insert(data.Members, {
			UserId = member.UserId,
			Name = member.Name
		})
	end
	return data
end

local function broadcastSquadUpdate(squad)
	local data = getSquadData(squad)
	for _, member in ipairs(squad.members) do
		squadUpdateEvent:FireClient(member, data)
	end
end

local function removePlayerFromSquad(player)
	local squad = playerSquadMap[player]
	if not squad then return end
	local index = table.find(squad.members, player)
	if index then
		table.remove(squad.members, index)
	end
	playerSquadMap[player] = nil
	if squad.leader == player then
		if #squad.members > 0 then
			squad.leader = squad.members[1]
		end
	end
	if #squad.members == 0 then
		table.remove(squads, table.find(squads, squad))
	else
		broadcastSquadUpdate(squad)
	end
	squadUpdateEvent:FireClient(player, nil)
end

local function addPlayerToSquad(player, inviter)
	removePlayerFromSquad(player)
	local squad = playerSquadMap[inviter]
	if not squad then
		squad = { id = nextSquadId, members = {inviter, player}, leader = inviter }
		nextSquadId = nextSquadId + 1
		table.insert(squads, squad)
		playerSquadMap[inviter] = squad
		playerSquadMap[player] = squad
	else
		table.insert(squad.members, player)
		playerSquadMap[player] = squad
	end
	broadcastSquadUpdate(squad)
end

inviteRequestEvent.OnServerEvent:Connect(function(player, targetPlayer)
	if not targetPlayer or targetPlayer == player then return end
	if playerSquadMap[targetPlayer] then return end
	pendingInvitations[targetPlayer] = player
	invitePromptEvent:FireClient(targetPlayer, player.Name, player.UserId)
end)

inviteResponseEvent.OnServerEvent:Connect(function(player, accepted)
	local inviter = pendingInvitations[player]
	if not inviter then return end
	pendingInvitations[player] = nil
	if accepted and Players:GetPlayerByUserId(inviter.UserId) then
		addPlayerToSquad(player, inviter)
	end
end)

leaveRequestEvent.OnServerEvent:Connect(function(player)
	removePlayerFromSquad(player)
end)

waypointRequestEvent.OnServerEvent:Connect(function(player, position)
	if typeof(position) ~= "Vector3" then return end
	local squad = playerSquadMap[player]
	if not squad then return end
	for _, member in ipairs(squad.members) do
		waypointUpdateEvent:FireClient(member, position, player.Name, player.UserId)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pendingInvitations[player] = nil
	for target, inviter in pairs(pendingInvitations) do
		if inviter == player then
			pendingInvitations[target] = nil
		end
	end
	removePlayerFromSquad(player)
end)
