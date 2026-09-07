local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LaunchRemote = ReplicatedStorage.GuidedMissile.Remotes.Launch
local MissileLaunched = ReplicatedStorage.GuidedMissile.MissileLaunched
local tool = script.Parent

tool.Activated:Connect(function()
    -- Direction de visée depuis la caméra
    local camera = workspace.CurrentCamera
    local aimDirection = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    -- Demander au serveur de lancer un missile
    LaunchRemote:FireServer(aimDirection)
    -- Notifier le ClientController pour démarrer le contrôle et la caméra
    MissileLaunched:Fire()
end)
