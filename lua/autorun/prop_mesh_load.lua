PropMLIB = PropMLIB or {}

if SERVER then
	AddCSLuaFile("autorun/prop_mesh_load.lua")
	
	-- LIB --
	-- Client side --
	AddCSLuaFile("lib/cl/setup.lua")
	AddCSLuaFile("lib/cl/pvs_cache.lua")
	AddCSLuaFile("lib/cl/url_texture.lua")
	AddCSLuaFile("lib/cl/queue_sys.lua")
	AddCSLuaFile("lib/cl/thumbnail.lua")
	
	-- Shared --
	AddCSLuaFile("lib/sh/setup.lua")
	AddCSLuaFile("lib/sh/mesh_parser.lua")
	AddCSLuaFile("lib/sh/obj.lua")
	AddCSLuaFile("lib/sh/util.lua")
end

-- SERVER --
if SERVER then
	include("lib/sv/setup.lua")
	include("lib/sv/registry.lua")
	
	resource.AddSingleFile("materials/vgui/entities/prop_mesh.vtf")
	resource.AddSingleFile("materials/vgui/entities/prop_mesh.vmt")
end

-- CLIENT --
if CLIENT then
	-- Folder structure
	file.CreateDir( "prop_mesh" )
	file.CreateDir( "prop_mesh/thumbnails" )
	file.CreateDir( "prop_mesh/models" )
	file.CreateDir( "prop_mesh/textures" )
	---
	
	include("lib/cl/setup.lua")
	include("lib/cl/pvs_cache.lua")
	include("lib/cl/url_texture.lua")
	include("lib/cl/queue_sys.lua")
	include("lib/cl/thumbnail.lua")
end

-- SHARED --
include("lib/sh/setup.lua")
include("lib/sh/mesh_parser.lua")
include("lib/sh/obj.lua")
include("lib/sh/util.lua")

if SERVER then print("[PropMLIB] Startup") end