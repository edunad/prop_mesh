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

ENT.DEBUG_MATERIAL = CreateMaterial( "QUBE_DEFAULT_MATERIAL_WIREFRAME", "Wireframe", {
	["$basetexture"] = "models/wireframe",
	["$model"] = "1",
	["$vertexalpha"] = "1",
	["$vertexcolor"] = "1",
	["$decal"] = "1"
})

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
ENT.UI = {}

ENT.HISTORY_MESHES = {}

---- INTERNAL CHECKS ----
ENT.__LOADED_MESH__ = false
ENT.__LOADED_TEXTURES__ = false
ENT.__PHYSICS_BOX__ = nil
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
	self.MATERIALS_URL = {}
	self.__LOADED_TEXTURES__ = false
	
	local totalTextures = #textures
	local onDone = function()
		totalTextures = totalTextures - 1
		
		if totalTextures <= 0 then
			self.__LOADED_TEXTURES__ = true
			self:CheckMeshCompletion()
		end
	end
	
	for _, v in pairs(textures) do
		if not v or string_trim(v) == "" then continue end
		QUBELib.URLMaterial.LoadMaterialURL(v, function()
			return onDone()
		end, function()
			return onDone()
		end)
		
		table_insert(self.MATERIALS_URL, v)
	end
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
	self.__LOADED_MESH__ = false
	
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
			
			self.__LOADED_MESH__ = true
			
			self:UpdateTextureName() -- Fix names
			self:CheckMeshCompletion()
		end
	})
end

function ENT:CheckMeshCompletion()
	if not self.__LOADED_MESH__ or not self.__LOADED_TEXTURES__ then return end
	timer.Simple(0.1, function() self:MeshComplete() end) -- Give it some time to fully render
end

function ENT:MeshComplete()
	local owner = self:GetOwner()
	if self.CPPIGetOwner then owner = self:CPPIGetOwner() end
	
	if LocalPlayer() ~= owner then return end
	self:TakeScreenshot()
end

function ENT:ClearMeshes()
	QUBELib.MeshParser.ClearMeshes(self.MESH_MODELS)
	self.MESH_MODELS = {}
end

function ENT:LocalLoadMesh(requestData)
	-- Cleanup --
	self:Clear()
	-- ------- --
	
	self.LAST_REQUESTED_MESH = table_copy(requestData)
	self:UpdateMeshSettings()
	
	self:LoadOBJ(requestData.uri, requestData.isAdmin, function(meshData)
		if not IsValid(self) then return end
		
		meshData.scale = requestData.scale
		meshData.phys = requestData.phys
		
		self:SetStatus("Done")
		self:BuildMeshes(meshData)
	end, function(err)
		print("[Qube]"..err)
		
		if not IsValid(self) then return end
		self:SetModelErrored(true)
		self:SetStatus(err)
	end)
end

function ENT:RetryModelParse()
	if not self.LAST_MODEL_ERRORED then return end
	
	local lastMesh = self.LAST_REQUESTED_MESH
	if not lastMesh then return end
	
	QUBELib.Obj.UnRegister(lastMesh.uri) -- Uncache it
	self:LocalLoadMesh(lastMesh)
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
--- PHYSICS ---
function ENT:TestCollision( startpos, delta, isbox, extents )
	if not IsValid( self.__PHYSICS_BOX__ ) then
		return
	end
	
	-- TraceBox expects the trace to begin at the center of the box, but TestCollision is bad
    local max = extents
    local min = -extents
    max.z = max.z - min.z
    min.z = 0

    local hit, norm, frac = self.__PHYSICS_BOX__:TraceBox( self:GetPos(), self:GetAngles(), startpos, startpos + delta, min, max )

    if not hit then
        return
    end

    return { 
        HitPos = hit,
        Normal  = norm,
        Fraction = frac,
    }
end
--- PHYSICS ---
---------------

