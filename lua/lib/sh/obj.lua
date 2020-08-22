local table_copy = table.Copy
local table_insert = table.insert

local math_min = math.min
local math_max = math.max
local math_sqrt = math.sqrt

local string_gmatch = string.gmatch
local string_match = string.match
local string_split = string.Split
local string_trim = string.Trim
local string_find = string.find
local string_explode = string.Explode
local string_replace = string.Replace

PropMLIB = PropMLIB or {}
PropMLIB.Obj = PropMLIB.Obj or {}
PropMLIB.Obj.Cache = PropMLIB.Obj.Cache or {}
PropMLIB.Obj.MAX_SUBMESHES = GetConVar( "prop_mesh_maxSubMeshes" )
PropMLIB.Obj.MAX_SAFE_VERTICES = GetConVar( "prop_mesh_maxVertices" )

PropMLIB.Obj.IsCached = function(uri)
	local cache = PropMLIB.Obj.Cache[uri]
	return (cache and cache ~= nil)
end

PropMLIB.Obj.Clear = function()
	PropMLIB.Obj.Cache = {}
	
	if SERVER then
		print("[PropMLIB][Server] Cleared obj model cache, sending to clients")
		net.Start("prop_mesh_lib")
			net.WriteString("OBJ_CACHE_CLEANUP")
		net.Broadcast()
	else
		print("[PropMLIB] Cleared obj model cache")
	end
end

PropMLIB.Obj.UnRegister = function(uri)
	PropMLIB.Obj.Cache[uri] = nil
end

PropMLIB.Obj.Register = function(uri, meshData)
	PropMLIB.Obj.Cache[uri] = meshData
end

PropMLIB.Obj.GetScaledTris = function(subMeshData, scale)
	local triCopy = table_copy(subMeshData)
	
	for i = 1, #triCopy do
		triCopy[i]["pos"] = triCopy[i]["pos"] * scale
	end
	
	return triCopy
end

