CreateConVar('sbox_maxqube_mesh', 10)

util.AddNetworkString("qube_mesh_command" )
util.AddNetworkString("qube_mesh_lib" )

duplicator.RegisterEntityModifier( "SAVE_DATA", function(ply, ent, data)
	if not IsValid(ply) or not ply:CheckLimit("qube_mesh") then return ent:Remove() end
	ply:AddCount("qube_mesh", ent)
	ply:AddCleanup("qube_mesh", ent)
			
	if not IsValid(ent) or not data.meshURL then return end
	if not ent.Load then return end
	
	timer.Simple(0.5, function()
		ent:Load(data.meshURL, data.textureURL, data.scale, data.phys)
	end)
end)

net.Receive("qube_mesh_command", function( len, ply )
	if not IsValid(ply) or not ply:IsPlayer() then return end
	local command = net.ReadString()
	
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end
	
	local isowner = false
	if ent.CPPIGetOwner then
		isowner = ent:CPPIGetOwner() == ply
	else
		isowner = ent:GetOwner() == ply
	end
	
	if not isowner then return end
	
	if command == "SET_DEBUG" then
		if not ent.SetDebug then return end
		ent:SetDebug(net.ReadBool())
	elseif command == "SET_FULLBRIGHT" then
		if not ent.SetFullbright then return end
		ent:SetFullbright(net.ReadBool())
	elseif command == "UPDATE_MESH" then
		local newData = net.ReadTable()
		if not newData then return end
		
		local currMesh = ent.LOADED_MESH
		if not currMesh then
			ent:Load(newData.uri, newData.textures, newData.scale, newData.phys)
		else
			if currMesh.uri ~= newData.uri then
				ent:Load(newData.uri, newData.textures, newData.scale, newData.phys)
				return
			end
			
			ent:SetTextures(newData.textures)
			ent:SetScale(newData.scale)
			ent:SetPhysScale(newData.phys)
		end
	end
end)