-- this is the actual functionality that takes a table of hexadecimal fields, runs through them, and constructs some sort of meaningful shit out of it
-- it starts by creating a new UIC class, adding all of the hexadecimal fields into it, and then it runs through and constructs further objects within - creating a "state" object for each state, so on
-- each UIC class has its own fields for editing, tooltipping, and display

-- the layout_parser also is where all the internal versioning is, and if all goes well, is the only file that needs updating each CA patch (when a new UIC version is introduced).


-- TODO does each class really need to be a different Lua type?
-- TODO ^ yes, but there can be a main "class" that they're all built from. I tried that once before and it failed but I eventually got it working
-- TODO decide if moving decode onto individual Lua types

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local parser = {
    name = "blorp",
    data = nil,             -- this is the saved hex data, cleared on every call

    root_uic = nil,         -- this is the saved UIC object which contains every field and baby class, also cleared on every call
    location = 1,           -- used to jump through the hex bytes

    -- TODO figure out how to do this!
    current_obj = nil,      -- this is the current object being looped through
}

-- parsers here (translate raw hex into actual data)

-- converts a series of hexadecimal bytes (between j and k) into a string
-- takes an original 2 bytes *before* the string as the "len" identifier.
function parser:chunk_to_str(j, k)
    ModLog("chunk to str "..tostring(j) .. " & "..tostring(k))

    -- only perform this stuff if there's a -1 k provided
    if k == -1 then
        -- first two bytes are the length identifier
        local len = self:chunk_to_int8(j, j+1)

        -- if the len is 0, then just return a string of "" (for optional strings)
        if len == 0 then ModLog(tostring(j)) ModLog(tostring(j+1)) return "\"\"", self:chunk_to_hex(j, j+1), j+1 end

        -- set k to the proper spot
        k = len + self.location -1
        ModLog(tostring(j)) ModLog(tostring(k))

        -- move j and k up by 2 (for the length above)
        j = j + 2 k = k + 2
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
    local hex = self:chunk_to_hex(j, k) -- start at the BEGINNING of "len", end at the end of the string

    return ret,hex,k
end

-- converts a length of text into a string-16 (which is, in hex, a string with empty 00 bytes between each character)
function parser:chunk_to_str16(j, k)
    -- first two bytes are the length identifier (tells the game how long the incoming string is)
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
    local hex = self:chunk_to_hex(j, k)

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


        -- NOT NEEDED

        -- ----- Lua obj types -----
        -- -- these act a bit differently, in that they themselves call self:decipher_chunk() instead of calling the native types directly
        -- -- changed names to reflect that. they will all still return the value, the full hex, and the starting/ending byte marks (and take j/k)

        -- -- Image types
        -- ComponentImage = parser.decipher_component_image,
        -- ComponentImages = parser.decipher_component_images,
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

-- TODO a different parser function to decipher each type? parser:decipher_uic() and what not?
-- TODO yes ^^^^^^^^^

function parser:decipher_component()

end

