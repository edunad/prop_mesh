
ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName		= "QUBE"
ENT.Author			= "FailCake"
ENT.RenderGroup 	= RENDERGROUP_TRANSLUCENT
ENT.AdminOnly		= false
ENT.Category		= "Editors"
ENT.Contact			= "https://github.com/edunad/qube"
ENT.Spawnable		= true

local math_clamp_ = math.Clamp
local math_abs = math.abs
local table_copy = table.Copy

-- Default SETTINGS ---------
ENT.MAX_SAFE_VOLUME = GetConVar( "qube_maxScaleVolume" )
ENT.MIN_SAFE_VOLUME = GetConVar( "qube_minScaleVolume" )

ENT.MIN_SAFE_SCALE = 0.01
ENT.MAX_SAFE_SCALE = 100

ENT.MAX_OBJ_SIZE_BYTES = GetConVar( "qube_maxOBJ_bytes" )
-----------------------------

--- LOADED MODEL ---
ENT.LOADED_MESH = nil
ENT.LAST_REQUESTED_MESH = {}

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
		
		timer.Simple(0.1, function()
			self.DEFAULT_MATERIAL:SetVector("$color2", Vector(0, 0, 0))
			self.DEFAULT_MATERIAL_PHYS:SetVector("$color2", Vector(1, 1, 1))
		end)
		return
	end
	
	self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetRenderMode( RENDERMODE_TRANSALPHA )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:DrawShadow( false )
	
	duplicator.StoreEntityModifier(self, "SAVE_DATA", self.SAVE_DATA)
	QUBELib.Registry.RegisterQube(self)
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
			
			QUBELib.PVSCache.Remove(entIndex)
			QUBELib.MeshParser.ClearMeshes(meshes)
		end)
	else
		QUBELib.Registry.UnRegisterQube(self)
	end
	
	QUBELib.MeshParser.UnRegister(self)
end
--- GENERAL ----
----------------

-------------
--- UTIL ----
function ENT:GetOBBSize(meshData)
	local minOBB = meshData.minOBB
	local maxOBB = meshData.maxOBB
	
	local width = maxOBB.x - minOBB.x
	local lenght = maxOBB.y - minOBB.y
	local height = maxOBB.z - minOBB.z
	
	return Vector(width, lenght, height)
end

function ENT:VectorToSafe(meshData, scale)
	local fixedScale = QUBELib.Util.ClampVector(Vector(scale.x, scale.y, scale.z) or Vector(), self.MIN_SAFE_SCALE, self.MAX_SAFE_SCALE)
	local minVol = self.MIN_SAFE_VOLUME:GetInt()
	local maxVol = self.MAX_SAFE_VOLUME:GetInt()
	
	local OBB = self:GetOBBSize(meshData)
	for i = 1, 3 do
		local size = OBB[i]
		local scaler = fixedScale[i]
		local size_actual = size * scaler
		local size_clamped = math_clamp_(size_actual, minVol, maxVol)
		local new = size_clamped / size
		
		if not QUBELib.Util.IsFinite(new) or math_abs(new) < 0.00000001 then return end
		fixedScale[i] = new
	end
	
	return fixedScale
end

function ENT:Clear()
	self.LOADED_MESH = nil
	
	self.LAST_REQUESTED_MESH = nil
	self.LAST_STATUS = nil
	self.LAST_MODEL_ERRORED = false
	
	self:SetDefaultPhysics()
	if CLIENT then self:ClearMeshes() end
end
--- UTIL ----
-------------

----------------
--- Physics ----
function ENT:CreateOBBPhysics(minOBB, maxOBB)
	if CLIENT then
		if IsValid( self.CLIENT_PHYSICS_BOX ) then
			self.CLIENT_PHYSICS_BOX:Destroy()
		end
	end
	
	-- Create OBB physics --
	self:PhysicsDestroy()
	if SERVER then
		self:PhysicsInitBox( minOBB, maxOBB )
		self:SetSolid( SOLID_VPHYSICS )
		
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion( false )
			phys:Sleep()
		end
	else
		self.CLIENT_PHYSICS_BOX = CreatePhysCollideBox( minOBB, maxOBB )
	end
end

function ENT:BuildPhysics(meshData)
	local safeScale = self:VectorToSafe(meshData, meshData.phys)
	local minOBB = meshData.minOBB * safeScale
	local maxOBB = meshData.maxOBB * safeScale
	
	self:CreateOBBPhysics(minOBB, maxOBB)
end

