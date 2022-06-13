export type Particle = {
	Element: GuiObject,
	Speed: number,
	Position: Vector2,
	SpreadAngle: number,
	RotSpeed: number,
	Acceleration: Vector2,
	Age: number,
	Ticks: number,
	maxAge: number,
	isDead: boolean,
	new: (Emitter: ParticleEmitter2D) -> (Particle),
	Update: (self: Particle, delta: number) -> (),
	Destroy: (self: Particle) -> ()
}
	
local ParticleClass: Particle = {}

local function Rotate(v: Vector2, degrees: number)
	local sin = math.sin(math.rad(degrees));
	local cos = math.cos(math.rad(degrees));

	local tx = v.x;
	local ty = v.y;
	return Vector2.new((cos * tx) - (sin * ty),(sin * tx) + (cos * ty))
end

function ParticleClass.new(emitter)
	local self = {}
	self.Element = emitter.Element:Clone()
	self.Element.Size = emitter.Size
	self.Element.Parent = emitter.Canvas
	
	emitter.preSpawn(self.Element)
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
	self.Element.Position = UDim2.new(
		UDim.new(0, self.Position.X),
		UDim.new(0, self.Position.Y)
	)
	self.SpreadAngle = math.random(emitter.SpreadAngle.Min, emitter.SpreadAngle.Max)
	self.RotSpeed = emitter.RotSpeed
	
	--unrotate the acceleration since the speed will be rotated
	self.Acceleration = Rotate(emitter.Acceleration, -self.SpreadAngle)
	
	self.Transparency = emitter.Transparency
	self.Age = 0
	self.Ticks = 0
	self.maxAge = math.random(emitter.Lifetime.Min, emitter.Lifetime.Max)
	self.isDead = false

	return setmetatable(self, {__index = ParticleClass})
end



function ParticleClass:Update(delta)

	if self.Age >= self.maxAge and self.maxAge > 0 then 
		self:Destroy()
		return
	end


	self.Ticks = self.Ticks + 1
	self.Age = self.Age + delta	
	
	local dir = Rotate(self.Speed, self.SpreadAngle) * Vector2.new(1,-1)
	self.Speed += (self.Acceleration * delta)

	self.Position += (dir * delta)
	self.Element.Position = UDim2.new(
		UDim.new(0, self.Position.X),
		UDim.new(0, self.Position.Y)
	)
	self.Element.Rotation += self.RotSpeed * delta

end

function ParticleClass:Destroy()
	self.isDead = true
	self.Element:Destroy()
end


export type ParticleEmitter2D = {
	particles: {Particle},
	Enabled: boolean,
	Element: GuiObject,
	Hook: GuiObject,
	preSpawn: any,
	Rate: number,
	Color: Color3,
	Size: UDim2,
	Transparency: number,
	ZOffset: number,
	xSpeed: NumberRange,
	ySpeed: NumberRange,
	SpreadAngle: NumberRange,
	RotSpeed: number,
	Lifetime: NumberRange,
	Acceleration: Vector2,
	EmitterMode: (string: "Point") | (string: "Fill"),
	Canvas: CanvasGroup,
	__dead: boolean,
	__elapsedTime: number,
	__runServiceConnection: RBXScriptConnection,
	new: (Hook: GuiObject, Element: GuiObject) -> (ParticleEmitter2D),
	Emit: (self: ParticleEmitter2D, count: number) -> (),
	Destroy: (self: ParticleEmitter2D) -> ()
}

local ParticleEmitterClass: ParticleEmitter2D = {}

function ParticleEmitterClass.new(hook: GuiObject, particleElement: GuiObject)
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
				table.insert(self.particles, ParticleClass.new(self))
				self.__elapsedTime = self.__elapsedTime - (1/self.Rate)
			end
		end
	end)

	return setmetatable(self, {__index = ParticleEmitterClass})
end


function ParticleEmitterClass:Emit(count: number)
	local counter = 0
	while counter < count do
		counter += 1
		table.insert(self.particles, ParticleClass.new(self))
	end
	
end

function ParticleEmitterClass:Destroy()

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

return ParticleEmitterClass
