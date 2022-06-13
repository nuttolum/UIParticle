local Particle = {}

local function Rotate(v: Vector2, degrees: number)
	local sin = math.sin(math.rad(degrees));
	local cos = math.cos(math.rad(degrees));

	local tx = v.x;
	local ty = v.y;
	return Vector2.new((cos * tx) - (sin * ty),(sin * tx) + (cos * ty))
end

function Particle.new(emitter)
	local self = {}
	self.element = emitter.Element:Clone()
	self.element.Size = emitter.Size
	self.element.Parent = emitter.Canvas
	
	emitter.preSpawn(self.element)
	self.Speed = Vector2.new(
		math.random(emitter.xSpeed.Min, emitter.xSpeed.Max),
		math.random(emitter.ySpeed.Min, emitter.ySpeed.Max)
	)
	
	local spawnPosition
	if emitter.EmitterMode == "Point" then
		spawnPosition = emitter.Hook.AbsolutePosition
		local size = emitter.Hook.AbsoluteSize
		spawnPosition = Vector2.new(spawnPosition.X + size.X/2, spawnPosition.Y + size.Y/2)
	else
		spawnPosition = emitter.Hook.AbsolutePosition
		local size = emitter.Hook.AbsoluteSize
		spawnPosition = Vector2.new(spawnPosition.X + math.random(0, size.X), spawnPosition.Y + math.random(0, size.Y))
	end
	
	self.Position = spawnPosition
	self.element.Position = UDim2.new(
		UDim.new(0, self.Position.X),
		UDim.new(0, self.Position.Y)
	)
	self.SpreadAngle = math.random(emitter.SpreadAngle.Min, emitter.SpreadAngle.Max)
	self.RotSpeed = emitter.RotSpeed
	
	--unrotate the acceleration since the speed will be rotated
	self.Acceleration = Rotate(emitter.Acceleration, -self.SpreadAngle)
	
	self.Transparency = emitter.Transparency
	self.age = 0
	self.ticks = 0
	self.maxAge = math.random(emitter.Lifetime.Min, emitter.Lifetime.Max)
	self.isDead = false

	return setmetatable(self, {__index = Particle})
end



function Particle:Update(delta)

	if self.age >= self.maxAge and self.maxAge > 0 then 
		self:Destroy()
		return
	end


	self.ticks = self.ticks + 1
	self.age = self.age + delta	
	
	local dir = Rotate(self.Speed, self.SpreadAngle) * Vector2.new(1,-1)
	self.Speed += (self.Acceleration * delta)

	self.Position += (dir * delta)
	self.element.Position = UDim2.new(
		UDim.new(0, self.Position.X),
		UDim.new(0, self.Position.Y)
	)
	self.element.Rotation += self.RotSpeed * delta

end

function Particle:Destroy()
	self.isDead = true
	self.element:Destroy()
end


local ParticleEmitter = {}


function ParticleEmitter.new(hook: GuiObject, particleElement: GuiObject)
	local self = {}
	self.particles = {}
	self.Enabled = false
	self.Element = particleElement
	self.Hook = hook

	self.preSpawn = function(p) end
	
	--properties
	self.Rate = 20
	self.Color = Color3.new(1,1,1)
	self.Size = particleElement.Size
	self.Transparency = 0
	self.ZOffset = 0
	self.xSpeed = NumberRange.new(0,0)
	self.ySpeed = NumberRange.new(150,500)
	self.SpreadAngle = NumberRange.new(-15,15)
	self.RotSpeed = 0
	self.Lifetime = NumberRange.new(5,10)
	self.Acceleration = Vector2.new(0,-500)
	
	-- "Fill": spawn randomly within the hook
	-- "Point": spawn at the center of the hook
	self.EmitterMode = "Point"
	--set up canvas
	self.Canvas = Instance.new("CanvasGroup")
	self.Canvas.Parent = hook:FindFirstAncestorWhichIsA("LayerCollector")
	self.Canvas.Size = UDim2.new(1,0,1,0)
	self.Canvas.AnchorPoint = Vector2.new(0.5,0.5)
	self.Canvas.Position = UDim2.new(0.5,0,0.5,0)
	self.Canvas.BackgroundTransparency = 1
	self.Canvas.ZIndex = self.Hook.ZIndex + self.ZOffset
	self.Canvas.GroupColor3 = self.Color
	self.Canvas.GroupTransparency = self.Transparency


	self.__dead = false
	self.__elapsedTime = 0
	
	self.__runServiceConnection = game:GetService("RunService").Heartbeat:Connect(function(delta)
		
		--hacky way to make sure the canvasgroup follows the values
		if self.Transparency ~= self.Canvas.GroupTransparency then
			self.Canvas.GroupTransparency = self.Transparency
		end
		if self.Color ~= self.Canvas.GroupColor3 then
			self.Canvas.GroupColor3 = self.Color
		end
		if self.ZOffset ~= self.Canvas.ZIndex - self.Hook.ZIndex then
			self.Canvas.GroupTransparency = self.Hook.ZIndex + self.ZOffset
		end
		self.__elapsedTime = self.__elapsedTime + delta	
		for index, particle in ipairs(self.particles) do
			if particle.isDead then 
				table.remove(self.particles, index)
			else
				particle:Update(delta)
			end
		end


		if self.Rate > 0 and (self.__dead == false) and self.Enabled then
			while self.__elapsedTime >= (1/self.Rate) do
				table.insert(self.particles, Particle.new(self))
				self.__elapsedTime = self.__elapsedTime - (1/self.Rate)
			end
		end
	end)
	
	return setmetatable(self, {__index = ParticleEmitter})
end


function ParticleEmitter:Emit(n: number)
	local counter = 0
	while counter < n do
		counter += 1
		table.insert(self.particles, Particle.new(self))
	end
	
end

function ParticleEmitter:Destroy()

	if self.__dead then
		error('Cannot destroy dead particle emitter.')
		return
	end

	self.__dead = true
	for _,particle in ipairs(self.particles) do
		if particle then
			particle:Destroy()
		end
	end

	if self.__runServiceConnection then
		self.__runServiceConnection:Disconnect()
	end
end

return ParticleEmitter
