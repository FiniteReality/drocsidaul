local json = require("cjson")

local decode = json.decode

local function recurse(t, f)
	for i, v in pairs(t) do
		f(t, i, v)
		if type(v) == "table" then
			recurse(v, f)
		end
	end
end

local function replace_nulls(t, i, v)
	if v == json.null then
		t[i] = nil
	end
end

function json.decode(...)
	local data = decode(...)
	recurse(data, replace_nulls)
	return data
end

return json