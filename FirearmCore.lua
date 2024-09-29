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

local BridgeNet = require(game.ReplicatedStorage.BridgeNet)

local State = BridgeNet.CreateBridge("ToolState")

local ReloadRemote = Atlas:GetObject("Reload")

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

local CachedBlacklistSet = {}



local Settings = {
	ShowBlood = false, -- Enable Blood?

	ShowMuzzleEffects = true, -- Enable Muzzle effects?

	ShowV1MuzzleEffects = false, -- Show V1\V2 Muzzle effects?

	ShellEjection = false, -- Eject shells?

	BulletShellOffset = Vector3.new(1, 1, 0), -- Vector 3 offset of the bulletshell when ejected

	ShellMeshID = 95392019, --MeshID of the shell

	ShellTextureID = 95391833, -- Shell TextureID

	DisappearTime = 5, -- Time in (Seconds) until a ejected shell dissapears

	NotifyPlayer = false, -- Notify the player when they failed team check

	AlwaysDamage = false, -- Ignore team check always allows damage

	EnableGuiltySystem = false, -- Enable \ disable class g guilty check

	EnableBulletHitNotifcation = true, -- Enables \ disables SCP:CB Hit notifcations: "A bullet hit your head"

	EnableMagStuff = true, -- Enables \ disables mag in and mag transparency 
	
	AlternativeSpread = false -- Enables S19 Spread system disable if you pefer mine which you should i dont know why anyone would like s19s
}
local function AddToBlacklist(instance)
	if not CachedBlacklistSet[instance] then
		table.insert(CachedBlacklist, instance)
		CachedBlacklistSet[instance] = true
	end
end
local lastInitializeTime = 0
local INITIALIZE_COOLDOWN = 5
local function InitializeBlacklist()
	local currentTime = tick()
	if currentTime - lastInitializeTime < INITIALIZE_COOLDOWN then
		return 
	end
	lastInitializeTime = currentTime
	local workspace = game:GetService("Workspace")
	local IsA = game.IsA
	for _, v in ipairs(game:GetDescendants()) do
		if IsA(v, "Accessory") or CollectionService:HasTag(v, "RayIgnore") then
			AddToBlacklist(v)
		elseif IsA(v, "BasePart") and v.Transparency == 1 and not CollectionService:HasTag(v, "RayBlock") then
			AddToBlacklist(v)
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
local function GetTeamPriority(teamName, PlayerWhoFired)
	for priorityLevel, teams in pairs(TeamPriorityModule) do
		for _, team in ipairs(teams) do
			if team == teamName then
				return tonumber(priorityLevel:match("%d+"))
			end
		end
	end

	if not PlayerWhoFired or not PlayerWhoFired:IsA("Player") then
		warn("Invalid PlayerWhoFired:", PlayerWhoFired)
		return nil
	end

	Notify:FireClient(PlayerWhoFired, "This player's team isn't defined in the Team Priority Module. If you see this, report this to the owner of the game.")
	warn("Team is nil, did you specify all teams in the module correctly?")
	return nil
end

local function TeamCheck(PlayerWhoFired, targetPlr, gun)
	local playerTeam = PlayerWhoFired.Team.Name
	local targetTeam = targetPlr.Team.Name

	local playerPriority = GetTeamPriority(playerTeam, PlayerWhoFired)
	local targetPriority = GetTeamPriority(targetTeam, PlayerWhoFired)

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
	if playerPriority == 1 and targetPriority == 2 then
		ClearToDamage = true
	end
	if playerPriority == 1 and targetPriority == 3 then 
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

ReloadRemote.OnServerEvent:Connect(function(gun, CurrentGun)
	local MagIn = CurrentGun.Handle.Primary:FindFirstChild("magIn")
	local MagOut = CurrentGun.Handle.Primary:FindFirstChild("magOut")
	local Mag = CurrentGun.Handle:FindFirstChild("Mag")
	MagOut:Play()
	--Mag.Transparency = 1
	task.wait(1.27)
	MagIn:Play()
	--Mag.Transparency = 0
end)

