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

function parser:decipher_component(parent_obj)
    local current_uic = nil
    local v_num = nil
    local v = nil

    if not parent_obj then
        current_uic = self.root_uic

        -- first up, grab the version!
        local version_header = dec("header", "str", 10, current_uic)

        -- change the string from "Version100" to "100", cutting off the version at the front
        v_num = tonumber(string.sub(version_header:get_value(), 8, 10))
        v = v_num
        current_uic:set_version(v_num)
    else
        current_uic = ui_editor_lib.new_obj("Component")

        v_num = self.root_uic:get_version()
        v = v_num
    end

    local function deciph(key, format, k)
        return dec(key, format, k, current_uic)
    end

    -- grab the "UI-ID", which is a unique 4-byte identifier for the UIC layout (all UI-ID's have to be unique within one file, I think globally as well but not sure)
    deciph("uid", "hex", 4)

    -- grab the name of the UIC. doesn't need to be unique or nuffin
    do
        deciph("name", "str", -1)
    end

    -- first undeciphered chunk! :D
    do
        -- unknown string
        deciph("b0", "str", -1)
    end

    -- next up is the Events looong string

    -- between v 100-110 there is no "num events" or table; it's just a single long string
    if v_num >= 100 and v_num < 110 then
        deciph("events", "str")
    elseif v_num >= 110 and v_num < 130 then
        -- TODO dis; this has "num events" length identifier (I believe it's int16, 4-bytes) and is followed by that many strings
        -- I *think* it also can just have one string with no num events, but I'm not positive
    end

    -- next section is the offsets tables
    do
        deciph("offsets", "int16", {x = 4, y = 4})
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
        deciph("b_01", "hex", 6)
        
        -- 7, visibility
        deciph("visible", "bool", 1)

        -- 8-12, undeciphered!
        deciph("b_02", "hex", 5)
    end

    -- TODO I believe if one of these exist they both need to; add in error checking for that!

    -- next bit is optional tooltip text
    do
        deciph("tooltip_text", "str16", -1)
    end

    -- next bit is tooltip_id; optional again
    do
        deciph("tooltip_id", "str16", -1) 
    end

    -- next bit is docking point, a little-endian int16 (so 01 00 00 00 turns into 00 00 00 01 turns into 1)
    do
        deciph("docking_point", "int16", 4)
    end

    -- next bit is docking offset (x,y)
    do
        deciph("dock_offsets", "int16", {x=4, y=4})
    end

    -- next bit is the component priority (where it's printed on the screen, higher = front, lower = back)
    -- TODO this? it seems like it's just one byte, but it might only be one byte if it's set to 0. find an example of this being filled out!
    do
        deciph("component_priority", "hex", 1)
    end

    -- this is the state that it defaults to (gasp).
    do
        deciph("default_state", "hex", 4)
    end

    -- call another method that starts off determining the length of the following chunk and turns it into a collection of component images onto the component
    self:decipher_collection("ComponentImage", current_uic)

    -- back to the component!

    -- the UI-ID of the "mask image"; can be empty, ie. 00 00 00 00
    deciph("mask_image", "hex", 4)

    if v_num >= 70 and v_num < 110 then
        deciph("b5", "hex", 4)
    end

    -- some 16-byte hex shit
    if v_num >= 126 and v_num < 130 then
        deciph("b_sth2", "hex", 16)
    end

    -- decipher all da states
    self:decipher_collection("ComponentState", current_uic)

    if v >= 126 and v < 130 then
        deciph("b_sth3", "hex", 16)
    end

    -- next up is Properties!
    self:decipher_collection("ComponentProperty", current_uic)

    -- unknown TODO
    deciph("b6", "hex", 4)

    self:decipher_collection("ComponentFunction", current_uic)

    -- TODO move this into the component decipher thingy
    if v_num >= 100 and v < 130 then
        local num_child = self:decipher_chunk("int16", 1, 4)

        for i = 1, num_child do
            local bits = self:decipher_chunk("hex", 1, 2)
            if bits == "00 00" then
                self:decipher_component(current_uic)
            else

            end
        end
    else
        self:decipher_collection("Component", current_uic)
    end

    -- if ($v >= 70 && $v < 100){
    --     for ($i = 0; $i < $this->num_child; ++$i){
    --         $uic = new UIC();
    --         $this->child[] = $uic;
    --         $uic->read($h, $this);
    --     }
    -- }
    -- else if ($v >= 100 && $v < 130){
    --     for ($i = 0; $i < $this->num_child; ++$i){
    --         $bits = tohex(fread($h, 2));
    --         if ($bits === '00 00'){
    --             $uic = new UIC();
    --             $this->child[] = $uic;
    --             $uic->read($h, $this);
    --         }
    --         else{
    --             fseek($h, -2, SEEK_CUR);
    --             $uic = new UIC_Template();
    --             $this->child[] = $uic;
    --             $uic->read($h, $this);
    --         }
    --     }
    -- }

    -- $this->readAfter($h);
    deciph("after_b0", "hex", 1)

    local type = deciph("after_type", "str", -1):get_value()


    if v >= 70 and v < 80 then
        if type == "List" then
        --     $a = array();
				
        --     $a[] = 'num_sth = '. tohex($num_sth = fread($h, 4));
        --     $num_sth = my_unpack_one($this, 'l', $num_sth);
        --     my_assert($num_sth < 10, $this);
        --     $b = array();
        --     for ($i = 0; $i < $num_sth; ++$i){
        --         $b[] = tohex(fread($h, 4));
        --     }
        --     $a[] = $b;
        --     $a[] = tohex(fread($h, 21));
            
        --     $this->after[] = $a;
        else
            if v == 79 then
                deciph("after_b1", "hex", 2)

                -- TODO if there's any children, add another field
                if false then
                    --     if ($this->num_child !== 0){
                    --         $this->after[] = tohex(fread($h, 4));
                    --     }
                    deciph("deciph_after_child", "hex", 4)
                end
            else
                deciph("after_b1", "hex", 6)
            end

            if type then
                deciph("after_b2", "hex", 1)
            end
        end

    elseif v >= 80 and v < 90 then
        if v >= 80 and v < 85 then
            deciph("after_b1", "hex", 5)
        else
            deciph("after_b1", "hex", 6)
        end
    else
        local has_type = false
        if type == "List" then -- 451
            has_type = true
        elseif type == "HorizontalList" then -- 541
            has_type = true
        elseif type == "RadialList" then -- 603
            has_type = true
        elseif type == "Table" then -- 615
            has_type = true
        else

        end

        if has_type and v >= 100 and v < 110 then -- 645
            -- do nothing
        else
            deciph("after_b1", "str", -1)

            local bit = deciph("after_bit", "hex", 1)
            bit = bit:get_value()

            if bit == '01' then
                local int = self:decipher_chunk("int16", 1, 4)
                for i = 1, int do
                    deciph("after_bit_"..i, "hex", 4)
                end
            end

            if v == 97 and not has_type then
                local bit2 = deciph("after_2_bit", "hex", 1)
                bit2 = bit2:get_value()

                if bit2 == '01' then
                    local len = deciph("after_2_bit_int1", "int16", 4):get_value()
                    deciph("after_2_bit_int2", "int16", 4)

                    for i = 1,4 do
                        deciph("after_2_bit_hex"..i, "hex", len)
                    end
                end
                deciph("after_2_bit_hex", "hex", 4)
            end

            local bit = deciph("after_3_bit", "hex", 1):get_value()
            if bit == '01' then -- 670
                -- TODO this has to do with models?
                deciph("after_3_bit_str", "str", -1)

                deciph("after_3_bit_b0", "hex", 74)

                -- num models?
                local len = deciph("after_3_bit_b1", "int16", 4):get_value()

                for i = 1, len do
                    deciph("after_3_bit_model"..i.."str1", "str", -1)
                    deciph("after_3_bit_model"..i.."str2", "str", -1)
                    deciph("after_3_bit_model"..i.."hex1", "hex", 1)

                    local len = deciph("after_3_bit_anim_num", "int16", 4):get_value()
                    for j = 1, len do
                        deciph("after_3_bit_model"..i.."_anim"..j.."str1", "str", -1)
                        deciph("after_3_bit_model"..i.."_anim"..j.."str2", "str", -1)
                        deciph("after_3_bit_model"..i.."_anim"..j.."hex", "hex", 4)
                    end
                end

                deciph("after_3_bit_b1", "hex", 3)
            elseif v >= 90 and v < 95 then
                deciph("after_3_bit_b0", "hex", 2)
            else
                deciph("after_3_bit_b0", "hex", 3)
            end

            if v >= 110 and v < 130 then
                -- TODO three floats (not ints!)
                deciph("after_3_bit_f1", "int16", 4)
                deciph("after_3_bit_f2", "int16", 4)
                deciph("after_3_bit_f3", "int16", 4)
            end
        end
    end

    if parent_obj then
        parent_obj:add_data(current_uic)
    end
    
    -- figure out what this does TODOTODOTODO
    -- TODO so this checks the number of bytes between the ending of the root component and the ending of the file, I believe
    -- if ($this->parent === null){
    --     $this->pos = ftell($h);
    --     fseek($h, 0, SEEK_END);
    --     $this->diff = ftell($h) - $this->pos;
    --     my_assert($this->diff === 0, $this);
    -- }

    return current_uic
end

function parser:decipher_component_mouse()
    local v = self.root_uic:get_version()

    local obj = ui_editor_lib.new_obj("ComponentMouse")

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    local ok, err = pcall(function()

    deciph("mouse_state", "hex", 4)
    deciph("state_uid", "hex", 4)

    if v >= 122 and v < 130 then
        deciph("b_sth", "hex", 16)
    end

    deciph("b0", "hex", 8)

    -- idk what this actually does
    -- TODO decipher this
    do
        -- this is the number of things to loop through, each is an array of 1 hex and 3 strings
        local num_sth = self:decipher_chunk("int16", 1, 4)

        local ret = {}

        -- ModLog("in mouse, num sth: "..num_sth)

        -- TODO resolve this SPAGOOT
        for i = 1, num_sth do
            -- ModLog("in loop, "..i)
            local inner_container = {}

            do
                local m_ret,hex = self:decipher_chunk("hex", 1, 4)
                local new_field = ui_editor_lib.classes.Field.new("hex1", m_ret, hex)

                inner_container[#inner_container+1] = new_field
            end
            
            if v >= 122 and v < 130 then
                local m_ret,hex = self:decipher_chunk("hex", 1, 16)
                local new_field = ui_editor_lib.classes.Field.new("hex2", m_ret, hex)

                inner_container[#inner_container+1] = new_field
            end

            do
                local m_ret,hex = self:decipher_chunk("str", 1, -1)
                local new_field = ui_editor_lib.classes.Field.new("str1", m_ret, hex)
                inner_container[#inner_container+1] = new_field
            end
            
            do               
                local m_ret,hex = self:decipher_chunk("str", 1, -1)
                local new_field = ui_editor_lib.classes.Field.new("str2", m_ret, hex)
                inner_container[#inner_container+1] = new_field
            end  
                      
            do
                local m_ret,hex = self:decipher_chunk("str", 1, -1)
                local new_field = ui_editor_lib.classes.Field.new("str3", m_ret, hex)
                inner_container[#inner_container+1] = new_field
            end

            -- containers don't take raw hex (only needed for individual lines!)
            local container = ui_editor_lib.classes.Container.new("sth"..i, inner_container)

            ret[#ret+1] = container
        end

        local container = ui_editor_lib.classes.Container.new("sths", ret)

        obj:add_data(container)
    end
end) if not ok then ModLog(err) end

    -- $this->num_sth = my_unpack_one($this, 'l', fread($h, 4));
    -- my_assert($this->num_sth < 20, $my);
    -- for ($i = 0; $i < $this->num_sth; ++$i){
    --     $a = array();
    --     $a[] = tohex(fread($h, 4));
    --     if ($v >= 122 && $v < 130){
    --         $a[] = tohex(fread($h, 16));
    --     }
    --     $a[] = read_string($h, 1, $my);
    --     $a[] = read_string($h, 1, $my);
    --     $a[] = read_string($h, 1, $my);
    --     $this->sth[] = $a;
    -- }

    return obj
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
            deciph("shadertechnique_vars", "hex", {4,4,4,4})
        end
        
        deciph("margin", "hex", {4,4,4,4})

        if v >= 125 and v < 130 then
            deciph("b5", "hex", 1)
        end
    end

    return obj
end


function parser:decipher_component_state()
    local v_num = self.root_uic:get_version()

    local obj = ui_editor_lib:new_obj("ComponentState")

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

    self:decipher_collection("ComponentImageMetric", obj)

    -- stuff before the mouse, 8 bytes
    deciph("b_mouse", "hex", 8)

    self:decipher_collection("ComponentMouse", obj)

    -- TODO there's one more field here, b8

    -- if ($v >= 122 && $v < 130){
    --     $a = read_string($h, 1, $my);
    --     if (empty($a)){
    --         $this->b8 = array($a);
    --     } else{
    --         $a = array($a);
            
    --         $num_sth = my_unpack_one($this, 'l', fread($h, 4));
    --         $sth = array();
    --         for ($i = 0; $i < $num_sth; ++$i){
    --             $b = array();
    --             $b[] = read_string($h, 1, $my);
    --             $b[] = tohex(fread($h, 16));
    --             $sth[] = $b;
    --         }
    --         $a[] = $sth;
            
    --         $num_sth = my_unpack_one($this, 'l', fread($h, 4));
    --         $sth = array();
    --         for ($i = 0; $i < $num_sth; ++$i){
    --             $b = array();
    --             $b[] = read_string($h, 1, $my);
    --             $b[] = read_string($h, 1, $my);
    --             $sth[] = $b;
    --         }
    --         $a[] = $sth;
            
    --         $this->b8 = $a;
    --     }

    return obj
end

-- starting at location 1, tries to decipher data going onwards to fill out a component image
function parser:decipher_component_image()
    ModLog("deciphering component image!")

    local obj = ui_editor_lib.classes.ComponentImage.new()

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    -- first 4 are the uid
    -- the UI-ID
    deciph("uid","hex",4)

    -- image path (can be optional)
    deciph("img_path", "str", -1)

    -- get the width + height
    deciph("w", "int16", 4)
    deciph("h", "int16", 4)

    -- TODO decode
    deciph("unknown_bool", "hex", 1)

    return obj
end

-- properties are just a k/v table, with a key mapped to a value, both strings
function parser:decipher_component_property()
    local v = self.root_uic:get_version()

    local obj = ui_editor_lib.new_obj("ComponentProperty")

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    -- TODO rename
    deciph("str1", "str", -1)
    deciph("str2", "str", -1)

    return obj
end

-- TODO do this later :)
function parser:decipher_component_function_animation()
    local v = self.root_uic:get_version()

    local obj = ui_editor_lib.new_obj("ComponentFunctionAnimation")

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    if v >= 110 and v < 130 then

    end
end

function parser:decipher_component_function()
    local v = self.root_uic:get_version()

    local obj = ui_editor_lib.new_obj("ComponentFunction")

    local function deciph(key, format, k)
        dec(key, format, k, obj)
    end

    deciph("name", "str", -1)

    deciph("b0", "hex", 2)

    self:decipher_collection("ComponentFunctionAnimation", obj)

    if v >= 91 and v <= 93 then
        deciph("b1", "hex", 2)
    elseif v >= 95 and v < 97 then
        deciph("b1", "hex", 2)
    elseif v >= 97 and v < 100 then
        deciph("str_sth", "str")
    elseif v >= 110 and v < 130 then
        deciph("str_sth", "str")
        deciph("b1", "str")
    end
end

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

    local type_to_func = {
        Component =                 parser.decipher_component,
        ComponentImage =            parser.decipher_component_image,
        ComponentState =            parser.decipher_component_state,
        ComponentImageMetric =      parser.decipher_component_image_metric,
        ComponentMouse =            parser.decipher_component_mouse,
        ComponentProperty =         parser.decipher_component_property,
        ComponentFunction =         parser.decipher_component_function,
        ComponentFunctionAnimation = parser.decipher_component_function_animation,
    }

    local func = type_to_func[collected_type]

    -- every collection starts with an int16 (four bytes) to inform how much of that thing is within
    local len,hex = self:decipher_chunk("int16", 1, 4)

    ModLog("len of "..collected_type.." is "..len)

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

    self:decipher_component()

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