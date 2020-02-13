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

QUBELib.Util.ClampVector = function(vec, min, max)
	if not vec then vec = Vector(0,0,0) end
	
	if not min then min = 0 end
	if not max then max = 1 end
	
	vec.x = math_clamp_(vec.x, min, max)
	vec.y = math_clamp_(vec.y, min, max)
	vec.z = math_clamp_(vec.z, min, max)
	
	return vec
end

QUBELib.Util.IsFinite = function(vec, min, max)
	if QUBELib.Util.IsNan(x) then return false end
	if x == math_huge then return false end
	if x == -math_huge then return false end
	
	return true
end

QUBELib.Util.IsNan = function(x)
	return x ~= x
end