function ENT:SetDefaultPhysics()
	local minOBB = Vector(-12, -12, -12)
	local maxOBB = Vector(12, 12, 12)
	
	self:CreateOBBPhysics(minOBB, maxOBB)
	
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
	if self.LAST_MODEL_ERRORED == errored then return end
	self.LAST_MODEL_ERRORED = errored
	
	if SERVER then
		net.Start("qube_mesh_command")
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
			
		net.Start("qube_mesh_command")
			net.WriteInt(self:EntIndex(), 32)
			net.WriteString("MESH_SCALE")
			net.WriteVector(scale)
		net.Broadcast()
	elseif CLIENT then
		self:BuildIMesh( self.LOADED_MESH ) -- Rebuild the mesh
	end
end

function ENT:SetPhysScale(phys)
	if not self.LOADED_MESH then return end
	self.LOADED_MESH.phys = phys
	self.LAST_REQUESTED_MESH.phys = phys
	
	-- Rebuild collisions
	self:BuildPhysics( self.LOADED_MESH )
		
	if SERVER then
		self.SAVE_DATA.phys = phys -- Update scale and save it
		self:SaveDupeData()
			
		net.Start("qube_mesh_command")
			net.WriteInt(self:EntIndex(), 32)
			net.WriteString("MESH_PHYS_SCALE")
			net.WriteVector(phys)			
		net.Broadcast()	
	end
end
--- SETS ---
------------

-------------
---  OBJ  ---
function ENT:CheckOBJUri(uri, onComplete)
	HTTP({
		url = uri,
		method = "HEAD",
		headers = {
			["Range"] = "bytes=0-"
		},
		success = function(body, len, headers, code)
			if not headers then return onComplete() end
			
			local fileSize = headers["Content-Length"] or headers["content-length"]
			if not fileSize then return onComplete() end
			
			local fileType = headers["Content-Type"]
			if not fileType or (fileType ~= "text/plain" and fileType ~= "application/octet-stream") then
				return onComplete()
			end
			
			return onComplete({
				fileSize = tonumber(fileSize),
				fileType = fileType
			})
		end,
		failed = function(err)
			return onComplete()
		end
	})
end

function ENT:LoadOBJ(uri, isAdmin, onSuccess, onFail)
	local fetchBody = nil
	local bodySize = nil
	local maxBytes = self.MAX_OBJ_SIZE_BYTES:GetInt()
	
	QUBELib.MeshParser.Register(self, {
		onInitialize = function(onInitialized)
			-- Entity died
			if not IsValid(self) then
				return QUBELib.MeshParser.QueueDone()
			end
			
			-- Being solved, send texture!
			if QUBELib.Obj.IsCached(uri) then
				self:SetStatus("Loading cached model")
				onSuccess(table_copy(QUBELib.Obj.Cache[uri]))
				return QUBELib.MeshParser.QueueDone()
			end
			
			self:SetStatus("Pre-fetching model")
			self:CheckOBJUri(uri, function(data)
				if not data then 
					QUBELib.MeshParser.QueueDone()
					return onFail("!! Invalid model url !!")
				end
				
				local niceSize = QUBELib.Util.NiceSize(data.fileSize)
				if not isAdmin then
					if data.fileSize > maxBytes then
						QUBELib.MeshParser.QueueDone()
						return onFail("!! Model too big (".. niceSize ..") !!")
					end
				end
				
				self:SetStatus("Fetching model")
				http.Fetch(uri, function(body, len, headers, code)
					fetchBody = body
					bodySize = niceSize
					
					return onInitialized()
				end, function(err)
					QUBELib.MeshParser.QueueDone()
					return onFail("!! Invalid url !!")
				end)
			end)
		end,
	
		onStatusUpdate = function(message)
			if not IsValid(self) or not message then return end
			self:SetStatus(message)
		end,
		
		onComplete = function(meshData)
			QUBELib.MeshParser.QueueDone()
			
			if not IsValid(self) then return end
			return onSuccess(meshData)
		end,
		
		onFailed = function()
			QUBELib.MeshParser.QueueDone()
			
			if not IsValid(self) then return end
			return onFail("!! FAILED: " .. self.LAST_STATUS .. " !!")
		end,
		
		co = coroutine.create(function ()
			if not IsValid(self) then
				return coroutine.yield(true, "")
			end
			
			local meshData = QUBELib.Obj.Parse(isAdmin, fetchBody, true)
			meshData.uri = uri
			meshData.metadata = {
				fileSize = bodySize
			}
			
			-- Cache it! --
			QUBELib.Obj.Register(uri, meshData)
			
			-- Finish it --
			return coroutine.yield(true, "Done parsing", meshData)
		end)
	})
end

function ENT:BuildMeshes(meshData)
	self.LOADED_MESH = meshData
	
	if CLIENT then self:BuildIMesh(meshData) end
	self:BuildPhysics(meshData)
end

---  OBJ  ---
-------------