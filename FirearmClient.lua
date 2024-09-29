--[[
	Writer: @SCPF_RedSky
	Name : FirearmClient.lua
	Date : 9/15/24
	ClassName : LocalScript
	RunTime: Client
	Description: 
	This system replicates the gun system from Site 19, originally created by AdministratorGnar and ThunderGemios10 
	Please note only Site-19 Verisons 0-3 are only supported
	If you want this to be like V4 just make a holster script and script firing animations yourself.
	This is the cleitnside aspect of the gun system, handling user input,
	attribute creations, mobile, and more.
--]]
--!nonstrict
--!native
--!divine-intellect
local Atlas = require(game.ReplicatedStorage.Atlas)

local InputService = game:GetService("UserInputService")

local BridgeNet = require(game.ReplicatedStorage.BridgeNet)

local State = BridgeNet.CreateBridge("ToolState")

local ReloadRemote = Atlas:GetObject("Reload")

local Player = game.Players.LocalPlayer

local LowerButton = Player.PlayerGui:WaitForChild("MobileUI").MobileButtons.LowerButton

local FireButton = Player.PlayerGui:WaitForChild("MobileUI").MobileButtons.FireButton

local ReloadButton = Player.PlayerGui:WaitForChild("MobileUI").MobileButtons.ReloadButton

local Mouse = Player:GetMouse()

local CurrentGun = nil

local CurrentFiremode = nil

local IsHolstered = false

local IsReloading = false

local canFire = false

local DEBUG_MODE = false

local isButtonDown = false


local _warn = warn

local _print = print

local GunAnimations = {}

local GunAmmo = {}

local OriginalAttributes = {}

local IsSystemChanging = {} 

local function SetSafeAttribute(gun, attributeName, value)
	IsSystemChanging[gun] = true 
	gun:SetAttribute(attributeName, value)
	task.wait()
	IsSystemChanging[gun] = false 
end

local function Init(gun)
	if gun.Parent ~= Player.Backpack then return end

	local success, SettingsModule = pcall(function()
		return require(gun:WaitForChild("Settings"))
	end)

	if not success or SettingsModule == nil then return end

	local equip, unequip

	OriginalAttributes[gun] = {
		Ammo = SettingsModule.Ammo,
		Damage = SettingsModule.Damage,
		RPM = SettingsModule.RPM,
		Automatic = SettingsModule.Automatic,
		CanLower = SettingsModule.CanLower
	}

	if not GunAmmo[gun] then
		GunAmmo[gun] = SettingsModule.Ammo
	end

	IsSystemChanging[gun] = false

	if gun then
		SetSafeAttribute(gun, "CurrentAmmo", GunAmmo[gun])
		SetSafeAttribute(gun, "Ammo", SettingsModule.Ammo)
		SetSafeAttribute(gun, "Automatic", SettingsModule.Automatic)
		SetSafeAttribute(gun, "RPM", SettingsModule.RPM)
		SetSafeAttribute(gun, "CanLower", SettingsModule.CanLower)
		SetSafeAttribute(gun, "Damage", SettingsModule.Damage)
	else
		warn("gun is nil")
	end


	GunAnimations[gun] = {}
	equip = gun.Equipped:Connect(function()
		for _, v in pairs(gun:FindFirstChild("Animations"):GetChildren()) do
			if v:IsA("Animation") then
				local success, AnimationTrack = pcall(function()
					if not Player.Character then
						Player.CharacterAdded:Wait()
					end

					local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						humanoid = Player.Character:WaitForChild("Humanoid", 5)
					end

					if humanoid then
						return humanoid:LoadAnimation(v)
					else
						error("Humanoid not found in player's character.")
					end
				end)

				if success and AnimationTrack then
					table.insert(GunAnimations[gun], AnimationTrack)
				else
					warn("Failed to load animation: " .. tostring(v.Name) .. ". Error: " .. tostring(AnimationTrack))
				end
			end
		end

		CurrentGun = gun
		canFire = true

		if GunAnimations[CurrentGun][1] then
			GunAnimations[CurrentGun][1]:Play(0.2)
		end

		if InputService.TouchEnabled then
			Player.PlayerGui.MobileUI.Enabled = not Player.PlayerGui.MobileUI.Enabled
		end

		gun:SetAttribute("CurrentAmmo", GunAmmo[gun])
	end)

	unequip = gun.Unequipped:Connect(function()
		if IsReloading then
			IsReloading = false
			canFire = true
		end

		if InputService.TouchEnabled then
			Player.PlayerGui.MobileUI.Enabled = not Player.PlayerGui.MobileUI.Enabled
		end

		GunAmmo[gun] = gun:GetAttribute("CurrentAmmo")
		CurrentGun = nil
		canFire = false
		IsHolstered = false
		isButtonDown = false

		for _, v in GunAnimations[gun] do
			v:Stop()
		end
	end)

	gun.AttributeChanged:Connect(function(attribute)
		if not IsSystemChanging[gun] then
			if attribute == "CurrentAmmo" and gun:GetAttribute("CurrentAmmo") ~= OriginalAttributes[gun].Ammo then
				Player:Kick("Attempted to exploit by modifying gun attributes (CurrentAmmo).")
			elseif attribute == "Damage" and gun:GetAttribute("Damage") ~= OriginalAttributes[gun].Damage then
				Player:Kick("Attempted to exploit by modifying gun attributes (Damage).")
			elseif attribute == "RPM" and gun:GetAttribute("RPM") ~= OriginalAttributes[gun].RPM then
				Player:Kick("Attempted to exploit by modifying gun attributes (RPM).")
			elseif attribute == "Automatic" and gun:GetAttribute("Automatic") ~= OriginalAttributes[gun].Automatic then
				Player:Kick("Attempted to exploit by modifying gun attributes (Automatic).")
			elseif attribute == "CanLower" and gun:GetAttribute("CanLower") ~= OriginalAttributes[gun].CanLower then
				Player:Kick("Attempted to exploit by modifying gun attributes (CanLower).")
			else
				Player:Kick("Attempted to exploit by modifying gun attributes.")
			end
		end
	end)
