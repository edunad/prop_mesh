
ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName		= "prop_mesh"
ENT.Author			= "FailCake"
ENT.RenderGroup 	= RENDERGROUP_TRANSLUCENT
ENT.AdminOnly		= false
ENT.Category		= "Custom Props"
ENT.Contact			= "https://github.com/edunad/prop_mesh"
ENT.Spawnable		= true

local math_clamp_ = math.Clamp
local math_abs = math.abs
local table_copy = table.Copy
local string_find = string.find

-- Default SETTINGS ---------
ENT.MAX_SAFE_VOLUME = GetConVar( "prop_mesh_maxScaleVolume" )
ENT.MIN_SAFE_VOLUME = GetConVar( "prop_mesh_minScaleVolume" )

ENT.MIN_SAFE_SCALE = 0.01
ENT.MAX_SAFE_SCALE = 100

ENT.MAX_OBJ_SIZE_BYTES = GetConVar( "prop_mesh_maxOBJ_bytes" )
-----------------------------

--- LOADED MODEL ---
ENT.LOADED_MESH = nil
ENT.LAST_REQUESTED_MESH = nil
ENT.LAST_PHYSICS_OBB = nil

ENT.LAST_MODEL_ERRORED = false
ENT.MATERIAL_URLS = {}
-------------------

--- OTHERS ---
ENT.LAST_STATUS = nil
--------------

----------------
--- GENERAL ----
function ENT:Initialize()
	self:SetDefaultPhysics()
	
	if CLIENT then
		self:GenerateExtraRandomColors()
		
		timer.Simple(0.01, function()
			if not IsValid(self) then return end
			self.DEFAULT_MATERIAL:SetVector("$color2", Vector(0, 0, 0))
			self.DEFAULT_MATERIAL_PHYS:SetVector("$color2", Vector(1, 1, 1))
		end)
		return
	end
	
	self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
	self:SetRenderMode( RENDERMODE_TRANSTEXTURE )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:DrawShadow( false )
	
	duplicator.StoreEntityModifier(self, "SAVE_DATA", self.SAVE_DATA)
	PropMLIB.Registry.RegisterPMesh(self)
end

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Debug" )
	self:NetworkVar( "Bool", 1, "Fullbright" )
end

function ENT:OnRemove()
	if CLIENT then
		local entIndex = self:EntIndex()
		local meshes = self.MESH_MODELS
		local panel = self.PANEL
		
		timer.Simple(0.1, function()
			if IsValid(self) then return end
			if self.PANEL then self.PANEL:Remove() end
			
			if IsValid( self.__PHYSICS_BOX__ ) then 
				self.__PHYSICS_BOX__:Destroy()
			end
			
			PropMLIB.PVSCache.Remove(entIndex)
			PropMLIB.MeshParser.ClearMeshes(meshes)
			PropMLIB.MeshParser.UnRegister(self)
		end)
	else
		PropMLIB.Registry.UnRegisterPMesh(self)
		PropMLIB.MeshParser.UnRegister(self)
	end
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
--- GENERAL ----
----------------

-------------
--- UTIL ----
function ENT:GetOBBSize(obb)
	local minOBB = obb.minOBB
	local maxOBB = obb.maxOBB
	
	local width = maxOBB.x - minOBB.x
	local lenght = maxOBB.y - minOBB.y
	local height = maxOBB.z - minOBB.z
	
	return Vector(width, lenght, height)
end

function ENT:VectorToSafe(scale, obb)
	local fixedScale = PropMLIB.Util.ClampVector(Vector(scale.x, scale.y, scale.z) or Vector(1, 1, 1), self.MIN_SAFE_SCALE, self.MAX_SAFE_SCALE)
	local minVol = self.MIN_SAFE_VOLUME:GetInt()
	local maxVol = self.MAX_SAFE_VOLUME:GetInt()
	
	local OBB = self:GetOBBSize(obb)
	for i = 1, 3 do
		local size = OBB[i]
		local scaler = fixedScale[i]
		local size_actual = size * scaler
		local size_clamped = math_clamp_(size_actual, minVol, maxVol)
		local new = size_clamped / size
		
		if not PropMLIB.Util.IsFinite(new) or math_abs(new) < 0.00000001 then return end
		fixedScale[i] = new
	end
	
	return fixedScale
end

