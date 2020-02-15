include('shared.lua')

local table_insert = table.insert
local table_remove = table.remove
local string_split = string.Split
local string_trim = string.Trim
local table_copy = table.Copy

local math_rand = math.Rand

----------------
--- SETTINGS ---
ENT.AutomaticFrameAdvance = true
ENT.DEFAULT_MATERIAL = CreateMaterial( "QUBE_DEFAULT_MATERIAL", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$model"] = "1",
	["$decal"] = "1"
})

ENT.DEFAULT_MATERIAL_PHYS = CreateMaterial( "QUBE_DEFAULT_MATERIAL_PHYS", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
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

language.Add( "SBoxLimit_qube_mesh", "You have hit the qube_mesh limit!" )
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
			self:ClearMeshes()
			
			local safeScale = self:VectorToSafe(meshData, meshData.scale)
			local minOBB = meshData.minOBB * safeScale
			local maxOBB = meshData.maxOBB * safeScale
			
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

function ENT:ClearMeshes()
	QUBELib.MeshParser.ClearMeshes(self.MESH_MODELS)
	self.MESH_MODELS = {}
end

function ENT:LocalLoadMesh(uri, scale, phys)
	-- Cleanup --
	self:Clear()
	-- ------- --
	
	local owner = self:GetOwner()
	if self.CPPIGetOwner then
		owner = self:CPPIGetOwner()
	end
	
	self.LAST_REQUESTED_MESH = {uri = uri, scale = scale, phys = phys}
	self:LoadOBJ(uri, owner, function(meshData)
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
	if not self.LAST_MODEL_ERRORED then return end
	
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
	local is_owner = false
	if self.CPPIGetOwner then
		is_owner = self:CPPIGetOwner() == LocalPlayer()
	else
		is_owner = self:GetOwner() == LocalPlayer()
	end
	
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
-- PHYSICS --
-------------

--------
-- UI --
function ENT:LoadHistory()
	if file.Exists("qube_mesh/__saved_meshes.json", "DATA") then
		local rawHistory = file.Read("qube_mesh/__saved_meshes.json")
		self.HISTORY_MESHES = util.JSONToTable( rawHistory )
	end
end

function ENT:AddHistory(addData)
	if not self.HISTORY_MESHES then self.HISTORY_MESHES = {} end
	if not addData or not addData.uri or string_trim(addData.uri) == "" then return end
	
	self.HISTORY_MESHES[addData.uri] = addData
	self:SaveHistory()
end

function ENT:RemoveHistory(index)
	if not self.HISTORY_MESHES then return end
	
	local key = table.GetKeys(self.HISTORY_MESHES)[index]
	if not key then return end
	
	self.HISTORY_MESHES[key] = nil
	self:SaveHistory()
end

function ENT:SaveHistory()
	file.CreateDir( "qube_mesh" )
	file.Write( "qube_mesh/__saved_meshes.json", util.TableToJSON( self.HISTORY_MESHES ) )
end

function ENT:RebuildHistoryTable(tbl)
	tbl:Clear()
	
	if self.HISTORY_MESHES then
		for _, v in pairs(self.HISTORY_MESHES) do
			local uriEnd = string_split(v.uri, "/")
			local textureEnd = ""
			
			for k, tex in pairs(v.textures) do
				if not tex or string_trim(tex) == "" then continue end
				local texPath = string_split(tex, "/")
				textureEnd = textureEnd .. texPath[#texPath]
				
				if k < #v.textures then
					textureEnd = textureEnd .. ";"
				end
			end
		
			tbl:AddLine(uriEnd[#uriEnd], textureEnd)
		end
	end
end

function ENT:CreateTextureRow(meshProps, index, value, onChange)
	local textureURL = meshProps:CreateRow( "Urls", "Texture_" .. index )
	textureURL:Setup( "Generic" )
	textureURL:SetValue( value or "" )
	textureURL.DataChanged = function( _, val )
		onChange(val)
	end
	
	return textureURL
end

function ENT:CreateMenu()
	if self.PANEL then
		self.PANEL:Remove()	
	end
	
	--- RELOAD HISTORY
	self:LoadHistory()
	-----
	
	local maxMaterials = QUBELib.Obj.MAX_SUBMESHES
	if LocalPlayer():IsAdmin() then
		maxMaterials = 20	
	end
	
	local currentMesh = self.LAST_REQUESTED_MESH
	local currentData = {
		uri = "",
		textures = {},
		scale = Vector(1, 1, 1),
		phys = Vector(1, 1, 1)
	}
	
	if currentMesh then
		currentData.uri = currentMesh.uri
		currentData.scale = currentMesh.scale
		currentData.phys = currentMesh.phys
	end
	
	if self.MATERIALS_URL then
		currentData.textures = table_copy(self.MATERIALS_URL)
		
		for i = 1, #currentData.textures do
			if currentData.textures[i] and currentData.textures[i] ~= "nil" then continue end
			currentData.textures[i] = ""
		end
	end
	
	self.PANEL = vgui.Create( "DFrame" )
	self.PANEL:SetSize( 600, 400 )
	self.PANEL:SetTitle( "QUBE Menu" )
	self.PANEL:SetDraggable( true )
	self.PANEL:MakePopup()
	self.PANEL:Center()
	
	self.PANEL.btnMinim:SetVisible( false )
	self.PANEL.btnMaxim:SetVisible( false )
	
	
	local sheet = vgui.Create( "DPropertySheet", self.PANEL )
	sheet:Dock( FILL )
	
	
	local meshPanel = vgui.Create( "DPanel", sheet )
	sheet:AddSheet( "Mesh", meshPanel, "icon16/brick.png" )
	
	local meshHistoryPanel = vgui.Create( "DPanel", sheet )
	sheet:AddSheet( "History", meshHistoryPanel, "icon16/book_addresses.png" )
	
	-----
	--- HISTORY ---
	----
	local MeshHistoryList = vgui.Create( "DListView", meshHistoryPanel )
	
	MeshHistoryList:Dock( FILL )
	MeshHistoryList:SetMultiSelect( false )
	
	MeshHistoryList:AddColumn( "OBJ" )
	MeshHistoryList:AddColumn( "TEXTURE" )
	
	self:RebuildHistoryTable(MeshHistoryList)
	
	MeshHistoryList.OnRowRightClick = function(panel, line)
		local SubMenu = DermaMenu(true, panel)
		local deleteBtn = SubMenu:AddOption( "Remove", function()
			self:RemoveHistory(line)
			self:RebuildHistoryTable(MeshHistoryList)
		end)
	
		deleteBtn:SetIcon( "icon16/delete.png" )
		SubMenu:Open()
	end
	
	-----
	--- MESH ---
	----
	local meshProps = vgui.Create( "DProperties", meshPanel )
	meshProps:Dock( FILL )
	
	-------
	local meshDebug = meshProps:CreateRow( "Settings", "Debug Mode" )
	meshDebug:Setup( "Boolean" )
	
	if self.GetDebug then 
		meshDebug:SetValue( self:GetDebug())
	else
		meshDebug:SetValue(false)
	end
	
	meshDebug.DataChanged = function( _, val )
		net.Start("qube_mesh_command")
			net.WriteString("SET_DEBUG")
			net.WriteEntity(self)
			net.WriteBool((val == 1))
		net.SendToServer()
	end
	-----
	
	local meshURL = meshProps:CreateRow( "Urls", "OBJ" )
	meshURL:Setup( "Generic" )
	meshURL:SetValue( currentData.uri )
	meshURL.DataChanged = function( _, val )
		currentData.uri = val
	end
	
	local textureURL = {}
	for i = 1, maxMaterials do 
		table_insert(textureURL, self:CreateTextureRow(meshProps, i, currentData.textures[i], function(val)
			currentData.textures[i] = val
		end))
	end
	
	
	----
	local meshSizeX = meshProps:CreateRow( "Scale", "Scale X" )
	meshSizeX:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	meshSizeX:SetValue( currentData.scale.x )
	meshSizeX.DataChanged = function( _, val ) 
		currentData.scale.x = val
	end
	
	local meshSizeY = meshProps:CreateRow( "Scale", "Scale Y" )
	meshSizeY:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	meshSizeY:SetValue( currentData.scale.y )
	meshSizeY.DataChanged = function( _, val ) 
		currentData.scale.y = val
	end
	
	local meshSizeZ = meshProps:CreateRow( "Scale", "Scale Z" )
	meshSizeZ:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	meshSizeZ:SetValue( currentData.scale.z )
	meshSizeZ.DataChanged = function( _, val ) 
		currentData.scale.z = val
	end
	----
	
	----
	local meshPhysCustom = meshProps:CreateRow( "Physics", "Reset physics to scale" )
	meshPhysCustom:Setup( "Boolean" )
	meshPhysCustom:SetValue( false )
	
	
	local meshPhysX = meshProps:CreateRow( "Physics", "Physics X" )
	meshPhysX:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	meshPhysX:SetValue( currentData.phys.x )
	meshPhysX.DataChanged = function( _, val ) 
		currentData.phys.x = val
	end
	
	local meshPhysY = meshProps:CreateRow( "Physics", "Physics Y" )
	meshPhysY:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	meshPhysY:SetValue( currentData.phys.y )
	meshPhysY.DataChanged = function( _, val ) 
		currentData.phys.y = val
	end
	
	local meshPhysZ = meshProps:CreateRow( "Physics", "Physics Z" )
	meshPhysZ:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	meshPhysZ:SetValue( currentData.phys.z )
	meshPhysZ.DataChanged = function( _, val ) 
		currentData.phys.z = val
	end
	----
	
	meshPhysCustom.DataChanged = function( _, val )
		if not val then return end
		
		meshPhysX:SetValue(currentData.scale.x)
		currentData.phys.x = currentData.scale.x
			
		meshPhysY:SetValue(currentData.scale.y)
		currentData.phys.y = currentData.scale.y
			
		meshPhysZ:SetValue(currentData.scale.z)
		currentData.phys.z = currentData.scale.z
		
		meshPhysCustom:SetValue( false )
	end
	
	---
	
	local updateBtn = vgui.Create( "DButton", meshPanel )
	updateBtn:SetText( "Update mesh" )
	updateBtn:Dock( BOTTOM  )
	updateBtn.DoClick = function()
		-- TODO, ADD COOLDOWN
		self:AddHistory(currentData)
		self:RebuildHistoryTable(MeshHistoryList)
		
		net.Start("qube_mesh_command")
			net.WriteString("UPDATE_MESH")
			net.WriteEntity(self)
			net.WriteTable(currentData)
		net.SendToServer()
	end
	
	MeshHistoryList.DoDoubleClick = function(panel, line)
		local key = table.GetKeys(self.HISTORY_MESHES)[line]
		if not key then return end
		
		local data = self.HISTORY_MESHES[key]
		if not data then return end
		
		for i = 1, #data.textures do 
			textureURL[i]:SetValue(data.textures[i])
		end
		
		meshURL:SetValue(data.uri)
		currentData.uri = data.uri
		
		if data.scale then
			meshSizeX:SetValue(data.scale.x)
			currentData.scale.x = data.scale.x
			
			meshSizeY:SetValue(data.scale.y)
			currentData.scale.y = data.scale.y
			
			meshSizeZ:SetValue(data.scale.z)
			currentData.scale.z = data.scale.z
		end
	
		if data.phys then
			meshPhysX:SetValue(data.phys.x)
			currentData.phys.x = data.phys.x
			
			meshPhysY:SetValue(data.phys.y)
			currentData.phys.y = data.phys.y
			
			meshPhysZ:SetValue(data.phys.z)
			currentData.phys.z = data.phys.z
		end
	
		self:EmitSound("buttons/button14.wav")
		net.Start("qube_mesh_command")
			net.WriteString("UPDATE_MESH")
			net.WriteEntity(self)
			net.WriteTable(data)
		net.SendToServer()
	end
	---
end
-- UI --
--------