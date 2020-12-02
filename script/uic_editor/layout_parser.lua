-- this is the actual functionality that takes a table of hexadecimal fields, runs through them, and constructs some sort of meaningful shit out of it
-- it starts by creating a new UIC class, adding all of the hexadecimal fields into it, and then it runs through and constructs further objects within - creating a "state" object for each state, so on
-- each UIC class has its own fields for editing, tooltipping, and display

-- the layout_parser also is where all the internal versioning is, and if all goes well, is the only file that needs updating each CA patch (when a new UIC version is introduced).


local ui_editor_lib = core:get_static_object("ui_editor_lib")

local parser = {
    name = "blorp",
    data = nil,             -- this is the saved hex data, cleared on every call

    root_uic = nil,         -- this is the saved UIC object which contains every field and baby class, also cleared on every call
    location = 1,           -- used to jump through the hex bytes
}

function parser:str16_to_chunk(str)
    -- first, grab the length
    local hex_str = ""

    local len = str:len()

    ModLog("Length of str: "..len)
    local hex_len = string.format("%02X", len) ..  "00"

    ModLog("Hex len of str: "..hex_len)

    hex_str = hex_len

        -- loop through each char in the string
        for i = 1, len do
            local c = str:sub(i, i)
            -- print(c)
            ModLog(c)
    
            -- string.byte converts the character (ie. "r") to the binary data, and then string.format turns the binary byte into a hexadecimal value
            -- it's done this way so it can be one long, consistent hex string, then turned completely into a bin string
            c = string.format("%02X", string.byte(c)) .. "00"
    
            -- the "00" is added padding for str16's
    
            hex_str = hex_str .. c
        end
    
        -- loops through every single hex byte (ie. everything with two hexa values, %x%x), then converts that byte into the relevant "char"
        -- for byte in hex_str:gmatch("%x%x") do
        --     -- print(byte)
    
        --     local bin_byte = string.char(tonumber(byte, 16))
    
        --     -- print(bin_byte)
    
        --     bin_str = bin_str .. bin_byte
        -- end
    
        -- ModLog(bin_str)
    
        return hex_str
end


-- parsers here (translate raw hex into actual data, and vice versa)
function parser:str_to_chunk(str)
    -- TODO errmsg if not a string or whatever?

    -- first, grab the length
    local hex_str = ""

    local len = str:len()

    ModLog("Length of str: "..len)
    local hex_len = string.format("%02X", len) ..  "00"

    ModLog("Hex len of str: "..hex_len)

    hex_str = hex_len

    -- loop through each char in the string
    for i = 1, len do
        local c = str:sub(i, i)
        -- print(c)
        ModLog(c)

        -- string.byte converts the character (ie. "r") to the binary data, and then string.format turns the binary byte into a hexadecimal value
        -- it's done this way so it can be one long, consistent hex string, then turned completely into a bin string
        c = string.format("%02X", string.byte(c))

        hex_str = hex_str .. c
    end

    -- loops through every single hex byte (ie. everything with two hexa values, %x%x), then converts that byte into the relevant "char"
    -- for byte in hex_str:gmatch("%x%x") do
    --     -- print(byte)

    --     local bin_byte = string.char(tonumber(byte, 16))

    --     -- print(bin_byte)

    --     bin_str = bin_str .. bin_byte
    -- end

    -- ModLog(bin_str)

    return hex_str
end

-- little-endian, four-bytes number. 00 00 80 3F -> 1, 00 00 00 40 -> 2, 00 00 80 40 -> 3, no clue what the patter here is.
-- TODO make this!
function parser:chunk_to_float(j, k)

end

