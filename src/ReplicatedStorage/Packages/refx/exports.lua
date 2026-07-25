local package = script.Parent

local baseEffect = require(package.baseEffect)
local wrapper = require(package.wrapper)
local client = require(package.client)
local configuration = require(package.configuration)
local serverEntries = require(package.serverEntries)

return {
	BaseEffect = baseEffect,
	VisualEffectDecorator = wrapper.VisualEffectDecorator,
	CreateEffect = wrapper.CreateEffect,
	Register = client.Register,
	Start = client.Start,
	GetActiveEffects = client.GetActiveEffects,
	GetServerEffectStats = serverEntries.getStats,
	Configure = configuration.Configure,
	Config = configuration.Config,
}