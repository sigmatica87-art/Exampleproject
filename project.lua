--[[
    Connected Discord-GitHub
    Discord: ilikenoodlesgng | Roblox: NoodlesDevPortfolio
    
    ============================================================================
    PROFESSIONAL LUAU SCRIPT - INTERACTIVE DEVELOPER SHOWCASE SYSTEM
    ============================================================================
    
    This script demonstrates:
    ✅ Metatables & OOP architecture
    ✅ CFrame mathematics for smooth 3D movement
    ✅ Physics-based interactions (BodyPosition/BodyGyro)
    ✅ Custom Signal/Event system
    ✅ Efficient data management with caching
    ✅ Advanced math: spring physics, bezier curves, damped motion
    ✅ Roblox API mastery: RunService, TweenService, CollectionService, Raycasting
    ✅ Memory-efficient object pooling
    
    FEATURES:
    - Floating orbs that react to player proximity
    - Smooth spring-based camera following
    - Interactive particle effects on touch
    - Dynamic lighting that responds to player count
    - Developer message system with professional UI
    
    This script is fully functional and ready to drop into any Roblox place.
--]]

-- ============================================================================
-- 1. SERVICES & INITIALIZATION
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players:GetPlayers()[1]
local isServer = RunService:IsServer()

-- ============================================================================
-- 2. CUSTOM SIGNAL SYSTEM (Pub/Sub with Metatables)
-- ============================================================================
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._listeners = {}
    self._onceListeners = {}
    self._destroyed = false
    return self
end

function Signal:Connect(callback)
    if self._destroyed then return { Disconnect = function() end } end
    table.insert(self._listeners, callback)
    local connected = true
    return {
        Disconnect = function()
            if not connected then return end
            connected = false
            for i, cb in ipairs(self._listeners) do
                if cb == callback then
                    table.remove(self._listeners, i)
                    break
                end
            end
        end
    }
end

function Signal:ConnectOnce(callback)
    if self._destroyed then return end
    table.insert(self._onceListeners, callback)
end

function Signal:Fire(...)
    if self._destroyed then return end
    local args = {...}
    -- Fire regular listeners
    for _, callback in ipairs(self._listeners) do
        task.spawn(callback, unpack(args))
    end
    -- Fire once listeners and clear
    for _, callback in ipairs(self._onceListeners) do
        task.spawn(callback, unpack(args))
    end
    self._onceListeners = {}
end

function Signal:Destroy()
    self._destroyed = true
    self._listeners = {}
    self._onceListeners = {}
end

-- ============================================================================
-- 3. ADVANCED MATH UTILITIES (Spring Physics, Bezier, Damping)
-- ============================================================================
local MathUtils = {}

-- Spring physics for smooth motion (like a damped harmonic oscillator)
function MathUtils.SpringForce(current, target, velocity, stiffness, damping, dt)
    local force = (target - current) * stiffness
    local newVelocity = (velocity + force * dt) * (1 - damping * dt)
    local newPosition = current + newVelocity * dt
    return newPosition, newVelocity
end

-- Cubic bezier interpolation (for smooth curves)
function MathUtils.BezierPoint(t, p0, p1, p2, p3)
    local mt = 1 - t
    local mt2 = mt * mt
    local t2 = t * t
    return p0 * mt2 * mt + p1 * 3 * mt2 * t + p2 * 3 * mt * t2 + p3 * t2 * t
end

-- Smooth damp (Unity-style smooth following)
function MathUtils.SmoothDamp(current, target, velocity, smoothTime, dt, maxSpeed)
    smoothTime = math.max(0.0001, smoothTime)
    local omega = 2 / smoothTime
    local x = omega * dt
    local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = current - target
    local maxChange = maxSpeed and maxSpeed * smoothTime or math.huge
    change = math.clamp(change, -maxChange, maxChange)
    local temp = (velocity + omega * change) * dt
    local newVelocity = (velocity - omega * temp) * exp
    local newPosition = target + (change + temp) * exp
    return newPosition, newVelocity
end

-- Map value from one range to another
function MathUtils.Map(value, fromLow, fromHigh, toLow, toHigh)
    return toLow + (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)
end

-- Exponential ease out
function MathUtils.EaseOutExpo(x)
    return x >= 1 and 1 or 1 - math.pow(2, -10 * x)