-- converts a series of hexadecimal bytes (between j and k) into a string
-- takes an original 2 bytes *before* the string as the "len" identifier.
function parser:chunk_to_str(j, k)
    ModLog("chunk to str "..tostring(j) .. " & "..tostring(k))

    local start_j = j

    -- only perform this stuff if there's a -1 k provided
    if k == -1 then
        -- first two bytes are the length identifier
        local len = self:chunk_to_int8(j, j+1)
        ModLog("len is: "..len)

        -- if the len is 0, then just return a string of "" (for optional strings)
        if len == 0 then ModLog(tostring(j)) ModLog(tostring(j+1)) return "\"\"", self:chunk_to_hex(j, j+1), j+1 end


        -- set k to the proper spot
        k = len + self.location -1
        ModLog(tostring(j)) ModLog(tostring(k))

        -- move j and k up by 2 (for the length above)
        j = j + 2
        k = k + 2
        ModLog(tostring(j)) ModLog(tostring(k))
    end

    -- adds each relevant hexadecimal byte into a table (only the string!)
    local block = {}
    for i = j, k do
        block[i] = self.data[i]
    end

    -- run through that table and convert the hex into formatted strings (\x56 from 56, for instance)
    local str = ""
    for i = j, k do
        str = str .. "\\x" .. block[i]
    end

    -- for each pattern of formatted strings (`\x56`), convert it into its char'd form
    -- tonumber(x,16) changes the number (56) to its place in binary (86) into the ASCII char (V)
    local ret = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)
    local hex = self:chunk_to_hex(start_j, k) -- start at the BEGINNING of "len", end at the end of the string

    return ret,hex,k
end

-- converts a length of text into a string-16 (which is, in hex, a string with empty 00 bytes between each character)
function parser:chunk_to_str16(j, k)
    -- first two bytes are the length identifier (tells the game how long the incoming string is)

    local start_j = j
    if k == -1 then
        local len = self:chunk_to_int8(j, j+1)

        -- if the len is 0, then just return a string of "" (for optional strings)
        if len == 0 then return "\"\"", self:chunk_to_hex(j, j+1), j+1 end

        -- double "len", since it's counting every 2-byte chunk (ie. a length of 4 would be "56 00 12 00 53 00 12 00")
        len = len*2

        -- set k to the proper spot
        k = len + self.location -1

        -- move j and k up by 2 (offset them by the length identifier above)
        j = j + 2 k = k + 2
    end

    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    local str = ""
    for i = j,k,2 do -- the "2" iterates by 2 instead of 1, so it'll skip every unwanted 00
        str = str .. "\\x" .. block[i]
    end

    local ret = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)
    local hex = self:chunk_to_hex(start_j, k)

    return ret,hex,k
end

-- turn the table of text into a single string (ie. {84, 03, 00 00} into "84 03 00 00")
function parser:chunk_to_hex(j, k)
    local block = {}
    for i = j,k do
        block[i] = tostring(self.data[i])
    end

    local ret = table.concat(block, " ", j, k)
    local hex = ret

    return ret,hex,k
end

