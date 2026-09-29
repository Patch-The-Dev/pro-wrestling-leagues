--!strict

export type PyroPreset = {
	BurstCount: number,
	ContinuousSeconds: number,
}

export type LightingPreset = {
	Brightness: number,
	ClockTime: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
}

local pyroPresets: { [string]: PyroPreset } = {
	None = {
		BurstCount = 0,
		ContinuousSeconds = 0,
	},
	Burst = {
		BurstCount = 20,
		ContinuousSeconds = 0,
	},
	Wall = {
		BurstCount = 8,
		ContinuousSeconds = 1.25,
	},
}

local lightingPresets: { [string]: LightingPreset } = {
	Default = {
		Brightness = 2,
		ClockTime = 14,
		Ambient = Color3.fromRGB(128, 128, 128),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
	},
	Spotlight = {
		Brightness = 1.35,
		ClockTime = 21,
		Ambient = Color3.fromRGB(32, 32, 46),
		OutdoorAmbient = Color3.fromRGB(18, 18, 28),
	},
}

local EntranceConfig = {
	LeadInSeconds = 0.5,
	EntrantSpacingSeconds = 4,
	CameraFocusSeconds = 3.5,
	LightingHoldSeconds = 3.5,
	PyroPresets = pyroPresets,
	LightingPresets = lightingPresets,
}

for _, preset in pyroPresets do
	table.freeze(preset)
end
for _, preset in lightingPresets do
	table.freeze(preset)
end

table.freeze(pyroPresets)
table.freeze(lightingPresets)
table.freeze(EntranceConfig)

return EntranceConfig