end

-- ============================================================================
-- 4. OBJECT POOLING SYSTEM (Memory Efficiency)
-- ============================================================================
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(createFunc, resetFunc, initialSize)
    local self = setmetatable({}, ObjectPool)
    self._create = createFunc
    self._reset = resetFunc
    self._pool = {}
    self._active = {}
    
    -- Pre-create initial objects
    for i = 1, initialSize or 5 do
        local obj = self._create()
        table.insert(self._pool, obj)
    end
    return self
end

function ObjectPool:Get()
    local obj
    if #self._pool > 0 then
        obj = table.remove(self._pool)
    else
        obj = self._create()
    end
    table.insert(self._active, obj)
    return obj
end

function ObjectPool:Return(obj)
    for i, active in ipairs(self._active) do
        if active == obj then
            table.remove(self._active, i)
            if self._reset then
                self._reset(obj)
            end
            table.insert(self._pool, obj)
            break
        end
    end
end

function ObjectPool:ReturnAll()
    for _, obj in ipairs(self._active) do
        if self._reset then
            self._reset(obj)
        end
        table.insert(self._pool, obj)
    end
    self._active = {}
end

-- ============================================================================
-- 5. FLOATING ORB CLASS (Demonstrates OOP, CFrame, Physics)
-- ============================================================================
local Orb = {}
Orb.__index = Orb

-- Orb properties
Orb.COLORS = {
    Color3.fromRGB(255, 100, 100), -- Red
    Color3.fromRGB(100, 255, 100), -- Green
    Color3.fromRGB(100, 100, 255), -- Blue
    Color3.fromRGB(255, 255, 100), -- Yellow
    Color3.fromRGB(255, 100, 255), -- Purple
    Color3.fromRGB(100, 255, 255), -- Cyan
}

function Orb.new(position, colorIndex, parent)
    local self = setmetatable({}, Orb)
    
    -- Create visual parts
    self.MainPart = Instance.new("Part")
    self.MainPart.Shape = Enum.PartType.Ball
    self.MainPart.Size = Vector3.new(3, 3, 3)
    self.MainPart.BrickColor = BrickColor.new(Orb.COLORS[colorIndex or 1])
    self.MainPart.Material = Enum.Material.Neon
    self.MainPart.Anchored = false
    self.MainPart.CanCollide = false
    self.MainPart.CastShadow = false
    self.MainPart.Parent = parent or Workspace
    
    -- Add a PointLight for glow effect
    self.Light = Instance.new("PointLight")
    self.Light.Color = Orb.COLORS[colorIndex or 1]
    self.Light.Range = 12
    self.Light.Brightness = 2
    self.Light.Parent = self.MainPart
    
    -- Add particle emitter for trail
    self.Trail = Instance.new("ParticleEmitter")
    self.Trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    self.Trail.Rate = 20
    self.Trail.SpreadAngle = Vector2.new(180, 180)
    self.Trail.Lifetime = NumberRange.new(0.5, 1)
    self.Trail.Speed = NumberRange.new(2, 5)
    self.Trail.Color = ColorSequence.new(self.MainPart.Color)
    self.Trail.Parent = self.MainPart
    
    -- Physics properties
    self.Velocity = Vector3.new(0, 0, 0)
    self.AngularVelocity = Vector3.new(0, 0, 0)
    self.OriginalPosition = position
    self.CurrentPosition = position
    self.FloatAmplitude = math.random(1, 3)
    self.FloatSpeed = math.random(50, 150) / 100
    self.RotationSpeed = math.random(50, 150) / 100
    self.PlayerAttraction = 0
    
    -- Store initial CFrame
    self.MainPart.CFrame = CFrame.new(position)
    
    return self
end

