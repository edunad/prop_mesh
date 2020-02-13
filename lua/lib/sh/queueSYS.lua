local table_insert = table.insert
local table_remove = table.remove

QUBELib = QUBELib or {}
QUBELib.QueueSYS = QUBELib.QueueSYS or {}
QUBELib.QueueSYS.Queue = {}
QUBELib.QueueSYS.IsParsing = false
QUBELib.QueueSYS.ParseTime = 0.25

QUBELib.QueueSYS.Register = function(queueItem)
	table_insert(QUBELib.QueueSYS.Queue, queueItem)
	
	if not QUBELib.QueueSYS.IsParsing then
		QUBELib.QueueSYS.IsParsing = true
		QUBELib.QueueSYS.QueueThink()
	end
end

QUBELib.QueueSYS.QueueThink = function(queueItem)
	if #QUBELib.QueueSYS.Queue <= 0 then
		QUBELib.QueueSYS.IsParsing = false
		return
	end
	
	local callbackData = table_remove(QUBELib.QueueSYS.Queue, 1)
	callbackData.callback()
	
	timer.Simple(QUBELib.QueueSYS.ParseTime, function()
		QUBELib.QueueSYS.QueueThink()	
	end)
end