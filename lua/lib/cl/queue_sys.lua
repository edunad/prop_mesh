if SERVER then return error("[PropMLIB]Tried to load 'queue_sys.lua' on SERVER") end

local table_insert = table.insert
local table_remove = table.remove

PropMLIB = PropMLIB or {}
PropMLIB.QueueSYS = PropMLIB.QueueSYS or {}
PropMLIB.QueueSYS.Queue = {}
PropMLIB.QueueSYS.ParseTime = CreateClientConVar("prop_mesh_queue_interval", 0.5, true, false, "How many seconds between prop_mesh mesh rendering (LOW VALUE = More chances of crashing) (Default: 0.5)", 0.30, 1)

PropMLIB.QueueSYS.Register = function(queueItem)
	table_insert(PropMLIB.QueueSYS.Queue, queueItem)
end

PropMLIB.QueueSYS.Initialize = function()
	timer.Remove("__prop_mesh_queuesys__")
	timer.Create("__prop_mesh_queuesys__", PropMLIB.QueueSYS.ParseTime:GetFloat(), 0, function()
		if #PropMLIB.QueueSYS.Queue <= 0 then return end

		local callbackData = table_remove(PropMLIB.QueueSYS.Queue, 1)
		callbackData.callback()
	end)
end

cvars.RemoveChangeCallback("prop_mesh_queue_interval", "__prop_mesh_queuesys__" )
cvars.AddChangeCallback("prop_mesh_queue_interval", function()
	print("[PropMLIB] 'prop_mesh_queue_interval' value changed, restarting queue")
	PropMLIB.QueueSYS.Initialize()
end, "__prop_mesh_queuesys__" )

-- Start queue --
PropMLIB.QueueSYS.Initialize()