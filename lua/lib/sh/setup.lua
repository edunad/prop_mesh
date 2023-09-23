-- CLEANUP --
cleanup.Register("prop_mesh")

-- Registry.PMESH CONVARS --
CreateConVar( "sbox_maxprop_mesh", 10, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh entities allowed (Default: 10)" )

CreateConVar( "prop_mesh_maxTriangles", 1650, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh Obj triangles allowed in TOTAL (Default: 1650)" )
CreateConVar( "prop_mesh_maxSubMeshes", 5, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh sub-meshes allowed (HIGH VALUE = More rendering lag) (Default: 5)" )
CreateConVar( "prop_mesh_maxOBJ_bytes", 2048576, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh obj size in BYTES (Default: 2048576)" )
CreateConVar( "prop_mesh_maxScaleVolume", 580, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh volume scale (Default: 580)" )
CreateConVar( "prop_mesh_minScaleVolume", 3, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Min prop_mesh volume scale (Default: 3)" )

CreateConVar( "prop_mesh_ignoreContentRange", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Ignore Content-Range check, users will be able to force the server to download huge files!" )

