local M = {
	PRIMITIVE = 0,
	OBJECT = 1,
	ARRAY = 2,
	STRING = 3,
}

local function jsmn_add_token(p, token, from, to, parent)
	local t = {
		token = token,
		from = from or 0,
		to = to or 0,
		size = 0,
		parent = parent or 0,
	}
	table.insert(p.tokens, t)
	return t
end

local function jsmn_parse_primitive(p, s)
	local from = p.pos
	local found = false
	while p.pos <= #s do
		local c = s:byte(p.pos)
		if (not p.strict and c == 0x3a) or
			c == 0x9 or c == 0xd or c == 0xa or c == 0x20 or
			c == 0x2c or c == 0x5d or c == 0x7d then
			found = true
			break
		end
		if not found and (c < 32 or c >= 127) then
			p.pos = from
			return false
		end
		p.pos = p.pos + 1
	end

	if not found and p.strict then
		p.pos = from
		return false
	end

	p.pos = p.pos - 1

	jsmn_add_token(p, M.PRIMITIVE, from, p.pos, p.parent)
	return true
end

local function jsmn_parse_string(p, s)
	local from = p.pos
	p.pos = p.pos + 1
	while p.pos <= #s do
		local c = s:byte(p.pos)
		if c == 0x22 then             -- '"'
			jsmn_add_token(p, M.STRING, from+1, p.pos-1, p.parent)
			return 0
		end
		if c == 0x5c and p.pos + 1 <= #s then -- '\\'
			p.pos = p.pos + 1
			local e = s:byte(p.pos)
			local f = string.char
			if e == 0x75 then -- '\u'
				for i = 1, 4 do
					if p.pos + i > #s then
						p.pos = from
						return false -- string is too short for unicode
					end
					local u = s:byte(p.pos+i)
					if not ((u >= 48 and u <= 57) or   -- 0..9
						(u >= 65 and u <= 70) or     -- A..F
						(u >= 97 and u <= 102)) then -- a..f
						p.pos = from
						return false -- invalid hex unicode digit
					end
				end
			elseif e ~= 0x22 and e ~= 0x2f and e ~= 0x5c and
				e ~= 0x62 and e ~= 0x66 and e ~= 0x72 and e ~= 0x6e and
				e ~= 0x74 then -- [",/,\, b, f, r, n, t]
				p.pos = from
				return false -- invalid escape
			end
		end
		p.pos = p.pos + 1
	end
	return true
end

local function jsmn_parse(p, s, strict)
	p = p or {
		str = s,
		pos = 1,         -- position in the string
		parent = 0,      -- index of the previous (parent) token
		-- strict mode is the default one
		strict = strict == nil and true or strict,
		tokens = {}
	}
	while p.pos <= #s do
		local c = s:byte(p.pos)
		if c == 0x7b or c == 0x5b then       -- 7b: '{'   5b: '['
			-- begin object/array
			local token = (c == 0x7b and M.OBJECT or M.ARRAY)
			if p.parent > 0 then
				local parent = p.tokens[p.parent]
				parent.size = parent.size + 1
			end
			local t = jsmn_add_token(p, token, p.pos, 0, p.parent)
			p.parent = #p.tokens
		elseif c == 0x7d or c == 0x5d then   -- 7d: '}'   5d: ']'
			-- end object/array
			if #p.tokens == 0 then
				return p, false, 'unexpected close delimiter'
			end
			local toktype = (c == 0x7d and M.OBJECT or M.ARRAY)
			local t = p.tokens[#p.tokens]
			while true do
				if (t.from > 0 and t.to == 0) or t.parent == 0 then
					if t.token ~= toktype then
						return p, false, 'open/close delimiters mismatch'
					end
					t.to = p.pos
					p.parent = t.parent
					break
				end
				t = p.tokens[t.parent]
			end
		elseif c == 0x22 then                -- 22: '"'
			-- parse quoted string
			if not jsmn_parse_string(p, s) then
				return p, false, 'invalid string'
			end
			if p.parent > 0 then
				local parent = p.tokens[p.parent]
				parent.size = parent.size + 1
			end
		elseif c == 0x9 or c == 0xa or c == 0xd or c == 0x20 then  -- "\t\r\n "
			-- skip
		elseif c == 0x3a then                -- 3a: ':'
			p.parent = #p.tokens
		elseif c == 0x2c then                -- 2c: ','
			-- array element or end of key/value pair
			local parent = p.tokens[p.parent]
			if p.parent > 0 and parent.token == M.STRING then
				p.parent = p.tokens[p.parent].parent
			end
		elseif not p.strict or               -- in non-strict mode any word is valid
			(c >= 0x30 and c <= 0x39) or       -- '0'..'9'
			c == 0x2d or                       -- '-', 't', 'f', 'n'
			c == 0x74 or c == 0x66 or c == 0x6e then

			local parent = p.tokens[p.parent]
			if p.parent > 0 then
				if parent.token == M.OBJECT or
					(parent.token == M.STRING and parent.size > 0) then
					return p, false, 'unexpected primitive'
				end
			end

			jsmn_parse_primitive(p, s)
			if p.parent > 0 then
				parent.size = parent.size + 1
			end
		else
			return p, false, 'unexpected symbol: '..string.char(c)..' '..c
		end
		p.pos = p.pos + 1
	end

	for i = #p.tokens, 1, -1 do
		if p.tokens[i].from > 0 and p.tokens[i].to == 0 then
			return p, false, nil
		end
	end

	return p, true, nil
end

M.parse = function(s, strict) return jsmn_parse(nil, s, strict) end

return M

