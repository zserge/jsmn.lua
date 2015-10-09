local tests_passed = 0
local tests_failed = 0

require('gambiarra')(function(e, test, msg)
	if e == 'pass' then
		print("[32m✔[0m "..test..': '..msg)
		tests_passed = tests_passed + 1
	elseif e == 'fail' then
		print("[31m✘[0m "..test..': '..msg)
		tests_failed = tests_failed + 1
	elseif e == 'except' then
		print("[31m✘[0m "..test..': '..msg)
		tests_failed = tests_failed + 1
	end
end)

local jsmn = require('jsmn')

local function tokeq(p, n, token, from, to, val, size)
	local t = p.tokens[n]
	if t == nil then
		ok(false, 'Token #'..n..' is nil')
		return
	end
	local s = {'primitive', 'object', 'array', 'string'}
	ok(t.token == token, 'Token #'..n..' type is: '..s[t.token+1])
	if from and to then
		ok(t.from == from and t.to == to, 'Token #'..n..' boundaries are: '..
			t.from..'..'..t.to)
	end
	if val then
		local s = p.str:sub(t.from, t.to)
		ok(s == val, 'Token #'..n..' is '..s)
	end
	if size then
		ok(t.size == size, 'Token size is '..t.size)
	end
end

local function tokenize(s, tokens, strict)
	local p, status, err = jsmn.parse(s, strict)
	print('  '..s)
	ok(status == true, 'parse: '..(err or 'ok'))
	ok(#p.tokens == #tokens, 'parsed '..#p.tokens..' tokens')
	for i, t in ipairs(tokens) do
		tokeq(p, i, t[1], t[2], t[3], t.s, t.size)
	end
end

local function fail(s)
	local p, status, err = jsmn.parse(s, strict)
	print('  '..s)
	ok(status == false and err ~= nil, 'parse failed as expected: '..(err or ''))
end

test('Empty', function()
	tokenize('{}', {
		{jsmn.OBJECT, 1, 2, s='{}', size=0},
	})
	tokenize('{"a":[]}', {
		{jsmn.OBJECT, 1, 8, s='{"a":[]}', size=1},
		{jsmn.STRING, 3, 3, s='a', size=1},
		{jsmn.ARRAY,  6, 7, s='[]', size=0},
	})
	tokenize('[{},{}]', {
		{jsmn.ARRAY,  1, 7, size=2},
		{jsmn.OBJECT, 2, 3, size=0},
		{jsmn.OBJECT, 5, 6, size=0},
	})
end)

test('Simple', function()
	tokenize('{"a": 0}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='a', size=1},
		{jsmn.PRIMITIVE, s='0'},
	})

	tokenize('{"a":{},"b":{}}', {
		{jsmn.OBJECT, size=2},
		{jsmn.STRING, s='a', size=1},
		{jsmn.OBJECT, size=0},
		{jsmn.STRING, s='b', size=1},
		{jsmn.OBJECT, size=0},
	})

	local s = '{\n "Day": 26,\n "Month": 9,\n "Year": 12\n }'
	tokenize(s, {
		{jsmn.OBJECT, size=3},
		{jsmn.STRING, s='Day', size=1},
		{jsmn.PRIMITIVE, s='26'},
		{jsmn.STRING, s='Month', size=1},
		{jsmn.PRIMITIVE, s='9'},
		{jsmn.STRING, s='Year', size=1},
		{jsmn.PRIMITIVE, s='12'},
	})
end)

test('Primitive', function()
	tokenize('{"boolVar": true}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='boolVar', size=1},
		{jsmn.PRIMITIVE, s='true'},
	})
	tokenize('{"boolVar": false}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='boolVar', size=1},
		{jsmn.PRIMITIVE, s='false'},
	})
	tokenize('{"intVar": 12345}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='intVar', size=1},
		{jsmn.PRIMITIVE, s='12345'},
	})
	tokenize('{"floatVar": 12.345}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='floatVar', size=1},
		{jsmn.PRIMITIVE, s='12.345'},
	})
	tokenize('{"nullVar": null}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='nullVar', size=1},
		{jsmn.PRIMITIVE, s='null'},
	})