if CLIENT then
	-- Based on PAC
	PropMLIB.Obj.CalculateNormals = function(triangleList)
		local coroutine_yield = coroutine.running() and coroutine.yield or function() end
		
		local vertexNormals = {}
		local triangleCount = #triangleList / 3
		local inverseTriangleCount = 1 / triangleCount
		local defaultNormal = Vector(0, 0, -1)
		
		for i = 1, triangleCount do
			local a, b, c = triangleList[1+(i-1)*3+0], triangleList[1+(i-1)*3+1], triangleList[1+(i-1)*3+2]
			
			local normal = defaultNormal
			if a.pos and b.pos and c.pos then 
				normal = (c.pos - a.pos):Cross(b.pos - a.pos):GetNormalized()
			end
			
			vertexNormals[a.pos_index] = vertexNormals[a.pos_index] or Vector()
			vertexNormals[a.pos_index] = (vertexNormals[a.pos_index] + normal)
			
			vertexNormals[b.pos_index] = vertexNormals[b.pos_index] or Vector()
			vertexNormals[b.pos_index] = (vertexNormals[b.pos_index] + normal)
		
			vertexNormals[c.pos_index] = vertexNormals[c.pos_index] or Vector()
			vertexNormals[c.pos_index] = (vertexNormals[c.pos_index] + normal)
					
			coroutine_yield(false, "Parsing normals")
		end
		
		local vertexCount = #triangleList
		local inverseVertexCount = 1 / vertexCount
		for i = 1, vertexCount do
			local normal = vertexNormals[triangleList[i].pos_index] or defaultNormal
			normal:Normalize()
			
			triangleList[i].normal = normal
			coroutine_yield(false, "Normalizing normals")
		end
	end
	
	-- Based on PAC
	PropMLIB.Obj.CalculateTangents = function(triangleList)
		local coroutine_yield = coroutine.running() and coroutine.yield or function() end
		
		do
			-- Lengyel, Eric. “Computing Tangent Space Basis Vectors for an Arbitrary Mesh”. Terathon Software, 2001. http://terathon.com/code/tangent.html
			local tan1 = {}
			local tan2 = {}
			local vertexCount = #triangleList
		
			for i = 1, vertexCount do
				tan1[i] = Vector(0, 0, 0)
				tan2[i] = Vector(0, 0, 0)
			end
			
			for i = 1, vertexCount - 2, 3 do
				local vert1, vert2, vert3 = triangleList[i], triangleList[i+1], triangleList[i+2]
				if not vert1 or not vert2 or not vert3 then continue end
				
				local p1, p2, p3 = vert1.pos, vert2.pos, vert3.pos
				local u1, u2, u3 = vert1.u, vert2.u, vert3.u
				local v1, v2, v3 = vert1.v, vert2.v, vert3.v
		
				local x1 = p2.x - p1.x;
				local x2 = p3.x - p1.x;
				local y1 = p2.y - p1.y;
				local y2 = p3.y - p1.y;
				local z1 = p2.z - p1.z;
				local z2 = p3.z - p1.z;
		
				local s1 = u2 - u1;
				local s2 = u3 - u1;
				local t1 = v2 - v1;
				local t2 = v3 - v1;
		
				local r = 1 / (s1 * t2 - s2 * t1)
				local sdir = Vector((t2 * x1 - t1 * x2) * r, (t2 * y1 - t1 * y2) * r, (t2 * z1 - t1 * z2) * r);
				local tdir = Vector((s1 * x2 - s2 * x1) * r, (s1 * y2 - s2 * y1) * r, (s1 * z2 - s2 * z1) * r);
		
				tan1[i]:Add(sdir)
				tan1[i+1]:Add(sdir)
				tan1[i+2]:Add(sdir)
		
				tan2[i]:Add(tdir)
				tan2[i+1]:Add(tdir)
				tan2[i+2]:Add(tdir)
				
				coroutine_yield(false, "Parsing tangents")
			end
		
			local tangent = {}
			for i = 1, vertexCount do
				local n = triangleList[i].normal
				local t = tan1[i]
		
				local tan = (t - n * n:Dot(t))
				tan:Normalize()
		
				local w = (n:Cross(t)):Dot(tan2[i]) < 0 and -1 or 1
	
				local tn1 = tan[1] ~= tan[1] and 0 or tan[1]
				local tn2 = tan[2] ~= tan[2] and 0 or tan[2]
				local tn3 = tan[3] ~= tan[3] and 0 or tan[3]
					
				triangleList[i].userdata = {tn1, tn2, tn3, w}
				
				coroutine_yield(false, "Parsing tangents")
			end
		end
	end
	
	-- Based on PAC	
	PropMLIB.Obj.CalculateFaces = function(faceLines, globalMesh)	
		local coroutine_yield = coroutine.running() and coroutine.yield or function () end	

		local faceLineCount = #faceLines	
		local inverseFaceLineCount = 1 / faceLineCount	
		local facesMapper = "([0-9]+)/?([0-9]*)/?([0-9]*)"	
		local triangleList = {}	
		local defaultNormal = Vector(0, 0, -1)	

		for i = 1, #faceLines do	
			local parts = faceLines[i]	
			if #parts < 3 then continue end	

			local v1PositionIndex, v1TexCoordIndex, v1NormalIndex = string_match(parts[1], facesMapper)	
			local v3PositionIndex, v3TexCoordIndex, v3NormalIndex = string_match(parts[2], facesMapper)	

			v1PositionIndex, v1TexCoordIndex, v1NormalIndex = tonumber(v1PositionIndex), tonumber(v1TexCoordIndex), tonumber(v1NormalIndex)	
			v3PositionIndex, v3TexCoordIndex, v3NormalIndex = tonumber(v3PositionIndex), tonumber(v3TexCoordIndex), tonumber(v3NormalIndex)	

			for i = 3, #parts do	
				local v2PositionIndex, v2TexCoordIndex, v2NormalIndex = string_match(parts[i], facesMapper)	
				v2PositionIndex, v2TexCoordIndex, v2NormalIndex = tonumber(v2PositionIndex), tonumber(v2TexCoordIndex), tonumber(v2NormalIndex)	

				local v1 = { pos_index = nil, pos = nil, u = nil, v = nil, normal = nil, userdata = nil }	
				local v2 = { pos_index = nil, pos = nil, u = nil, v = nil, normal = nil, userdata = nil }	
				local v3 = { pos_index = nil, pos = nil, u = nil, v = nil, normal = nil, userdata = nil }	

				v1.pos_index = v1PositionIndex	
				v2.pos_index = v2PositionIndex	
				v3.pos_index = v3PositionIndex	

				v1.pos = globalMesh.positions[v1PositionIndex]	
				v2.pos = globalMesh.positions[v2PositionIndex]	
				v3.pos = globalMesh.positions[v3PositionIndex]	

				if #globalMesh.texCoordsU > 0 then	
					v1.u = globalMesh.texCoordsU[v1TexCoordIndex]	
					v2.u = globalMesh.texCoordsU[v2TexCoordIndex]	
					v3.u = globalMesh.texCoordsU[v3TexCoordIndex]	
				else	
					v1.u = 0	
					v2.u = 0	
					v3.u = 0	
				end	

				if #globalMesh.texCoordsV > 0 then	
					v1.v = globalMesh.texCoordsV[v1TexCoordIndex]	
					v2.v = globalMesh.texCoordsV[v2TexCoordIndex]	
					v3.v = globalMesh.texCoordsV[v3TexCoordIndex]	
				else	
					v1.v = 0	
					v2.v = 0	
					v3.v = 0	
				end	

				if #globalMesh.normals > 0 then	
					v1.normal = globalMesh.normals[v1NormalIndex]	
					v2.normal = globalMesh.normals[v2NormalIndex]	
					v3.normal = globalMesh.normals[v3NormalIndex]	
				else	
					v1.normal = defaultNormal	
					v2.normal = defaultNormal	
					v3.normal = defaultNormal	
				end	

				triangleList[#triangleList + 1] = v1	
				triangleList[#triangleList + 1] = v2	
				triangleList[#triangleList + 1] = v3	

				v3PositionIndex, v3TexCoordIndex, v3NormalIndex = v2PositionIndex, v2TexCoordIndex, v2NormalIndex	
			end	

			coroutine_yield(false, "Parsing triangles")	
		end		

		return triangleList	
	end	

	PropMLIB.Obj.NewSubMesh = function(name)
		return {
			mtl = 'default',
			
			positionsCount = 0,
			faceLines = {},
			name = name
		}
	end
end

-- ID: newmtl None
-- TEXTURE: map_Kd Sheep_VertColor.png
PropMLIB.Obj.ParseMTL = function(baseURL, body)
	local parsedData = {}
	local rawData = string_split(body, "\n")
	
	local currentMTL = {}
	for _, v in pairs(rawData) do
		local data = string_explode("%s+", v, true)
		local mode = tostring(data[1])
		
		if mode == "newmtl" then
			currentMTL.id = tostring(data[2])
		elseif mode == "map_Kd" then
			local filePath = tostring(data[#data])
			filePath = string_replace(filePath, '\\', '/')
			filePath = string_replace(filePath, '//', '/')
			
			currentMTL.material = filePath
		end
		
		-- GROUP DONE --
		if currentMTL.id and currentMTL.material then
			parsedData[currentMTL.id] = table_copy(currentMTL)
			currentMTL = {}
		end
	end
	
	return parsedData
end

PropMLIB.Obj.Parse = function(isAdmin, body, fixNormals)
	local coroutine_yield = coroutine.running() and coroutine.yield or function () end
	local fixNormals = (fixNormals ~= nil and fixNormals or true)
	
	if not body or string_trim(body) == "" then return coroutine_yield(true, "Invalid model") end
	if not string_find(body, "\no ") then -- Add a default object
		body = "o default\n" .. body
	end
	
	local rawData = string_split(body, "\n")
	local minOBB = Vector(100000, 100000, 100000)
	local maxOBB = Vector(-100000, -100000, -100000)
			
	local subMeshes = {}
	local globalMesh = {
		positions = {},
		texCoordsU = {},
		texCoordsV = {},
		normals = {}
	}
	
	for _, v in pairs(rawData) do
		local data = string_explode("%s+", v, true)
		local mode = tostring(data[1])
		
		if mode == "v" then -- POSITION
			local x = tonumber(data[2]) or 1
			local y = tonumber(data[3]) or 1
			local z = tonumber(data[4]) or 1
			local pos = Vector(x, y, z)
			
			-- We don't really care about it on server :<
			if CLIENT then
				globalMesh.positions[#globalMesh.positions + 1] = pos
				subMeshes[#subMeshes].positionsCount = subMeshes[#subMeshes].positionsCount + 1
			end
			
			-- OBB parsing --
			minOBB.x = math_min(x, minOBB.x)
			minOBB.y = math_min(y, minOBB.y)
			minOBB.z = math_min(z, minOBB.z)
				
			maxOBB.x = math_max(x, maxOBB.x)
			maxOBB.y = math_max(y, maxOBB.y)
			maxOBB.z = math_max(z, maxOBB.z)
			---------
		elseif CLIENT then
			if mode == "vt" then -- UV
				local rawU = tonumber(data[2]) or 0
				local rawV = tonumber(data[3]) or 0

				globalMesh.texCoordsU[#globalMesh.texCoordsU + 1] = rawU % 1
				globalMesh.texCoordsV[#globalMesh.texCoordsV + 1] = (1 - rawV) % 1
			elseif mode == "vn" then -- NORMALS
				local nx = tonumber(data[2]) or 0
				local ny = tonumber(data[3]) or 0
				local nz = tonumber(data[4]) or 0
					
				local inverseLength = 1 / math_sqrt(nx * nx + ny * ny + nz * nz)
				nx, ny, nz = nx * inverseLength, ny * inverseLength, nz * inverseLength
				
				globalMesh.normals[#globalMesh.normals + 1] = Vector(nx, ny, nz)
			elseif mode == "f" then -- FACES
				local parts = {}
				local matchLine = string_match(v, "^ *f +(.*)")
				for part in string_gmatch(matchLine, "[^ ]+") do	
					parts[#parts + 1] = part
				end
				
				subMeshes[#subMeshes].faceLines[#subMeshes[#subMeshes].faceLines + 1] = parts
			elseif mode == "o" then -- OBJECT
				local name = tostring(data[2]) or ("obj_" .. #subMeshes)
				local maxSubMeshes = PropMLIB.Obj.MAX_SUBMESHES:GetInt()
				
				if #subMeshes < maxSubMeshes or isAdmin then
					table_insert(subMeshes, PropMLIB.Obj.NewSubMesh(name))
				end
			elseif mode == "usemtl" then -- MATERIAL ID
				subMeshes[#subMeshes].mtl = tostring(data[2])
			end
		end
		
		coroutine_yield(false, "Parsing raw data")
	end
	
	if minOBB.x == 0 then minOBB.x = -1 end
	if minOBB.y == 0 then minOBB.y = -1 end
	if minOBB.z == 0 then minOBB.z = -1 end
	
	if maxOBB.x == 0 then maxOBB.x = 1 end
	if maxOBB.y == 0 then maxOBB.y = 1 end
	if maxOBB.z == 0 then maxOBB.z = 1 end
	
	--
	if SERVER then
		local width = maxOBB.x - minOBB.x
		local lenght = maxOBB.y - minOBB.y
		local height = maxOBB.z - minOBB.z
		local volumeOBB = width * lenght * height
		
		return {
			minOBB = minOBB, 
			maxOBB = maxOBB,
			volumeOBB = width * lenght * height
		}
	elseif CLIENT then
		if #subMeshes <= 0 then
			return coroutine_yield(false, "Invalid model")
		end
		
		local parsedSubMeshes = {}
		local maxVertices = PropMLIB.Obj.MAX_SAFE_VERTICES:GetInt()
		
		for _, objMesh in pairs(subMeshes) do
			if not isAdmin then
				if objMesh.positionsCount <= 0 or objMesh.positionsCount > maxVertices then
					continue
				end
			end
			
			local tris = PropMLIB.Obj.CalculateFaces(objMesh.faceLines, globalMesh)
			if fixNormals then
				PropMLIB.Obj.CalculateNormals(tris)
				PropMLIB.Obj.CalculateTangents(tris)
			end
			
			tris.name = objMesh.name
			tris.mtl = objMesh.mtl
			
			table_insert(parsedSubMeshes, tris)
			coroutine_yield(false, "Parsing Sub-Mesh")
		end
		
		if #parsedSubMeshes <= 0 then
			return coroutine_yield(false, "Invalid model") 
		end
		
		local width = maxOBB.x - minOBB.x
		local lenght = maxOBB.y - minOBB.y
		local height = maxOBB.z - minOBB.z
		local volumeOBB = width * lenght * height
		
		return {
			subMeshes = parsedSubMeshes,
			
			minOBB = minOBB, 
			maxOBB = maxOBB,
			volumeOBB = width * lenght * height
		}
	end
end

concommand.Add( "prop_mesh_objcache_clear", function()
	PropMLIB.Obj.Clear()
end, nil, "Clears all cached models")