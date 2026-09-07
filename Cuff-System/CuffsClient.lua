local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CuffsRemote = ReplicatedStorage:FindFirstChild("CuffsRemote")

local player = Players.LocalPlayer
local tool = script.Parent

local PROXIMITY_RADIUS = 10
local equipped = false
local activePrompts = {}
local updateLoop = nil

local function clearPrompts()
    for _, prompt in pairs(activePrompts) do
        if prompt.Parent then
            prompt:Destroy()
        end
    end
    table.clear(activePrompts)
end

local function updatePrompts()
    if not equipped then
        clearPrompts()
        return
    end

    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local inRange = {}

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local otherCharacter = other.Character
            if otherCharacter then
                local otherRoot = otherCharacter:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local distance = (root.Position - otherRoot.Position).Magnitude
                    if distance <= PROXIMITY_RADIUS then
                        inRange[other.UserId] = true
                        local existingPrompt = activePrompts[other.UserId]
                        if not existingPrompt or not existingPrompt.Parent then
                            local prompt = Instance.new("ProximityPrompt")
                            prompt.Name = "CuffsPrompt"
                            prompt.ActionText = "Detain"
                            prompt.ObjectText = other.Name
                            prompt.KeyboardKeyCode = Enum.KeyCode.E
                            prompt.HoldDuration = 1
                            prompt.MaxActivationDistance = PROXIMITY_RADIUS
                            prompt.RequiresLineOfSight = false
                            prompt.Parent = otherRoot

                            prompt.Triggered:Connect(function()
                                CuffsRemote:FireServer(other.UserId)
                            end)

                            activePrompts[other.UserId] = prompt
                            print("[CUFFS] Prompt created for: " .. other.Name)
                        end
                    end
                end
            end
        end
    end

    -- Supprimer les prompts hors de portée
    for userId, prompt in pairs(activePrompts) do
        if not inRange[userId] or not prompt.Parent then
            prompt:Destroy()
            activePrompts[userId] = nil
        end
    end
end

local RunService = game:GetService("RunService")

local function startLoop()
    if updateLoop then return end
    updateLoop = task.spawn(function()
        while equipped do
            updatePrompts()
            local camera = workspace.CurrentCamera
            if camera then
                CuffsRemote:FireServer("drag", camera.CFrame.Position, camera.CFrame.LookVector)
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

local function stopLoop()
    if updateLoop then
        task.cancel(updateLoop)
        updateLoop = nil
    end
    clearPrompts()
end

tool.Equipped:Connect(function()
    equipped = true
    print("[CUFFS] Tool equipped")
    startLoop()
end)

tool.Unequipped:Connect(function()
    equipped = false
    stopLoop()
    CuffsRemote:FireServer("unequip")
end)

player.CharacterAdded:Connect(function()
    if equipped then
        updatePrompts()
    end
end)