end)

test('String', function()
	tokenize('{"strVar": "hello world"}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='strVar', size=1},
		{jsmn.STRING, s='hello world'},
	})
	
	---- FIXME
	--local esc = 'escaped: \\/\r\n\t\b\f\"\\'
	--local s = '{"strVar" : "'..esc..'"}'
	--tokenize(s, {
		--{jsmn.OBJECT, size=1},
		--{jsmn.STRING, s='strVar', size=1},
		--{jsmn.STRING, s=esc},
	--})

	tokenize('{"strVar": ""}', {
		{jsmn.OBJECT, size=1},
		{jsmn.STRING, s='strVar', size=1},
		{jsmn.STRING, s=''},
	})
end)

test('Partial string', function()
	--js = "\"x\": \"va";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r == JSMN_ERROR_PART && tok[0].type == JSMN_STRING);
	--check(TOKEN_STRING(js, tok[0], "x"));
	--check(p.toknext == 1);

	--char js_slash[9] = "\"x\": \"va\\";
	--r = jsmn_parse(&p, js_slash, sizeof(js_slash), tok, 10);
	--check(r == JSMN_ERROR_PART);

	--char js_unicode[10] = "\"x\": \"va\\u";
	--r = jsmn_parse(&p, js_unicode, sizeof(js_unicode), tok, 10);
	--check(r == JSMN_ERROR_PART);

	--js = "\"x\": \"valu";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r == JSMN_ERROR_PART && tok[0].type == JSMN_STRING);
	--check(TOKEN_STRING(js, tok[0], "x"));
	--check(p.toknext == 1);

	--js = "\"x\": \"value\"";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r >= 0 && tok[0].type == JSMN_STRING
			--&& tok[1].type == JSMN_STRING);
	--check(TOKEN_STRING(js, tok[0], "x"));
	--check(TOKEN_STRING(js, tok[1], "value"));

	--js = "\"x\": \"value\", \"y\": \"value y\"";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r >= 0 && tok[0].type == JSMN_STRING
			--&& tok[1].type == JSMN_STRING && tok[2].type == JSMN_STRING
			--&& tok[3].type == JSMN_STRING);
	--check(TOKEN_STRING(js, tok[0], "x"));
	--check(TOKEN_STRING(js, tok[1], "value"));
	--check(TOKEN_STRING(js, tok[2], "y"));
	--check(TOKEN_STRING(js, tok[3], "value y"));
end)

test('Partial array', function()
	--js = "  [ 1, true, ";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r == JSMN_ERROR_PART && tok[0].type == JSMN_ARRAY
			--&& tok[1].type == JSMN_PRIMITIVE && tok[2].type == JSMN_PRIMITIVE);

	--js = "  [ 1, true, [123, \"hello";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r == JSMN_ERROR_PART && tok[0].type == JSMN_ARRAY
			--&& tok[1].type == JSMN_PRIMITIVE && tok[2].type == JSMN_PRIMITIVE
			--&& tok[3].type == JSMN_ARRAY && tok[4].type == JSMN_PRIMITIVE);

	--js = "  [ 1, true, [123, \"hello\"]";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r == JSMN_ERROR_PART && tok[0].type == JSMN_ARRAY
			--&& tok[1].type == JSMN_PRIMITIVE && tok[2].type == JSMN_PRIMITIVE
			--&& tok[3].type == JSMN_ARRAY && tok[4].type == JSMN_PRIMITIVE
			--&& tok[5].type == JSMN_STRING);
	--/* check child nodes of the 2nd array */
	--check(tok[3].size == 2);

	--js = "  [ 1, true, [123, \"hello\"]]";
	--r = jsmn_parse(&p, js, strlen(js), tok, 10);
	--check(r >= 0 && tok[0].type == JSMN_ARRAY
			--&& tok[1].type == JSMN_PRIMITIVE && tok[2].type == JSMN_PRIMITIVE
			--&& tok[3].type == JSMN_ARRAY && tok[4].type == JSMN_PRIMITIVE
			--&& tok[5].type == JSMN_STRING);
	--check(tok[3].size == 2);
	--check(tok[0].size == 3);
