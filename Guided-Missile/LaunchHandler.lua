local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LaunchRemote = ReplicatedStorage.GuidedMissile.Remotes.Launch
local ControlRemote = ReplicatedStorage.GuidedMissile.Remotes.Control

local MissileController = require(script.Parent.MissileController)

LaunchRemote.OnServerEvent:Connect(function(player, aimDirection)
    MissileController.LaunchMissile(player, aimDirection)
end)

ControlRemote.OnServerEvent:Connect(function(player, direction)
    MissileController.SetControlDirection(player, direction)
end)
