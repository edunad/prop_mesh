local string_trim = string.Trim
local string_find = string.find

AddCSLuaFile( "cl_init.lua" ) -- Make sure clientside
AddCSLuaFile( "shared.lua" )  -- and shared scripts are sent.
 
include('shared.lua')

ENT.SAVE_DATA = {}
--- INIT ---

--------------
--- Spawn ----
local function MakeQUBEEnt(ply, data)
	if IsValid(ply) and not ply:CheckLimit("qube_mesh") then return nil end
	
	local ent = ents.Create("qube_mesh")
	if not ent:IsValid() then return nil end
	
	ent:SetPos(data.Pos)
	
	if ent.CPPISetOwner then 
		ent:CPPISetOwner(ply)
	else
		ent:SetOwner(ply)
	end
	
	ent:Spawn()
	ent:Activate()
	
	if IsValid(pl) then
		ply:AddCount("qube_mesh", ent)
		ply:AddCleanup("qube_mesh", ent)
	end
	
	return ent
end

function ENT:SpawnFunction( ply, tr )
	if (not tr.Hit) then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 16
	return MakeQUBEEnt(ply, {Pos=SpawnPos})
end
--- Spawn ----
--------------

-------------
--- SEND ----
function ENT:SendLoadedMesh(ply)
	local lastMesh = self.LAST_REQUESTED_MESH
	if not lastMesh then return end
	
	-- SEND TEXTURES AND MESH --
	self:SendTextures(self.MATERIAL_URLS, ply)
	self:SendLoadMesh(lastMesh.uri, lastMesh.scale, lastMesh.phys, ply)
end

function ENT:SendLoadMesh(uri, scale, phys, ply)
	net.Start("qube_mesh_command")
		net.WriteInt(self:EntIndex(), 32)
		net.WriteString("MESH_LOAD")
		net.WriteString(uri)
		net.WriteVector(scale)
		net.WriteVector(phys)
	if ply then
		net.Send(ply)	
	else 
		net.Broadcast()
	end
end

function ENT:SetTextures(textures)
	if not textures or #textures <= 0 then return end
	self.MATERIAL_URLS = textures
	
	self.SAVE_DATA.textureURL = textures -- Save
	self:SaveDupeData()
	
	self:SendTextures(textures)
end

function ENT:SendTextures(textures, ply)
	net.Start("qube_mesh_command")
	net.WriteInt(self:EntIndex(), 32)
	net.WriteString("TEXTURE_LOAD")
	net.WriteTable(textures)
	
	if ply then
		net.Send(ply)
	else
		net.Broadcast()
	end
end
--- SEND ----
-------------

----------------
--- GENERAL ----
function ENT:OnNewPlayerJoin(newPly)
	self:SendLoadedMesh(newPly)
end

function ENT:Use(ply, caller)
	if not IsValid(ply) then return end
	
	net.Start("qube_mesh_command")
		net.WriteInt(self:EntIndex(), 32)
		net.WriteString("ON_USE_PRESS")
	net.Send(ply)
end

function ENT:Think()
	self:EnableCustomCollisions(true) -- Gravity gun likes to mess with it
	
	if SERVER then
		self:NextThink( CurTime() )
	elseif CLIENT then
		self:SetNextClientThink( CurTime() )
	end
	
	return true
end

function ENT:SaveDupeData()
	if not IsValid(self) or not self.SAVE_DATA then return end
	duplicator.StoreEntityModifier(self, "SAVE_DATA", self.SAVE_DATA)
end

function ENT:Load(uri, textures, scale, phys)
	if not uri or string_trim(uri) == "" then return end
	local owner = self:GetOwner()
	if self.CPPIGetOwner then 
		owner = self:CPPIGetOwner()
	end
	
	-- FIX INPUT ---
	scale = QUBELib.Util.ClampVector(scale or Vector(), self.MIN_SAFE_SCALE, self.MAX_SAFE_SCALE)
	phys = QUBELib.Util.ClampVector(phys or Vector(), self.MIN_SAFE_SCALE, self.MAX_SAFE_SCALE)
	----------

	-- Quick Dropbox fix --
	if string_find(uri, "dropbox") then
		uri = string_replace(uri, "dl=1", "raw=1")
	end
	--

	-- Adv dupe saving
	self.SAVE_DATA = {meshURL = uri, textures = textures, scale = scale, phys = phys}
	self:SaveDupeData()
	-------
	
	-- Clear --
	self:Clear()
	-----------
	
	self:SetTextures(textures)
	
	self.LAST_REQUESTED_MESH = {uri = uri, scale = scale, phys = phys}
	self:SendLoadMesh(uri, scale, phys) -- Start client load
	
	-- Server load --
	self:LoadOBJ(uri, owner, function(meshData)
		meshData.scale = scale
		meshData.phys = phys
		
		self:BuildMeshes(meshData)
	end, function(err)
		-- ERR
		print("server side failed :<", err)
	end)
end
--- GENERAL ----
----------------
