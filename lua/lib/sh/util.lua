local math_round = math.Round
local math_clamp_ = math.Clamp
local math_huge = math.huge

QUBELib = QUBELib or {}
QUBELib.Util = QUBELib.Util or {}

-- Taken from metastruct, cus im lazy --
QUBELib.Util.NiceSize = function(size)
	size = tonumber( size )
	
	if ( size <= 0 ) then return "0" end
	if ( size < 1000 ) then return size .. " Bytes" end
	if ( size < 1000 * 1000 ) then return math_round( size / 1000, 2 ) .. " KB" end
	if ( size < 1000 * 1000 * 1000 ) then return math_round( size / ( 1000 * 1000 ), 2 ) .. " MB" end

	return math_round( size / ( 1000 * 1000 * 1000 ), 2 ) .. " GB"
end

QUBELib.Util.SafeVector = function(vec, negative)
	if not vec then 
		if negative then return Vector(-1, -1, -1)
		else return Vector(1, 1, 1) end
	end
	
	if not QUBELib.Util.IsFinite(vec.x) then
		if negative then vec.x = -1 else vec.x = 1 end
	end
	
	if not QUBELib.Util.IsFinite(vec.y) then 
		if negative then vec.y = -1 else vec.y = 1 end
	end
	
	if not QUBELib.Util.IsFinite(vec.z) then
		if negative then vec.z = -1 else vec.z = 1 end
	end
	
	return vec
end

QUBELib.Util.ClampVector = function(vec, min, max)
	if not vec then vec = Vector(0, 0, 0) end
	
	if not min then min = 0 end
	if not max then max = 1 end
	
	vec.x = math_clamp_(vec.x, min, max)
	vec.y = math_clamp_(vec.y, min, max)
	vec.z = math_clamp_(vec.z, min, max)
	
	return vec
end

QUBELib.Util.IsFinite = function(x)
	if not x or QUBELib.Util.IsNan(x) then return false end
	if x == math_huge then return false end
	if x == -math_huge then return false end
	
	return true
end

QUBELib.Util.IsNan = function(x)
	return x ~= x
end

--- Taken from PAC3, thanks :D! ---
--- https://github.com/CapsAdmin/pac3/blob/97ab99e9e8f5f16063ee5480ee33d21970822b8c/lua/pac3/core/shared/http.lua
QUBELib.Util.FixUrl = function(url)
	url = url:Trim()

	if url:find("dropbox", 1, true) then
		url = url:gsub([[^http%://dl%.dropboxusercontent%.com/]], [[https://dl.dropboxusercontent.com/]])
		url = url:gsub([[^https?://dl.dropbox.com/]], [[https://www.dropbox.com/]])
		url = url:gsub([[^https?://www.dropbox.com/s/(.+)%?dl%=[01]$]], [[https://dl.dropboxusercontent.com/s/%1]])
		url = url:gsub([[^https?://www.dropbox.com/s/(.+)$]], [[https://dl.dropboxusercontent.com/s/%1]])
		return url
	end

	if url:find("drive.google.com", 1, true) and not url:find("export=download", 1, true) then
		local id =
			url:match("https://drive.google.com/file/d/(.-)/") or
			url:match("https://drive.google.com/file/d/(.-)$") or
			url:match("https://drive.google.com/open%?id=(.-)$")

		if id then
			return "https://drive.google.com/uc?export=download&id=" .. id
		end
		return url
	end

	if url:find("gitlab.com", 1, true) then
		return url:gsub("^(https?://.-/.-/.-/)blob", "%1raw")
	end

	url = url:gsub([[^http%://onedrive%.live%.com/redir?]],[[https://onedrive.live.com/download?]])
	url = url:gsub("pastebin.com/([a-zA-Z0-9]*)$", "pastebin.com/raw.php?i=%1")
	url = url:gsub("github.com/([a-zA-Z0-9_]+)/([a-zA-Z0-9_]+)/blob/", "github.com/%1/%2/raw/")
	return url
end