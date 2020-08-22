if SERVER then return error("[PropMLIB]Tried to load 'thumbnail.lua' on SERVER") end

PropMLIB = PropMLIB or {}
PropMLIB.Thumbnail = PropMLIB.Thumbnail or {}
PropMLIB.Thumbnail.ThumbnailsCache = {}
PropMLIB.Thumbnail.TakingScreenshot = false
PropMLIB.Thumbnail.RTTexture = GetRenderTarget( "prop_mesh_rttexture_", ScrW(), ScrH(), true )

PropMLIB.Thumbnail.Clear = function()
	PropMLIB.Thumbnail.ThumbnailsCache = {}
end

PropMLIB.Thumbnail.TakeThumbnail = function(data)
	if not data or not data.uri then return end
	-- if PropMLIB.Thumbnail.HasThumbnail(data.uri) then return end TODO: Figure out if textures changed / model?
	
	PropMLIB.Thumbnail.TakingScreenshot = true
	PropMLIB.Thumbnail.ScreenshotDrawHook(data)
end

PropMLIB.Thumbnail.SaveThumbnail = function(name, data)
	local fileName = util.CRC(name) .. ".jpg"
	local path = "prop_mesh/thumbnails/" .. fileName
	
	local f = file.Open(path, "wb", "DATA" )
	if not f then return print("[PropMLIB] Failed to save mesh thumbnail") end
	
	f:Write( data )
	f:Close()
	
	PropMLIB.Thumbnail.ThumbnailsCache[path] = nil
end

PropMLIB.Thumbnail.Initialize = function()
	local files, directories = file.Find("prop_mesh/thumbnails/*.jpg", "DATA")
	
	PropMLIB.Thumbnail.ThumbnailsCache = {}
	for _, v in pairs(files) do
		PropMLIB.Thumbnail.ThumbnailsCache["prop_mesh/thumbnails/" .. v] = true
	end
end

PropMLIB.Thumbnail.HasThumbnail = function(name)
	local fileName = util.CRC(name) .. ".jpg"
	return PropMLIB.Thumbnail.ThumbnailsCache[fileName]
end

PropMLIB.Thumbnail.DeleteThumbnail = function(name)
	local fileName = util.CRC(name) .. ".jpg"
	local path = "prop_mesh/thumbnails/" .. fileName
	if not file.Exists(path, "DATA" ) then return end
	
	file.Delete(path)
	PropMLIB.Thumbnail.ThumbnailsCache[path] = nil
end

PropMLIB.Thumbnail.RemoveHook = function()
	hook.Remove("PostDrawViewModel", "__prop_mesh_screenshot__")
end

PropMLIB.Thumbnail.ClearHook = function()
	PropMLIB.Thumbnail.TakingScreenshot = false
	PropMLIB.Thumbnail.RemoveHook()
end

PropMLIB.Thumbnail.ScreenshotDrawHook = function(data)
	hook.Add("PostDrawViewModel", "__prop_mesh_screenshot__", function()
		if not PropMLIB.Thumbnail.TakingScreenshot then return PropMLIB.Thumbnail.ClearHook() end
		if not data or not IsValid(data.ent) then return PropMLIB.Thumbnail.ClearHook() end
		
		local thumbnailData = nil
		render.PushRenderTarget( PropMLIB.Thumbnail.RTTexture )
			cam.Start3D( data.origin, data.angles, data.fov )
				render.Clear( 35, 35, 35, 255, true )
				
				render.SuppressEngineLighting( true )
					data.ent:DrawTranslucent()
				render.SuppressEngineLighting( false )
				
				local startX = (ScrW() - 1024) / 2
				local endX = 1024
				if startX <= 0 then
					endX = ScrW()
					startX = 0
				end
				
				
				local startY = (ScrH() - 1024) / 2
				local endY = 1024
				if startY <= 0 then
					endY = ScrH()
					startY = 0
				end
				
				thumbnailData = render.Capture({ 
					format = "jpeg", 
					quality = 70, 
					x = startX,
					y = startY,
					h = endY, 
					w = endX 
				})
			cam.End3D()
		render.PopRenderTarget()
		
		if thumbnailData then
			PropMLIB.Thumbnail.SaveThumbnail(data.uri, thumbnailData)
		end
		
		PropMLIB.Thumbnail.ClearHook()
	end)
end

PropMLIB.Thumbnail.Initialize()

concommand.Add( "prop_mesh_thumbnail_clear", function()
	PropMLIB.Thumbnail.Clear()
end, nil, "Clears thumbnail cache")