function ENT:Clear()
	-- Clear currently loaded --
	self.LOADED_MESH = nil

	-- Clear last requested --
	self.LAST_REQUESTED_MESH = nil

	-- Clear status / error ---
	self.LAST_STATUS = nil
	self.LAST_MODEL_ERRORED = false

	-- Clear physics --
	self.LAST_PHYSICS_OBB = nil
	self:SetDefaultPhysics()

	-- Clear meshes --
	if CLIENT then self:ClearMeshes() end
end
--- UTIL ----
-------------

----------------
--- Physics ----
function ENT:CreateOBBPhysics(minOBB, maxOBB, forced)
	if not IsValid(self) then return end

	minOBB = PropMLIB.Util.SafeVector(minOBB, true)
	maxOBB = PropMLIB.Util.SafeVector(maxOBB, false)

	if not forced then
		if self.LAST_PHYSICS_OBB and 
			self.LAST_PHYSICS_OBB.minOBB:IsEqualTol(minOBB,0) and 
			self.LAST_PHYSICS_OBB.maxOBB:IsEqualTol(maxOBB,0) then
			return
		end

		self.LAST_PHYSICS_OBB = {minOBB = minOBB, maxOBB = maxOBB}
	end
	
	if CLIENT then
		if IsValid( self.__PHYSICS_BOX__ ) then
			self.__PHYSICS_BOX__:Destroy()
		end
	end
	
	-- Create OBB physics --
	if SERVER then
		self:PhysicsInitBox( minOBB, maxOBB )
		self:SetSolid( SOLID_VPHYSICS )
	
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion( false )
			phys:Sleep()
		end
	else
		self.__PHYSICS_BOX__ = CreatePhysCollideBox( minOBB, maxOBB )
	end
	
	self:SetCollisionBounds( minOBB, maxOBB )
end

function ENT:BuildPhysics(phys, obb)
	local safeScale = self:VectorToSafe(phys, obb)
	if not safeScale then safeScale = 1 end
	
	local minOBB = obb.minOBB * safeScale
	local maxOBB = obb.maxOBB * safeScale

	self:CreateOBBPhysics(minOBB, maxOBB)
end

function ENT:SetDefaultPhysics()
	local minOBB = Vector(-12, -12, -12)
	local maxOBB = Vector(12, 12, 12)

	-- Ignore physics check --
	self:CreateOBBPhysics(minOBB, maxOBB, true)

	if CLIENT then 
		self:SetRenderBounds(minOBB, maxOBB)
	end
end
--- Physics ----
----------------

------------
--- SETS ---
function ENT:SetStatus(newStatus)
	if SERVER then return end -- Ignore server for now?
	
	if self.LAST_STATUS == newStatus then return end
	self.LAST_STATUS = newStatus
end

function ENT:SetModelErrored(errored)
	self.LAST_MODEL_ERRORED = errored
	
	if SERVER then
		net.Start("prop_mesh_command")
			net.WriteInt(self:EntIndex(), 32)
			net.WriteString("MODEL_FAILED")
			net.WriteBool(errored)
		net.Broadcast()
	end
end

function ENT:SetScale(scale)
	if not self.LOADED_MESH then return end

	self.LOADED_MESH.scale = scale
	self.LAST_REQUESTED_MESH.scale = scale
	
	if SERVER then
		self.SAVE_DATA.scale = scale -- Update scale and save it
		self:SaveDupeData()
			
		net.Start("prop_mesh_command")
			net.WriteInt(self:EntIndex(), 32)
			net.WriteString("MESH_SCALE")
			net.WriteVector(scale)
		net.Broadcast()
	elseif CLIENT then
		self:BuildIMesh( self.LOADED_MESH ) -- Rebuild the mesh
	end
end

function ENT:SetPhysScale(phys, obb)
	if self.LOADED_MESH then
		self.LOADED_MESH.phys = phys
		self.LOADED_MESH.obb = obb
	end

	if self.LAST_REQUESTED_MESH then
		self.LAST_REQUESTED_MESH.phys = phys
	end

	-- Rebuild collisions
	self:BuildPhysics( phys, obb )
		
	if SERVER then
		self.SAVE_DATA.obb = obb -- Update obb and save it
		self.SAVE_DATA.phys = phys -- Update phys and save it
		self:SaveDupeData()
		
		net.Start("prop_mesh_command")
			net.WriteInt(self:EntIndex(), 32)
			net.WriteString("MESH_PHYS_SCALE")
			net.WriteVector(phys)			
			net.WriteTable(obb)			
		net.Broadcast()	
	end
end
--- SETS ---
------------

