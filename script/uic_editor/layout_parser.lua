-- this is the actual functionality that takes a table of hexadecimal fields, runs through them, and constructs some sort of meaningful shit out of it
-- it starts by creating a new UIC class, adding all of the hexadecimal fields into it, and then it runs through and constructs further objects within - creating a "state" object for each state, so on
-- each UIC class has its own fields for editing, tooltipping, and display

-- the layout_parser also is where all the internal versioning is, and if all goes well, is the only file that needs updating each CA patch (when a new UIC version is introduced).


local uied = core:get_static_object("ui_editor_lib")

local parser = {
    name = "blorp",
    data = nil,             -- this is the saved hex data, cleared on every call

    root_uic = nil,         -- this is the saved UIC object which contains every field and baby class, also cleared on every call
    location = 1,           -- used to jump through the hex bytes

    field_count = 0,
}

-- create a 4-byte hex code (ie. "AF 52 C4 DE"), randomly
function parser:regenerate_uiid()
    local hexes = {
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "A",
        "B",
        "C",
        "D",
        "E",
        "F",
    }

    local bytes = {}

    math.randomseed(os.time())

    for i = 1,8 do
        local c = hexes[math.random(1, #hexes)]

        bytes[#bytes+1] = c
    end

    local str = table.concat(bytes, "")

    return str
end

function parser:bool_to_chunk(bool)
    if not is_boolean(bool) then
        -- errmsg
        return false
    end

    local hex_str = ""

    if bool == true then hex_str = "01" elseif bool == false then hex_str = "00" end

    return hex_str
end

function parser:utf8_to_chunk(str)
    -- first, grab the length
    local hex_str = ""

    local len = str:len()

    uied:log("Length of str: "..len)
    local hex_len = string.format("%02X", len)-- ..  "00"

    for _ = 1, 4-hex_len:len() do
        hex_len = hex_len .. "0"
    end

    uied:log("Hex len of str: "..hex_len)

    hex_str = hex_len

    -- loop through each char in the string
    for i = 1, len do
        local c = str:sub(i, i)
        -- print(c)
        uied:log(c)

        -- string.byte converts the character (ie. "r") to the binary data, and then string.format turns the binary byte into a hexadecimal value
        -- it's done this way so it can be one long, consistent hex string, then turned completely into a bin string
        c = string.format("%02X", string.byte(c)) .. "00"

        -- the "00" is added padding for utf8's

        hex_str = hex_str .. c
    end

    -- loops through every single hex byte (ie. everything with two hexa values, %x%x), then converts that byte into the relevant "char"
    -- for byte in hex_str:gmatch("%x%x") do
    --     -- print(byte)

    --     local bin_byte = string.char(tonumber(byte, 16))

    --     -- print(bin_byte)

    --     bin_str = bin_str .. bin_byte
    -- end

    -- uied:log(bin_str)

    return hex_str
end

-- parsers here (translate raw hex into actual data, and vice versa)
function parser:str_to_chunk(str)
    -- TODO errmsg if not a string or whatever?

    -- first, grab the length
    local hex_str = ""

    local len = str:len()

    uied:log("Length of str: "..len)
    local hex_len = string.format("%02X", len)-- ..  "00"

    for _ = 1, 4-hex_len:len() do
        hex_len = hex_len .. "0"
    end

    uied:log("Hex len of str: "..hex_len)

    hex_str = hex_len

    -- loop through each char in the string
    for i = 1, len do
        local c = str:sub(i, i)
        -- print(c)
        uied:log(c)

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

    -- uied:log(bin_str)

    return hex_str
end

function parser:int16_to_chunk(int)
    local hex = string.format("%X", int)
    
    if hex:len() < 4 then
        for _ = 1, 4 - hex:len() do
            hex = "0" .. hex
        end
    end

    local data = {}
    for i = 2,4,2 do
        local c = hex:sub(i-1, i)
        data[#data+1] = c
    end

    local str = ""
    for i = #data,1,-1 do
        str = str .. data[i]
    end

    return str
end

-- takes an integer and turns it into the relevant hex
function parser:int32_to_chunk(int)
    -- convert the integer into a hex right away.
    -- this converts "1920" into "780"
    local hex = string.format("%X", int)

    -- add in padding to get the number up to 4 total bytes
    -- becomes "00000780"
    if hex:len() < 8 then
        for _ = 1, 8 - hex:len() do
            hex = "0" .. hex
        end
    end

    -- split the full string into the 4 separate bytes
    -- ie., {00, 00, 07, 80}
    local data = {}
    for i = 2,8,2 do
        local c = hex:sub(i-1,i)
        data[#data+1] = c
    end

    -- recreate the string with little endian (so the smallest byte is first, largest byte is last)
    -- ie., "80070000" (the correct version!)
    local str = ""
    for i = #data,1,-1 do
        str = str .. data[i]
    end

    return str
end

-- https://stackoverflow.com/questions/18886447/convert-signed-ieee-754-float-to-hexadecimal-representation
-- thanks internet
local function float2hex (n)
    if n == 0.0 then return 0.0 end

    local sign = 0
    if n < 0.0 then
        sign = 0x80
        n = -n
    end

    local mant, expo = math.frexp(n)
    local hext = {}

    if mant ~= mant then
        hext[#hext+1] = string.char(0xFF, 0x88, 0x00, 0x00)

    elseif mant == math.huge or expo > 0x80 then
        if sign == 0 then
            hext[#hext+1] = string.char(0x7F, 0x80, 0x00, 0x00)
        else
            hext[#hext+1] = string.char(0xFF, 0x80, 0x00, 0x00)
        end

    elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
        hext[#hext+1] = string.char(sign, 0x00, 0x00, 0x00)

    else
        expo = expo + 0x7E
        mant = (mant * 2.0 - 1.0) * math.ldexp(0.5, 24)
        hext[#hext+1] = string.char(sign + math.floor(expo / 0x2),
                                    (expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
                                    math.floor(mant / 0x100) % 0x100,
                                    mant % 0x100)
    end

    return tonumber(string.gsub(table.concat(hext),"(.)",
                                function (c) return string.format("%02X%s",string.byte(c),"") end), 16)
end

local function hex2float (c)
    if c == 0 then return 0.0 end
    local c = string.gsub(string.format("%X", c),"(..)",function (x) return string.char(tonumber(x, 16)) end)
    local b1,b2,b3,b4 = string.byte(c, 1, 4)
    local sign = b1 > 0x7F
    local expo = (b1 % 0x80) * 0x2 + math.floor(b2 / 0x80)
    local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4

    if sign then
        sign = -1
    else
        sign = 1
    end

    local n

    if mant == 0 and expo == 0 then
        n = sign * 0.0
    elseif expo == 0xFF then
        if mant == 0 then
            n = sign * math.huge
        else
            n = 0.0/0.0
        end
    else
        n = sign * math.ldexp(1.0 + mant / 0x800000, expo - 0x7F)
    end

    return n
end

local function intToHex(IN)
    local B,K,OUT,I=16,"0123456789ABCDEF","",0
    local D
    while IN>0 do
        I=I+1
        IN,D=math.floor(IN/B),math.mod(IN,B)+1
        OUT=string.sub(K,D,D)..OUT
    end


    OUT = "0x" .. OUT
    return OUT
end

function parser:float_to_hex(float)
    local int = float2hex(float)

    local hex = intToHex(int)

    return hex
end

-- little-endian, four-bytes number. 00 00 80 3F -> 1, 00 00 00 40 -> 2, 00 00 80 40 -> 3, no clue what the patter here is.
-- TODO make this!
function parser:chunk_to_float(j, k)
    -- for now, just do int32, fuck it
    -- grab the relevant bytes

    -- for now, disbable it for int32
    do
        return self:chunk_to_int32(j, k)
    end

    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    -- flip the bytes! (changed 56 00 to 00 56, still a table)
    local flipped = {}
    for i = k,j,-1 do -- loop backwards, starting at the end and going to the start by -1 each loop (ie. from 2 to 1, lol)
        flipped[#flipped+1] = tostring(block[i])
    end

    local str = "0x"..table.concat(flipped, "")
    uied:log("Hex for float at ["..j.."] ["..k.."] is ["..str.."].")

    local float = hex2float(str)
    local hex = self:chunk_to_hex(j, k)

    return float,hex,k
end

-- converts a series of hexadecimal bytes (between j and k) into a string
-- takes an original 2 bytes *before* the string as the "len" identifier.
function parser:chunk_to_str(j, k)
    uied:log("chunk to str "..tostring(j) .. " & "..tostring(k))

    local start_j = j

    -- only perform this stuff if there's a -1 k provided
    if k == -1 then
        -- first two bytes are the length identifier
        local len = self:chunk_to_int16(j, j+1)
        uied:log("len is: "..len)

        -- if the len is 0, then just return a string of "" (for optional strings)
        if len == 0 then uied:log(tostring(j)) uied:log(tostring(j+1)) return "\"\"", self:chunk_to_hex(j, j+1), j+1 end


        -- set k to the proper spot
        k = len + self.location -1
        uied:log(tostring(j)) uied:log(tostring(k))

        -- move j and k up by 2 (for the length above)
        j = j + 2
        k = k + 2
        uied:log(tostring(j)) uied:log(tostring(k))
    end

    -- adds each relevant hexadecimal byte into a table (only the string!)
    local block = {}
    for i = j, k do
        block[i] = self.data[i]
    end

    -- run through that table and convert the hex into formatted strings (\x56 from 56, for instance)
    local str = ""
    for i = j, k do
        str = str .. "\\x" .. (block[i] or "")
    end

    -- for each pattern of formatted strings (`\x56`), convert it into its char'd form
    -- tonumber(x,16) changes the number (56) to its place in binary (86) into the ASCII char (V)
    local ret = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)
    local hex = self:chunk_to_hex(start_j, k) -- start at the BEGINNING of "len", end at the end of the string

    return ret,hex,k
end

-- converts a length of text into a string-16 (which is, in hex, a string with empty 00 bytes between each character)
function parser:chunk_to_utf8(j, k)
    -- first two bytes are the length identifier (tells the game how long the incoming string is)

    local start_j = j
    if k == -1 then
        local len = self:chunk_to_int16(j, j+1)

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
-- always an unsigned int16, which means it's a hex byte converted into a number followed by an empty 00
-- this is "little endian", which means the hex is actually read backwards. ie., 56 00 is actually read as 00 56, which is translated to 00 86 in base-16
function parser:chunk_to_int16(j, k)
    -- TODO int16 should only take numbers 1 apart from each other, it can only be two bytes. error check that
    uied:log("chunk to int16 between "..tostring(j).." and " ..tostring(k))

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
function parser:chunk_to_int32(j, k)
    -- TODO int32's can only be 4-bytes!

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
        utf8 = parser.chunk_to_utf8,
        hex = parser.chunk_to_hex,

        -- number types!
        int16 = parser.chunk_to_int16,
        int32 = parser.chunk_to_int32,
        float = parser.chunk_to_float,

        -- boolean (with a pseudonym)
        bool = parser.chunk_to_boolean,
        boolean = parser.chunk_to_boolean,
    }

    uied:log("deciphering chunk ["..tostring(j).." - "..tostring(k) .. "], with format ["..format.."]")

    local func = format_to_func[format]
    if not func then uied:log("func not found") return end

    -- this returns the *value* searched for, the string'd hex of the chunk, and the start and end indices (needed for types such as strings or tables with unknown lengths before deciphering)
    local value,hex,end_k = func(self, j, k)

    -- set location to k+1, for next decipher_chunk call
    self.location = end_k+1

    -- increase the internal field count

    uied:log("Deciphered hex is: \n\t" .. hex)
    self.field_count = self.field_count+1

    return value,hex
end

-- shorthand to prevent typing the same thing a billions
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
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

---- TODO remove "override"; it's to prevent the "templatecomponent" check within a template component. SUCKS.
function parser:decipher_collection(collected_type, obj_to_add, override)
    if not is_string(collected_type) then
        -- errmsg
        return false
    end

    -- turns it from "ComponentImage" to "ComponentImages", very simply
    local key = collected_type.."s"

    -- TODO I can do better than this
    if collected_type == "ComponentProperty" then
        key = "ComponentProperties"
    elseif collected_type == "ComponentTemplateChild" then
        key = "ComponentTemplateChildren"
    end

    -- local hex = ""

    uied:log("\ndeciphering "..key)

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

    -- every collection starts with an int32 (four bytes) to inform how much of that thing is within
    local len,hex = self:decipher_chunk("int32", 1, 4) 
    --dec(collected_type.."len","int32", 4, obj_to_add):get_value()

    uied:log("len of "..key.." is "..len)

    local ret = {}

    local collection = uied:new_obj("Collection", key)

    for i = 1, len do
        local val

        
        -- TODO templates and UIC's are really the same thing, don't treat them differently like this
        if collected_type == "Component" then
            local bits,bits_hex = self:decipher_chunk("hex", 1, 2)

            -- local bits = deciph("bits", "hex", 2):get_value() --parser:decipher_chunk("hex", 1, 2)
            if bits == "00 00" or override then
                local child = uied:new_obj("Component")
                if bits == "00 00" then
                    local new_field = uied.classes.Field:new("bits", bits, bits_hex)
                    child:add_data(new_field)
                else
                    self.location = self.location -2
                end
    
                uied:log("deciphering new component within "..obj_to_add:get_key())
                child:decipher()
    
                uied:log("component deciphered with key ["..child:get_key().."]")
    
                uied:log("adding them to the current obj, "..obj_to_add:get_key())

                val = child
            else
                self.location = self.location -2
    
                -- TODO this shouldn't be separate
                local template = uied:new_obj("ComponentTemplate")
                template:decipher()

                val = template
            end
        else

            local new_type = uied:new_obj(collected_type)
            val = new_type:decipher()

            --local val,new_hex,end_k = func(self)

            -- set the key as, example, "ComponentMouse1" (if there's no ui-id or name set!)
            val:set_key(collected_type..tostring(i), "index")
            uied:log("created "..collected_type.." with key "..val:get_key())
        end

        val:set_parent(collection)
        ret[#ret+1] = val
        --hex = hex .. new_hex
    end

    collection.data = ret

    obj_to_add:add_data(collection)

    return collection--,hex
end

-- key here is a unique ID so the field can be saved into the root uic. key also references the relevant tooltip and text localisations
-- format is the type you're expecting - hex, str, int32, etc. Can also be the Lua object type - ie., "ComponentImage". If a native type is provided, a "Field" is returned
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

        new_field = uied.classes.Field:new(key, val, hex_boi)
        uied:log("chunk deciphered with key ["..key.."], the hex was ["..hex_boi.."]")
    else -- k is not a table, decipher normally
        local ret,hex = self:decipher_chunk(format, j, k)

        new_field = uied.classes.Field:new(key, ret, hex)
        uied:log("chunk deciphered with key ["..key.."], the hex was ["..hex.."]")
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

--     uied:log("decipher name: "..self.name)

--     local root_uic = self.root_uic

--     self:decipher_component(true)

--     return root_uic
-- end

setmetatable(parser, {
    __index = parser,
    __call = function(self, hex_table) -- called by using `parser(hex_table)`, where hex_table is an array with each hex byte set as a string in order ("t" here is a reference to the "parser" table itself)
        uied:log("yay")
        uied:log(self.name)

        -- self.name = "new name"

        uied:log(self.name)

        -- TODO verify the hex table first?

        self.data = {}
        self.root_uic = nil

        local root_uic = uied.classes.Component:new()
        root_uic:set_is_root(true)

        self.data =       hex_table
        self.root_uic =   root_uic
        self.location =   1
        self.field_count = 0

        -- go right into deciphering! (returns the root_uic created!)
        return root_uic:decipher(), self.field_count
    end
})


return parser