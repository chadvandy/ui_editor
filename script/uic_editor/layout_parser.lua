local nums = {}


-- push the location up each chunk_to_str, so when we run chunk_to_str(1, 10), location gets changed to 11.
-- next time we use chunk_to_str, we can use chunk_to_str(1, 4), to get the *next* four bytes. saves using wildly large numbers
local location = 1

-- converts a series of hexadecimal bytes (between j and k) into a string
local function chunk_to_str(j, k)
    -- adds each hexadecimal byte into a table
    local block = {}
    for i = j, k do
        block[i] = nums[i]
    end

    -- run through that table and convert the hex into formatted strings (\x56 from 56, for instance)
    local str = ""
    for i = j, k do
        str = str .. "\\x" .. block[i]
    end

    -- for each pattern of formatted strings (`\x56`), convert it into its char'd form
    -- tonumber(x,16) changes the number (56) to its place in binary (86) into the ASCII char (V)
    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)

    ---- this was within the above function(x) to test the statements
    -- local first = true
    -- if first then print(x) print(tonumber(x,16)) print(string.char(tonumber(x,16))) first = false end
    return str
end

local function chunk_to_hex(j, k)
    local block = {}
    for i = j,k do
        block[i] = nums[i]
    end

    local str = table.concat(block, " ", j, k)

    return str
end

-- take a chunk of the bytes and turn them into a length number
-- always an unsigned int4, which means it's a hex byte converted into a number followed by an empty 00
-- ie., 56 00 is translated into 86 length
local function chunk_to_len(j, k)

    -- get the hex string for this section
    local len = chunk_to_hex(j, k)

    -- cut out the "00"
    len = string.sub(len, 1, 2)

    -- turn the hex string into the real number (ie. 56 -> 86)
    len = tonumber(len, 16)

    return len
end

local function chunk_to_int16(j, k)
    local block = {}
    for i = j,k do
        block[i] = nums[i]
    end

    local str = ""

    for i = k,j, -1 do
        str = str .. block[i]
    end

    str = tonumber(str, 16)
    return str
end


local function decipher_chunk(format, j, k)
    j = j + location - 1
    k = k + location - 1

    --print(j)
    --print(k)

    local retval = nil

    if format == "str" then
        retval = chunk_to_str(j, k)
    end

    if format == "hex" then
        retval = chunk_to_hex(j, k)
    end

    if format == "len" then
        retval = chunk_to_len(j, k)
    end

    if format == "int16" then
        retval = chunk_to_int16(j, k)
    end

    -- set location to k+1, for next chunk_to_str call
    location = k+1

    return retval
end

local function decipher_file(file_path)
    print("deciphering: "..file_path)

    local example_file = assert(io.open(file_path, "rb+"))

    local data = ""
    nums = {}
    location = 1

    local block_num = 10
    while true do
        local bytes = example_file:read(block_num)
        if not bytes then break end

        for b in string.gfind(bytes, ".") do
            local byte = string.format("%02X", string.byte(b))

            data = data .. " " .. byte
            nums[#nums+1] = byte
        end
    end

    example_file:close()

    print(data)

    -- first 10 bytes are always the version string - "Version102"
    local v = decipher_chunk("str", 1, 10)
    print(v)

    -- grab the last 3 digits - "102"
    local v_num = tonumber(string.sub(v, 8, 10))
    print(v_num)

    -- next 4 bytes are the UI-ID for the "root" component
    local root_uid = decipher_chunk("hex", 1, 4)
    print(root_uid)

    -- next 2 bytes are the length for the next string (unsigned int followed by 00), followed by the string itself (the UIC name)
    do
        local len = decipher_chunk("len", 1, 2) -- 1,2) used so the location goes beyond the 00
        print(len)

        -- read the name by checking 1,len
        local name = decipher_chunk("str", 1, len)
        print(name)
    end

    -- next 2 bytes are the length for the next string (b0, undeciphered), followed by the string itself
    -- this is optional, which means it might just be 00 00
    do
        local len = decipher_chunk("len", 1, 2)
        print(len)

        if len == 0 then
            -- there is nothing in this undeciphered chunk
            print("there is nothing in this undeciphered chunk")
        else
            local b0 = decipher_chunk("str", 1, len)
            print(b0)
        end
    end

    -- next section is the Events string

    -- between 100-110, there is no "num events"; it's just a single long string
    if v_num >= 100 and v_num < 110 then
        local len = decipher_chunk("len", 1, 2)

        print(len)

        if len == 0 then
            print("no event found")
        else
            local event = decipher_chunk("str", 1, len)
            print(event)
        end

    -- upwards, there is a "num events" integer, which is followed by that many individual strings with individual length indicators
    elseif v_num >= 110 and v_num < 130 then

    end

    -- next section is the offsets; two 4-byte sequences for the x-offset and y-offset
    -- they are int16's (4-byte, signed ie. positive or negative)
    do
        local x = decipher_chunk("int16", 1, 4)
        local y = decipher_chunk("int16", 1, 4)

        print(x)
        print(y)
    end

    -- next section is undeciphered b1, which is only available between 70-89
    if v_num >= 70 and v_num < 90 then
        
    end
end

decipher_file("ui/bullet_point")
decipher_file("ui/button_cycle")
--s=[[hello \x77\x6f\x72\x6c\x64]]
--[[s=s:gsub("\\x(%x%x)",function (x) return string.char(tonumber(x,16)) end)
print(s)]]