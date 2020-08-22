if SERVER then return error("[PropMLIB]Tried to load 'PVSCache.lua' on SERVER") end

PropMLIB = PropMLIB or {}
PropMLIB.PVSCache = PropMLIB.PVSCache or {}
PropMLIB.PVSCache.Cache = {}
PropMLIB.PVSCache.Message_Delay_Mult = 0.2

PropMLIB.PVSCache.ResolveNetCache = function(ent)
	local id = ent:EntIndex()
	if not PropMLIB.PVSCache.Cache[id] then return end
	
	local t = 0
	for k, v in pairs(PropMLIB.PVSCache.Cache[id]) do
		if not v then continue end
		
		timer.Simple(PropMLIB.PVSCache.Message_Delay_Mult * t, function() 
			if not IsValid(ent) then return end
			v(ent)
		end)
		
		t = t + 1
	end
	
	PropMLIB.PVSCache.Remove(id) -- Clear all messages
end

PropMLIB.PVSCache.Remove = function(id)
	PropMLIB.PVSCache.Cache[id] = {}
end

PropMLIB.PVSCache.CacheNetMessage = function(id, key, onPVS)
	if not PropMLIB.PVSCache.Cache[id] then
		PropMLIB.PVSCache.Cache[id] = {}	
	end
	
	PropMLIB.PVSCache.Cache[id][key] = onPVS -- Cache latest message
end


hook.Add("NetworkEntityCreated", "__loadmodel_prop_mesh__", function(ent)
	if not IsValid(ent) or not IsValid(LocalPlayer()) then return end
	if ent:GetClass() ~= "prop_mesh" then
		PropMLIB.PVSCache.Remove(ent:EntIndex())
		return 
	end
	
	if ent.OnPVSReload then ent:OnPVSReload()end
	PropMLIB.PVSCache.ResolveNetCache(ent) 
end)