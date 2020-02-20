if SERVER then return error("[QUBELib]Tried to load 'queue_sys.lua' on SERVER") end

local table_insert = table.insert
local table_remove = table.remove

QUBELib = QUBELib or {}
QUBELib.QueueSYS = QUBELib.QueueSYS or {}
QUBELib.QueueSYS.Queue = {}
QUBELib.QueueSYS.ParseTime = CreateClientConVar("qube_queue_interval", 0.35, true, false, "How many seconds between qube mesh rendering (LOW VALUE = More chances of crashing) (Default: 0.35)", 0.35, 1)

QUBELib.QueueSYS.Register = function(queueItem)
	table_insert(QUBELib.QueueSYS.Queue, queueItem)
end

QUBELib.QueueSYS.Initialize = function()
	timer.Remove("__qube_mesh_queuesys__")
	timer.Create("__qube_mesh_queuesys__", QUBELib.QueueSYS.ParseTime:GetFloat(), 0, function()
		if #QUBELib.QueueSYS.Queue <= 0 then return end
		
		local callbackData = table_remove(QUBELib.QueueSYS.Queue, 1)
		callbackData.callback()
	end)
end

cvars.AddChangeCallback("qube_queue_interval", function()
	print("[QUBELib] 'qube_queue_interval' value changed, restarting queue")
	QUBELib.QueueSYS.Initialize()
end, "__qube_mesh_queuesys__" )