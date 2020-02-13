local table_insert = table.insert
local table_remove = table.remove
local math_rand = math.Rand

----------------
--- SETTINGS ---
ENT.AutomaticFrameAdvance = true
ENT.DEFAULT_MATERIAL = CreateMaterial( "QUBE_DEFAULT_MATERIAL", "UnlitGeneric", {
	["$basetexture"] = Material("models/debug/debugwhite"):GetTexture("$basetexture"),
	["$model"] = "1",
	["$decal"] = "1"
})

ENT.DEFAULT_MATERIAL_PHYS = CreateMaterial( "QUBE_DEFAULT_MATERIAL_PHYS_", "UnlitGeneric", {
	["$basetexture"] = Material("models/debug/debugwhite"):GetTexture("$basetexture"),
	["$model"] = "1",
	["$decal"] = "1"
})

ENT.DEFAULT_MATERIAL:SetVector("$color2", Vector(0, 0, 0))
ENT.DEFAULT_MATERIAL_PHYS:SetVector("$color2", Vector(1, 1, 1))
	
ENT.DEBUG_MATERIAL = Material("models/wireframe")
ENT.DEBUG_MATERIALS_COLORS = {
	{0.90, 0.29, 0.23},
	{0.16, 0.50, 0.72},
	{0.15, 0.68, 0.37},
	{0.10, 0.73, 0.61},
	{0.60, 0.34, 0.71},
	{0.94, 0.76, 0.05}
}
----------------

ENT.MESH_MODELS = {}

ENT.CLIENT_PHYSICS_BOX = nil
ENT.PANEL = nil

ENT.HISTORY_MESHES = {}

----

language.Add( "SBoxLimit_"..ENT_TAG, "You have hit the "..ENT_TAG.." limit!" )
surface.CreateFont( "QUBE_DEBUGFIXED", {
	font		= "DebugFixedSmall",
	size		= ScreenScale(6),
	weight		= 200
})

--- SETTINGS ---
----------------

---------------
--- GENERAL ---
function ENT:LoadTextures(textures)
	for _, v in pairs(textures) do
		if not v or string_trim(v) == "" then continue end
		QUBELib.URLMaterial.LoadMaterialURL(v)
	end
		
	self.MATERIALS_URL = textures
end

function ENT:GenerateExtraRandomColors()
	for i = 0, 20 do
		table_insert(self.DEBUG_MATERIALS_COLORS, {math_rand(0, 1), math_rand(0, 1), math_rand(0, 1)})
	end
end
--- GENERAL ---
---------------

------------
--- MESH ---
function ENT:BuildIMesh(meshData)
	-- Prevent crashing players if spammed --
	QUBELib.QueueSYS.Register({
		callback = function()
			if not IsValid(self) then return end
		
			local safeScale = self:VectorToSafe(meshData, meshData.scale)
			local minOBB = meshData.minOBB * safeScale
			local maxOBB = meshData.maxOBB * safeScale
			
			self:ClearMeshes()
			self:SetRenderBounds( minOBB, maxOBB )
			
			for _, v in pairs(meshData.subMeshes) do
				local scaledTris = QUBELib.Obj.GetScaledTris(v, safeScale)
				local msh = Mesh()
				
				msh:BuildFromTriangles(scaledTris)
				table_insert(self.MESH_MODELS, msh)
			end
		end
	})
end

function ENT:ClearMeshes(meshes)
	if self.MESH_MODELS and #self.MESH_MODELS > 0 then
		for _, v in pairs(self.MESH_MODELS) do
			if not v or v == NULL then continue end
			v:Destroy()
		end
	end
		
	self.MESH_MODELS = {}
end

function ENT:LocalLoadMesh(uri, scale, phys)
	-- Cleanup --
	self:Clear()
	-- ------- --
	
	self.LAST_REQUESTED_MESH = {uri = uri, scale = scale, phys = phys}
	self:LoadOBJ(uri, self:CPPIGetOwner(), function(meshData)
		meshData.scale = scale
		meshData.phys = phys
		
		self:SetStatus("Done")
		self:BuildMeshes(meshData)
	end, function(err)
		self:SetModelErrored(true)
		self:SetStatus(err)
	end)
end

function ENT:RetryModelParse()
	if not ent.LAST_MODEL_ERRORED then return end
	
	local lastMesh = self.LAST_REQUESTED_MESH
	if not lastMesh then return end
	
	QUBELib.Obj.UnRegister(lastMesh.uri) -- Uncache it
	self:LocalLoadMesh(lastMesh.uri, lastMesh.scale, lastMesh.phys)
