local table_remove = table.remove

QUBELib = QUBELib or {}
QUBELib.MeshParser = QUBELib.MeshParser or {}
QUBELib.MeshParser.CurThread = nil
QUBELib.MeshParser.Threads = {}
	
QUBELib.MeshParser.ClearMeshes = function (imeshes)
	if not imeshes or #imeshes <= 0 then return end
	for _, v in pairs(imeshes) do
		if not v or v == NULL then continue end
		v:Destroy()
	end
end

QUBELib.MeshParser.Register = function (tblData)
	table_insert(QUBELib.MeshParser.Threads, tblData)
end

QUBELib.MeshParser.QueueDone = function ()
	QUBELib.MeshParser.CurThread = nil
end

QUBELib.MeshParser.QueueThink = function ()
	if not QUBELib.MeshParser.CurThread then
		QUBELib.MeshParser.CurThread = table_remove(QUBELib.MeshParser.Threads, 1)
		
		QUBELib.MeshParser.CurThread.onInitialize(function()
			QUBELib.MeshParser.CurThread.__INIT__ = true
		end)
	else
		if not QUBELib.MeshParser.CurThread.__INIT__ then
			return
		end
		
		-- START RENDERING
		local PARSING_THERSOLD = 0.005
		local t0 = SysTime ()
		local finished, statusMessage
		
		-- COROUTINE
		while SysTime () - t0 < PARSING_THERSOLD do
			success, finished, statusMessage, meshData = coroutine.resume(QUBELib.MeshParser.CurThread.co)
			QUBELib.MeshParser.CurThread.onStatusUpdate(statusMessage)
					
			if (not success or finished) then break end
		end
		
		--- CHECK
		if not success then
			QUBELib.MeshParser.CurThread.onFailed("!! Failed to parse !!")
			return
		end
		
		if finished then
			QUBELib.MeshParser.CurThread.onComplete(meshData)
			return
		end
	end
end

hook.Add("Think", "__loadmodel_qube_mesh__", function()
	if #QUBELib.MeshParser.Threads <= 0 and not QUBELib.MeshParser.CurThread then return end
	QUBELib.MeshParser.QueueThink()
end)