local string_trim = string.Trim
local string_find = string.find
local string_replace = string.Replace

AddCSLuaFile( "cl_init.lua" ) -- Make sure clientside
AddCSLuaFile( "shared.lua" )  -- and shared scripts are sent.
 
include('shared.lua')

ENT.SAVE_DATA = {}
--- INIT ---

--------------
--- Spawn ----
local function MakePMESHEnt(ply, data)
	if IsValid(ply) and not ply:CheckLimit("prop_mesh") then return nil end
	
	local ent = ents.Create("prop_mesh")
	if not ent:IsValid() then return nil end
	
	ent:SetPos(data.Pos)
	
	if ent.CPPISetOwner then
		ent:CPPISetOwner(ply)
	else
		ent:SetNWEntity("owner", ply)
	end
	
	ent:Spawn()
	ent:Activate()
	
	if IsValid(ply) then
		ply:AddCount("prop_mesh", ent)
		ply:AddCleanup("prop_mesh", ent)
	end
	
	return ent
end

function ENT:SpawnFunction( ply, tr )
	if (not tr.Hit) then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 16
	return MakePMESHEnt(ply, {Pos = SpawnPos})
end
--- Spawn ----
--------------

-------------
--- SEND ----
function ENT:SendLoadedMeshToNewPlayer(ply)
	local lastMesh = self.LAST_REQUESTED_MESH
	if not lastMesh or not lastMesh.uri then return end
	
	-- SEND TEXTURES AND MESH --
	self:SendTextures(self.MATERIAL_URLS, ply)
	self:SendLoadMesh(lastMesh, ply)
end

function ENT:SendLoadMesh(data, ply)
	net.Start("prop_mesh_command")
		net.WriteInt(self:EntIndex(), 32)
		net.WriteString("MESH_LOAD")
		net.WriteTable(data)
	if ply then
		net.Send(ply)	
	else 
		net.Broadcast()
	end
end

function ENT:SetTextures(textures)
	if not textures or #textures <= 0 then return end
	self.MATERIAL_URLS = textures
	
	self.SAVE_DATA.textures = textures -- Save
	self:SaveDupeData()
	
	self:SendTextures(textures)
end

function ENT:SendTextures(textures, ply)
	net.Start("prop_mesh_command")
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
	self:SendLoadedMeshToNewPlayer(newPly)
end

function ENT:Use(ply, caller)
	if not IsValid(ply) then return end
	
	net.Start("prop_mesh_command")
		net.WriteInt(self:EntIndex(), 32)
		net.WriteString("ON_USE_PRESS")
	net.Send(ply)
end

function ENT:SaveDupeData()
	if not IsValid(self) or not self.SAVE_DATA then return end
	duplicator.StoreEntityModifier(self, "SAVE_DATA", self.SAVE_DATA)
end

function ENT:Load(uri, textures, scale, phys, duped)
	if not uri or string_trim(uri) == "" then return end
	local owner = self:GetNWEntity("owner")
	if self.CPPIGetOwner then 
		owner = self:CPPIGetOwner()
	end
	
	local isAdmin = owner:IsAdmin()
	
	-- FIX INPUT ---
	scale = PropMLIB.Util.ClampVector(scale or Vector(1, 1, 1), self.MIN_SAFE_SCALE, self.MAX_SAFE_SCALE)
	phys = PropMLIB.Util.ClampVector(phys or Vector(1, 1, 1), self.MIN_SAFE_SCALE, self.MAX_SAFE_SCALE)
	uri = PropMLIB.Util.FixUrl(uri)
	----------

	-- Adv dupe saving
	self.SAVE_DATA = {meshURL = uri, textures = textures, scale = scale, phys = phys}
	self:SaveDupeData()
	-------
	
	-- Clear --
	if not duped then self:Clear() end
	-----------
	
	self:SetTextures(textures)
	
	self.LAST_REQUESTED_MESH = {uri = uri, scale = scale, phys = phys, isAdmin = isAdmin, duped = duped}
	self:SendLoadMesh(self.LAST_REQUESTED_MESH) -- Start client load
	
	-- Server load --
	self:LoadOBJ(uri, isAdmin, function(meshData)
		meshData.scale = scale
		meshData.phys = phys

		-- Adv dupe save OBB
		self.SAVE_DATA.obb = meshData.obb
		self:SaveDupeData()
		-------

		self:BuildMeshes(meshData)
	end, function(err)
		-- ERR
		print("server side failed :<", err)
	end)
end
--- GENERAL ----
----------------