end
--- MESH ---
------------


------------
--- UTIL ---
function ENT:GetModelMaterial(index, DebugMode)
	if DebugMode then
		return self.DEBUG_MATERIAL
	end
	
	local mat = self.DEFAULT_MATERIAL
	if self.MATERIALS_URL and self.MATERIALS_URL[index] then
		if QUBELib.URLMaterial.Materials[self.MATERIALS_URL[index]] then
			mat = QUBELib.URLMaterial.Materials[self.MATERIALS_URL[index]]
		end
	end
	
	return mat
end

function ENT:OnPVSReload()
	local meshData = self.LOADED_MESH
	if not meshData	then return end
	
	local safeScale = self:VectorToSafe(meshData, meshData.scale)
	local minOBB = meshData.minOBB * safeScale
	local maxOBB = meshData.maxOBB * safeScale
		
	self:SetRenderBounds(minOBB, maxOBB)
end
--- UTIL ---
------------

---------------
--- DRAWING ---
function ENT:DrawTranslucent()
	self:Draw()
end

function ENT:Draw()
	local DebugMode = self.GetDebug and self:GetDebug()
	local minOBB, maxOBB = self:GetRenderBounds()
	
	if not self.LOADED_MESH then
		render.MaterialOverride( self.DEFAULT_MATERIAL )
			self:DrawModel()
			render.DrawWireframeBox( self:GetPos(), self:GetAngles(), minOBB, maxOBB, Color(255, 255, 255), true)
		render.MaterialOverride()
		
		self:DrawLOGO()
	else
		if DebugMode then self:DrawDEBUGBoxes() end
		self:DrawModelMeshes(DebugMode)
	end
	
	if DebugMode then self:DrawDEBUGInfo() end
end

function ENT:DrawDEBUGBoxes()
	local minROBB, maxROBB = self:GetRenderBounds()
	local minPOBB, maxPOBB = self:OBBMins(), self:OBBMaxs()
	local pos = self:GetPos()
	local ang = self:GetAngles()
	
	render.SetMaterial( self.DEFAULT_MATERIAL )
	render.DrawBox( pos, ang, minROBB, maxROBB, Color(1, 1, 1, 1), true)
	
	render.DrawWireframeBox( pos, ang, minROBB, maxROBB, Color(255, 255, 255, 255), true)
	
	render.SetMaterial( self.DEFAULT_MATERIAL_PHYS )
	render.DrawBox( pos, ang, minPOBB, maxPOBB, Color(255, 255, 255, 255), true)
end

