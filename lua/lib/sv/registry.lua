if CLIENT then return error("[QUBELib]Tried to load 'registry.lua' on CLIENT") end

local table_insert = table.insert
local table_remove = table.remove
local table_removeByValue = table.RemoveByValue

QUBELib = QUBELib or {}
QUBELib.Registry = QUBELib.Registry or {}
QUBELib.Registry.QUBES = QUBELib.Registry.QUBES or {}

QUBELib.Registry.RegisterQube = function(ent)
	table_insert(QUBELib.Registry.QUBES, ent)
end

QUBELib.Registry.UnRegisterQube = function(ent)
	table_removeByValue(QUBELib.Registry.QUBES, ent)
end

QUBELib.Registry.Init = function()
	if not QUBELib.Registry.QUBES or #QUBELib.Registry.QUBES <= 0 then return end
	for k, v in pairs(QUBELib.Registry.QUBES) do
		if IsValid(v) then continue end
		table_remove(QUBELib.Registry.QUBES, k)
	end
end

QUBELib.Registry.NewPlayer = function(newPly)
	for k, v in pairs(QUBELib.Registry.QUBES) do
		if not IsValid(v) then continue end
		v:OnNewPlayerJoin(newPly)
	end
end

hook.Add("PlayerInitialSpawn", "__playerspawn_qube_mesh__", function(newPly)
	timer.Simple(5, function()
		QUBELib.Registry.NewPlayer(newPly)
	end)
end)

QUBELib.Registry.Init()