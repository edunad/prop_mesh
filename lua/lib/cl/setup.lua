net.Receive("qube_mesh_lib", function()
	local command = net.ReadString()
	if command == "OBJ_CACHE_CLEANUP" then
		QUBELib.Obj.Clear()
	end
end)

net.Receive("qube_mesh_command", function()
	local indx = net.ReadInt(32)
	local ent = Entity(indx)
	local command = net.ReadString()
	
	if command == "MESH_LOAD" then
		local uri = net.ReadString()
		
		local scale = net.ReadVector()
		local phys = net.ReadVector()
		
		if not IsValid(ent) then
			return QUBELib.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if newEnt.LocalLoadMesh then
					newEnt:LocalLoadMesh(uri, scale, phys)
				end
			end)
		else
			if ent.LocalLoadMesh then
				ent:LocalLoadMesh(uri, scale, phys)
			end
		end
	elseif command == "TEXTURE_LOAD" then
		local textures = net.ReadTable()
		
		if not IsValid(ent) then
			return QUBELib.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.LoadTextures then return end
				newEnt:LoadTextures(textures)
			end)
		else
			if not ent.LoadTextures then return end
			ent:LoadTextures(textures)
			return
		end
	elseif command == "MESH_PHYS_SCALE" then
		local phys = net.ReadVector()
		
		if not IsValid(ent) then
			return QUBELib.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.SetPhysScale then return end
				newEnt:SetPhysScale(phys)
			end)
		else
			if not ent.SetPhysScale then return end
			ent:SetPhysScale(phys)
			return
		end
	elseif command == "MODEL_FAILED" then
		local errored = net.ReadBool()
		
		if not IsValid(ent) then
			return QUBELib.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.SetModelErrored then return end
				newEnt:SetModelErrored(errored)
			end)
		else
			if not ent.SetModelErrored then return end
			ent:SetModelErrored(errored)
		end
	elseif command == "MESH_SCALE" then
		local scale = net.ReadVector()
		
		if not IsValid(ent) then
			return QUBELib.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.SetScale then return end
				newEnt:SetScale(scale)
			end)
		else
			if not ent.SetScale then return end
			ent:SetScale(scale)
		end
	elseif command == "ON_USE_PRESS" then
		if not IsValid(ent) then return end
		if input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT) then return end -- Allow Sitting
		
		local hasErrored = ent.LAST_MODEL_ERRORED
		if LocalPlayer() == ent:CPPIGetOwner() then
			if hasErrored then
				if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
					ent:RetryModelParse()
				else
					--ent:CreateMenu()
				end
			else
				--ent:CreateMenu()
			end
		elseif hasErrored then
			ent:RetryModelParse()
		end
	end
end)