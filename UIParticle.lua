--custom type for the 2d number sequences
export type NumberSequence2D = {
	X: NumberSequence,
	Y: NumberSequence
}

export type Particle = {
	Element: GuiObject,
	Speed: number,
	Position: Vector2,
	SpreadAngle: number,
	RotSpeed: number,
	Acceleration: Vector2,
	Size: NumberSequence2D | Vector2,
	Transparency: NumberSequence | number,
	Color: ColorSequence | Color3,
	Age: number,
	Ticks: number,
	maxAge: number,
	isDead: boolean,
	Canvas: CanvasGroup,
	new: (Emitter: ParticleEmitter2D) -> (Particle),
	Update: (self: Particle, delta: number) -> (),
	Destroy: (self: Particle) -> ()
}

local ParticleClass: Particle = {}
ParticleClass.__index = ParticleClass
local function Rotate(v: Vector2, degrees: number)
	local sin = math.sin(math.rad(degrees));
	local cos = math.cos(math.rad(degrees));

	local tx = v.x;
	local ty = v.y;
	return Vector2.new((cos * tx) - (sin * ty),(sin * tx) + (cos * ty))
end

local function Normalize(min, max, alpha)
	return (alpha - min)/(max-min)
end

-- sequence evaluation functions taken from developer hub 

