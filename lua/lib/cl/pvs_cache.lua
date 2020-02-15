if SERVER then return error("[QUBELib]Tried to load 'PVSCache.lua' on SERVER") end

QUBELib = QUBELib or {}
QUBELib.PVSCache = QUBELib.PVSCache or {}
QUBELib.PVSCache.Cache = {}
QUBELib.PVSCache.Message_Delay_Mult = 0.2

QUBELib.PVSCache.ResolveNetCache = function(ent)
	local id = ent:EntIndex()
	if not QUBELib.PVSCache.Cache[id] then return end
	
	local t = 0
	for k, v in pairs(QUBELib.PVSCache.Cache[id]) do
		if not v then continue end
		
		timer.Simple(QUBELib.PVSCache.Message_Delay_Mult * t, function() 
			if not IsValid(ent) then return end
			v(ent)
		end)
		
		t = t + 1
	end
	
	QUBELib.PVSCache.Remove(id) -- Clear all messages
end

QUBELib.PVSCache.Remove = function(id)
	QUBELib.PVSCache.Cache[id] = {}
end

QUBELib.PVSCache.CacheNetMessage = function(id, key, onPVS)
	if not QUBELib.PVSCache.Cache[id] then
		QUBELib.PVSCache.Cache[id] = {}	
	end
	
	QUBELib.PVSCache.Cache[id][key] = onPVS -- Cache latest message
end


hook.Add("NetworkEntityCreated", "__loadmodel_qube_mesh__", function(ent)
	if not IsValid(ent) or not IsValid(LocalPlayer()) then return end
	if ent:GetClass() ~= "qube_mesh" then
		QUBELib.PVSCache.Remove(ent:EntIndex())
		return 
	end
	
	if ent.OnPVSReload then ent:OnPVSReload()end
	QUBELib.PVSCache.ResolveNetCache(ent) 
end)