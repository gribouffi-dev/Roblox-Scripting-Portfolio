local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LaunchRemote = ReplicatedStorage.GuidedMissile.Remotes.Launch
local MissileLaunched = ReplicatedStorage.GuidedMissile.MissileLaunched
local tool = script.Parent

tool.Activated:Connect(function()
    local camera = workspace.CurrentCamera
    local aimDirection = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    LaunchRemote:FireServer(aimDirection)
    MissileLaunched:Fire()
end)
