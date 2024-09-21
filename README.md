Site 19 Gun System
This gun system was made to replicate the gun system found in "Site-19 Roleplay" made by AdministratorGnar and ThunderGemios10
This system includes almost all features of the gun system including Mobile support.]]
--[Inside the Settings inside "FireCore" (ServerScript) there are these 8 Options you can customise to your liking]

```lua
local Settings = {
	ShowBlood = true, -- Enable Blood?
	ShowMuzzleEffects = true, -- Enable Muzzle effects?
	ShowV1MuzzleEffects = false, -- Show V1\V2 Muzzle effects?
	ShellEjection = true, -- Eject shells?
	BulletShellOffset = Vector3.new(1, 1, 0), -- Vector 3 offset of the bulletshell when ejected
	ShellMeshID = 95392019, --MeshID of the shell
	ShellTextureID = 95391833, -- Shell TextureID
	DisappearTime = 5, -- Time in (Seconds) until a ejected shell dissapears
	NotifyPlayer = true -- Notify the player when they failed team check
	AlwaysDamage = true -- Ignore team check always allows damage
}
```

# Note this gun system, uses Atlas framework automaticlly packaged in the release https://github.com/SCPFBluesky/Atlas-Framework
