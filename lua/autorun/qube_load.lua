QUBELib = QUBELib or {}

if SERVER then
	AddCSLuaFile("autorun/qube_load.lua")
	
	-- LIB --
	-- Client side --
	AddCSLuaFile("lib/cl/setup.lua")
	AddCSLuaFile("lib/cl/PVSCache.lua")
	AddCSLuaFile("lib/cl/URLTexture.lua")
	
	-- Shared --
	AddCSLuaFile("lib/sh/setup.lua")
	AddCSLuaFile("lib/sh/meshParser.lua")
	AddCSLuaFile("lib/sh/obj.lua")
	AddCSLuaFile("lib/sh/queueSYS.lua")
	AddCSLuaFile("lib/sh/util.lua")
end

-- SERVER --
if SERVER then
	include("lib/sv/setup.lua")
	include("lib/sv/registry.lua")
end

-- CLIENT --
if CLIENT then
	include("lib/cl/setup.lua")
	include("lib/cl/PVSCache.lua")
	include("lib/cl/URLTexture.lua")
end

-- SHARED --
include("lib/sh/setup.lua")
include("lib/sh/meshParser.lua")
include("lib/sh/obj.lua")
include("lib/sh/queueSYS.lua")
include("lib/sh/util.lua")

if SERVER then print("[QUBELib] Startup") end