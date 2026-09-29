--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Combatant = require(ServerScriptService.Server.Domain.Combat.Combatant)

local function createCombatant()
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 22
	humanoid.JumpPower = 60
	humanoid.AutoRotate = true
	humanoid.Parent = character
	character.Parent = workspace
	return Combatant.new({ UserId = 10 } :: any, character), character, humanoid
end

local function enterState(combatant: any, state: string)
	if state == "SittingOnTurnbuckle" or state == "Falling" then
		assert(combatant:SetState("ClimbingTurnbuckle"))
	elseif state == "StandingUp" or state == "Pinned" then
		assert(combatant:SetState("Grounded"))
	end
	assert(combatant:SetState(state))
end

return function()
	describe("Combatant movement", function()
		it("locks incapacitated movement and restores the character on recovery", function()
			local combatant, character, humanoid = createCombatant()
			expect(combatant:SetState("Stunned")).to.equal(true)
			expect(humanoid.WalkSpeed).to.equal(0)
			expect(humanoid.JumpPower).to.equal(0)
			expect(humanoid.AutoRotate).to.equal(false)
			expect(combatant:SetState("Roaming")).to.equal(true)
			expect(humanoid.WalkSpeed).to.equal(22)
			expect(humanoid.JumpPower).to.equal(60)
			expect(humanoid.AutoRotate).to.equal(true)

			expect(combatant:SetState("Grounded")).to.equal(true)
			expect(humanoid.WalkSpeed).to.equal(0)
			combatant:ResetForMatchEnd()
			expect(combatant:GetState()).to.equal("Roaming")
			expect(humanoid.WalkSpeed).to.equal(22)
			combatant:Destroy()
			character:Destroy()
		end)
	end)

	describe("Combatant damage reactions", function()
		for _, state in
			{
				"Taunting",
				"ClimbingTurnbuckle",
				"SittingOnTurnbuckle",
				"Falling",
				"Grappling",
				"Pinning",
				"StandingUp",
			}
		do
			it(`knocks down a fighter in {state} when poise breaks`, function()
				local combatant, character = createCombatant()
				enterState(combatant, state)
				combatant:ApplyDamage({
					HealthDamage = 1,
					PoiseDamage = CombatConfig.MaxPoise,
					AttackerFinisher = 0,
					VictimFinisher = 0,
					StunSeconds = 0.5,
				})
				expect(combatant:GetState()).to.equal("Grounded")
				expect(combatant:GetSnapshot().Poise).to.equal(0)
				expect(combatant:GetSnapshot().Health).to.equal(CombatConfig.MaxHealth - 1)
				combatant:Destroy()
				character:Destroy()
			end)
		end

		for _, state in { "ClimbingTurnbuckle", "SittingOnTurnbuckle", "Falling", "StandingUp" } do
			it(`stuns a fighter in {state} without a poise break`, function()
				local combatant, character = createCombatant()
				enterState(combatant, state)
				combatant:ApplyDamage({
					HealthDamage = 1,
					PoiseDamage = 10,
					AttackerFinisher = 0,
					VictimFinisher = 0,
					StunSeconds = 0.5,
				})
				expect(combatant:GetState()).to.equal("Stunned")
				combatant:Destroy()
				character:Destroy()
			end)
		end

		for _, state in { "Grounded", "Pinned" } do
			it(`does not release a fighter in {state} for a lesser stun`, function()
				local combatant, character = createCombatant()
				enterState(combatant, state)
				combatant:ApplyDamage({
					HealthDamage = 1,
					PoiseDamage = 10,
					AttackerFinisher = 0,
					VictimFinisher = 0,
					StunSeconds = 0.5,
				})
				expect(combatant:GetState()).to.equal(state)
				combatant:Destroy()
				character:Destroy()
			end)
		end
	end)
end
