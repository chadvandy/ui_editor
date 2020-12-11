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

-- local b = "84 03 00 00"
-- print(b:fromhex())
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

local function hex_to_int32(hex)
    local str = ""
    for i = #hex,1,-1 do
        str = str .. hex[i]
    end

    local ret = tonumber(str, 16)

    return ret
end

local function int32_to_hex(int32)
    print(int32)

    local hex = string.format("%X", int32)
    print(hex)

    local len = hex:len()

    for _ = 1, 8 - len do
        hex = "0" .. hex
    end

    local data = {}
    for i = 2,8,2 do
        local c = hex:sub(i-1,i)
        data[#data+1] = c
    end

    local str = ""
    for i = #data,1,-1 do
        str = str .. data[i]
    end

    -- local str = ""
    -- for i = 8,1,-1 do
    --     local c = hex:sub(i,i)
    --     str = str .. c
    -- end

    return str
end

-- local hex = {"80", "07", "00", "00"}
-- local int32 = hex_to_int32(hex)
-- print(int32)


local my_num = 1920
local my_hex = int32_to_hex(my_num)
print(my_hex)

print("fuck yes")
for i = 1,0 do
    print("my Test")
end
print('fuck no')

local str 