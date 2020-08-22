-- CLEANUP --
cleanup.Register("prop_mesh")

-- Registry.PMESH CONVARS --
CreateConVar( "sbox_maxprop_mesh", 10, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh entities allowed (Default: 10)" )

CreateConVar( "prop_mesh_maxVertices", 6000, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh Obj vertices allowed in TOTAL (Default: 10)" )
CreateConVar( "prop_mesh_maxSubMeshes", 5, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh sub-meshes allowed (HIGH VALUE = More rendering lag) (Default: 5)" )
CreateConVar( "prop_mesh_maxOBJ_bytes", 2048576, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh obj size in BYTES (Default: 2048576)" )
CreateConVar( "prop_mesh_maxScaleVolume", 580, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max prop_mesh volume scale (Default: 580)" )
CreateConVar( "prop_mesh_minScaleVolume", 3, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Min prop_mesh volume scale (Default: 3)" )