# UIParticle
An attempt at replicating the ROBLOX ParticleEmitters as closely as possible in 2D UIs

### Installation
Create a new ModuleScript anywhere (preferably ReplicatedStorage) and paste the source code into it.

### Usage

```lua
--Require the module
local UIParticleEmitter = require("path.to.ModuleScript")

--Create a new particle emitter, passing a hook (the UI equivalent of a ParticleEmitter's parent) and an element (the element that will represent a particle)
local emitter = UIParticleEmitter.new(hook, element)

--Assign some properties
emitter.Rate = 20
emitter.Acceleration = Vector2.new(15,15)
emitter.Color = Color3.new(0.5,0.5,1)

--Emit 50 particles
emitter:Emit(50)

--Enable the emitter
emitter.Enabled = true

```