function evalCS(cs, t)
	if typeof(cs) ~= "ColorSequence" then return cs end
	-- If we are at 0 or 1, return the first or last value respectively
	if t == 0 then return cs.Keypoints[1].Value end
	if t == 1 then return cs.Keypoints[#cs.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #cs.Keypoints - 1 do
		local this = cs.Keypoints[i]
		local next = cs.Keypoints[i + 1]
		if t >= this.Time and t < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (t - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return Color3.new(
				(next.Value.R - this.Value.R) * alpha + this.Value.R,
				(next.Value.G - this.Value.G) * alpha + this.Value.G,
				(next.Value.B - this.Value.B) * alpha + this.Value.B
			)
		end
	end
end

local function evalNS(ns, t)
	if typeof(ns) ~= "NumberSequence" then return ns end
	-- If we are at 0 or 1, return the first or last value respectively
	if t == 0 then return ns.Keypoints[1].Value end
	if t == 1 then return ns.Keypoints[#ns.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #ns.Keypoints - 1 do
		local this = ns.Keypoints[i]
		local next = ns.Keypoints[i + 1]
		if t >= this.Time and t < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (t - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return (next.Value - this.Value) * alpha + this.Value
		end
	end
end

function evalNR(range)
	if typeof(range) ~= "NumberRange" then return range end
	return math.random(range.Min, range.Max)
end
function ParticleClass.new(emitter)
	local self = {}
	self.Element = emitter.Element:Clone()
	self.Color = emitter.Color
	self.StartSize = self.Element.AbsoluteSize
	self.Transparency = emitter.Transparency
	self.Canvas = Instance.new("CanvasGroup")
	self.Canvas.Parent = emitter.Hook:FindFirstAncestorWhichIsA("LayerCollector")
	self.Canvas.Size = UDim2.fromOffset(self.Element.AbsoluteSize.X, self.Element.AbsoluteSize.Y)
	self.Canvas.AnchorPoint = Vector2.new(0.5,0.5)
	self.Canvas.BackgroundTransparency = 1
	self.Canvas.ZIndex = emitter.Hook.ZIndex + emitter.ZOffset
	self.Canvas.GroupColor3 = evalCS(self.Color, 0)
	self.Canvas.GroupTransparency = evalNS(self.Transparency, 0)
	self.Element.Size = UDim2.fromScale(1,1)
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
	self.Canvas.Position = UDim2.new(
		UDim.new(0, self.Position.X),
		UDim.new(0, self.Position.Y)
	)
	self.Element.AnchorPoint = Vector2.new(0.5,0.5)
	self.Element.Position = UDim2.fromScale(0.5,0.5)
	self.Element.Parent = self.Canvas
	self.Size = emitter.Size
	emitter.preSpawn(self.Element)
	self.Speed = Vector2.new(
		evalNR(emitter.xSpeed),
		evalNR(emitter.ySpeed)
	)


	self.SpreadAngle = evalNR(emitter.SpreadAngle)
	self.RotSpeed = evalNR(emitter.RotSpeed)

	--unrotate the acceleration since the speed will be rotated
	self.Acceleration = Rotate(emitter.Acceleration, -self.SpreadAngle)

	self.Transparency = emitter.Transparency
	self.Age = 0
	self.Ticks = 0
	self.maxAge = evalNR(emitter.Lifetime)
	self.isDead = false

	return setmetatable(self, ParticleClass)
end



function ParticleClass:Update(delta)

	if self.Age >= self.maxAge and self.maxAge > 0 then 
		self:Destroy()
		return
	end


	self.Ticks = self.Ticks + 1
	self.Age = self.Age + delta	
	local xSize, ySize = evalNS(self.Size.X, Normalize(0, self.maxAge, self.Age)), evalNS(self.Size.Y, Normalize(0, self.maxAge, self.Age))
	if xSize and ySize then
		self.Canvas.Size = UDim2.new(
			UDim.new(0, self.StartSize.X * xSize),
			UDim.new(0, self.StartSize.Y *ySize)
		)
	end
	local nextColor = evalCS(self.Color, Normalize(0, self.maxAge, self.Age))
	if nextColor and nextColor ~= self.Canvas.GroupColor3  then
		self.Canvas.GroupColor3 = nextColor
	end
	self.Canvas.GroupTransparency = evalNS(self.Transparency, Normalize(0, self.maxAge, self.Age))


	local dir = Rotate(self.Speed, self.SpreadAngle) * Vector2.new(1,-1)
	self.Speed += (self.Acceleration * delta)

	self.Position += (dir * delta)
	self.Canvas.Position = UDim2.new(
		UDim.new(0, self.Position.X),
		UDim.new(0, self.Position.Y)
	)



	self.Canvas.Rotation += self.RotSpeed * delta

end

function ParticleClass:Destroy()
	self.isDead = true
	self.Canvas:Destroy()
end


export type ParticleEmitter2D = {
	particles: {Particle},
	Enabled: boolean,
	Element: GuiObject,
	Hook: GuiObject,
	preSpawn: (Particle) -> (),
	Rate: number,
	Color: ColorSequence | Color3,
	Size: NumberSequence2D | Vector2,
	Transparency: NumberSequence | number,
	ZOffset: number,
	xSpeed: NumberRange | number,
	ySpeed: NumberRange | number,
	SpreadAngle: NumberRange | number,
	RotSpeed: NumberRange | number,
	Lifetime: NumberRange | number,
	Acceleration: Vector2,
	EmitterMode: (string: "Point") | (string: "Fill"),
	__dead: boolean,
	__elapsedTime: number,
	__runServiceConnection: RBXScriptConnection,
	new: (Hook: GuiObject, Element: GuiObject) -> (ParticleEmitter2D),
	fromEmitter3D: (Hook: GuiObject, Emitter: ParticleEmitter, unitMultiplier: number?) -> (ParticleEmitter2D),
	Emit: (self: ParticleEmitter2D, count: number) -> (),
	Destroy: (self: ParticleEmitter2D) -> ()
}

local ParticleEmitterClass: ParticleEmitter2D = {}
ParticleEmitterClass.__index = ParticleEmitterClass
function ParticleEmitterClass.fromEmitter3D(hook: GuiObject, emitter: ParticleEmitter, unitMultiplier: number?)
	local self = {}
	unitMultiplier = unitMultiplier or 1
	self.particles = {}
	self.Enabled = false
	self.Element = Instance.new("ImageLabel")
	self.Element.Size = UDim2.new(0,unitMultiplier,0,unitMultiplier)
	self.Element.Image = emitter.Texture
	self.Element.BackgroundTransparency = 1
	self.Element.Parent = game.ReplicatedStorage
	self.Hook = hook

	self.preSpawn = function(p) end

	--properties
	self.Rate = emitter.Rate
	self.Color = emitter.Color
	self.Size = {X = emitter.Size, Y = emitter.Size}
	self.Transparency = emitter.Transparency
	self.ZOffset = emitter.ZOffset
	self.xSpeed = NumberRange.new(0,0)
	self.ySpeed = NumberRange.new(emitter.Speed.Min * unitMultiplier, emitter.Speed.Max * unitMultiplier)
	self.SpreadAngle = NumberRange.new(emitter.SpreadAngle.X, emitter.SpreadAngle.Y)
	self.RotSpeed = emitter.RotSpeed
	self.Lifetime = emitter.Lifetime
	self.Acceleration = Vector2.new(emitter.Acceleration.X * unitMultiplier, emitter.Acceleration.Y * unitMultiplier)

	self.EmitterMode = emitter.ShapeStyle == Enum.ParticleEmitterShapeStyle.Volume and "Fill" or "Point"



	self.__dead = false
	self.__elapsedTime = 0

	self.__runServiceConnection = game:GetService("RunService").Heartbeat:Connect(function(delta)


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

	return setmetatable(self, ParticleEmitterClass)
end

function ParticleEmitterClass.new(hook: GuiObject, particleElement: GuiObject)
	local self = {}

	self.particles = {}
	self.Enabled = false
	self.Element = particleElement
	self.Hook = hook

	self.preSpawn = function(p) end

	--properties
	self.Rate = 20
	self.Color = ColorSequence.new(Color3.new(1,1,1))
	self.Size = {X = NumberSequence.new(1), Y = NumberSequence.new(1)}
	self.Transparency = NumberSequence.new(0)
	self.ZOffset = 0
	self.xSpeed = NumberRange.new(0,0)
	self.ySpeed = NumberRange.new(150,500)
	self.SpreadAngle = NumberRange.new(-15,15)
	self.RotSpeed = NumberRange.new(0)
	self.Lifetime = NumberRange.new(5,10)
	self.Acceleration = Vector2.new(0,-500)

	-- "Fill": spawn randomly within the hook
	-- "Point": spawn at the center of the hook
	self.EmitterMode = "Point"



	self.__dead = false
	self.__elapsedTime = 0

	self.__runServiceConnection = game:GetService("RunService").Heartbeat:Connect(function(delta)


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
