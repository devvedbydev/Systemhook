local CONFIG = {
    ESPColor = Color3.fromRGB(173, 216, 230),
    TargetColor = Color3.fromRGB(255, 255, 255),
    PredictionTime = 0.067,
    ESPEnabled = true,
    TargetStrafe = false,
    StrafeDistance = 20,
    StrafeSpeed = 10,
    CircleColor = Color3.fromRGB(255, 255, 255),
    CircleRadius = 0,
    AimbotSmoothness = 5, 
    HeadshotPredictionTime = 0.079,
    AimbotFOV = 90,
    StrafeRandomRange = 60, 
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local targetPlayer = nil
local aiming = false
local strafeEnabled = CONFIG.TargetStrafe
local strafeAngle = 0
local highlights = {}
local circleIndicators = {}
local currentStrafeSpeed = CONFIG.StrafeSpeed
local directionChangeInterval = 0.143 -- Interval for changing direction
local lastDirectionChange = tick()

local function updateHighlight(character, color)
    local highlight = highlights[character] or character:FindFirstChild("Highlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "Highlight"
        highlight.Adornee = character
        highlight.Parent = character
        highlight.FillColor = Color3.new(1, 1, 1) -- Set default fill color
        highlight.FillTransparency = 1 -- Fully transparent fill
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0.5
        highlights[character] = highlight
    else
        highlight.OutlineColor = color
    end
end

local function removeHighlight(character)
    local highlight = highlights[character]
    if highlight then
        highlight:Destroy()
        highlights[character] = nil
    end
end

local function updatePlayerESP(player)
    if CONFIG.ESPEnabled then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = player.Character.HumanoidRootPart
            local screenPosition, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
            local color
            if player == LocalPlayer then
                color = Color3.fromRGB(0, 0, 255) -- Blue for local player
            elseif onScreen then
                local ray = Ray.new(Camera.CFrame.Position, humanoidRootPart.Position - Camera.CFrame.Position)
                local hitPart = workspace:FindPartOnRay(ray)
                if hitPart and hitPart:IsDescendantOf(player.Character) then
                    color = Color3.fromRGB(0, 255, 0) -- Green for visible
                else
                    color = Color3.fromRGB(255, 0, 0) -- Red for invisible
                end
            else
                color = Color3.fromRGB(255, 0, 0) -- Red for invisible
            end

            -- Update highlight only if in view
            if onScreen then
                if player == targetPlayer then
                    updateHighlight(player.Character, CONFIG.TargetColor)
                else
                    updateHighlight(player.Character, color)
                end
            else
                removeHighlight(player.Character)
            end
        else
            removeHighlight(player.Character)
        end
    else
        removeHighlight(player.Character)
    end
end

local function getClosestPlayerToCursor()
    local mouse = LocalPlayer:GetMouse()
    local closestPlayer = nil
    local shortestDistance = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local character = player.Character
            local characterPosition = character.HumanoidRootPart.Position
            local screenPosition, onScreen = Camera:WorldToScreenPoint(characterPosition)
            if onScreen then
                local mousePosition = Vector2.new(mouse.X, mouse.Y)
                local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - mousePosition).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

local function predictFuturePosition(character, predictionTime)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return Vector3.new(0, 0, 0)
    end
    local velocity = humanoidRootPart.AssemblyLinearVelocity
    local acceleration = humanoidRootPart.AssemblyAngularVelocity
    return humanoidRootPart.Position + (velocity * predictionTime) + (0.5 * acceleration * predictionTime^2)
end

local function predictHeadshotPosition(character, predictionTime)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return Vector3.new(0, 0, 0)
    end
    local head = character:FindFirstChild("Head")
    if not head then
        return humanoidRootPart.Position
    end
    local headPosition = head.Position
    local velocity = humanoidRootPart.AssemblyLinearVelocity
    local acceleration = humanoidRootPart.AssemblyAngularVelocity
    return headPosition + (velocity * predictionTime) + (0.5 * acceleration * predictionTime^2)
end

local function handleAimlockAndStrafe()
    if aiming and targetPlayer and targetPlayer.Character then
        local character = targetPlayer.Character
        local predictedPosition
        if CONFIG.AimbotFOV >= 90 then
            predictedPosition = predictFuturePosition(character, CONFIG.PredictionTime)
        else
            predictedPosition = predictHeadshotPosition(character, CONFIG.HeadshotPredictionTime)
        end

        -- Directly set the camera CFrame to target the predicted position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPosition)

        if strafeEnabled then
            if tick() - lastDirectionChange > directionChangeInterval then
                strafeAngle = math.random(0, 360)
                currentStrafeSpeed = math.random(1, CONFIG.StrafeSpeed * 2)
                lastDirectionChange = tick()
            end

            -- Calculate strafe position around the target with random offset
            local randomOffset = math.random(-CONFIG.StrafeRandomRange, CONFIG.StrafeRandomRange)
            local strafeOffset = (character.HumanoidRootPart.Position - HumanoidRootPart.Position).unit * CONFIG.StrafeDistance
            local strafePosition = CFrame.new(character.HumanoidRootPart.Position) * CFrame.Angles(0, math.rad(randomOffset + strafeAngle), 0) * CFrame.new(strafeOffset)

            -- Update the player's position to simulate strafing around the target
            HumanoidRootPart.CFrame = CFrame.new(strafePosition.Position, character.HumanoidRootPart.Position)

            -- Draw a circle around the target to represent the strafing area
            local circle = circleIndicators[character] or character:FindFirstChild("CircleIndicator")
            if not circle then
                circle = Instance.new("BillboardGui")
                circle.Name = "CircleIndicator"
                circle.Size = UDim2.new(0, CONFIG.CircleRadius * 2, 0, CONFIG.CircleRadius * 2)
                circle.AlwaysOnTop = true
                circle.Adornee = character.HumanoidRootPart
                circle.Parent = character
                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(1, 0, 1, 0)
                frame.BackgroundColor3 = CONFIG.CircleColor
                frame.BackgroundTransparency = 0.5
                frame.Parent = circle
                circleIndicators[character] = circle
            end
            circle.Size = UDim2.new(0, CONFIG.CircleRadius * 2, 0, CONFIG.CircleRadius * 2)
        end
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        aiming = not aiming
        if aiming then
            targetPlayer = getClosestPlayerToCursor()
            print(aiming and targetPlayer)
        else
            targetPlayer = nil
            print("Aimlock disabled.")
        end
    elseif input.KeyCode == Enum.KeyCode.Y then
        print("Target strafe is patched.")
    elseif input.KeyCode == Enum.KeyCode.X then
        print("Useless function called, strafe is patched.")
    end
