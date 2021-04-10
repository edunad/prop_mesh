net.Receive("prop_mesh_lib", function()
	local command = net.ReadString()
	if command == "OBJ_CACHE_CLEANUP" then
		PropMLIB.Obj.Clear()
	end
end)

net.Receive("prop_mesh_command", function()
	local indx = net.ReadInt(32)
	local ent = Entity(indx)
	local command = net.ReadString()
	
	if command == "MESH_LOAD" then
		local data = net.ReadTable()
		
		if not IsValid(ent) then
			return PropMLIB.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.LocalLoadMesh then return end
				newEnt:LocalLoadMesh(data)
			end)
		else
			if not ent.LocalLoadMesh then return end
			ent:LocalLoadMesh(data)
		end
	elseif command == "TEXTURE_LOAD" then
		local textures = net.ReadTable()
		
		if not IsValid(ent) then
			return PropMLIB.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.LoadTextures then return end
				newEnt:LoadTextures(textures)
			end)
		else
			if not ent.LoadTextures then return end
			ent:LoadTextures(textures)
		end
	elseif command == "MESH_PHYS_SCALE" then
		local phys = net.ReadVector()
		local obb = net.ReadTable()
		
		if not IsValid(ent) then
			return PropMLIB.PVSCache.CacheNetMessage(indx, command, function(newEnt)
				if not newEnt.SetPhysScale then return end
				newEnt:SetPhysScale(phys, obb)
			end)
		else
			if not ent.SetPhysScale then return end
			ent:SetPhysScale(phys, obb)
		end
	elseif command == "MODEL_FAILED" then
		local errored = net.ReadBool()
		
		if not IsValid(ent) then
			return PropMLIB.PVSCache.CacheNetMessage(indx, command, function(newEnt)
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
			return PropMLIB.PVSCache.CacheNetMessage(indx, command, function(newEnt)
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
		if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
			if not ent.LAST_MODEL_ERRORED then return end
			ent:RetryModelParse()
			return
		end
		
		local owner = ent:GetNWEntity("owner")
		if ent.CPPIGetOwner then
			owner = ent:CPPIGetOwner()
		end
		
		if LocalPlayer() == owner then
			ent:CreateMenu()
		end
	end
end)