local table_copy = table.Copy
local table_insert = table.insert

local math_min = math.min
local math_max = math.max
local math_sqrt = math.sqrt

local string_gmatch = string.gmatch
local string_match = string.match
local string_split = string.Split
local string_trim = string.Trim


QUBELib = QUBELib or {}
QUBELib.Obj = QUBELib.Obj or {}
QUBELib.Obj.Cache = QUBELib.Obj.Cache or {}
QUBELib.Obj.MAX_SUBMESHES = GetConVar( "qube_maxSubMeshes" )
QUBELib.Obj.MAX_SAFE_VERTICES = GetConVar( "qube_maxVertices" )

QUBELib.Obj.IsCached = function(uri)
	local cache = QUBELib.Obj.Cache[uri]
	return (cache and cache ~= nil)
end

QUBELib.Obj.Clear = function()
	QUBELib.Obj.Cache = {}
	
	if SERVER then
		net.Start("qube_mesh_lib")
			net.WriteString("OBJ_CACHE_CLEANUP")
		net.Broadcast()
	end
end

QUBELib.Obj.UnRegister = function(uri)
	QUBELib.Obj.Cache[uri] = nil
end

QUBELib.Obj.Register = function(uri, meshData)
	QUBELib.Obj.Cache[uri] = meshData
end

QUBELib.Obj.GetScaledTris = function(subMeshData, scale)
	local triCopy = table_copy(subMeshData)
	
	for i = 1, #triCopy do
		triCopy[i]["pos"] = triCopy[i]["pos"] * scale
	end
	
	return triCopy
end

if CLIENT then
	-- Based on PAC
	QUBELib.Obj.CalculateNormals = function(triangleList)
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
	QUBELib.Obj.CalculateTangents = function(triangleList)
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
	
	QUBELib.Obj.NewSubMesh = function(name)
		return {
			positionsCount = 0,
			triangles = {},
			name = name
		}
	end
end

QUBELib.Obj.Parse = function(isAdmin, body, fixNormals)
	local coroutine_yield = coroutine.running() and coroutine.yield or function () end
	local fixNormals = (fixNormals ~= nil and fixNormals or true)
	local rawData = string_split(body, "\n")
	
	if not body or string_trim(body) == "" or #rawData <= 0 then return coroutine_yield(true, "Invalid model") end
	
	local minOBB = Vector(100000, 100000, 100000)
	local maxOBB = Vector(-100000, -100000, -100000)
	local defaultNormal = Vector(0, 0, -1)
			
	local subMeshes = {}
	local globalMesh = {
		positions = {},
		texCoordsU = {},
		texCoordsV = {},
		normals = {}
	}
	
	for _, v in pairs(rawData) do
		local data = string_split(v, " ")
		local mode = data[1]
		
		if mode == "v" then -- POSITION
			local x = tonumber(data[2]) or 0
			local y = tonumber(data[3]) or 0
			local z = tonumber(data[4]) or 0
			local pos = Vector(x, y, z)
			
			-- We don't really care about it on server :<
			if CLIENT then
				globalMesh.positions[#globalMesh.positions + 1] = pos
				subMeshes[#subMeshes].positionsCount = subMeshes[#subMeshes].positionsCount + 1
			end
			
			-- OBB parsing --
			minOBB.x = math_min(pos.x, minOBB.x)
			minOBB.y = math_min(pos.y, minOBB.y)
			minOBB.z = math_min(pos.z, minOBB.z)
				
			maxOBB.x = math_max(pos.x, maxOBB.x)
			maxOBB.y = math_max(pos.y, maxOBB.y)
			maxOBB.z = math_max(pos.z, maxOBB.z)
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
				local currentMesh = subMeshes[#subMeshes]
				for _, Data in pairs( { data[4], data[3], data[2] } ) do
					local parts = string_split(Data, "/")
					
					table_insert(currentMesh.triangles , {
						pos = ( parts[1] ~= nil and globalMesh.positions[ tonumber( parts[ 1 ] ) ] or nil ),
						normal = ( parts[3] ~= nil and globalMesh.normals[ tonumber( parts[ 3 ] ) ] or defaultNormal ), -- Fallback
						u = ( parts[2] ~= nil and globalMesh.texCoordsU[ tonumber( parts[ 2 ] ) ] or nil ),
						v = ( parts[2] ~= nil and globalMesh.texCoordsV[ tonumber( parts[ 2 ] ) ] or nil ),
						pos_index = parts[ 1 ]
					})
				end
			elseif mode == "o" then
				local name = tostring(data[2]) or ("obj_" .. #subMeshes)
				local maxSubMeshes = QUBELib.Obj.MAX_SUBMESHES:GetInt()
				
				if #subMeshes < maxSubMeshes or isAdmin then
					table_insert(subMeshes, QUBELib.Obj.NewSubMesh(name))
				end
			end
		end
		
		coroutine_yield(false, "Parsing raw data")
	end
	
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
		local maxVertices = QUBELib.Obj.MAX_SAFE_VERTICES:GetInt()
		
		for _, objMesh in pairs(subMeshes) do
			if not isAdmin then
				if objMesh.positionsCount <= 0 or objMesh.positionsCount > maxVertices then
					continue
				end
			end
			
			local tris = objMesh.triangles
			if fixNormals then
				QUBELib.Obj.CalculateNormals(tris)
				QUBELib.Obj.CalculateTangents(tris)
			end
			
			tris.name = objMesh.name
			
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