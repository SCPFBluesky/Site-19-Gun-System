--[[
	Writer: @SCPF_RedSky
	Name : FirearmCore.lua
	Date : 9/15/24
	ClassName : Script
	RunTime: Server
	Description: 
	This system replicates the gun system from Site 19, originally created by AdministratorGnar and ThunderGemios10 
	Please note only Site-19 Verisons 0-3 are only supported
	If you want this to be like V4 just make a holster script and script firing animations yourself.
	This is the serverside aspect of the gun system, handling team checks, muzzle effects
	shell ejection general settings and more
--]]
--!nonstrict
--!native
--!divine-intellect
local Atlas = require(game.ReplicatedStorage.Atlas)
local State = game.ReplicatedStorage:WaitForChild("State")
local TeamPriorityModule = Atlas:LoadLibrary("TeamPriorityModule")
local Muzzle = game.ReplicatedStorage.Shared.Muzzle
local OldEffect = game.ReplicatedStorage.Shared.OldMuzzle
local HitEffects = game.ReplicatedStorage.Effects
local Notify = Atlas:GetObject("NotifyPlayer")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TAU = math.pi * 2
local RNG = Random.new()

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true
CachedBlacklist = {}
local Initialized = false


local Settings = {
	ShowBlood = true, -- Enable Blood?
	ShowMuzzleEffects = true, -- Enable Muzzle effects?
	ShowV1MuzzleEffects = false, -- Show V1\V2 Muzzle effects?
	ShellEjection = false, -- Eject shells?
	BulletShellOffset = Vector3.new(1, 1, 0), -- Vector 3 offset of the bulletshell when ejected
	ShellMeshID = 95392019, --MeshID of the shell
	ShellTextureID = 95391833, -- Shell TextureID
	DisappearTime = 5, -- Time in (Seconds) until a ejected shell dissapears
	NotifyPlayer = true, -- Notify the player when they failed team check
	AlwaysDamage = false, -- Ignore team check always allows damage
	EnableGuiltySystem = false -- Enable \ disable class g guilty check
}

local function InitializeBlacklist()
	if Initialized == false then
	for _,v in pairs(game.Workspace:GetDescendants()) do
		if v:IsA("Instance") then
			if v:HasTag("RayIgnore") and not table.find(CachedBlacklist, v) then
				--	warn(v)
				--warn(CachedBlacklist)
				table.insert(CachedBlacklist ,v)
			end
		end
	end
	for _,v  in pairs(game:GetDescendants()) do
		if v:IsA("Accessory") and not table.find(CachedBlacklist, v) then
			--warn(v.Name)
			table.insert(CachedBlacklist, v)
		end
	end
	for _, v in pairs(game.Workspace:GetDescendants()) do
		if v:IsA("BasePart") and v.Transparency == 1 and not table.find(CachedBlacklist, v)then
			table.insert(CachedBlacklist, v)
		end
		end
	end
end


game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		for _, v in pairs(char:GetDescendants()) do
			if v:IsA("Accessory") then
				CollectionService:AddTag(v, "RayIgnore")
			end
		end
		char.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Accessory") then
				CollectionService:AddTag(descendant, "RayIgnore")
			end
		end)
	end)
end)
local function GetTeamPriority(teamName)
	for priorityLevel, teams in pairs(TeamPriorityModule) do
		for _, team in ipairs(teams) do
			if team == teamName then
				return tonumber(priorityLevel:match("%d+"))
			end
		end
	end
	print("Team is nil, did you specifiy the team in the moudle right?")
	return nil 
end

local function TeamCheck(PlayerWhoFired, targetPlr, gun)
	local playerTeam = PlayerWhoFired.Team.Name
	local targetTeam = targetPlr.Team.Name

	local playerPriority = GetTeamPriority(playerTeam)
	local targetPriority = GetTeamPriority(targetTeam)

	local ClearToDamage = false

	if Settings.AlwaysDamage == true and not (PlayerWhoFired == targetPlr) then
		return true
	end

	if PlayerWhoFired == targetPlr then
		return false
	end

	if playerPriority == 1 and targetPriority == 1 then
		ClearToDamage = false
		if Settings.NotifyPlayer == true then
			Notify:FireClient(PlayerWhoFired, "You cannot damage people on your own team.")
		end
	elseif playerPriority == 2 then
		if targetPriority == 2 or targetPriority == 3 then
			ClearToDamage = false
			if Settings.NotifyPlayer == true then
				Notify:FireClient(PlayerWhoFired, "You cannot damage people who also work for the Foundation.")
			end
		elseif targetTeam == "Chaos Insurgency" then
			ClearToDamage = true
		end

		if targetTeam == "Class D" then
			if Settings.EnableGuiltySystem == true then
				if targetPlr.Character:GetAttribute("Guilty") == true then
					ClearToDamage = true
				else
					if Settings.NotifyPlayer == true then
						Notify:FireClient(PlayerWhoFired, "You cannot damage Class Ds who did nothing wrong.")
					end
					ClearToDamage = false
				end
			else
				ClearToDamage = true
			end
		end
	elseif playerPriority == 3 then
		ClearToDamage = true
	end

	if playerPriority == 2 and targetTeam == "Chaos Insurgency" then
		ClearToDamage = true
	end

	if playerTeam == "Chaos Insurgency" and (targetPriority == 2 or targetPriority == 3) then
		ClearToDamage = true
	end

	if (playerTeam == "Chaos Insurgency" and targetTeam == "Class D") or
		(playerTeam == "Class D" and targetTeam == "Chaos Insurgency") then
		ClearToDamage = false
		if Settings.NotifyPlayer == true then
			Notify:FireClient(PlayerWhoFired, "You cannot damage people on your own team.")
		end
	end

	if targetPlr and targetPlr.Character:GetAttribute("Zombie") == true then
		ClearToDamage = true
	end

	return ClearToDamage
