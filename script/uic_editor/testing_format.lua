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


-- local my_num = 1920
-- local my_hex = int32_to_hex(my_num)
-- print(my_hex)

-- print("fuck yes")
-- for i = 1,0 do
--     print("my Test")
-- end
-- print('fuck no')

-- local str 

-- function float2hex (n)
--     if n == 0.0 then return 0.0 end

--     local sign = 0
--     if n < 0.0 then
--         sign = 0x80
--         n = -n
--     end

--     local mant, expo = math.frexp(n)
--     local hext = {}

--     if mant ~= mant then
--         hext[#hext+1] = string.char(0xFF, 0x88, 0x00, 0x00)

--     elseif mant == math.huge or expo > 0x80 then
--         if sign == 0 then
--             hext[#hext+1] = string.char(0x7F, 0x80, 0x00, 0x00)
--         else
--             hext[#hext+1] = string.char(0xFF, 0x80, 0x00, 0x00)
--         end

--     elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
--         hext[#hext+1] = string.char(sign, 0x00, 0x00, 0x00)

--     else
--         expo = expo + 0x7E
--         mant = (mant * 2.0 - 1.0) * math.ldexp(0.5, 24)
--         hext[#hext+1] = string.char(sign + math.floor(expo / 0x2),
--                                     (expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
--                                     math.floor(mant / 0x100) % 0x100,
--                                     mant % 0x100)
--     end

--     return tonumber(
--         string.gsub(table.concat(hext),"(.)",
--             function (c) 
--                 return string.format("%02X%s",string.byte(c),"") 
--             end
--         ),
--         16
--     )
-- end


-- function hex2float (c)
--     if c == 0 then return 0.0 end
--     local c = string.gsub(string.format("%X", c),"(..)",function (x) return string.char(tonumber(x, 16)) end)
--     local b1,b2,b3,b4 = string.byte(c, 1, 4)
--     local sign = b1 > 0x7F
--     local expo = (b1 % 0x80) * 0x2 + math.floor(b2 / 0x80)
--     local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4

--     if sign then
--         sign = -1
--     else
--         sign = 1
--     end

--     local n

--     if mant == 0 and expo == 0 then
--         n = sign * 0.0
--     elseif expo == 0xFF then
--         if mant == 0 then
--             n = sign * math.huge
--         else
--             n = 0.0/0.0
--         end
--     else
--         n = sign * math.ldexp(1.0 + mant / 0x800000, expo - 0x7F)
--     end

--     return n
-- end

-- function intToHex(IN)
--     local B,K,OUT,I=16,"0123456789ABCDEF","",0
--     local D
--     while IN>0 do
--         I=I+1
--         IN,D=math.floor(IN/B),math.mod(IN,B)+1
--         OUT=string.sub(K,D,D)..OUT
--     end

--     OUT = "0x" .. OUT
--     return OUT
-- end

-- print (float2hex(1))
-- local hex = float2hex(1)
-- print(hex)
-- print(intToHex(hex))
-- print(hex2float("0x3F800000"))


local my_obj = {
    key = "bloop",
    is_root = function() return true end,
}

local your_obj = {
    key = "bloop",
    is_root = function() return false end,
}

local mein_obj = {
    key = "blorp",
    -- is_root = function() return true end,
}

local objs = {my_obj, mein_obj, your_obj}

for i = 1, #objs do
    local obj = objs[i]

    if (obj.key == "bloop" and obj.is_root()) or obj.key ~= "bloop" then
        print(obj.key)
    end
end