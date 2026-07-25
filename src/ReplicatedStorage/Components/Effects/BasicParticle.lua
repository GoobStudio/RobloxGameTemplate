local REFX = require(game.ReplicatedStorage.Packages.refx)
local BasicParticle = REFX.CreateEffect("BasicParticle")

function BasicParticle:OnConstruct(EffectAttachment,Parent)
    self.EffectAttachment = EffectAttachment
    self.Parent = Parent
end

function BasicParticle:OnStart()
	self.ParticleSystem = self.EffectAttachment:Clone()
    self.ParticleSystem.Parent = self.Parent or workspace
    local Particles = {}
    for _,v in pairs(self.ParticleSystem:GetDescendants()) do
        if v:IsA("ParticleEmitter") then
            table.insert(Particles,v)
        end
    end

    local LongestLifetime = 0
    for _,particle in pairs(Particles) do
        particle:Emit(particle:GetAttribute("EmitCount") or 0)
        LongestLifetime = math.max(LongestLifetime, particle.Lifetime.Max)
        if particle:GetAttribute("EmitTime") then
            particle.Enabled = true
            LongestLifetime = math.max(LongestLifetime, particle:GetAttribute("EmitTime") + particle.Lifetime.Max)
            task.delay(particle:GetAttribute("EmitTime"), function()
                particle.Enabled = false
            end)
        end
    end

    game:GetService("Debris"):AddItem(self.ParticleSystem, LongestLifetime + 1)
end

function BasicParticle:OnDestroy()
	-- no-op
end

return BasicParticle
