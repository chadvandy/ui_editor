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

local bytes = {"84", "03", "00", "00"}

get_signed_long(bytes)

do
    local bytes = {"01", "00", "00", "00"}

    get_signed_long(bytes)
end

--[[local str = "84030000"
print(str)

local bin = str:fromhex()
print(bin)

local test = struct.pack("s", bin)

print(test)]]