end


local function Fire(player, gun, arg, aimOrigin, aimDirection, dmg, char)
	if not table.find(CachedBlacklist, char) then
		table.insert(CachedBlacklist, char)
	end
	InitializeBlacklist()
	Initialized = true

	if player.Character.Humanoid.Health == 0 then return end

	if arg == "Discharge" then
		local FireSound = gun.Handle:FindFirstChild("FireSound") or gun.Handle.Fire:Clone()
		FireSound.Parent = gun.Handle
		FireSound.TimePosition = 0
		FireSound:Play()
		game.Debris:AddItem(FireSound, FireSound.TimeLength) 


		local Range = 900
		RayParams.FilterDescendantsInstances = CachedBlacklist
		local TAU = math.pi * 2
		local MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE = 0.5, 0.5

		local directionalCF = CFrame.new(Vector3.new(), aimDirection)
		local spreadDirection = (directionalCF *
			CFrame.fromOrientation(0, 0, RNG:NextNumber(0, TAU)) *
			CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0)
		).LookVector

		local raycastResult = workspace:Raycast(aimOrigin, spreadDirection * Range, RayParams)

		if raycastResult and raycastResult.Position then
			local Attach = HitEffects.Effects:Clone()
			Attach.Parent = workspace.Terrain
			Attach.CFrame = CFrame.new(raycastResult.Position, raycastResult.Position + raycastResult.Normal)

			local hitInstance = raycastResult.Instance
			local hitHumanoid = hitInstance.Parent:FindFirstChild("Humanoid")

			if hitHumanoid then
				Attach.Hit:Play()
				local targetPlr = Players:GetPlayerFromCharacter(hitHumanoid.Parent)

				if not targetPlr or TeamCheck(player, targetPlr, gun) then
					hitHumanoid:TakeDamage(dmg)
				end

				if Settings.ShowBlood and targetPlr ~= player then
					Attach.Blood:Emit(20)
				end
			else
				Attach.Flash:Emit(20)
				Attach.Smoke:Emit(20)
				game.Debris:addItem(Attach, Attach.Smoke.Lifetime.Max+0.1)
			end
		end

		if Settings.ShellEjection then
			local Shell = gun.Handle:FindFirstChild("Shell") or Instance.new("Part")
			Shell.Name = "Shell"
			Shell.Size = Vector3.new(0.2, 0.2, 0.32)
			Shell.CanCollide = true
			Shell.Parent = workspace
			Shell.CFrame = gun.Handle.ShellEjectPoint.CFrame * CFrame.fromEulerAnglesXYZ(-2.5, 1, 1)
			Shell.Velocity = Shell.CFrame.LookVector * 20 + Vector3.new(math.random(-10, 10), 20, math.random(-10, 10))

			local shellMesh = Shell:FindFirstChild("Mesh") or Instance.new("SpecialMesh", Shell)
			shellMesh.MeshId = "rbxassetid://" .. Settings.ShellMeshID
			shellMesh.TextureId = "rbxassetid://" .. Settings.ShellTextureID

			game:GetService("Debris"):AddItem(Shell, Settings.DisappearTime)
		end

		local showMuzzleEffects = Settings.ShowMuzzleEffects
		local effectsCloned = false
		if showMuzzleEffects and not effectsCloned then
			local effectsSource = Settings.ShowV1MuzzleEffects and OldEffect or Muzzle
			for _, v in pairs(effectsSource:GetChildren()) do
				local newEffect = v:Clone()
				newEffect.Parent = gun.Handle.Muzzle

				if newEffect:IsA("PointLight") then
					newEffect.Enabled = true
					game.Debris:AddItem(newEffect, 0.1)
				elseif newEffect:IsA("ParticleEmitter") then
					newEffect:Emit(20)
					game.Debris:AddItem(newEffect, newEffect.Lifetime.Max)
				end
			end
			effectsCloned = true
		end

		for i = #CachedBlacklist, 1, -1 do
			if CachedBlacklist[i] == player.Character then
				table.remove(CachedBlacklist, i)
			end
		end
	end
end



State.OnServerEvent:Connect(Fire)
