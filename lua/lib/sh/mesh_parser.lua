local table_remove = table.remove
local table_insert = table.insert
local table_count = table.Count
local table_keys = table.GetKeys

QUBELib = QUBELib or {}
QUBELib.MeshParser = QUBELib.MeshParser or {}
QUBELib.MeshParser.CurThread = nil
QUBELib.MeshParser.Threads = {}
	
QUBELib.MeshParser.ClearMeshes = function (imeshes)
	if not imeshes or #imeshes <= 0 then return end
	for _, v in pairs(imeshes) do
		if not v or not v:IsValid() then continue end
		v:Destroy()
	end
end

QUBELib.MeshParser.Register = function(ent, tblData)
	if not IsValid(ent) then return end
	local indx = ent:EntIndex()
	
	QUBELib.MeshParser.CancelThread(indx) -- Cancel previous thread
	QUBELib.MeshParser.Threads[indx] = tblData
end

QUBELib.MeshParser.CancelThread = function(indx)
	if not QUBELib.MeshParser.Threads[indx] then return end
	if QUBELib.MeshParser.CurThread ~= QUBELib.MeshParser.Threads[indx] then return end
	
	QUBELib.MeshParser.CurThread = nil
end

QUBELib.MeshParser.UnRegister = function(ent)
	if not IsValid(ent) then return end
	local indx = ent:EntIndex()

	QUBELib.MeshParser.CancelThread(indx)
	QUBELib.MeshParser.Remove(indx)
end

QUBELib.MeshParser.QueueDone = function ()
	QUBELib.MeshParser.CurThread = nil
end

QUBELib.MeshParser.Remove = function(index)
	local data = QUBELib.MeshParser.Threads[index]
	QUBELib.MeshParser.Threads[index] = nil
	return data
end


QUBELib.MeshParser.QueueThink = function ()
	if not QUBELib.MeshParser.CurThread then
		local tblKey = table_keys(QUBELib.MeshParser.Threads)[1]
		
		QUBELib.MeshParser.CurThread = QUBELib.MeshParser.Remove(tblKey)
		QUBELib.MeshParser.CurThread.onInitialize(function()
			QUBELib.MeshParser.CurThread.__INIT__ = true
		end)
	else
		local currThread = QUBELib.MeshParser.CurThread
		if not currThread or not currThread.__INIT__ then
			return
		end
		
		-- START RENDERING
		local PARSING_THERSOLD = 0.005
		local t0 = SysTime ()
		local finished, statusMessage
		
		-- COROUTINE
		while SysTime () - t0 < PARSING_THERSOLD do
			if not currThread then break end
			success, finished, statusMessage, meshData = coroutine.resume(currThread.co)
			
			if statusMessage then currThread.onStatusUpdate(statusMessage)end
			if (not success or finished) then break end
		end
		
		--- CHECK
		if currThread then
			if not success then
				currThread.onFailed()
				return
			end
			
			if finished then
				currThread.onComplete(meshData)
				return
			end
		end
	end
end

hook.Add("Think", "__loadmodel_qube_mesh__", function()
	if table_count(QUBELib.MeshParser.Threads) <= 0 and not QUBELib.MeshParser.CurThread then return end
	QUBELib.MeshParser.QueueThink()
end)