local firingTimes = {}
local MAX_SPREAD_ANGLE = 13
local SPREAD_INCREMENT = 0.06
State:Connect(function(player, arg)
	if arg == "Stop" then
		firingTimes[player] = 0
	end
end)
State:Connect(function(gun, arg)
	
end)
local function Fire(player, gun, arg, aimOrigin, aimDirection, dmg, char)
	if not firingTimes[player] then
		firingTimes[player] = 0
	end
	if not table.find(CachedBlacklist, char) then
		table.insert(CachedBlacklist, char)
	end
	InitializeBlacklist()

	if player.Character.Humanoid.Health == 0 then return end
	
	if arg == "Discharge" then
		local FireSound = gun:FindFirstChild("Handle"):FindFirstChild("FireSound") or gun.Handle.Fire:Clone()
		FireSound.Parent = gun:FindFirstChild("Handle")
		FireSound.TimePosition = 0
		FireSound:Play()
		game.Debris:AddItem(FireSound, FireSound.TimeLength) 

		local Range = 900
		RayParams.FilterDescendantsInstances = CachedBlacklist
		local TAU = math.pi * 2

		local MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE = 0.8, 0.8
		if Settings.AlternativeSpread == true then
			firingTimes[player] = firingTimes[player] + 1
			local spreadMultiplier = math.min(firingTimes[player] * SPREAD_INCREMENT, MAX_SPREAD_ANGLE)
			MIN_BULLET_SPREAD_ANGLE = MIN_BULLET_SPREAD_ANGLE + spreadMultiplier
			MAX_BULLET_SPREAD_ANGLE = MAX_BULLET_SPREAD_ANGLE + spreadMultiplier
		end
		
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

			local function GetHitPart(part)
				if part:IsA("BasePart") then
					if part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" then
						return "Torso"
					elseif part.Name == "Head" then
						return "Head"
					elseif part.Name == "Left Arm" or part.Name == "Right Arm" or part.Name == "Left Leg" or part.Name == "Right Leg" then
						return part.Name
					elseif part.Name == "RightUpperArm" or part.Name == "LeftUpperArm" then
						return "Shoulder"
					elseif part.Name == "RightLowerArm" or part.Name == "LeftLowerArm" then
						return "Lower Arm"
					elseif part.Name == "RightUpperLeg" or part.Name == "LeftUpperLeg" then
						return "Upper Leg"
					elseif part.Name == "RightLowerLeg" or part.Name == "LeftLowerLeg" then
						return "Lower Leg"
					end
				end
				return "Torso"
			end

			if hitHumanoid then
				Attach.Hit:Play()
				local targetPlr = Players:GetPlayerFromCharacter(hitHumanoid.Parent)

				if targetPlr then
					local hitPart = GetHitPart(hitInstance)
					local message
					if hitPart == "Torso" then
						message = "A bullet hit your Torso."
					elseif hitPart == "Head" then
						message = "A bullet hit your Head."
					elseif hitPart == "Left Arm" then
						message = "A bullet hit your Left Arm."
					elseif hitPart == "Right Arm" then
						message = "A bullet hit your Right Arm."
					elseif hitPart == "Left Leg" then
						message = "A bullet hit your Left Leg."
					elseif hitPart == "Right Leg" then
						message = "A bullet hit your Right Leg."
					elseif hitPart == "Shoulder" then
						message = "A bullet hit your Shoulder."
					elseif hitPart == "Lower Arm" then
						message = "A bullet hit your Lower Arm."
					elseif hitPart == "Upper Leg" then
						message = "A bullet hit your Upper Leg."
					elseif hitPart == "Lower Leg" then
						message = "A bullet hit your Lower Leg."
					end

					if message and Settings.EnableBulletHitNotifcation == true then
						Notify:FireClient(targetPlr, message)
					end
				end

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

		if Settings.ShellEjection == true then
			local ShellPos = (gun:FindFirstChild("Handle").ShellEjectPoint.CFrame *
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
			Weld.Part0 = gun:FindFirstChild("Handle")
			Weld.Part1 = Chamber
			Weld.C0 = CFrame.new(Settings.BulletShellOffset.X, Settings.BulletShellOffset.Y, Settings.BulletShellOffset.Z)
			Chamber.Position = ShellPos
			Chamber.Parent = workspace.CurrentCamera

			local function spawner()
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


		local showMuzzleEffects = Settings.ShowMuzzleEffects
		local effectsCloned = false
		if showMuzzleEffects and not effectsCloned then
			local effectsSource = Settings.ShowV1MuzzleEffects and OldEffect or Muzzle
			for _, v in pairs(effectsSource:GetChildren()) do
				local newEffect = v:Clone()
				newEffect.Parent = gun:FindFirstChild("Handle").Muzzle

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


State:Connect(Fire)
