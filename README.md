# QUBE - Prop .obj importer
![](https://i.imgur.com/PL0FRnq.gif)
> ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀THE FUN CANNOT BE HALTED

QUBE allows you to use .obj models as props using box collisions!
Supports multi-textured models!

## NOTES
- Only .obj models are supported!
- When using QUBE make sure you at least have a **Prop Protection ADDON** (else it will use SetOwner to determine the owner, preventing you from grabbing it!)
- If you want to use it **SINGLEPLAYER**, make sure "Local Server" is ticked! **DO NOT START IT IN PURE SINGLEPLAYER**

## COMMANDS
```
CLIENT :
	qube_urltexture_proxy <1 or 0>- Use proxy to load textures? (Protects IP) (Default: 1)
	qube_urltexture_timeout <number> - How many seconds before timing out (Default: 30)
	-------------
	qube_queue_interval <0.35 to 1> - How many seconds between qube mesh rendering (LOW VALUE = More chances of crashing) (Default: 0.35)
	-------------
	qube_urltexture_reload - Reloads all url textures
	qube_urltexture_clear - Clear url texture cache
```
```
SERVER :
	sbox_maxqube_mesh <number> - Max Qubes per players (Default: 10)
	qube_maxVertices <number> - Max QUBE Obj vertices allowed in TOTAL (Default: 6000)
	qube_maxSubMeshes <number> - Max QUBE sub-meshes allowed (HIGH VALUE = More rendering lag) (Default: 5)
	qube_maxOBJ_bytes <number> - Max QUBE obj size in BYTES (Default: 2048576)
	qube_maxScaleVolume <number> - Max QUBE volume scale (Default: 580)
	qube_minScaleVolume <number> - Min QUBE volume scale (Default: 3)
```

## KNOWN ISSUES

- When props / thrusters / etc are "welded" to QUBE, on Adv.Duplicator / Duplicator, it will loose the original constraints
- If your model looks **"weird"** try converting the faces to tris (if you use blender, when exporting the obj, tick **"Triangulate Faces"**
**- Textures might fail if not on GMOD BRANCH "x64-x86", since chromium has not been merged yet.**


## TODO
### Mesh
- [ ] Save parsed mesh on client as cache
- [ ] Save textures on client as cache

### Entity
- [ ] Fix Adv.dup constrains
- [ ] Server / Client code improvements
- [x] Add console commands to limit QUBE on client side
- [x] Add console commands server side for admins
- [ ] Handle server failing to parse model?
- [ ] Better UI Panel

## LINKS
- Workshop : https://steamcommunity.com/sharedfiles/filedetails/?id=1997179073

## SCREENSHOTS
![](https://i.imgur.com/5p3USX0.png)
![](https://i.imgur.com/fc4tl7K.png)
