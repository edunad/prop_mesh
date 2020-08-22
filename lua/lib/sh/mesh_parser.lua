local table_remove = table.remove
local table_insert = table.insert
local table_count = table.Count
local table_keys = table.GetKeys

PropMLIB = PropMLIB or {}
PropMLIB.MeshParser = PropMLIB.MeshParser or {}
PropMLIB.MeshParser.CurThread = nil
PropMLIB.MeshParser.Threads = {}
	
PropMLIB.MeshParser.ClearMeshes = function (imeshes)
	if not imeshes or #imeshes <= 0 then return end
	for _, v in pairs(imeshes) do
		if not v or v == NULL or not pcall( v.Draw, v ) then continue end
		v:Destroy()
	end
end

PropMLIB.MeshParser.Register = function(ent, tblData)
	if not IsValid(ent) then return end
	local indx = ent:EntIndex()
	
	PropMLIB.MeshParser.CancelThread(indx) -- Cancel previous thread
	PropMLIB.MeshParser.Threads[indx] = tblData
end

PropMLIB.MeshParser.CancelThread = function(indx)
	if not PropMLIB.MeshParser.Threads[indx] then return end
	if PropMLIB.MeshParser.CurThread ~= PropMLIB.MeshParser.Threads[indx] then return end
	
	PropMLIB.MeshParser.CurThread = nil
end

PropMLIB.MeshParser.UnRegister = function(ent)
	if not IsValid(ent) then return end
	local indx = ent:EntIndex()

	PropMLIB.MeshParser.CancelThread(indx)
	PropMLIB.MeshParser.Remove(indx)
end

PropMLIB.MeshParser.QueueDone = function ()
	PropMLIB.MeshParser.CurThread = nil
end

PropMLIB.MeshParser.Remove = function(index)
	local data = PropMLIB.MeshParser.Threads[index]
	PropMLIB.MeshParser.Threads[index] = nil
	return data
end


PropMLIB.MeshParser.QueueThink = function ()
	if not PropMLIB.MeshParser.CurThread then
		local tblKey = table_keys(PropMLIB.MeshParser.Threads)[1]
		
		PropMLIB.MeshParser.CurThread = PropMLIB.MeshParser.Remove(tblKey)
		PropMLIB.MeshParser.CurThread.onInitialize(function()
			PropMLIB.MeshParser.CurThread.__INIT__ = true
		end)
	else
		local currThread = PropMLIB.MeshParser.CurThread
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

hook.Add("Think", "__loadmodel_prop_mesh__", function()
	if table_count(PropMLIB.MeshParser.Threads) <= 0 and not PropMLIB.MeshParser.CurThread then return end
	PropMLIB.MeshParser.QueueThink()
end)