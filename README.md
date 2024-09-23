# Site 19 Gun System Replica

This gun system was made to replicate the gun system found in "Site-19 Roleplay" made by AdministratorGnar and ThunderGemios10

This system includes almost all features of the gun system including Mobile support

Inside the Settings inside "FireCore" (ServerScript) there are 11 Options you can customise to your liking

```lua
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
	EnableGuiltySystem = true -- Enable \ disable class g guilty check
}
```

# Note this gun system, uses Atlas framework automaticlly packaged in the release https://github.com/SCPFBluesky/Atlas-Framework

# In order to add custom items to Class D Guilty system go into the script calle "Guilty" in ServerScriptService and add your item names their

```lua
local itemlist = {
	"Ballistic Shield",
	"Glock 22",
	"HK416s",
	"Honey Badger",
	"Intervention",
	"Kriss Vector",
	"M249",
	"MP5-SD",
	"P90",
	"P90s",
	"Special M249"
}
```
# For example if I wanted to add a keycard to the list I would do it like this

```lua
local itemlist = {
	"Ballistic Shield",
	"Glock 22",
	"HK416s",
	"Honey Badger",
	"Intervention",
	"Kriss Vector",
	"M249",
	"MP5-SD",
	"P90",
	"P90s",
	"Special M249",
	"Level-3"
}
```
# When adding items don't forget to add the , at the previous item.