end)

test('Invalid objects/arrays', function()
	fail('[10}')
	fail('{10]')
	fail('{"a": 1]')
	-- FIXME:
	--fail('["a": 1]')
end)

test('Complex JSON', function()
	local s = [[{ "height":10, "layers":[ { "data":[6,6], "height":10,
		"name":"Calque de Tile 1", "opacity":1, "type":"tilelayer",
		"visible":true, "width":10, "x":0, "y":0 }],
		"orientation":"orthogonal", "properties": { }, "tileheight":32,
		"tilesets":[ { "firstgid":1, "image":"..\\/images\\/tiles.png",
		"imageheight":64, "imagewidth":160, "margin":0, "name":"Tiles",
		"properties":{}, "spacing":0, "tileheight":32, "tilewidth":32 }],
		"tilewidth":32, "version":1, "width":10 }
	]]
	local p, status, err = jsmn.parse(s)
	ok(status == true and err == nil, 'parsed successfully')
end)

test('Unicode', function()
	tokenize('{"a": "\\uAbcD"}', {
		{jsmn.OBJECT}, {jsmn.STRING}, {jsmn.STRING}
	})
	tokenize('{"a": "str\\u0000"}', {
		{jsmn.OBJECT}, {jsmn.STRING}, {jsmn.STRING}
	})
	tokenize('{"a": "\\uFFFFstr"}', {
		{jsmn.OBJECT}, {jsmn.STRING}, {jsmn.STRING}
	})
	tokenize('{"a":["str\\u0280"]}', {
		{jsmn.OBJECT}, {jsmn.STRING}, {jsmn.ARRAY}, {jsmn.STRING}
	})

	fail('{"a":"str\\uFFGFstr"}')
	fail('{"a":"str\\u@FfFstr"}')
	fail('{"a":["str\\u028"]}')
end)

test('Token count', function()
	tokenize('[[]]', {
		{jsmn.ARRAY, size=1},
		{jsmn.ARRAY, size=0},
	})
	tokenize('[[], []]', {
		{jsmn.ARRAY, size=2},
		{jsmn.ARRAY, size=0},
		{jsmn.ARRAY, size=0},
	})
	tokenize('[[], [[]], [[], []]]', {
		{jsmn.ARRAY, size=3},
		{jsmn.ARRAY, size=0},
		{jsmn.ARRAY, size=1},
		{jsmn.ARRAY, size=0},
		{jsmn.ARRAY, size=2},
		{jsmn.ARRAY, size=0},
		{jsmn.ARRAY, size=0},
	})
	tokenize('["a", [[], []]]', {
		{jsmn.ARRAY, size=2},
		{jsmn.STRING, s='a'},
		{jsmn.ARRAY, size=2},
		{jsmn.ARRAY, size=0},
		{jsmn.ARRAY, size=0},
	})
	tokenize('[[], "[], [[]]", [[]]]', {
		{jsmn.ARRAY, size=3},
		{jsmn.ARRAY, size=0},
		{jsmn.STRING, s='[], [[]]'},
		{jsmn.ARRAY, size=1},
		{jsmn.ARRAY, size=0},
	})

	tokenize('[1, 2, 3]', {
		{jsmn.ARRAY},
		{jsmn.PRIMITIVE, s='1'},
		{jsmn.PRIMITIVE, s='2'},
		{jsmn.PRIMITIVE, s='3'},
	})

	tokenize('[1, 2, [3, "a"], null]', {
		{jsmn.ARRAY, size=4},
		{jsmn.PRIMITIVE, s='1'},
		{jsmn.PRIMITIVE, s='2'},
		{jsmn.ARRAY, size=2},
		{jsmn.PRIMITIVE, s='3'},
		{jsmn.STRING, s='a'},
		{jsmn.PRIMITIVE, s='null'},
	})
end)

test('Invalid key/values', function()
	fail('{"a", 0}')
	fail('{"a": {2}}')
	fail('{"a": {2: 3}}')
	fail('{"a": {"b": 2 3}}')
end)

if tests_failed > 0 then os.exit(1) end