end)

local function onChatMessage(message)
    if message:lower() == ".binds" then
        local bindsInfo = [[
Commands:
  E - Toggle aimlock (lock on/off target)
]]
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
            Chat:Chat(LocalPlayer.Character.Head, bindsInfo, Enum.ChatColor.Blue)
        end
    end
end

LocalPlayer.Chatted:Connect(onChatMessage)

local function updateAllPlayerESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = player.Character.HumanoidRootPart
            local screenPosition, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
            if onScreen then
                updatePlayerESP(player)
            else
                removeHighlight(player.Character)
                local circle = circleIndicators[player.Character]
                if circle then
                    circle:Destroy()
                end
            end
        end
    end
end

local function refreshPlayerESP(player)
    if player.Character then
        updatePlayerESP(player)
    end
end

RunService.RenderStepped:Connect(function()
    if CONFIG.ESPEnabled then
        updateAllPlayerESP()
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                removeHighlight(player.Character)
                local circle = circleIndicators[player.Character]
                if circle then
                    circle:Destroy()
                end
            end
        end
    end
    handleAimlockAndStrafe()
end)

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function()
        refreshPlayerESP(player)
    end)
end

local function onCharacterAdded(character)
    HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
    updateAllPlayerESP()
end

local function onPlayerRemoving(player)
    if player.Character then
        removeHighlight(player.Character)
        local circle = circleIndicators[player.Character]
        if circle then
            circle:Destroy()
        end
    end
end

local function onCharacterRemoving(character)
    removeHighlight(character)
    local circle = circleIndicators[character]
    if circle then
        circle:Destroy()
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
LocalPlayer.CharacterRemoving:Connect(onCharacterRemoving)    
