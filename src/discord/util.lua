local type = type
local error = error
local format = string.format
local getinfo = debug and debug.getinfo

local function getFuncName(pos)
	if getinfo then
		return getinfo(pos+1, "n").name
	else
		return "?"
	end
end


local _M = { }

function _M.typecheck(pos, real, expectedTypes)
	local realType = type(real)
	local funcName = getFuncName(2)

	local isCorrectType = false

	local expected = expectedTypes

	if type(expectedTypes) == "table" then
		for i = 1, #expectedTypes do
			if realType == expectedTypes[i] then
				isCorrectType = true
			else
				expected = expectedTypes[i]
			end
		end
	else
		isCorrectType = realType == expectedTypes
	end

	if not isCorrectType then
		error(format("bad argument #%s to '%s' (%s expected, got %s)", pos, funcName, expected, realType), 2)
	end
end

return _M