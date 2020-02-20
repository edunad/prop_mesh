if SERVER then return error("[QUBELib]Tried to load 'thumbnail.lua' on SERVER") end

QUBELib = QUBELib or {}
QUBELib.Thumbnail = QUBELib.Thumbnail or {}
QUBELib.Thumbnail.ThumbnailsCache = {}
QUBELib.Thumbnail.TakingScreenshot = false
QUBELib.Thumbnail.RTTexture = GetRenderTarget( "qube_mesh_rttexture_", ScrW(), ScrH(), true )

QUBELib.Thumbnail.Clear = function()
	QUBELib.Thumbnail.ThumbnailsCache = {}
end

QUBELib.Thumbnail.TakeThumbnail = function(data)
	if not data or not data.uri then return end
	-- if QUBELib.Thumbnail.HasThumbnail(data.uri) then return end TODO: Figure out if textures changed / model?
	
	QUBELib.Thumbnail.TakingScreenshot = true
	QUBELib.Thumbnail.ScreenshotDrawHook(data)
end

QUBELib.Thumbnail.SaveThumbnail = function(name, data)
	local fileName = util.CRC(name) .. ".jpg"
	local path = "qube_mesh/thumbnails/" .. fileName
	
	local f = file.Open(path, "wb", "DATA" )
	if not f then return print("[QUBELib] Failed to save mesh thumbnail") end
	
	f:Write( data )
	f:Close()
	
	QUBELib.Thumbnail.ThumbnailsCache[path] = nil
end

QUBELib.Thumbnail.Initialize = function()
	local files, directories = file.Find("qube_mesh/thumbnails/*.jpg", "DATA")
	
	QUBELib.Thumbnail.ThumbnailsCache = {}
	for _, v in pairs(files) do
		QUBELib.Thumbnail.ThumbnailsCache["qube_mesh/thumbnails/" .. v] = true
	end
end

QUBELib.Thumbnail.HasThumbnail = function(name)
	local fileName = util.CRC(name) .. ".jpg"
	return QUBELib.Thumbnail.ThumbnailsCache[fileName]
end

QUBELib.Thumbnail.DeleteThumbnail = function(name)
	local fileName = util.CRC(name) .. ".jpg"
	local path = "qube_mesh/thumbnails/" .. fileName
	if not file.Exists(path, "DATA" ) then return end
	
	file.Delete(path)
	QUBELib.Thumbnail.ThumbnailsCache[path] = nil
end

QUBELib.Thumbnail.RemoveHook = function()
	hook.Remove("PostDrawViewModel", "__qube_mesh_screenshot__")
end

QUBELib.Thumbnail.ScreenshotDrawHook = function(data)
	hook.Add("PostDrawViewModel", "__qube_mesh_screenshot__", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not QUBELib.Thumbnail.TakingScreenshot then return end
		
		local thumbnailData = nil
		render.PushRenderTarget( QUBELib.Thumbnail.RTTexture )
			cam.Start3D( data.origin, data.angles, data.fov )
				render.Clear( 35, 35, 35, 255, true )
				
				render.SuppressEngineLighting( true )
					data.ent:Draw()
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
			QUBELib.Thumbnail.SaveThumbnail(data.uri, thumbnailData)
		end
		
		QUBELib.Thumbnail.TakingScreenshot = false
		QUBELib.Thumbnail.RemoveHook()
	end)
end

QUBELib.Thumbnail.Initialize()

concommand.Add( "qube_thumbnail_clear", function()
	QUBELib.Thumbnail.Clear()
end, nil, "Clears thumbnail cache")