-- takes two bytes and turns them into a Lua number
-- always an unsigned int8, which means it's a hex byte converted into a number followed by an empty 00
-- this is "little endian", which means the hex is actually read backwards. ie., 56 00 is actually read as 00 56, which is translated to 00 86 in base-16
function parser:chunk_to_int8(j, k)
    -- TODO int8 should only take numbers 1 apart from each other, it can only be two bytes. error check that
    ModLog("chunk to int8 between "..tostring(j).." and " ..tostring(k))

    -- grab the relevant bytes
    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    -- flip the bytes! (changed 56 00 to 00 56, still a table)
    local flipped = {}
    for i = k,j,-1 do -- loop backwards, starting at the end and going to the start by -1 each loop (ie. from 2 to 1, lol)
        flipped[#flipped+1] = tostring(block[i])
    end

    -- take the bytes and turn them into a string (ie. "0056")
    local str = table.concat(flipped, "", 1, #flipped)

    local ret = tonumber(str, 16)
    local hex = self:chunk_to_hex(j, k)

    -- turn the string into a number, using base-16 to convert it (which turns "0056" into 86, since tonumber drops excess 0's)
    return ret,hex,k
end

-- convert a 4-byte hex section into an integer
-- this part is a little weird, since integers like this are actually read backwards in hex (little-endian). ie., 84 03 00 00 in hex is read as 00 00 03 84, which ends up being 03 84, which is converted into 900
function parser:chunk_to_int16(j, k)
    -- TODO int16's can only be 4-bytes!

    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    local str = ""

    for i = k,j, -1 do
        str = str .. block[i]
    end

    local ret = tonumber(str, 16)
    local hex = self:chunk_to_hex(j, k)

    return ret,hex,k
end

-- convert a single byte into true or false. 00 for false, 01 for true
function parser:chunk_to_boolean(j, k)
    local hex = self:chunk_to_hex(j, k)

    local ret = false
    if hex == "01" then
        ret = true
    end

    return ret,hex,k
end

function parser:decipher_chunk(format, j, k)
    if is_nil(j) then j = 1 end
    if is_nil(k) then k = -1 end
    j = j + self.location - 1
    if k ~= -1 then
        k = k + self.location - 1
    end

    local format_to_func = {
        ----- native types -----
    
        -- string types (hex is a string-ified set of hexadecimal bytes, ie "84 03 00 00")
        str = parser.chunk_to_str,
        str16 = parser.chunk_to_str16,
        hex = parser.chunk_to_hex,

        -- number types!
        int8 = parser.chunk_to_int8,
        int16 = parser.chunk_to_int16,

        -- boolean (with a pseudonym)
        bool = parser.chunk_to_boolean,
        boolean = parser.chunk_to_boolean,
    }

    ModLog("deciphering chunk ["..tostring(j).." - "..tostring(k) .. "], with format ["..format.."]")

    local func = format_to_func[format]
    if not func then ModLog("func not found") return end

    -- this returns the *value* searched for, the string'd hex of the chunk, and the start and end indices (needed for types such as strings or tables with unknown lengths before deciphering)
    local value,hex,end_k = func(self, j, k)

    -- set location to k+1, for next decipher_chunk call
    self.location = end_k+1

    return value,hex
end

-- shorthand to prevent typing the same thing a billions
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

-- function parser:decipher_component()

-- end

-- function parser:decipher_component_mouse_sth()

-- end

-- function parser:decipher_component_mouse()

-- end

-- function parser:decipher_component_image_metric()

-- end


-- function parser:decipher_component_state()

-- end

-- function parser:decipher_component_image()

-- end

-- function parser:decipher_component_property()

-- end

-- function parser:decipher_component_function_animation()

-- end

-- function parser:decipher_component_function()

-- end

function parser:decipher_collection(collected_type, obj_to_add)
    if not is_string(collected_type) then
        -- errmsg
        return false
    end

    -- turns it from "ComponentImage" to "ComponentImages", very simply
    local key = collected_type.."s"

    -- TODO I can do better than this
    if collected_type == "ComponentProperty" then
        key = "ComponentProperties"
    end

    -- local hex = ""

    ModLog("\ndeciphering "..collected_type)

    -- local type_to_func = {
    --     Component =                 parser.decipher_component,
    --     ComponentImage =            parser.decipher_component_image,
    --     ComponentState =            parser.decipher_component_state,
    --     ComponentImageMetric =      parser.decipher_component_image_metric,
    --     ComponentMouse =            parser.decipher_component_mouse,
    --     ComponentProperty =         parser.decipher_component_property,
    --     ComponentFunction =         parser.decipher_component_function,
    --     ComponentFunctionAnimation = parser.decipher_component_function_animation,
    --     ComponentMouseSth =         parser.decipher_component_mouse_sth,
    -- }

    -- local func = type_to_func[collected_type]

    -- every collection starts with an int16 (four bytes) to inform how much of that thing is within
    local len,hex = dec(collected_type.."len","int16", 4, obj_to_add):get_value()--self:decipher_chunk("int16", 1, 4)

    ModLog("len of "..collected_type.." is "..len)

    -- if none are found, just return 0 / "00 00 00 00"
    if len == 0 then
        return len,hex--,4
    end

    local ret = {}

    for i = 1, len do
        local new_type = ui_editor_lib.new_obj(collected_type)
        local val = new_type:decipher()

        --local val,new_hex,end_k = func(self)

        -- set the key as, example, "ComponentMouse1" (if there's no ui-id or name set!)
        val:set_key(collected_type..tostring(i), "index")
        ModLog("created "..collected_type.." with key "..val:get_key())

        ret[#ret+1] = val
        --hex = hex .. new_hex
    end

    -- containers don't take raw hex (only needed for individual lines!)
    local container = ui_editor_lib.new_obj("Container", key, ret)
    --ui_editor_lib.classes.Container:new(key, ret)

    -- TODO do this within the :decipher() method on each type? ie. `self:add_data(obj:decipher_collection("ComponentImage"))` less shit to pass around.
    obj_to_add:add_data(container)

    return container--,hex
end

-- key here is a unique ID so the field can be saved into the root uic. key also references the relevant tooltip and text localisations
-- format is the type you're expecting - hex, str, int16, etc. Can also be the Lua object type - ie., "ComponentImage". If a native type is provided, a "Field" is returned
-- k is the end searched location. ie., if you're looking at a 4-byte field, k should be 4. k default to -1, for "unknown length". k can be a k/v table as well, for fields with multiple data inside (ie. offsets). it should be a k/v table with keys linked to lengths (ie. {x=4,y=4})
-- obj is the object it's being added to (ie. is this field in a specific state, or component, or WHAT). Defaults to the root uic obj
function parser:dec(key, format, k, obj)
    local j = 1 -- always start at the first byte!

    if is_nil(k) then     k = -1              end         -- assume k is -1 when undefined
    if is_nil(obj) then   obj = self.root_uic end         -- assume the referenced object is the root component

    local new_field = nil

    -- if k is a table, decipher the chunks through a loop
    if is_table(k) then
        local val = {}
        local hex_boi = ""
        for i_key,v in pairs(k) do
            -- "v" is the end location here
            local ret,hex = self:decipher_chunk(format, j, v)
            val[i_key]=ret
            hex_boi=hex_boi.." "..hex
        end

        new_field = ui_editor_lib.classes.Field:new(key, val, hex_boi)
        ModLog("chunk deciphered with key ["..key.."], the hex was ["..hex_boi.."]")
    else -- k is not a table, decipher normally
        local ret,hex = self:decipher_chunk(format, j, k)

        new_field = ui_editor_lib.classes.Field:new(key, ret, hex)
        ModLog("chunk deciphered with key ["..key.."], the hex was ["..hex.."]")
    end

    new_field:set_native_type(format)

    return obj:add_data(new_field)
end

-- this function goes through the entire hexadecimal table, and translates each bit within into the relevant Lua object
-- this means the entire layout file is turned into a "root_uic" Lua object, which has methods to get all states, all children, all the children's states, etc., etc., as well as methods for display and getting specific fields
-- each Lua object holds other important data, such as the raw hex associated with that field
-- this function needs to be updated with any new UIC version created
-- function parser:decipher()
--     if is_nil(self.data) then
--         -- errmsg
--         return false
--     end

--     ModLog("decipher name: "..self.name)

--     local root_uic = self.root_uic

--     self:decipher_component(true)

--     return root_uic
-- end

setmetatable(parser, {
    __index = parser,
    __call = function(self, hex_table) -- called by using `parser(hex_table)`, where hex_table is an array with each hex byte set as a string in order ("t" here is a reference to the "parser" table itself)
        -- ModLog("yay")
        -- ModLog(self.name)

        -- self.name = "new name"

        -- ModLog(self.name)

        -- TODO verify the hex table first?

        local root_uic = ui_editor_lib.classes.Component:new()
        root_uic:set_is_root(true)

        self.data =       hex_table
        self.root_uic =   root_uic
        self.location =   1

        -- go right into deciphering! (returns the root_uic created!)
        return root_uic:decipher()
    end
})


return parser