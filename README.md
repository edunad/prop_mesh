# prop_mesh - Custom Model Loader

prop_mesh allows you to use .obj models as props using box collisions!
Supports multi-textured models!

## NOTES

- Only .obj models are supported!
- You can find prop_mesh on Entities -> Custom Models
- When using prop_mesh make sure you at least have a **Prop Protection ADDON** (else it will use SetOwner to determine the owner, preventing you from grabbing it!)
- If you want to use it **SINGLEPLAYER**, make sure "Local Server" is ticked! **DO NOT START IT IN PURE SINGLEPLAYER**

## COMMANDS

```
CLIENT :
	prop_mesh_urltexture_timeout <number> - How many seconds before timing out (Default: 30)
	-------------
	prop_mesh_queue_interval <0.35 to 1> - How many seconds between prop_mesh mesh rendering (LOW VALUE = More chances of crashing) (Default: 0.35)
	-------------
	prop_mesh_urltexture_reload - Reloads all url textures
	prop_mesh_urltexture_clear - Clear url texture cache
```

```
SERVER :
	sbox_maxprop_mesh <number> - Max prop_mesh per players (Default: 10)

	prop_mesh_maxTriangles <number> - Max prop_mesh Obj triangles allowed in TOTAL (Default: 1650)
	prop_mesh_maxSubMeshes <number> - Max prop_mesh sub-meshes allowed (HIGH VALUE = More rendering lag) (Default: 5)
	prop_mesh_maxOBJ_bytes <number> - Max prop_mesh obj size in BYTES (Default: 2048576)
	prop_mesh_maxScaleVolume <number> - Max prop_mesh volume scale (Default: 580)
	prop_mesh_minScaleVolume <number> - Min prop_mesh volume scale (Default: 3)
	prop_mesh_ignoreContentRange <number> - Ignore Content-Range check, users will be able to force the server to download huge files! (Default: 0)
```

```
SHARED :
	prop_mesh_objcache_clear - Clear cached models (If ran on server, it will clear clients cache)
```

## KNOWN ISSUES

- If your model looks **"weird"** try converting the faces to tris (if you use blender, when exporting the obj, tick **"Triangulate Faces"**

## TODO

### Mesh

- [ ] Save parsed mesh on client as cache
- [ ] Save textures on client as cache
- [x] Split the mesh if triangles limit is high

### Entity

- [x] Fix Adv.dup constrains
- [ ] Server / Client code improvements
- [x] Add console commands to limit prop_mesh on client side
- [x] Add console commands server side for admins
- [ ] Handle server failing to parse model?
- [x] Better UI Panel

## LINKS

- [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2205982705)
- [Tutorial](https://youtu.be/g1nbhyNAZkU)

## SCREENSHOTS

![](https://i.imgur.com/5p3USX0.png)
![](https://i.imgur.com/fc4tl7K.png)