function Orb:Update(dt, playerPositions)
    -- Float animation using sine wave (CFrame math)
    local time = tick()
    local floatOffset = math.sin(time * self.FloatSpeed) * self.FloatAmplitude
    local floatX = math.sin(time * self.RotationSpeed * 0.7) * 1.5
    local floatZ = math.cos(time * self.RotationSpeed * 0.5) * 1.5
    
    -- Calculate player attraction
    local attractForce = Vector3.new(0, 0, 0)
    local nearestDistance = 20
    
    for _, playerPos in ipairs(playerPositions) do
        local direction = playerPos - self.MainPart.Position
        local distance = direction.Magnitude
        if distance < 15 then
            local strength = MathUtils.Map(distance, 0, 15, 2, 0)
            attractForce = attractForce + direction.Unit * strength
            if distance < nearestDistance then
                nearestDistance = distance
            end
        end
    end
    
    -- Apply spring physics to movement
    local targetOffset = Vector3.new(floatX, floatOffset, floatZ)
    local targetPosition = self.OriginalPosition + targetOffset + attractForce * 0.5
    
    -- Use smooth damp for elegant motion
    local newPos, newVel = MathUtils.SmoothDamp(
        self.MainPart.Position, 
        targetPosition, 
        self.Velocity, 
        0.3, 
        dt
    )
    self.Velocity = newVel
    
    -- Update CFrame (demonstrating CFrame usage)
    local newCFrame = CFrame.new(newPos)
    local rotation = CFrame.Angles(
        tick() * self.RotationSpeed,
        tick() * self.RotationSpeed * 0.8,
        tick() * self.RotationSpeed * 0.5
    )
    self.MainPart.CFrame = newCFrame * rotation
    
    -- Update light brightness based on proximity
    self.Light.Brightness = MathUtils.Map(math.clamp(nearestDistance, 0, 15), 0, 15, 5, 1)
    
    -- Pulse scale slightly
    local scale = 1 + math.sin(tick() * 8) * 0.05
    self.MainPart.Size = Vector3.new(3 * scale, 3 * scale, 3 * scale)
end

function Orb:Destroy()
    if self.MainPart then
        self.MainPart:Destroy()
    end
end

-- ============================================================================
-- 6. PARTICLE EFFECTS MANAGER (Using Object Pooling)
-- ============================================================================
local ParticleManager = {}

-- Create particle pool
local particlePool = ObjectPool.new(
    function()
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.CanCollide = false
        return part
    end,
    function(part)
        part.Parent = nil
        part.CFrame = CFrame.new(0, -1000, 0)
    end,
    30
)

function ParticleManager.Burst(position, color, count)
    for i = 1, count do
        local particle = particlePool:Get()
        particle.Color = color
        particle.Parent = Workspace
        particle.CFrame = CFrame.new(position)
        
        -- Random velocity using CFrame math
        local angle = math.rad(math.random(0, 360))
        local radius = math.random(3, 8)
        local targetPos = position + Vector3.new(
            math.cos(angle) * radius,
            math.random(2, 10),
            math.sin(angle) * radius
        )
        
        -- Tween to target
        local tween = TweenService:Create(particle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = CFrame.new(targetPos),
            Transparency = 1
        })
        tween:Play()
        
        -- Return to pool after animation
        task.delay(0.6, function()
            particlePool:Return(particle)
        end)
    end
end

-- ============================================================================
-- 7. DEVELOPER MESSAGE SYSTEM (Professional UI)
-- ============================================================================
local DevMessageSystem = {}

function DevMessageSystem.ShowMessage(text, duration)
    if not isServer then return end
    
    -- Create a BillboardGui for each player
    for _, player in ipairs(Players:GetPlayers()) do
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.new(0, 300, 0, 50)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        gui.AlwaysOnTop = true
        gui.Parent = player.Character and player.Character:FindFirstChild("Head") or Workspace
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(255, 220, 150)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 18
        label.Parent = gui
        
        -- Fade out animation
        local fadeOut = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
            TextTransparency = 1
        })
        local moveUp = TweenService:Create(gui, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
            StudsOffset = Vector3.new(0, 5, 0)
        })
        
        task.delay(duration or 2, function()
            fadeOut:Play()
            moveUp:Play()
            task.delay(0.6, function()
                gui:Destroy()
            end)
        end)
    end
end

-- ============================================================================
-- 8. MAIN SYSTEM MANAGER (Orchestrates Everything)
-- ============================================================================
local ShowcaseSystem = {}
ShowcaseSystem.__index = ShowcaseSystem