end


local function Lower(gun)

	if not CurrentGun or CurrentGun.Parent ~= Player.Character or IsReloading == true then
		return
	end

	if not CurrentGun:GetAttribute("CanLower") then
		return 
	end

	IsHolstered = not IsHolstered 
	if IsHolstered then
		canFire = false
		if GunAnimations[CurrentGun][3] then
			GunAnimations[CurrentGun][3]:Play() --V2\V1 Speed : 0.3 V3: Blank
		end

	else
		canFire = true
		if GunAnimations[CurrentGun][3] then
			GunAnimations[CurrentGun][3]:Stop()
		end
		if GunAnimations[CurrentGun][1] then
			GunAnimations[CurrentGun][1]:Play() --V2\V1 Speed : .2 V3: Blank
		end

	end
end


function Reload(gun)
	local success, currentGunSettings = pcall(function()
		return require(CurrentGun:FindFirstChild("Settings"))
	end)

	if not success or currentGunSettings == nil then return end

	if not CurrentGun or not CurrentGun.Parent or CurrentGun.Parent ~= Player.Character or IsReloading == true then
		return
	end
	if CurrentGun:GetAttribute("CurrentAmmo") == currentGunSettings.Ammo then
		return
	end
	ReloadRemote:FireServer(CurrentGun)
	SetSafeAttribute(CurrentGun, "CurrentAmmo", 0)
	IsReloading = true
	canFire = false
	
	if GunAnimations[CurrentGun][2] then
		GunAnimations[CurrentGun][2]:Play(.2)
		task.wait(GunAnimations[CurrentGun][2].Length)
		if not CurrentGun or not CurrentGun.Parent or CurrentGun.Parent ~= Player.Character then
			IsReloading = false
			return
		end
	end

	local success, currentGunSettings = pcall(function()
		return require(CurrentGun:FindFirstChild("Settings"))
	end)

	if not success or currentGunSettings == nil then return end

	if currentGunSettings then
		GunAmmo[CurrentGun] = currentGunSettings.Ammo
	else
		warn("nil")
	end

	if not CurrentGun then
		IsReloading = false
		return
	end

	if GunAnimations[CurrentGun] and GunAnimations[CurrentGun][1] then
		GunAnimations[CurrentGun][1]:Play()
	end
	SetSafeAttribute(CurrentGun, "CurrentAmmo", GunAmmo[CurrentGun])
	IsReloading = false
	canFire = true
end

local CONST_RANGE = 1000
local RayParams = RaycastParams.new()
RayParams.RespectCanCollide = true
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true


local function RealFire(gun)
	if IsHolstered or not CurrentGun or not canFire or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health == 0 or IsReloading then
		return
	end

	local CurrentAmmo = gun:GetAttribute("CurrentAmmo")
	if not CurrentAmmo or CurrentAmmo <= 0 then
		return
	end
	SetSafeAttribute(gun, "CurrentAmmo",CurrentAmmo - 1)
	GunAmmo[gun] = gun:GetAttribute("CurrentAmmo")

	local mousePos = Mouse.Hit.Position
	local camera = workspace.CurrentCamera
	local cameraRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)

	local aimDirection = cameraRay.Direction
	RayParams.FilterDescendantsInstances = {workspace.CurrentCamera}

	local raycastResult = workspace:Raycast(cameraRay.Origin, aimDirection * CONST_RANGE, RayParams)

	local aimPoint = raycastResult and raycastResult.Position or (cameraRay.Origin + aimDirection * CONST_RANGE)
	State:Fire(gun, "Discharge", cameraRay.Origin, aimDirection, gun:GetAttribute("Damage"), Player.Character)
end




InputService.InputBegan:Connect(function(inputobject, gpe)
	if not gpe and inputobject.KeyCode == Enum.KeyCode.E then
		Lower(CurrentGun)
	end
end)


ReloadButton.MouseButton1Click:Connect(function()
	if CurrentGun and not IsReloading then
		Reload(CurrentGun)
	end
end)


LowerButton.MouseButton1Click:Connect(function()
	if CurrentGun then
		Lower(CurrentGun)
	end
end)

InputService.InputBegan:Connect(function(inputobject, gpe)
	if not CurrentGun or IsReloading == true then
		return
	end
	if not gpe and inputobject.KeyCode == Enum.KeyCode.R then
		Reload(CurrentGun)
	end
end)

FireButton.MouseButton1Down:Connect(function()
	if not CurrentGun or IsHolstered or IsReloading or not canFire then return end
	RealFire(CurrentGun)
		
	FireButton.MouseButton1Up:Connect(function()
		isButtonDown = false
	end)

	if CurrentGun:GetAttribute("Automatic") then
		while isButtonDown and canFire and not IsHolstered do
			RealFire(CurrentGun)
			wait(CurrentGun:GetAttribute("RPM"))
		end
	end
end)



Mouse.Button1Down:Connect(function()
	isButtonDown = true
	if CurrentGun and canFire and not IsHolstered then
		RealFire(CurrentGun)
		if CurrentGun:GetAttribute("Automatic") then
			while isButtonDown and canFire and not IsHolstered do
				RealFire(CurrentGun)
				wait(CurrentGun:GetAttribute("RPM"))
			end
		end
	end
end)

Mouse.Button1Up:Connect(function() 
	isButtonDown = false 
	State:Fire("Stop")
end)


Atlas:BindToTag("Firearm", Init)
