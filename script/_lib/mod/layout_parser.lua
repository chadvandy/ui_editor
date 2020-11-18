local parser = {
    loaded_uic = nil,
    loaded_uic_path = nil,
}

function parser.init()
    local path = "script/uic_editor/classes/"
    parser.ui = require(path.."ui_panel")
    parser.uic_class = require(path.."uic_class")
end

function parser.load_uic_with_path(path)
    if not is_string(path) then
        -- errmsg
        return false
    end

    local file = assert(io.open(path, "rb+"))
    if not file then
        ModLog("file not found!")
        return false
    end

    local data = ""
    local nums = {}
    --local location = 1

    local block_num = 10
    while true do
        local bytes = file:read(block_num)
        if not bytes then break end

        for b in string.gfind(bytes, ".") do
            local byte = string.format("%02X", string.byte(b))

            data = data .. " " .. byte
            nums[#nums+1] = byte
        end
    end

    file:close()

    local uic = parser.uic_class:new_with_data(data, nums)
    parser.loaded_uic = uic
    parser.loaded_uic_path = path

    parser.ui:load_uic()
end

-- parsers here (translate raw hex into actual data)
-- converts a series of hexadecimal bytes (between j and k) into a string
function parser.chunk_to_str(obj, j, k)
    -- adds each hexadecimal byte into a table
    local block = {}
    for i = j, k do
        block[i] = obj.bytes[i]
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

function parser.chunk_to_str16(obj, j, k)
    local block = {}
    for i = j,k do
        block[i] = obj.bytes[i]
    end

    local str = ""
    for i = j,k,2 do -- the "2" iterates by 2 instead of 1, so it'll skip every unwanted 00
        str = str .. "\\x" .. block[i]
    end

    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)

    return str
end

function parser.chunk_to_hex(obj, j, k)
    local block = {}
    for i = j,k do
        block[i] = obj.bytes[i]
    end

    -- turn the table of numbers (ie. {84, 03, 00, 00}) into a string with spaces between each (ie. "84 03 00 00")
    local str = table.concat(block, " ", j, k)

    return str
end

-- take a chunk of the bytes and turn them into a length number
-- always an unsigned int4, which means it's a hex byte converted into a number followed by an empty 00 (or three empty 00's)
-- ie., 56 00 is translated into 86 length (as is 56 00 00 00)
function parser.chunk_to_len(obj, j, k)

    -- get the hex string for this section
    local len = parser.chunk_to_hex(obj, j, k)

    -- cut out the "00"
    len = string.sub(len, 1, 2)

    -- turn the hex string into the real number (ie. 56 -> 86)
    len = tonumber(len, 16)

    return len
end

-- convert a 4-byte hex section into an integer
-- this part is a little weird, since integers like this are actually read backwards in hex (little-endian). ie., 84 03 00 00 in hex is read as 00 00 03 84, which ends up being 03 84, which is converted into 900
function parser.chunk_to_int16(obj, j, k)
    local block = {}
    for i = j,k do
        block[i] = obj.bytes[i]
    end

    local str = ""

    for i = k,j, -1 do
        str = str .. block[i]
    end

    str = tonumber(str, 16)
    return str
end

-- convert a single byte into true or false. 00 for false, 01 for true
function parser.chunk_to_boolean(obj, j, k)
    local hex = parser.chunk_to_hex(obj, j, k)

    local ret = false
    if hex == "01" then
        ret = true
    end

    return ret
end

core:add_static_object("layout_parser", parser)

parser.init()