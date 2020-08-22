if SERVER then return error("[PropMLIB]Tried to load 'URLTexture.lua' on SERVER") end

local table_insert = table.insert
local table_removeByValue = table.RemoveByValue
local table_remove = table.remove
local table_count = table.Count

local string_trim = string.Trim
local string_find = string.find
local string_split = string.Split

PropMLIB = PropMLIB or {}
PropMLIB.URLMaterial = PropMLIB.URLMaterial or {}

PropMLIB.URLMaterial.MAX_TIMEOUT = CreateClientConVar("prop_mesh_urltexture_timeout", 30, true, false, "How many seconds before timing out (Default: 30)")
PropMLIB.URLMaterial.RequestedTextures = PropMLIB.URLMaterial.RequestedTextures or {}
PropMLIB.URLMaterial.Materials = PropMLIB.URLMaterial.Materials or {}
PropMLIB.URLMaterial.Panels = PropMLIB.URLMaterial.Panels or {}
PropMLIB.URLMaterial.Queue = {}

PropMLIB.URLMaterial.Clear = function()
	PropMLIB.URLMaterial.Materials = {}
	print("[PropMLIB] Cleared all loaded materials")
end

PropMLIB.URLMaterial.ReloadTextures = function()
	PropMLIB.URLMaterial.Clear() -- Clear all materials first
	
	for uri, _ in pairs(PropMLIB.URLMaterial.RequestedTextures) do
		print("[PropMLIB] Reloading texture ".. uri)
		PropMLIB.URLMaterial.LoadMaterialURL(uri)
	end
	
	print("[PropMLIB] Reloaded " .. tostring(table_count(PropMLIB.URLMaterial.RequestedTextures)) .. " textures!")
end

PropMLIB.URLMaterial.LoadMaterialURL = function(uri, success, failure)
	if uri == "" then return end
	
	if PropMLIB.URLMaterial.Materials[uri] then
		if success then success(PropMLIB.URLMaterial.Materials[uri]) end
		return
	end
	
	local imgURL = uri:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
	local PANEL = vgui.Create("DHTML")
	local onFail = function(msg)
		if PANEL then PANEL:Remove() end
		PropMLIB.URLMaterial.RequestedTextures[uri] = nil
		
		print("[PropMLIB] Texture failed: " .. imgURL .. " -> " .. msg)
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
				
				table_removeByValue(PropMLIB.URLMaterial.Panels, PANEL)
				table_insert(PropMLIB.URLMaterial.Queue, {
					panel = PANEL,
					uri = uri,
					cooldown = CurTime() + PropMLIB.URLMaterial.MAX_TIMEOUT:GetInt(),
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
	
	PropMLIB.URLMaterial.RequestedTextures[uri] = true -- Used on texture reload
	table_insert(PropMLIB.URLMaterial.Panels, PANEL)
end

PropMLIB.URLMaterial.ClearPanels = function()
	local panels = PropMLIB.URLMaterial.Panels
	if not panels or #panels <= 0 then return end
	
	for _, v in pairs(panels) do 
		if not IsValid(v) then continue end
		v:Remove()
	end
	
	PropMLIB.URLMaterial.Panels = {}
end

PropMLIB.URLMaterial.CreateMaterial = function(name, baseTexture)
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

hook.Add("Think", "__loadtexture_prop_mesh__", function()
	if #PropMLIB.URLMaterial.Queue <= 0 then return end
	
	for k, v in pairs( PropMLIB.URLMaterial.Queue ) do
		if not IsValid(v.panel) then continue end
		
		if v.panel:GetHTMLMaterial() and not v.panel:IsLoading() then
			local material = v.panel:GetHTMLMaterial()
			local matName = material:GetName()
			
			local Mat = PropMLIB.URLMaterial.CreateMaterial(matName .. CurTime(), matName)
			if not Mat then
				if v.failure then v.failure() end
				return
			end
			
			PropMLIB.URLMaterial.Materials[v.uri] = Mat
			v.panel:Remove()
			
			if v.success then v.success(Mat) end
			
			table_remove( PropMLIB.URLMaterial.Queue, k )
			table_removeByValue(PropMLIB.URLMaterial.Panels, v.panel)
		elseif CurTime() > v.cooldown then
			if v.failure then v.failure() end
			 
			table_remove( PropMLIB.URLMaterial.Queue, k )
			table_removeByValue(PropMLIB.URLMaterial.Panels, v.panel)
		end
	end
end)

concommand.Add( "prop_mesh_urltexture_reload", function()
	PropMLIB.URLMaterial.ReloadTextures()
end, nil, "Reloads all url textures")

concommand.Add( "prop_mesh_urltexture_clear", function()
	PropMLIB.URLMaterial.Clear()
end, nil, "Clear url texture cache")

PropMLIB.URLMaterial.ClearPanels()