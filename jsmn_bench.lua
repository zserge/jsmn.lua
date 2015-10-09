local jsmn = require('jsmn')

-- JSON string: wikipedia example stored 1000 times in an array
local s = "[" .. string.rep([[{
  "firstName": "John",
  "lastName": "Smith",
  "isAlive": true,
  "age": 25,
  "address": {
    "streetAddress": "21 2nd Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10021-3100"
  },
  "phoneNumbers": [
    {
      "type": "home",
      "number": "212 555-1234"
    },
    {
      "type": "office",
      "number": "646 555-4567"
    }
  ],
  "children": [],
  "spouse": null
}, ]], 1000):sub(1, -3) .. "]"

print('JSON string length: '..#s)

local function parse()
	local p, status, err = jsmn.parse(s)
	if not status or err ~= nil then
		error('Parse failed: '..status..' '..err)
	end
end

local function scan()
	local b = 0
	for i = 1,#s do
		b = b + s:byte(i)
	end
end

local function bench(f, n)
	local res = {}
	local unpack = unpack or table.unpack
	for i = 1, n do
		local start_time = os.clock()
		f()
		table.insert(res, (os.clock() - start_time))
	end
	-- Calculate average
	local avg = 0
	for i, v in ipairs(res) do
		avg = avg + v
	end
	avg = avg / #res

	-- Build and return result table
	print('avg: '..avg, ' min: '..math.min(unpack(res))..
		' max: '..math.max(unpack(res)))
	print('speed: '..(#s/avg)..' bytes/sec')
end

bench(scan, 100)
bench(parse, 100)
