if CLIENT then return error("[PropMLIB]Tried to load 'registry.lua' on CLIENT") end

local table_insert = table.insert
local table_remove = table.remove
local table_removeByValue = table.RemoveByValue

PropMLIB = PropMLIB or {}
PropMLIB.Registry = PropMLIB.Registry or {}
PropMLIB.Registry.PMESH = PropMLIB.Registry.PMESH or {}

PropMLIB.Registry.RegisterPMesh = function(ent)
	table_insert(PropMLIB.Registry.PMESH, ent)
end

PropMLIB.Registry.UnRegisterPMesh = function(ent)
	table_removeByValue(PropMLIB.Registry.PMESH, ent)
end

PropMLIB.Registry.Init = function()
	if not PropMLIB.Registry.PMESH or #PropMLIB.Registry.PMESH <= 0 then return end
	for k, v in pairs(PropMLIB.Registry.PMESH) do
		if IsValid(v) then continue end
		table_remove(PropMLIB.Registry.PMESH, k)
	end
end

PropMLIB.Registry.NewPlayer = function(newPly)
	for k, v in pairs(PropMLIB.Registry.PMESH) do
		if not IsValid(v) then continue end
		v:OnNewPlayerJoin(newPly)
	end
end

hook.Add("PlayerInitialSpawn", "__playerspawn_prop_mesh__", function(newPly)
	timer.Simple(10, function()
		PropMLIB.Registry.NewPlayer(newPly)
	end)
end)

PropMLIB.Registry.Init()