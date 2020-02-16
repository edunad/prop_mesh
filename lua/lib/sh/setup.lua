-- CLEANUP --
cleanup.Register("qube_mesh")

-- QUBE CONVARS --
CreateConVar( "qube_maxVertices", 6000, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max QUBE Obj vertices allowed in TOTAL (Default: 10)" )
CreateConVar( "qube_maxSubMeshes", 5, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max QUBE sub-meshes allowed (HIGH VALUE = More rendering lag) (Default: 5)" )
CreateConVar( "qube_maxOBJ_bytes", 2048576, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max QUBE obj size in BYTES (Default: 2048576)" )
CreateConVar( "qube_maxScaleVolume", 580, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max QUBE volume scale (Default: 580)" )
CreateConVar( "qube_minScaleVolume", 3, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Min QUBE volume scale (Default: 3)" )