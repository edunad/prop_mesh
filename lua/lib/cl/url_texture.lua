if SERVER then return error("[QUBELib]Tried to load 'URLTexture.lua' on SERVER") end

local table_insert = table.insert
local table_removeByValue = table.RemoveByValue
local table_remove = table.remove
local table_count = table.Count

local string_trim = string.Trim
local string_find = string.find
local string_split = string.Split

QUBELib = QUBELib or {}
QUBELib.URLMaterial = QUBELib.URLMaterial or {}

QUBELib.URLMaterial.MAX_TIMEOUT = CreateClientConVar("qube_urltexture_timeout", 30, true, false, "How many seconds before timing out (Default: 30)")
QUBELib.URLMaterial.RequestedTextures = QUBELib.URLMaterial.RequestedTextures or {}
QUBELib.URLMaterial.Materials = QUBELib.URLMaterial.Materials or {}
QUBELib.URLMaterial.Panels = QUBELib.URLMaterial.Panels or {}
QUBELib.URLMaterial.Queue = {}

QUBELib.URLMaterial.Clear = function()
	QUBELib.URLMaterial.Materials = {}
	print("[QUBELib] Cleared all loaded materials")
end

QUBELib.URLMaterial.ReloadTextures = function()
	QUBELib.URLMaterial.Clear() -- Clear all materials first
	
	for uri, _ in pairs(QUBELib.URLMaterial.RequestedTextures) do
		print("[QUBELib] Reloading texture ".. uri)
		QUBELib.URLMaterial.LoadMaterialURL(uri)
	end
	
	print("[QUBELib] Reloaded " .. tostring(table_count(QUBELib.URLMaterial.RequestedTextures)) .. " textures!")
end

QUBELib.URLMaterial.LoadMaterialURL = function(uri, success, failure)
	if uri == "" then return end
	
	if QUBELib.URLMaterial.Materials[uri] then
		if success then success(QUBELib.URLMaterial.Materials[uri]) end
		return
	end
	
	local imgURL = uri:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
	local PANEL = vgui.Create("DHTML")
	local onFail = function(msg)
		if PANEL then PANEL:Remove() end
		QUBELib.URLMaterial.RequestedTextures[uri] = nil
		
		print("[QUBELib] Texture failed: " .. imgURL .. " -> " .. msg)
		if failure then failure() end
	end
	
	PANEL:SetAlpha( 0 )
	PANEL:SetMouseInputEnabled( false )
	PANEL:SetPos(0, 0)
	
	PANEL.ConsoleMessage = function(panel, data)
		if not data or string_trim(data) == "" then return end
		if string_find(data, "DATA:") then
			data = data:gsub("DATA:","")
			
			local args = string_split(data, ",")
			if not args or #args <= 0 then
				return onFail("Invalid texture")
			end
			
			local width  = tonumber(args[1]) or 0
			local height = tonumber(args[2]) or 0
			
			if width <= 0 or height <= 0 then return onFail("Invalid texture") end
			PANEL:SetSize(width, height)
			
			timer.Simple(1, function()
				PANEL:UpdateHTMLTexture()
				
				table_removeByValue(QUBELib.URLMaterial.Panels, PANEL)
				table_insert(QUBELib.URLMaterial.Queue, {
					panel = PANEL,
					uri = uri,
					cooldown = CurTime() + QUBELib.URLMaterial.MAX_TIMEOUT:GetInt(),
					success = success,
					failure = failure
				})
			end)
		else
			return onFail(data)
		end
	end
	

	PANEL:SetHTML([[
		<html>
			<head>
				<style type="text/css">
					html {
						overflow: hidden;
					}
					
					body {
						margin: 0px 0px;
						padding: 0px 0px;
					}
					
					#image {
						width: 100%;
						height: 100%;
					}
				</style>
			</head>
			<body>
				<script>
					function onImageLoad() {
						var image = document.getElementById("image");
						if(image.width > 2816 && image.height > 1704) {
							console.log("Image too big! ( Max : 2816x1704 )");
						} else {
							console.log("DATA:" + image.width + "," + image.height);
						}
					};
				</script>
				<img id='image' onAbort='console.log('Failed to load Image');' onError='console.log('Failed to load Image');' onLoad='onImageLoad();' src="]].. imgURL ..[["/>
			</body>
		</html>
	]])
	
	QUBELib.URLMaterial.RequestedTextures[uri] = true -- Used on texture reload
	table_insert(QUBELib.URLMaterial.Panels, PANEL)
end

QUBELib.URLMaterial.ClearPanels = function()
	local panels = QUBELib.URLMaterial.Panels
	if not panels or #panels <= 0 then return end
	
	for _, v in pairs(panels) do 
		if not IsValid(v) then continue end
		v:Remove()
	end
	
	QUBELib.URLMaterial.Panels = {}
end

QUBELib.URLMaterial.CreateMaterial = function(name, baseTexture)
	return CreateMaterial(name, "VertexLitGeneric", {
		["$basetexture"] = baseTexture,
		
		["$alphatest"] = "1",
		["$allowalphatocoverage"] = "1",
		
		["$distancealpha"] = "1",
		
		["$vertexcolor"] = "1",
		
		["$model"] = "1",
		["$nocull"] = "1",
		["$nomip"] = "1",
        ["$nolod"] = "1",
        ["$nocompress"] = "1",
	})
end

hook.Add("Think", "__loadtexture_qube_mesh__", function()
	if #QUBELib.URLMaterial.Queue <= 0 then return end
	
	for k, v in pairs( QUBELib.URLMaterial.Queue ) do
		if not IsValid(v.panel) then continue end
		
		if v.panel:GetHTMLMaterial() and not v.panel:IsLoading() then
			local material = v.panel:GetHTMLMaterial()
			local matName = material:GetName()
			
			local Mat = QUBELib.URLMaterial.CreateMaterial(matName .. CurTime(), matName)
			if not Mat then
				if v.failure then v.failure() end
				return
			end
			
			QUBELib.URLMaterial.Materials[v.uri] = Mat
			v.panel:Remove()
			
			if v.success then v.success(Mat) end
			
			table_remove( QUBELib.URLMaterial.Queue, k )
			table_removeByValue(QUBELib.URLMaterial.Panels, v.panel)
		elseif CurTime() > v.cooldown then
			if v.failure then v.failure() end
			 
			table_remove( QUBELib.URLMaterial.Queue, k )
			table_removeByValue(QUBELib.URLMaterial.Panels, v.panel)
		end
	end
end)

concommand.Add( "qube_urltexture_reload", function()
	QUBELib.URLMaterial.ReloadTextures()
end, nil, "Reloads all url textures")

concommand.Add( "qube_urltexture_clear", function()
	QUBELib.URLMaterial.Clear()
end, nil, "Clear url texture cache")

QUBELib.URLMaterial.ClearPanels()