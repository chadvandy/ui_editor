--[[
    types to decode: 
]]

local function return_string_from_bytes(bytes)
    local block = {}
    for i = 1,#bytes do
        block[i] = bytes[i]
    end

    -- turn the table of numbers (ie. {84, 03, 00, 00}) into a string with spaces between each (ie. "84 03 00 00")
    local str = table.concat(block, " ", 1, #bytes)

    return str
end

-- signed long - 4 bytes, can be positive or negative
local function get_signed_long(bytes)
    print(return_string_from_bytes(bytes))

    local str = ""
    for i = #bytes,1, -1 do
        str = str .. bytes[i]
    end

    print(str)
    str = tonumber(str, 16)
    print(str)
end

local function get_float(bytes)
    print(return_string_from_bytes(bytes))

    local str = ""

    -- little-endian!
    for i = #bytes,1, -1 do
        str = str .. bytes[i]
    end

    print(str)
    print(string.format("%f", tonumber(str, 16)))
    print(str)
    local m,n = math.frexp(tonumber(str, 16))
    print(m) print(n)
end

-- local bytes = {"00", "00", "00", "40"}

-- get_float(bytes)



-- local bytes = {"84", "03", "00", "00"}

-- get_signed_long(bytes)

-- do
--     local bytes = {"01", "00", "00", "00"}

--     get_signed_long(bytes)
-- end



-- local str = "Version100"

-- print(str_to_hex(str))

-- local file = io.open("ui/button_cycle")
-- local block_num = 10
-- while true do
--     local bytes = file:read(block_num)
--     if not bytes then break end

--     for b in string.gfind(bytes, ".") do
--         print(b)
--         print(string.byte(b))
--         local byte = string.format("%02X", string.byte(b))
--         --print(byte)
--         --data = data .. " " .. byte
--         --data[#data+1] = byte
--     end
-- end

-- local b = "g"
-- print(b)
-- b = string.byte(b)
-- print(b)
-- b = string.char(b)
-- print(b)

function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local b = "84 03 00 00"
print(b:fromhex())
-- local b = "6F"
-- print(b)
-- b = string.char(tonumber(b))
-- print(b)
-- b = string.char(tonumber(b, 16))
-- print(b)


--[[local str = "84030000"
print(str)

local bin = str:fromhex()
print(bin)

local test = struct.pack("s", bin)

print(test)]]