function ENT:DrawDEBUGInfo()
	local minROBB, maxROBB = self:GetRenderBounds()
	local renderCenter = self:WorldSpaceCenter()
	local pos = self:GetPos()
	local plyPos = LocalPlayer():GetPos()
	local ang = self:GetAngles()
	
	local meshData = self.LOADED_MESH
	if meshData then
		local TexVec, TexAng = LocalToWorld( Vector(maxROBB.x - 0.5, maxROBB.y - 0.5, maxROBB.z), Angle(), pos, ang )
		cam.Start3D2D( TexVec, TexAng, 0.1)
			render.PushFilterMag(TEXFILTER.POINT)
			render.PushFilterMin(TEXFILTER.POINT)
				draw.SimpleTextOutlined( #meshData.subMeshes .. " MESHES", "QUBE_DEBUGFIXED", 0, 0, Color( 255, 255, 255, 255 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT, 1, Color(1,1,1))
				draw.SimpleTextOutlined( meshData.metadata.fileSize , "QUBE_DEBUGFIXED", 0, 20, Color( 255, 255, 255, 255 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT, 1, Color(1,1,1))
			render.PopFilterMag()
			render.PopFilterMin()
		cam.End3D2D()
		
		local TexVec2, TexAng2 = LocalToWorld( Vector(minROBB.x + 0.5, minROBB.y, maxROBB.z), Angle(), pos, ang )
		cam.Start3D2D( TexVec2, TexAng2, 0.1)
			for k, v in pairs(meshData.subMeshes) do
				local color = self.DEBUG_MATERIALS_COLORS[k]
				draw.SimpleTextOutlined( k ..": ".. v.name , "QUBE_DEBUGFIXED", 0,  k * 18 - ((#meshData.subMeshes + 1) * 19), Color(color[1] * 255,color[2] * 255, color[3] * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT, 1, Color(1, 1, 1))
			end
		cam.End3D2D()	
	end
end

function ENT:DrawLOGO()
	local pos = self:WorldSpaceCenter() + Vector(0, 0, 4)
	if self.LAST_STATUS or self.LAST_MODEL_ERRORED then
		pos = pos + Vector( 0, 0, 4 )
	end
	
	local ang = EyeAngles()
	ang:RotateAroundAxis(ang:Right(), 90)
	ang:RotateAroundAxis(ang:Up(), -90)
	
	cam.Start3D2D(pos, ang, 0.5)
		render.PushFilterMag(TEXFILTER.POINT)
		render.PushFilterMin(TEXFILTER.POINT)
			draw.DrawText( "QUBE", "TargetID", 0, -1, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
		render.PopFilterMag()
		render.PopFilterMin()
	cam.End3D2D()
	
	self:DrawStatus(pos, ang)
end

function ENT:DrawStatus(pos, ang)
	local is_owner = LocalPlayer() == self:CPPIGetOwner()
	
	cam.Start3D2D(pos, ang, 0.18)
		render.PushFilterMag(TEXFILTER.POINT)
		render.PushFilterMin(TEXFILTER.POINT)
			if self.LAST_STATUS then
				draw.DrawText(tostring(self.LAST_STATUS), "DebugFixedSmall", 0, 50, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
			end
			
			if hasErrored then
				if is_owner then
					draw.DrawText("USE + SHIFT to retry", "DebugFixedSmall", 0, 70, Color( 192, 57, 43, 255 ), TEXT_ALIGN_CENTER )
				else
					draw.DrawText("USE to retry", "DebugFixedSmall", 0, 70, Color( 192, 57, 43, 255 ), TEXT_ALIGN_CENTER )
				end
			end
		render.PopFilterMag()
		render.PopFilterMin()
	cam.End3D2D()
end

function ENT:DrawModelMeshes(DebugMode)
	if not self.LOADED_MESH then return end
	if not self.MESH_MODELS or #self.MESH_MODELS <= 0 then return end
	if not IsValid(self) then return end
	
	self:DrawModel() -- Draw first mesh
		
	if #self.MESH_MODELS > 1 then
		local matrix = Matrix()
		matrix:SetAngles(self:GetAngles())
		matrix:SetTranslation(self:GetPos())
			
		-- Draw rest of meshes
		cam.PushModelMatrix( matrix )
			for i = 2, #self.MESH_MODELS do
				local v = self.MESH_MODELS[i]
				if not v or v == NULL then continue end
					
				local mat = self:GetModelMaterial(i, DebugMode)
				if DebugMode then
					local color = self.DEBUG_MATERIALS_COLORS[i]
					mat:SetVector("$color2", Vector(color[1], color[2], color[3]))	
				end
				
				render.SetMaterial( mat )
				if not v.Draw then
					table_remove(self.MESH_MODELS, i)
				else
					v:Draw()	
				end
			end
		cam.PopModelMatrix()
	end
end

function ENT:GetRenderMesh()
	if not self.MESH_MODELS or #self.MESH_MODELS <= 0 then return end
	
	local initialMesh = self.MESH_MODELS[1]
	if not initialMesh or initialMesh == NULL then return end
	
	local DebugMode = self.GetDebug and self:GetDebug()
	local mat = self:GetModelMaterial(1, DebugMode)
	
	if DebugMode then
		local color = self.DEBUG_MATERIALS_COLORS[1]
		mat:SetVector("$color2", Vector(color[1], color[2], color[3])) -- Might be a bad idea, but it looks cool
	end
	
	return { Mesh = self.MESH_MODELS[1], Material = mat } -- Render first mesh
end
--- DRAWING ---
---------------

-------------
-- PHYSICS --
function ENT:TestCollision( startpos, delta, isbox, extents )
	if not IsValid( self.CLIENT_PHYSICS_BOX ) then
		return
	end
		
	-- TraceBox expects the trace to begin at the center of the box, but TestCollision is bad
	local max = extents
	local min = -extents
	max.z = max.z - min.z
	min.z = 0

	local hit, norm, frac = self.CLIENT_PHYSICS_BOX:TraceBox( self:GetPos(), self:GetAngles(), startpos, startpos + delta, min, max )
	if not hit then
		return
	end

	return {
		HitPos = hit,
		Normal = norm,
		Fraction = frac,
	}
end