---------------
--- DRAWING ---
function ENT:DrawTranslucent()
	local DebugMode = (self.GetDebug and self:GetDebug())
	if QUBELib.Thumbnail.TakingScreenshot then DebugMode = false end
	
	if not self.LOADED_MESH then
		local minOBB, maxOBB = self:GetRenderBounds()
		
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
	local pos = self:GetPos()
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
	local pos = self:GetPos() + Vector(0, 0, 4)
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
	cam.Start3D2D(pos, ang, 0.18)
		render.PushFilterMag(TEXFILTER.POINT)
		render.PushFilterMin(TEXFILTER.POINT)
			if self.LAST_STATUS then
				draw.DrawText(tostring(self.LAST_STATUS), "DebugFixedSmall", 0, 55, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
			end
			
			if self.LAST_MODEL_ERRORED then
				draw.DrawText("SHIFT + USE to retry", "DebugFixedSmall", 0, 70, Color( 192, 57, 43, 255 ), TEXT_ALIGN_CENTER )
			end
		render.PopFilterMag()
		render.PopFilterMin()
	cam.End3D2D()
end

function ENT:DrawModelMeshes(DebugMode)
	if not self.LOADED_MESH then return end
	if not self.MESH_MODELS or #self.MESH_MODELS <= 0 then return end
	if not IsValid(self) then return end
	
	local Fullbright = self.GetFullbright and self:GetFullbright()
	if Fullbright then render.SuppressEngineLighting( true ) end
	
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
	
	if Fullbright then render.SuppressEngineLighting( false ) end
end

function ENT:GetRenderMesh()
	if not self.MESH_MODELS or #self.MESH_MODELS <= 0 then return end
	
	local initialMesh = self.MESH_MODELS[1]
	if not initialMesh or initialMesh == NULL then return end
	
	local DebugMode = self.GetDebug and self:GetDebug()
	if QUBELib.Thumbnail.TakingScreenshot then DebugMode = false end
	
	local mat = self:GetModelMaterial(1, DebugMode)
	if DebugMode then
		local color = self.DEBUG_MATERIALS_COLORS[1]
		mat:SetVector("$color2", Vector(color[1], color[2], color[3])) -- Might be a bad idea, but it looks cool
	end
	
	return { Mesh = self.MESH_MODELS[1], Material = mat } -- Render first mesh
end


-- TODO: IMPROVE ANGLE AND POSITIONING --
function ENT:TakeScreenshot()
	local loadedMesh = self.LOADED_MESH
	if not loadedMesh then return end
	
	local maxOBB, minOBB = self:GetRenderBounds()
	local OAngle = self:GetAngles()
	local OPos = self:GetPos()
	
	local size = 0
	size = math.max( size, math.abs(minOBB.x) + math.abs(maxOBB.x) )
	size = math.max( size, math.abs(minOBB.y) + math.abs(maxOBB.y) )
	size = math.max( size, math.abs(minOBB.z) + math.abs(maxOBB.z) )
	
	if ( size < 900 ) then
		size = size * (1 - ( size / 254 ))
	else
		size = size * (1 - ( size / 4096 ))
	end
	
	size = math.Clamp( size, 5, 1000 )
	--
	local ViewPos, ViewAngle = LocalToWorld(Vector(maxOBB.z - size, (maxOBB.y + minOBB.y) / 2, 0), Angle(0, 0, -90), OPos, OAngle)
	QUBELib.Thumbnail.TakeThumbnail({
		ent = self,
		uri = loadedMesh.uri,
		origin = ViewPos,
		angles = ViewAngle
	})
	
	-- Regenerate icons
	timer.Simple(0.15, function()
		if not IsValid(self) then return end
		self:GenerateSpawnIcons() 
	end)
end
--- DRAWING ---
---------------

--------
-- UI --

function ENT:CreateHelpers(props)
	--- DEBUG ---
	local meshDebug = props:CreateRow( "Helpers", "Debug" )
	meshDebug:Setup( "Boolean" )
	
	if self.GetDebug then meshDebug:SetValue(self:GetDebug())
	else meshDebug:SetValue(false) end
	
	meshDebug.DataChanged = function( _, val )
		net.Start("qube_mesh_command")
			net.WriteString("SET_DEBUG")
			net.WriteEntity(self)
			net.WriteBool((val == 1))
		net.SendToServer()
	end
	----
	
	-------
	local meshFullbright = props:CreateRow( "Helpers", "Fullbright" )
	meshFullbright:Setup( "Boolean" )
	
	if self.GetFullbright then meshFullbright:SetValue(self:GetFullbright())
	else meshFullbright:SetValue(false) end
	
	meshFullbright.DataChanged = function( _, val )
		net.Start("qube_mesh_command")
			net.WriteString("SET_FULLBRIGHT")
			net.WriteEntity(self)
			net.WriteBool((val == 1))
		net.SendToServer()
	end
	-----
end

function ENT:CreateMeshMenu()
	local meshPanel = vgui.Create( "DPanel", self.UI.SHEET )
	self.UI.SHEET:AddSheet( "Mesh", meshPanel, "icon16/brick_edit.png" )
	
	local props = vgui.Create( "DProperties", meshPanel )
	props:Dock( FILL )
	
	-----
	local meshURL = props:CreateRow( "Urls", "OBJ" )
	meshURL:Setup( "Generic" )
	---
	
	---- SCALES ---
	local meshSizeX = props:CreateRow( "Mesh Scale", "Scale X" )
	meshSizeX:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	
	local meshSizeY = props:CreateRow( "Mesh Scale", "Scale Y" )
	meshSizeY:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	
	local meshSizeZ = props:CreateRow( "Mesh Scale", "Scale Z" )
	meshSizeZ:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	----
	
	---- PHYSICS SCALE ---
	local meshPhysReset = props:CreateRow( "Physics Scale", "Reset physics to scale" )
	meshPhysReset:Setup( "Boolean" )
	meshPhysReset:SetValue( false )
	
	local meshPhysX = props:CreateRow( "Physics Scale", "Physics X" )
	meshPhysX:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	
	local meshPhysY = props:CreateRow( "Physics Scale", "Physics Y" )
	meshPhysY:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	
	local meshPhysZ = props:CreateRow( "Physics Scale", "Physics Z" )
	meshPhysZ:Setup( "Float", { min = self.MIN_SAFE_SCALE, max = self.MAX_SAFE_SCALE } )
	
	self:CreateHelpers(props)
	
	-- Garry pls.
	local uriElement = meshURL:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	local SXElement = meshSizeX:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	local SYElement = meshSizeY:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	local SZElement = meshSizeZ:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	
	local PXElement = meshPhysX:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	local PYElement = meshPhysY:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	local PZElement = meshPhysZ:GetChildren()[2]:GetChildren()[1]:GetChildren()[1]
	----
	
	meshPhysReset.DataChanged = function( _, val )
		if not val then return end
		meshPhysX:SetValue(SXElement:GetValue())
		meshPhysY:SetValue(SYElement:GetValue())
		meshPhysZ:SetValue(SZElement:GetValue())
		
		meshPhysReset:SetValue( false )
		surface.PlaySound( "garrysmod/ui_click.wav" )
	end
	----
	
	self.UI.MeshElements = {
		uri = meshURL:GetChildren()[2]:GetChildren()[1]:GetChildren()[1],
		
		scale = {SXElement, SYElement, SZElement}, 
		phys = {PXElement, PYElement, PZElement}
	}
	
	-- Update mesh --
	self:UpdateMeshSettings()
end

function ENT:CreateTextureRow(parent, index)
	local textureURL = parent:CreateRow( "Urls", index )
	textureURL:Setup( "Generic" )
	
	local debugColor = self.DEBUG_MATERIALS_COLORS[index]
	local labelElement = textureURL.Label
	labelElement:SetColor(Color(debugColor[1] * 255, debugColor[2] * 255, debugColor[3] * 255))

	textureURL.Paint = function(self, w, h)
		if ( !IsValid( self.Inner ) ) then return end

		local Skin = self:GetSkin()
		local editing = self.Inner:IsEditing()
		local disabled = !self.Inner:IsEnabled() || !self:IsEnabled()

		if ( disabled ) then
			surface.SetDrawColor( Skin.Colours.Properties.Column_Disabled )
			surface.DrawRect( w * 0.45, 0, w, h )
		end

		surface.SetDrawColor( Skin.Colours.Properties.Border )
		surface.DrawRect( w - 1, 0, 1, h )
		surface.DrawRect( w * 0.45, 0, 1, h )
		surface.DrawRect( 0, h - 1, w, 1 )
		
		surface.SetDrawColor( Color(1, 1, 1) )
		surface.DrawRect( 0.1, 0.1, w * 0.45 - 0.1, h - 0.1 )
	end
	
	return {
		uriText = textureURL:GetChildren()[2]:GetChildren()[1]:GetChildren()[1],
		rowText = textureURL
	}
end

function ENT:CreateTextureMenu()
	local maxMaterials = QUBELib.Obj.MAX_SUBMESHES:GetInt()
	if LocalPlayer():IsAdmin() then
		maxMaterials = 20
	end
	
	local texturePanel = vgui.Create( "DPanel", self.UI.SHEET )
	self.UI.SHEET:AddSheet( "Textures", texturePanel, "icon16/images.png" )
	
	local props = vgui.Create( "DProperties", texturePanel )
	props:Dock( FILL )
	
	self.UI.TextureRows = {}
	for i = 1, maxMaterials do 
		table_insert(self.UI.TextureRows, self:CreateTextureRow(props, i))
	end
	
	self:UpdateTextureName()
end

-----
function ENT:RemoveHistory(uri)
	if not self.HISTORY_MESHES or not self.HISTORY_MESHES[uri] then return end
	self.HISTORY_MESHES[uri] = nil
	
	self:SaveHistory()
end

function ENT:SaveHistory()
	file.Write( "qube_mesh/__saved_meshes.json", util.TableToJSON( self.HISTORY_MESHES ) )
	self:GenerateSpawnIcons() -- Re-generate it
end

function ENT:AddHistory(addData)
	if not self.HISTORY_MESHES then self.HISTORY_MESHES = {} end
	if not addData or not addData.uri or string_trim(addData.uri) == "" then return end
	
	self.HISTORY_MESHES[addData.uri] = addData
	self:SaveHistory()
end

function ENT:LoadHistory()
	if not file.Exists("qube_mesh/__saved_meshes.json", "DATA") then return end
	
	local rawHistory = file.Read("qube_mesh/__saved_meshes.json")
	self.HISTORY_MESHES = util.JSONToTable( rawHistory )
end

function ENT:CreateSpawnIcon(uri, panel, iconLayout, onClick, onRightClick)
	local button = vgui.Create( "DImageButton", iconLayout )
	button:SetSize( 128, 128 )
	button:SetTooltip(uri)
	button:SetImage( "../data/qube_mesh/thumbnails/" .. util.CRC(uri) .. ".jpg" )
	button.DoClick = function()
		return onClick(uri)
	end
	
	button.DoRightClick = function()
		local SubMenu = DermaMenu(true, panel)
		local deleteBtn = SubMenu:AddOption( "Remove", function()
			self:RemoveHistory(uri)
			button:Remove()
			return
		end)
		
		deleteBtn:SetIcon( "icon16/delete.png" )
		SubMenu:Open()
	end
end

function ENT:CreateHistoryMenu()
	self:LoadHistory() -- Load history
	
	self.UI.HISTORYPANEL = vgui.Create( "DPanel", self.UI.SHEET )
	self.UI.SHEET:AddSheet( "Saved Meshes", self.UI.HISTORYPANEL, "icon16/book_addresses.png" )
	
	local scroll = vgui.Create( "DScrollPanel", self.UI.HISTORYPANEL) -- Create the Scroll panel
	scroll:Dock( FILL )
	
	self.UI.ICONLIST = vgui.Create( "DIconLayout", scroll )
	self.UI.ICONLIST:Dock( FILL )
	self.UI.ICONLIST:SetSpaceY( 5 )
	self.UI.ICONLIST:SetSpaceX( 5 )
	self.UI.ICONLIST:Layout()
	
	self:GenerateSpawnIcons()
end

----

function ENT:SanitizeTextures(textures)
	if not textures or #textures <= 0 then return textures end
	
	local cleanTextures = {}
	for _, text in pairs(textures) do
		if not text or string_trim(text) == "" then continue end
		table_insert(cleanTextures, text)
	end
	
	return cleanTextures
end

function ENT:UILoadData(data)
	surface.PlaySound( "garrysmod/ui_click.wav" )
	
	net.Start("qube_mesh_command")
		net.WriteString("UPDATE_MESH")
		net.WriteEntity(self)
		net.WriteTable(data)
	net.SendToServer()
end

function ENT:GenerateSpawnIcons()
	if not self.UI or not IsValid(self.UI.PANEL) or not self.UI.ICONLIST then return end
	self.UI.ICONLIST:Clear()
	
	local onClick = function(clickedURL)
		local savedData = self.HISTORY_MESHES[clickedURL]
		if not self.HISTORY_MESHES or not savedData then return end
		if savedData.textures then
			savedData.textures = self:SanitizeTextures(savedData.textures)
		end
		
		self:UILoadData(savedData)
		self:UpdateTextureName(savedData)
		self:UpdateMeshSettings(savedData)
	end
	
	for _, v in pairs(self.HISTORY_MESHES) do
		self:CreateSpawnIcon(v.uri, self.UI.HISTORYPANEL, self.UI.ICONLIST, function(clickedURL)
			return onClick(clickedURL)
		end)
	end
end

function ENT:UpdateMeshSettings(savedData)
	if not self.UI or not IsValid(self.UI.PANEL) or not self.UI.MeshElements then return end
	local elements = self.UI.MeshElements
	local currentData = savedData or table_copy(self.LAST_REQUESTED_MESH)
	
	elements.uri:SetValue( currentData.uri or "" )
	
	local scale = currentData.scale or Vector(1, 1, 1)
	elements.scale[1]:SetValue(scale.x)
	elements.scale[2]:SetValue(scale.y)
	elements.scale[3]:SetValue(scale.z)
	
	local phys = currentData.phys or Vector(1, 1, 1)
	elements.phys[1]:SetValue(phys.x)
	elements.phys[2]:SetValue(phys.y)
	elements.phys[3]:SetValue(phys.z)
end

function ENT:UpdateTextureName(texturesData)
	if not self.UI or not IsValid(self.UI.PANEL) or not self.UI.TextureRows then return end
	
	local materials = table_copy(self.MATERIALS_URL) or {}
	if texturesData and texturesData.textures then
		materials = texturesData.textures
	end
	
	local loadedMesh = self.LOADED_MESH
	for i = 1, #self.UI.TextureRows do
		local tRow = self.UI.TextureRows[i]
		if not tRow or not tRow.rowText or not tRow.rowText.Label then continue end
		
		local name = nil
		if loadedMesh and loadedMesh.subMeshes[i] then
			name = loadedMesh.subMeshes[i].name
		end
		
		tRow.rowText.Label:SetText(name or "Texture_" .. i)
		tRow.uriText:SetText(materials[i] or "")
	end
end

function ENT:CreateMenu()
	if self.UI then
		if IsValid(self.UI.PANEL) then 
			self.UI.PANEL:Remove()
		end
	else
		self.UI = {}
	end
	
	self.UI.PANEL = vgui.Create( "DFrame" )
	self.UI.PANEL:SetSize( 568, 400 )
	self.UI.PANEL:SetTitle( "QUBE - Settings Menu" )
	self.UI.PANEL:SetDraggable( true )
	self.UI.PANEL:Center()
	self.UI.PANEL:MakePopup()
	
	self.UI.PANEL.btnMinim:SetVisible( false )
	self.UI.PANEL.btnMaxim:SetVisible( false )
	
	
	---- SECTIONS ---
	self.UI.SHEET = vgui.Create( "DPropertySheet", self.UI.PANEL )
	self.UI.SHEET:Dock( FILL )
	
	--- MESH ---
	self:CreateMeshMenu()
	--- TEXTURE ---
	self:CreateTextureMenu()
	--- HISTORY ---
	self:CreateHistoryMenu()
	---------------
	
	local updateBtn = vgui.Create( "DButton", self.UI.PANEL )
	updateBtn:SetText( "Update mesh" )
	updateBtn:Dock( BOTTOM  )
	updateBtn.DoClick = function()
		local elements = self.UI.MeshElements
		if not elements then return end
		
		local texts = {}
		for _, v in pairs(self.UI.TextureRows) do
			if not v or not v.uriText then continue end
			table_insert(texts, v.uriText:GetValue())
		end
		
		local data = {
			uri = elements.uri:GetValue(),
			scale = Vector(elements.scale[1]:GetValue(), elements.scale[2]:GetValue(), elements.scale[3]:GetValue()),
			phys = Vector(elements.phys[1]:GetValue(), elements.phys[2]:GetValue(), elements.phys[3]:GetValue()),
			textures = self:SanitizeTextures(texts)
		}
		
		self:AddHistory(data)
		self:UILoadData(data)
	end
end
-- UI --
--------