function parser:decipher_component_image_metric()
    local v = self.root_uic:get_version()

    local obj = ui_editor_lib.new_obj("ComponentImageMetric")

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    deciph("uid", "hex", 4)

    if v >= 126 and v < 130 then
        deciph("b_sth", "hex", 16)
    end

    deciph("offset", "int16", {x=4,y=4})
    deciph("dimensions", "int16", {w=4,h=4})

    deciph("colour", "hex", 4)

    -- ui_colour_preset_type_key ?
    if v>=119 and v<130 then
        deciph("str_sth", "str")
    end

    -- bool, whether it's tiled or not
    deciph("tiled", "bool", 1)

    -- whether the image is flipped on the x/y axes
    deciph("x_flipped", "bool", 1)
    deciph("y_flipped", "bool", 1)

    deciph("docking_point", "int16", 4)

    deciph("dock_offset", "int16", {x=4,y=4})

    -- TODO this might be CanResizeWidth/Height
    -- dock right/bottom; they seem to be bools?
    deciph("dock", "bool", {right=1,left=1})

    deciph("rotation_angle", "hex", 4)
    deciph("pivot_point", "int16", {x=4,y=4})

    if v >= 103 then
        deciph("rotation_axis", "int16", {4,4,4})
        deciph("shader_name", "str")
    else
        deciph("shader_name", "str")
        deciph("rotation_axis", "int16", {4,4,4})
    end

    if v <= 102 then
        deciph("b4", "hex", 4)
    end

    if v == 79 then
        deciph("b5", "hex", 8)
    elseif v >= 70 and v < 80 then
        deciph("b6", "hex", 9)
    elseif v >= 80 and v< 95 then
        if v == 92 or v == 93 then
            deciph("margin", "hex", {4,4,4,4})
        else
            deciph("margin", "hex", {4,4})
        end
    else
        if v >= 103 then
            -- TODO: is this todo even needed? can't tell if this is just old
            --[[			
                if ($v >= 103){
                    $this->shadertechnique_vars = my_unpack_array($my, 'f4', fread($h, 4 * 4));
                    foreach ($this->shadertechnique_vars as &$a){ $a = round($a * 10000000) / 10000000; }
                    unset($a);
                }
            ]]
            deciph("shadertechnique_vars", "hex", {4,4,4,4})
        end
        
        deciph("margin", "hex", {4,4,4,4})

        if v >= 125 and v < 130 then
            deciph("b5", "hex", 1)
        end
    end

    return obj
end


-- TODO need a dec() rewrite for within these bois. Alternatively, supply the object that things are being saved to
-- that's a good idea, TODO
function parser:decipher_component_state()
    local v_num = self.root_uic:get_version()

    -- TODO change this to `ui_editor_lib:new_obj("class_key")` for a quick fix
    local obj = ui_editor_lib.classes.ComponentState.new()

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    deciph("uid", "hex", 4)

    if v_num >= 126 and v_num < 130 then
        deciph("b_sth", "hex", 16)
    end

    deciph("name", "str", -1)

    deciph("width", "int16", 4)
    deciph("height", "int16", 4)

    -- localised text
    deciph("text", "str16", -1)
    deciph("tooltip_text", "str16", -1)

    -- text bounds
    deciph("text_width", "int16", 4)
    deciph("text_height", "int16", 4)

    -- text alignment -- TODO figure out translation, ie. 1 = Top or whatever
    deciph("text_valign", "int16", 4)
    deciph("text_halign", "int16", 4)

    -- texthbehavior(?) TODO decode
    deciph("b1", "hex", 1)

    deciph("text_label", "str16", -1)

    -- they swap order between versions
    if v_num <= 115 then
        deciph("b3", "hex", 2)
        deciph("text_localised", "str16", -1)
    else        
        deciph("text_localised", "str16", -1)
        deciph("b3", "hex", 2)
    end

    -- TODO this seems wrong, shouldn't they all have tt label?
    -- tooltip_label + two undeciphered fields
    if v_num >= 70 and v_num < 90 then
        deciph("tooltip_label", "str16")
    elseif v_num >= 90 and v_num < 110 then
        deciph("tooltip_label", "str16")
        deciph("b5", "str")
    elseif v_num >= 110 and v_num < 120 then
        if v_num <= 115 then
            deciph("b4", "hex", 4)
        end
    elseif v_num == 121 or v_num == 129 then
        deciph("b5", "str")
    end

    -- text infos!
    deciph("font_name", "str")
    deciph("font_size", "int16", 4)
    deciph("font_leading", "int16", 4)
    deciph("font_tracking", "int16", 4)
    deciph("font_colour", "hex", 4)

    -- font category
    deciph("fontcat_name", "str")

    -- text offsets!
    -- first is only two ints - x and y offset; second is four, with left/right/top/bottom offsets
    if v_num >= 70 and v_num < 80 then
        deciph("text_offset", "int16", {x=4,y=4})
    elseif v_num >= 80 and v_num <= 130 then
        deciph("text_offset", "int16", {l=4,r=4,t=4,b=4})
    end

    -- undeciphered!
    if v_num >= 70 and v_num < 80 then
        deciph("b7", "hex", 7)-- dunno what this did, huh. TODO 7 is weird here.
    elseif v_num >= 90 and v_num < 130 then
        -- TODO the second byte sets interactive (00 = uninteractive, etc)
        deciph("b7", "hex", 4)
    end

    deciph("shader_name", "str")
    -- TODO these are actually floats not ints!
    -- shader variables; int16
    deciph("shader_vars", "int16", {one=4,two=4,three=4,four=4})

    deciph("text_shader_name", "str")
    -- TODO these are actually floats not ints!
    -- shader variables; int16
    deciph("text_shader_vars", "int16", {one=4,two=4,three=4,four=4})

    self:decipher_collection("ComponentImageMetric")


    -- stuff before the mouse, 8 bytes
    deciph("b_mouse", "hex", 8)

    -- TODO mouse stuff, another collection
    --self:decipher_collection("ComponentMouse")

    return obj
