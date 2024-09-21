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
RayParams.RespectCanCollide = true
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local CachedBlacklist = {}
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
	AlwaysDamage = false -- Ignore team check always allows damage
}

local function InitializeBlacklist()
	if not Initialized then
		CachedBlacklist = {}

		for _, v in pairs(game.Workspace:GetDescendants()) do
			if v:IsA("BasePart") and (v.Transparency == 1) then
				table.insert(CachedBlacklist, v)
			elseif v:HasTag("RayIgnore") then
				table.insert(CachedBlacklist, v)
			end
		end

		
		Initialized = true
	end
end

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
		elseif targetTeam == "Class D" and targetPlr.Character:GetAttribute("Guilty") == true then
			ClearToDamage = true
		else
			if Settings.NotifyPlayer == true then
				--Notify:FireClient(PlayerWhoFired, "You cannot damage Class Ds who did nothing wrong.")
			end
			ClearToDamage = true
		end
	elseif playerPriority == 3 then
		ClearToDamage = true
	elseif playerPriority == 2 and targetTeam == "Chaos Insurgency" then
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


local function Fire(player, gun, arg, aimOrigin, aimDirection, dmg)
	table.insert(CachedBlacklist, player.Character)
	table.insert(CachedBlacklist, gun)     
	InitializeBlacklist()

	if player.Character.Humanoid.Health == 0 then return end


	if arg == "Discharge" then
		local FireSound = gun.Handle.Fire:Clone()
		FireSound.Parent = gun.Handle
		FireSound.TimePosition = 0
		FireSound:Play()
		FireSound.Ended:Connect(function()
			FireSound:Destroy()
		end)

		local Range = 900
		RayParams.FilterDescendantsInstances = CachedBlacklist

		local MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE = 0.5,0.5
		local TAU = math.pi * 2

		local directionalCF = CFrame.new(Vector3.new(), aimDirection)

		local spreadDirection = (directionalCF * 
			CFrame.fromOrientation(0, 0, RNG:NextNumber(0, TAU)) * 
			CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0) -- Random pitch spread
		).LookVector

		local raycastResult = workspace:Raycast(aimOrigin, spreadDirection * Range, RayParams)

		

		if raycastResult and raycastResult.Position then
			local Attach = HitEffects.Effects:Clone()
			Attach.Parent = game.Workspace.Terrain
			Attach.CFrame = CFrame.new(raycastResult.Position, raycastResult.Position + raycastResult.Normal)

			local hitInstance = raycastResult.Instance
			if hitInstance.Parent:FindFirstChild("Humanoid") then
				Attach.Hit:Play()
				local Humanoid = hitInstance.Parent.Humanoid
				local targetPlr = Players:GetPlayerFromCharacter(Humanoid.Parent)

				if not targetPlr or TeamCheck(player, targetPlr, gun) then
					Humanoid:TakeDamage(dmg)
				end

				if Settings.ShowBlood and targetPlr ~= player then
					Attach.Blood:Emit(20)
				end
			else
				Attach.Flash:Emit(20)
				Attach.Smoke:Emit(20)
			end
		end

		if Settings.ShellEjection == true then
			local ShellPos = (gun.Handle.ShellEjectPoint.CFrame *
				CFrame.new(Settings.BulletShellOffset.X, Settings.BulletShellOffset.Y, Settings.BulletShellOffset.Z)).p
			local Chamber = Instance.new("Part")
			Chamber.Name = "Chamber"
			Chamber.Size = Vector3.new(0.01, 0.01, 0.01)
			Chamber.Transparency = 1
			Chamber.Anchored = false
			Chamber.CanCollide = false
			Chamber.TopSurface = Enum.SurfaceType.SmoothNoOutlines
			Chamber.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
			local Weld = Instance.new("Weld", Chamber)
			Weld.Part0 = gun.Handle
			Weld.Part1 = Chamber
			Weld.C0 = CFrame.new(Settings.BulletShellOffset.X, Settings.BulletShellOffset.Y, Settings.BulletShellOffset.Z)
			warn(Weld.C0)
			Chamber.Position = ShellPos
			Chamber.Parent = workspace.CurrentCamera

			local function spawner()
				print("yes called hi.")
				local Shell = Instance.new("Part")
				Shell.CFrame = Chamber.CFrame * CFrame.fromEulerAnglesXYZ(-2.5, 1, 1)
				Shell.Size = Vector3.new(0.2, 0.2, 0.32)
				Shell.CanCollide = true
				Shell.Name = "Shell"
				Atlas:TagObject(Shell, "RayIgnore")
				Shell.Velocity = Chamber.CFrame.lookVector * 20 + Vector3.new(math.random(-10, 10), 20, math.random(-10, 10))
				Shell.RotVelocity = Vector3.new(0, 200, 0)
				Shell.Parent = workspace

				local shellmesh = Instance.new("SpecialMesh")
				warn(Shell.Position)
				shellmesh.Scale = Vector3.new(2, 2, 2)
				shellmesh.MeshId = "rbxassetid://" .. Settings.ShellMeshID
				shellmesh.TextureId = "rbxassetid://" .. Settings.ShellTextureID
				shellmesh.MeshType = Enum.MeshType.FileMesh
				shellmesh.Parent = Shell

				game:GetService("Debris"):addItem(Shell, Settings.DisappearTime)
			end
			spawn(spawner)
			game.Debris:AddItem(Chamber, 10)
		end

		local effectsCloned = false 

		if Settings.ShowMuzzleEffects then
			if not effectsCloned then 
				local EffectsSource = Settings.ShowV1MuzzleEffects and OldEffect or Muzzle
				for _, v in pairs(EffectsSource:GetChildren()) do
					local newEffect = v:Clone()
					newEffect.Parent = gun.Handle.Muzzle

					if newEffect:IsA("PointLight") then
						newEffect.Enabled = true
						game.Debris:AddItem(newEffect, 0.1)
					elseif newEffect:IsA("ParticleEmitter") then
						if Settings.ShowV1MuzzleEffects then
							newEffect:Emit()
						else
							newEffect:Emit(20)
							game.Debris:AddItem(newEffect, newEffect.Lifetime.Max)
						end
					end

					for i = #CachedBlacklist, 1, -1 do
						if CachedBlacklist[i] == player.Character then
							table.remove(CachedBlacklist, i)
						end
					end
				end

				effectsCloned = true 
			end
		end
	end
	end



State.OnServerEvent:Connect(Fire)