-------------
---  OBJ  ---
function ENT:CheckOBJUri(uri, onComplete)
	local allowedTypes = {"text/plain", "application/octet%-stream", "application/x%-tgif"}

	HTTP({
		url = uri,
		method = "GET",
		headers = {
			["Range"] = "bytes=0-1",
			["Accept-Encoding"] = "none"
		},
		success = function(code, body, headers)
			if not headers then return onComplete("!! Cannot PRE-FETCH model !!") end

			local fileSize = nil
			local fileRange = headers["Content-Range"] or headers["content-range"]

			if fileRange then
				local range = string.Explode('/', fileRange)
				if not range or not range[2] then return onComplete("!! Failed to find 'Content-Range' header !!") end

				fileSize = range[2]
			else
				if string.StartWith(uri, 'https://pastebin.com') then
					fileSize = #body
				else
					return onComplete("!! Failed to find 'Content-Range' header !!")
				end
			end
			
			local fileType = headers["Content-Type"]
			if not fileType then return onComplete("!! Failed to find 'Content-Type' header !!") end
			
			local foundType = false
			for _, v in pairs(allowedTypes) do
				if string_find(fileType, v) then
					foundType = true
					break
				end
			end
			
			if not foundType then
				print("[PropMLIB] Allowed content-types: ")
				PrintTable(allowedTypes)
				
				return onComplete("!! Content-Type '" .. fileType .. "' not allowed !!") 
			end
			
			return onComplete(nil, {
				fileSize = tonumber(fileSize),
				fileType = fileType
			})
		end,
		failed = function(err)
			return onComplete("!! Cannot PRE-FETCH model !!")
		end
	})
end

function ENT:LoadOBJ(uri, isAdmin, onSuccess, onFail)
	local fetchBody = nil
	local bodySize = nil
	local maxBytes = self.MAX_OBJ_SIZE_BYTES:GetInt()
	
	PropMLIB.MeshParser.Register(self, {
		onInitialize = function(onInitialized)
			-- Entity died
			if not IsValid(self) then
				return PropMLIB.MeshParser.QueueDone()
			end
			
			-- Being solved, send texture!
			if PropMLIB.Obj.IsCached(uri) then
				self:SetStatus("Loading cached model")
	
				onSuccess(table_copy(PropMLIB.Obj.Cache[uri]))
				return PropMLIB.MeshParser.QueueDone()
			end
			
			self:SetStatus("Pre-fetching model")
			self:CheckOBJUri(uri, function(err, data)
				if err then 
					PropMLIB.MeshParser.QueueDone()
					return onFail(err)
				end
				
				local niceSize = PropMLIB.Util.NiceSize(data.fileSize)
				if not isAdmin then
					if data.fileSize > maxBytes then
						PropMLIB.MeshParser.QueueDone()
						return onFail("!! Model too big (".. niceSize ..") !!")
					end
				end
				
				self:SetStatus("Fetching model")
				HTTP({
					url = uri,
					method = "GET",
					success = function(code, body, headers)
						fetchBody = body
						bodySize = niceSize
						
						return onInitialized()
					end,
					failed = function(err)
						PropMLIB.MeshParser.QueueDone()
						return onFail("!! Invalid url !!")
					end
				})
			end)
		end,
	
		onStatusUpdate = function(message)
			if not IsValid(self) or not message then return end
			self:SetStatus(message)
		end,
		
		onComplete = function(meshData)
			PropMLIB.MeshParser.QueueDone()
			
			if not IsValid(self) then return end
			return onSuccess(table_copy(meshData))
		end,
		
		onFailed = function()
			PropMLIB.MeshParser.QueueDone()
			if not IsValid(self) then return end
			
			local status = self.LAST_STATUS or "UNKNOWN"
			return onFail("!! FAILED: " .. status .. " !!")
		end,
		
		co = coroutine.create(function ()
			if not IsValid(self) then
				return coroutine.yield(true, "")
			end
			
			local meshData = PropMLIB.Obj.Parse(isAdmin, fetchBody, true)
			meshData.uri = uri
			meshData.metadata = {
				fileSize = bodySize
			}
			
			-- Cache it! --
			PropMLIB.Obj.Register(uri, meshData)
			
			-- Finish it --
			return coroutine.yield(true, "Done parsing", meshData)
		end)
	})
end

function ENT:BuildMeshes(meshData)
	self.LOADED_MESH = table_copy(meshData)
	
	if CLIENT then self:BuildIMesh(meshData) end
	self:BuildPhysics(meshData.phys, meshData.obb)
end

---  OBJ  ---
-------------