end

-- starting at location 1, tries to decipher data going onwards to fill out a component image
function parser:decipher_component_image()
    ModLog("deciphering component image!")

    local tab = {}

    local function deciph(key, format, j, k)
        local new_val,new_hex,new_k = self:decipher_chunk(format, j, k)

        tab[#tab+1] = ui_editor_lib.classes.Field.new(key, new_val, new_hex)
    end

    -- first 4 are the uid
    -- the UI-ID
    deciph("uid","hex",1,4)

    -- image path (can be optional)
    deciph("img_path", "str", 1, -1)

    -- get the width + height
    deciph("w", "int16", 1, 4)
    deciph("h", "int16", 1, 4)

    -- TODO decode
    deciph("unknown_bool", "hex", 1, 1)

    local image = ui_editor_lib.classes.ComponentImage.new()
    
    image:add_data_table(tab)

    return image
end


function parser:decipher_collection(collected_type)
    if not is_string(collected_type) then
        -- errmsg
        return false
    end

    -- turns it from "ComponentImage" to "ComponentImages", very simply
    local key = collected_type.."s"

    -- local hex = ""

    ModLog("deciphering "..collected_type)

    local type_to_func = {
        ComponentImage =            parser.decipher_component_image,
        ComponentState =            parser.decipher_component_state,
        ComponentImageMetric =      parser.decipher_component_image_metric
    }

    local func = type_to_func[collected_type]

    -- every collection starts with an int16 (four bytes) to inform how much of that thing is within
    local len,hex = self:decipher_chunk("int16", 1, 4)

    -- if none are found, just return 0 / "00 00 00 00"
    if len == 0 then
        return len,hex--,4
    end

    local ret = {}

    for i = 1, len do
        local val,new_hex,end_k = func(self)

        ret[#ret+1] = val
        -- hex = hex .. new_hex
    end

    -- containers don't take raw hex (only needed for individual lines!)
    local container = ui_editor_lib.classes.Container.new(key, ret)

    -- TODO figure out a better way to add it to the current UIC
    self.root_uic:add_data(container)

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
            local ret,hex = parser:decipher_chunk(format, j, v)
            val[i_key]=ret
            hex_boi=hex_boi.." "..hex
        end

        new_field = ui_editor_lib.classes.Field.new(key, val, hex_boi)
        ModLog("chunk deciphered with key ["..key.."], the hex was ["..hex_boi.."]")
    else -- k is not a table, decipher normally
        local ret,hex = self:decipher_chunk(format, j, k)

        new_field = ui_editor_lib.classes.Field.new(key, ret, hex)
        ModLog("chunk deciphered with key ["..key.."], the hex was ["..hex.."]")
    end

    return obj:add_data(new_field)
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

    ModLog("decipher name: "..self.name)

    local root_uic = self.root_uic

    -- TODO change how this works so it calls parser:decipher_component() for the root (figure out how to make that work !)

    -- TODO add each deciphered field into the root_uic (or the relevant child object)
    -- TODO how is this going to work for childrens?

    local deco = dec

    -- first up, grab the version!
    local version_header = dec("header", "str", 10)

    -- change the string from "Version100" to "100", cutting off the version at the front
    local v_num = tonumber(string.sub(version_header:get_value(), 8, 10))
    root_uic:set_version(v_num)

    -- grab the "UI-ID", which is a unique 4-byte identifier for the UIC layout (all UI-ID's have to be unique within one file, I think globally as well but not sure)
    dec("uid", "hex", 4)

    -- grab the name of the UIC. doesn't need to be unique or nuffin
    do
        dec("name", "str", -1)
    end

    -- first undeciphered chunk! :D
    do
        -- unknown string
        dec("b0", "str", -1)
    end

    -- next up is the Events looong string

    -- between v 100-110 there is no "num events" or table; it's just a single long string
    if v_num >= 100 and v_num < 110 then
        dec("events", "str")
    elseif v_num >= 110 and v_num < 130 then
        -- TODO dis; this has "num events" length identifier (I believe it's int16, 4-bytes) and is followed by that many strings
        -- I *think* it also can just have one string with no num events, but I'm not positive
    end

    -- next section is the offsets tables
    do
        dec("offsets", "int16", {x = 4, y = 4})
    end    

    -- next section is undeciphered b1, which is only available between 70-89
    --self.b1 = ""
    if v_num >= 70 and v_num < 90 then
        -- TODO dis
    end

        -- next 12 are undeciphered bytes
    -- jk first 6 are undeciphered, 7 in visibility, 8-12 are undeciphered
    do
        -- first 6, undeciphered
        dec("b_01", "hex", 6)
        
        -- 7, visibility
        dec("visible", "bool", 1)

        -- 8-12, undeciphered!
        dec("b_02", "hex", 5)
    end

    -- TODO I believe if one of these exist they both need to; add in error checking for that!

    -- next bit is optional tooltip text
    do
        deco("tooltip_text", "str16", -1)
    end

    -- next bit is tooltip_id; optional again
    do
        deco("tooltip_id", "str", -1) 
    end

    -- next bit is docking point, a little-endian int16 (so 01 00 00 00 turns into 00 00 00 01 turns into 1)
    do
        dec("docking_point", "int16", 4)
    end

    -- next bit is docking offset (x,y)
    do
        dec("dock_offsets", "int16", {x=4, y=4})
    end

    -- next bit is the component priority (where it's printed on the screen, higher = front, lower = back)
    -- TODO this? it seems like it's just one byte, but it might only be one byte if it's set to 0. find an example of this being filled out!
    do
        dec("component_priority", "hex", 1)
    end

    -- this is the state that it defaults to (gasp).
    do
        dec("default_state", "hex", 4)
    end

    -- call another method that starts off determining the length of the following chunk and turns it into a collection of component images onto the component
    self:decipher_collection("ComponentImage", "component_images")

    -- back to the component!

    -- the UI-ID of the "mask image"; can be empty, ie. 00 00 00 00
    dec("mask_image", "hex", 4)

    if v_num >= 70 and v_num < 110 then
        dec("b5", "hex", 4)
    end

    -- some 16-byte hex shit
    if v_num >= 126 and v_num < 130 then
        dec("b_sth2", "hex", 16)
    end

    -- decipher all da states
    self:decipher_collection("ComponentState", "component_states")

    return root_uic
end

setmetatable(parser, {
    __index = parser,
    __call = function(self, hex_table) -- called by using `parser(hex_table)`, where hex_table is an array with each hex byte set as a string in order ("t" here is a reference to the "parser" table itself)
        ModLog("yay")
        ModLog(self.name)

        self.name = "new name"

        ModLog(self.name)

        -- TODO verify the hex table first?

        local root_uic = ui_editor_lib.classes.Component:new("root_uic")
        root_uic:set_is_root(true)

        self.data =       hex_table
        self.root_uic =   root_uic
        self.location =   1

        -- go right into deciphering! (returns the root_uic created!)
        return self:decipher()
    end
})


return parser