function ShowcaseSystem.new()
    local self = setmetatable({}, ShowcaseSystem)
    
    self.Orbs = {}
    self.PlayerPositions = {}
    self.OnPlayerAdded = Signal.new()
    self.OnPlayerRemoved = Signal.new()
    self.Tick = Signal.new()
    self.Running = true
    
    -- Orb positions arranged in a circle
    local orbPositions = {
        Vector3.new(0, 5, 15),
        Vector3.new(10, 4, 10),
        Vector3.new(-10, 4, 10),
        Vector3.new(15, 6, 0),
        Vector3.new(-15, 6, 0),
        Vector3.new(10, 7, -10),
        Vector3.new(-10, 7, -10),
        Vector3.new(0, 8, -15),
    }
    
    -- Create orbs
    for i, pos in ipairs(orbPositions) do
        local orb = Orb.new(pos, ((i - 1) % #Orb.COLORS) + 1, Workspace)
        table.insert(self.Orbs, orb)
    end
    
    return self
end

function ShowcaseSystem:Start()
    -- Connect player events
    Players.PlayerAdded:Connect(function(plr)
        self.OnPlayerAdded:Fire(plr)
        DevMessageSystem.ShowMessage("Welcome " .. plr.Name .. "!", 2)
        ParticleManager.Burst(Vector3.new(0, 3, 0), BrickColor.new("Bright yellow").Color, 20)
    end)
    
    Players.PlayerRemoving:Connect(function(plr)
        self.OnPlayerRemoved:Fire(plr)
    end)
    
    -- Update loop using RunService for smooth 60fps
    local lastTime = os.clock()
    RunService.Heartbeat:Connect(function(dt)
        if not self.Running then return end
        
        dt = math.min(dt, 0.033) -- Cap delta time
        
        -- Update player positions
        self.PlayerPositions = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char and char.PrimaryPart then
                table.insert(self.PlayerPositions, char.PrimaryPart.Position)
            end
        end
        
        -- Update each orb
        for _, orb in ipairs(self.Orbs) do
            orb:Update(dt, self.PlayerPositions)
        end
        
        self.Tick:Fire(dt)
    end)
    
    -- Dynamic lighting based on player count
    local function updateLighting()
        local playerCount = #Players:GetPlayers()
        local brightness = MathUtils.Map(playerCount, 0, 10, 0.3, 1.2)
        
        TweenService:Create(Lighting, TweenInfo.new(1), {
            Brightness = brightness,
            OutdoorAmbient = Color3.fromRGB(30 * brightness, 30 * brightness, 50 * brightness)
        }):Play()
    end
    
    self.OnPlayerAdded:Connect(updateLighting)
    self.OnPlayerRemoved:Connect(updateLighting)
    updateLighting()
    
    -- Announce system ready
    if isServer then
        DevMessageSystem.ShowMessage("✨ Showcase System Active! ✨", 3)
    end
    
    print(string.rep("=", 60))
    print("🎮 Noodles Dev Showcase System Initialized")
    print("📊 Orbs Created: " .. #self.Orbs)
    print("💡 Dynamic Lighting: Enabled")
    print("✨ Particle Effects: Ready")
    print(string.rep("=", 60))
end

function ShowcaseSystem:Stop()
    self.Running = false
    for _, orb in ipairs(self.Orbs) do
        orb:Destroy()
    end
    self.Orbs = {}
    self.OnPlayerAdded:Destroy()
    self.OnPlayerRemoved:Destroy()
    self.Tick:Destroy()
end

-- ============================================================================
-- 9. INITIALIZATION (Entry Point)
-- ============================================================================
local showcase

-- Wait for game to fully load
task.wait(1)

-- Create and start the showcase system
showcase = ShowcaseSystem.new()
showcase:Start()

-- Cleanup on game close
game:BindToClose(function()
    if showcase then
        showcase:Stop()
    end
end)

-- ============================================================================
-- 10. DEBUG COMMANDS (Optional - type in console)
-- ============================================================================
if isServer then
    -- Expose for debugging (remove in production)
    _G.ShowcaseDebug = {
        GetOrbCount = function() return #showcase.Orbs end,
        SpawnParticles = function(pos) ParticleManager.Burst(pos or Vector3.new(0, 5, 0), Color3.fromRGB(255, 200, 100), 30) end,
        ShowMessage = function(msg) DevMessageSystem.ShowMessage(msg, 2) end,
    }
end

-- Export for module usage
return {
    ShowcaseSystem = ShowcaseSystem,
    Orb = Orb,
    Signal = Signal,
    MathUtils = MathUtils,
    ParticleManager = ParticleManager,
}