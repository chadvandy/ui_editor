-- this is the actual functionality that takes a table of hexadecimal fields, runs through them, and constructs some sort of meaningful shit out of it
-- it starts by creating a new UIC class, adding all of the hexadecimal fields into it, and then it runs through and constructs further objects within - creating a "state" object for each state, so on
-- each UIC class has its own fields for editing, tooltipping, and display

-- the layout_parser also is where all the internal versioning is, and if all goes well, is the only file that needs updating each CA patch (when a new UIC version is introduced).

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local parser = {
    name = "blorp",
    data = nil,     -- this is the saved hex data, cleared on every call

    root_uic = nil, -- this is the saved UIC object which contains every field and baby class, also cleared on every call
    location = 1,   -- used to jump through the hex bytes
}

-- parsers here (translate raw hex into actual data)
-- converts a series of hexadecimal bytes (between j and k) into a string
function parser:chunk_to_str(j, k)
    -- adds each hexadecimal byte into a table
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
    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)

    ---- this was within the above function(x) to test the statements
    -- local first = true
    -- if first then print(x) print(tonumber(x,16)) print(string.char(tonumber(x,16))) first = false end
    return str
end

function parser:chunk_to_str16(j, k)
    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    local str = ""
    for i = j,k,2 do -- the "2" iterates by 2 instead of 1, so it'll skip every unwanted 00
        str = str .. "\\x" .. block[i]
    end

    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)

    return str
end

function parser:chunk_to_hex(j, k)
    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    -- turn the table of numbers (ie. {84, 03, 00, 00}) into a string with spaces between each (ie. "84 03 00 00")
    local str = table.concat(block, " ", j, k)

    return str
end

-- take a chunk of the bytes and turn them into a length number
-- always an unsigned int4, which means it's a hex byte converted into a number followed by an empty 00 (or three empty 00's)
-- ie., 56 00 is translated into 86 length (as is 56 00 00 00)
function parser:chunk_to_len(j, k)

    -- get the hex string for this section
    local len = self:chunk_to_hex(j, k)

    -- cut out the "00"
    len = string.sub(len, 1, 2)

    -- turn the hex string into the real number (ie. 56 -> 86)
    len = tonumber(len, 16)

    return len
end

-- convert a 4-byte hex section into an integer
-- this part is a little weird, since integers like this are actually read backwards in hex (little-endian). ie., 84 03 00 00 in hex is read as 00 00 03 84, which ends up being 03 84, which is converted into 900
function parser:chunk_to_int16(j, k)
    local block = {}
    for i = j,k do
        block[i] = self.data[i]
    end

    local str = ""

    for i = k,j, -1 do
        str = str .. block[i]
    end

    str = tonumber(str, 16)
    return str
end

-- convert a single byte into true or false. 00 for false, 01 for true
function parser:chunk_to_boolean(j, k)
    local hex = self:chunk_to_hex(j, k)

    local ret = false
    if hex == "01" then
        ret = true
    end

    return ret
end

function parser:decipher_chunk(format, j, k)
    j = j + self.location - 1
    k = k + self.location - 1

    local format_to_func = {
        str = parser.chunk_to_str,
        str16 = parser.chunk_to_str16,
        hex = parser.chunk_to_hex,
        len = parser.chunk_to_len,
        int16 = parser.chunk_to_int16,
        bool = parser.chunk_to_boolean
    }

    local func = format_to_func[format]
    if not func then ModLog("func not found") return end

    local retval = func(self, j, k)
    local hex = self:chunk_to_hex(j, k)

    -- set location to k+1, for next decipher_chunk call
    self.location = k+1

    return retval, hex
end

-- this function goes through the entire hexadecimal table, and translates each bit within into the relevant Lua object
-- this means the entire layout file is turned into a "root_uic" Lua object, which has methods to get all states, all children, all the children's states, etc., etc., as well as methods for display and getting specific fields
-- each Lua object holds other important data, such as the raw hex associated with that field
-- this function needs to be updated with any new UIC version created
function parser:decipher()
    if is_nil(self.data) then
        -- errmsg
        return false
    end

    local root_uic = self.root_uic

    -- TODO add each deciphered field into the root_uic (or the relevant child object)
    -- TODO how is this going to work for childrens?

    -- shorthand to prevent typing the same thing a billions
        -- key here is a unique ID so the field can be saved into the root uic. key also references the relevant tooltip and text localisations
        -- format is the type you're expecting - hex, str, int16, etc
        -- j and k are the start and end indices (-1 can be supplied for the latter if the field, such as states, allows it)
        -- uic_type is the expected Lua object to return. if this is a regular field, supply nothing. if this is something like a state or an image, supply the relevant type
        -- is_deciphered is a shorthand to supply whether this specific field is actually deciphered or completely unknown.
            -- might not need the above at all on second thought, since that can be done through localisation and the like, TODO
    local function dec(key, format, j, k, uic_type, is_deciphered)
        if is_nil(is_deciphered) then   is_deciphered = true end    -- assume this is true so it's typed less
        if is_nil(uic_type)      then   uic_type = "field" end      -- ditto, assume the type is "field" when unspecified

        -- TODO assert the types

        -- get the expected return value, and the relevant hex chunk
        local ret,hex = self:decipher_chunk(format, j, k)

        local retval = nil

        if uic_type == "field" then
            root_uic:add_field(ui_editor_lib.uic_field.new(key, ret, hex, is_deciphered))
        end

        return retval
    end

    -- first up, grab the version!
    local version_header = dec("header", "str", 1, 10, "field")
    root_uic:set_version(tonumber(string.sub(version_header:get_value(), 8, 10))) -- change the string from "Version100" to "100", cutting off the version at the front

    -- grab the "UI-ID", which is a unique 4-byte identifier for the UIC layout (all UI-ID's have to be unique within one file, I think globally as well but not sure)
    dec("uid", "hex", 1, 4, "field")

    -- grab the name of the UIC. doesn't need to be unique or nuffin
    do
        -- TODO change how this is functionally, make one function that has the len and everything all in one

        local len = self:decipher_chunk("len", 1, 2) -- 1,2 used instead of 1,1 so the location goes past the 00
        --print(len)

        -- read the name by checking 1,len
        dec("name", "str", 1, len, "field")
    end


end

setmetatable(parser, {
    __index = parser,
    __call = function(self, hex_table) -- called by using `parser(hex_table)`, where hex_table is an array with each hex byte set as a string in order ("t" here is a reference to the "parser" table itself)
        print("yay")
        print(self.name)

        -- TODO verify the hex table first?
        self.data =       hex_table
        self.root_uic =   ui_editor_lib.uic_class:new("root_uic")
        self.location =   1

        -- go right into deciphering!

        self:decipher()
    end
})


return parser