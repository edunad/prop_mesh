if SERVER then return error("[QUBELib]Tried to load 'URLTexture.lua' on SERVER") end

local table_insert = table.insert
local table_removeByValue = table.RemoveByValue
local table_remove = table.remove
local table_count = table.Count

QUBELib = QUBELib or {}
QUBELib.URLMaterial = QUBELib.URLMaterial or {}

QUBELib.URLMaterial.USE_PROXY = CreateClientConVar("qube_urltexture_proxy", 1, true, false, "Use proxy to load textures? (Protects IP) (Default: 1)")
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
	
	for uri, ent in pairs(QUBELib.URLMaterial.RequestedTextures) do
		if not IsValid(ent) then
			print("[QUBELib] Removed unused texture " .. uri)
			table_removeByValue(QUBELib.URLMaterial.RequestedTextures, uri)
			continue
		end
		
		QUBELib.URLMaterial.LoadMaterialURL(ent, uri)
	end
	
	print("[QUBELib] Reloaded " .. tostring(table_count(QUBELib.URLMaterial.RequestedTextures)) .. " textures!")
end

QUBELib.URLMaterial.LoadMaterialURL = function(ent, uri, success, failure)
	if uri == "" then return end
	
	if QUBELib.URLMaterial.Materials[uri] then 
		if success then success(QUBELib.URLMaterial.Materials[uri]) end
		return
	end
	
	local PANEL = vgui.Create("DHTML")
	PANEL:SetAlpha( 0 )
	PANEL:SetMouseInputEnabled( false )
	PANEL:NewObjectCallback("imageLoader", "finished")
	PANEL:NewObjectCallback("imageLoader", "error")
	PANEL:SetPos(0, 0)
	
	PANEL.OnCallback = function(_, objectName, methodName, args)
		if objectName ~= "imageLoader" then return end
		
		if methodName == "finished" then
			if #args <= 0 then return end
			if not IsValid(PANEL) then return end
			
			local width  = tonumber(args[1]) or 0
			local height = tonumber(args[2]) or 0
				
			if width <= 0 or height <= 0 then return end
			PANEL:SetSize(width, height)
			
			timer.Simple(0.5, function()
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
		elseif methodName == "error" then
			if #args < 0 then return end
			PANEL:Remove()
			
			if failure then failure() end
			return
		end
	end
	
	local imgURL = uri:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
	if QUBELib.URLMaterial.USE_PROXY:GetBool() then
		imgURL = "https://images.weserv.nl/?url=" .. imgURL
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
				<script type="text/javascript">
					function imageError() {
						imageLoader.error("Image not found!");
					};
					
					window.onerror = function(message, file, lineNumber) {
						imageLoader.error(message);
					};
					
					function imageLoaded() {
						let image = document.getElementById("image");
						
						if(image.width > 2816 && image.height > 1704) {
							imageLoader.error("Image too big! ( Max : 2816x1704 )");
						} else {
							imageLoader.finished(image.width, image.height);
						}
					};
				</script>
			
				<img id="image" src="]].. imgURL ..[[" onerror="imageError()" onload="imageLoaded()" onabort="imageError()" />
			</body>
		</html>
	]])
	
	QUBELib.URLMaterial.RequestedTextures[uri] = ent -- Used on texture reload
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
		
		["$alpha"] = "1",
		["$alphatest"] = "1",
		["$alphatestreference"] = ".5",
		["$allowalphatocoverage"] = "1",
		
		["$model"] = "1",
		["$nocull"] = "1",
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