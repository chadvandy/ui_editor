local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local Component = {
    type = "Component",
}

setmetatable(Component, BaseClass)

Component.__index = Component
Component.__tostring = BaseClass.__tostring

function Component:new(o)
    o = o or {}
    
    setmetatable(o, self)

    o.data = {}
    o.key = nil

    o.version = 0
    o.header_uic = nil
    o.b_is_root = false

    return o
end

function Component:set_is_root(b)
    self.b_is_root = b
end

function Component:is_root()
    return self.b_is_root
end

-- TODO check if is root? if not, get root?
function Component:get_version()
    return self.version
end

function Component:set_version(verzh)
    if not is_number(verzh) then
        -- errmsg
        return false
    end

    if self.version ~= 0 then
        -- already set, errmsg
        return false
    end

    self.version = verzh
end


function Component:decipher()
    local v_num = nil
    local v = nil

    if self:is_root() then
        local version_header = dec("header", "str", 10, self)

        v_num = tonumber(string.sub(version_header:get_value(), 8, 10))
        v = v_num
        self:set_version(v_num)
    else
        v_num = parser.root_uic:get_version()
        v = v_num
    end

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    -- grab the "UI-ID", which is a unique 4-byte identifier for the UIC layout (all UI-ID's have to be unique within one file, I think globally as well but not sure)
    deciph("ui-id", "hex", 4)

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

        -- TODO create ComponentEvent type?
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
    parser:decipher_collection("ComponentImage", self)

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
    parser:decipher_collection("ComponentState", self)

    if v >= 126 and v < 130 then
        deciph("b_sth3", "hex", 16)
    end

    -- next up is Properties!
    parser:decipher_collection("ComponentProperty", self)

    -- unknown TODO
    deciph("b6", "hex", 4)

    parser:decipher_collection("ComponentFunction", self)

    -- TODO move this into decipher_collection
    if v_num >= 100 and v < 130 then
        local num_child = parser:decipher_chunk("int16", 1, 4)
        ModLog("VANDY NUM CHILDREN: "..tostring(num_child))

        -- TODO templates and UIC's are really the same thing, don't treat them differently like this
        for i = 1, num_child do
            local bits = parser:decipher_chunk("hex", 1, 2)
            if bits == "00 00" then
                ModLog("deciphering new component within "..self:get_key())

                local child = ui_editor_lib.new_obj("Component")
                child:decipher()

                ModLog("component deciphered with key ["..child:get_key().."]")

                ModLog("adding them to the current obj, "..self:get_key())
                self:add_data(child)
            else

            end
        end
    else
        ModLog("is this ever called?")
        parser:decipher_collection("Component", self)
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

    -- TODO ComponentLayoutEngine stuff :)
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
                local int = parser:decipher_chunk("int16", 1, 4)
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

            local ok, err = pcall(function()

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
        end) if not ok then ModLog(err) end
        end
    end

    -- if parent_obj then
    --     ModLog("adding UIC ["..current_uic:get_key().."] as child to parent ["..parent_obj:get_key().."].")

    --     parent_obj:add_data(current_uic)
    -- end
    
    -- figure out what this does TODOTODOTODO
    -- TODO so this checks the number of bytes between the ending of the root component and the ending of the file, I believe
    -- if ($this->parent === null){
    --     $this->pos = ftell($h);
    --     fseek($h, 0, SEEK_END);
    --     $this->diff = ftell($h) - $this->pos;
    --     my_assert($this->diff === 0, $this);
    -- }

    local d = self:get_data()

    ModLog("Component created with name ["..self:get_key().."]. Looping through data:")
    for i = 1, #d do
        ModLog("Data at "..tostring(i).." is ["..tostring(d[i]).."].")
        if tostring(d[i]) == "UIED_Component" then
            ModLog("Key is: "..d[i]:get_key())
        end
    end

    return self
end

-- create a new UIC with provided data (a large string with all the hexes) and a hex table
-- function obj:new_with_data(data, hex)
--     local o = {}
--     setmetatable(o, {__index = obj})

--     o.bytes = hex
--     o.data_string = data

--     o.location = 1

--     o.data = {}
--     o.indexes = {}

--     o.deciphered = false

--     o:decipher()

--     return o
-- end

-- TODO add parser-deciphered fields into the obj
-- TODO add obj:display() or some such, which acts as the ui panel creator for this uicomponent - takes the list_box UIC component, and runs through this UIC object's data

-- function obj:decipher_chunk(format, j, k)
--     j = j + self.location - 1
--     k = k + self.location - 1

--     --print(j)
--     --print(k)

--     local format_to_func = {
--         str = parser.chunk_to_str,
--         str16 = parser.chunk_to_str16,
--         hex = parser.chunk_to_hex,
--         len = parser.chunk_to_len,
--         int16 = parser.chunk_to_int16,
--         bool = parser.chunk_to_boolean
--     }

--     local func = format_to_func[format]
--     if not func then ModLog("func not found") return end

--     local retval = func(self, j, k)

--     -- set location to k+1, for next decipher_chunk call
--     self.location = k+1

--     return retval
-- end

-- -- "data_type" can be "header" or "table" (for now), empty for regular
-- function obj:add_data(index, value, data_type)
--     self.indexes[#self.indexes+1] = index
    
--     self.data[index] = {
--         value = value,
--         data_type = data_type,
--     }
-- end

-- TODO move this entirely to layout_parser
-- loops through all of the bytes within this UIC, and translates them into the actual data
-- function obj:decipher()
--     if self.deciphered then
--         -- errmsg
--         return false
--     end

--     -- first 10 bytes are always the version string - "Version102"
--     local v = self:decipher_chunk("str", 1, 10)

--     -- grab the last 3 digits and set it as version
--     local v_num = tonumber(string.sub(v, 8, 10))
--     v = v_num
--     self:add_data("version", v)

--     -- next 4 bytes are the UI-ID for the component
--     self:add_data("uid", self:decipher_chunk("hex", 1, 4))

--     -- next 2 bytes are the length for the next string (unsigned int followed by 00), followed by the string itself (the UIC name)
--     do
--         local len = self:decipher_chunk("len", 1, 2) -- 1,2 used instead of 1,1 so the location goes past the 00
--         --print(len)

--         -- read the name by checking 1,len
--         self:add_data("name", self:decipher_chunk("str", 1, len))
--     end

--     -- next 2 bytes are the length for the next string (b0, undeciphered), followed by the string itself
--     -- this is optional, which means it might just be 00 00
--     do
--         local len = self:decipher_chunk("len", 1, 2)
--         --print(len)

--         local b0 = nil

--         if len == 0 then
--             -- there is nothing in this undeciphered chunk
--             --print("there is nothing in this undeciphered chunk")
--             b0 = "00 00"
--         else
--             b0 = self:decipher_chunk("str", 1, len)
--             --print(b0)
--         end

--         self:add_data("b0", b0)
--     end

--     -- next section is the Events string

--     -- between 100-110, there is no "num events"; it's just a single long string
--     if v_num >= 100 and v_num < 110 then
--         local len = self:decipher_chunk("len", 1, 2)

--         --print(len)

--         local events = "00 00"

--         if len == 0 then
--             print("no event found")
--         else
--             events = self:decipher_chunk("str", 1, len)
--         end

--         self:add_data("events", events)

--     -- upwards, there is a "num events" integer, which is followed by that many individual strings with individual length indicators
--     elseif v_num >= 110 and v_num < 130 then

--     end

--     -- next section is the offsets; two 4-byte sequences for the x-offset and y-offset
--     -- they are int16's (4-byte, signed ie. positive or negative)
--     do
--         local x = self:decipher_chunk("int16", 1, 4)
--         local y = self:decipher_chunk("int16", 1, 4)

--         self:add_data("offsets", {x=x,y=y}, "table")

--         --[[self.offsets = {
--             x = x,
--             y = y
--         }]]
--     end

--     -- next section is undeciphered b1, which is only available between 70-89
--     self.b1 = ""
--     if v_num >= 70 and v_num < 90 then
--         -- TODO dis
--     end

--     -- next 12 are undeciphered bytes
--     -- jk first 6 are undeciphered, 7 in visibility, 8-12 are undeciphered
--     do
--         -- first 6, undeciphered
--         local hex = self:decipher_chunk("hex", 1, 6)
--         self:add_data("b_01", hex)
        
--         -- 7, visibility
--         local visible = self:decipher_chunk("hex", 1, 1)
--         if visible == "01" then
--             visible = true
--         else
--             visible = false
--         end

--         self:add_data("visible", visible)

--         -- 8-12, undeciphered!
--         self:add_data("b_02", self:decipher_chunk("hex", 1, 5))
--     end

--     -- next bit is tooltip text; optional, so it might just be 00 00
--     do
--         local len = self:decipher_chunk("len", 1, 2)

--         local tooltip_text

--         if len == 0 then
--             -- do nothing
--             tooltip_text = "00 00" -- two blank bytes
--         else
--             -- this is a weird string; it's a different type of char so it goes char-00-char-00
--             -- ie., "Zoom" is "5A 00 6F 00 6F 00 6D 00", instead of just being "5A 6F 6F 6D"
--             tooltip_text = self:decipher_chunk("str16", 1, len*2) -- len*2 is to make up for all the blank 00's
--         end

--         self:add_data("tooltip_text", tooltip_text)
--     end

--     -- next bit is tooltip_id; optional again
--     do
--         local len = self:decipher_chunk("len", 1, 2)

--         local tooltip_id

--         if len == 0 then
--             tooltip_id = "00 00"
--         else
--             tooltip_id = self:decipher_chunk("str", 1, len)
--         end

--         self:add_data("tooltip_id", tooltip_id)
--     end

--     -- next bit is docking point, 4 bytes
--     do
--         local hex = self:decipher_chunk("hex", 1, 4)

--         -- cut so it's just the first byte (dock is only 0-9)
--         hex = string.sub(hex, 1,2)
        
--         hex = tonumber(hex, 16)
--         self:add_data("docking_point", hex)
--     end

--     -- next bit is docking offset (x,y)
--     do
--         local x = self:decipher_chunk("int16", 1, 4)
--         local y = self:decipher_chunk("int16", 1, 4)

--         self:add_data("dock_offsets", {x=x,y=y})
--     end

--     -- next bit is the component priority (where it's printed on the screen, higher = front, lower = back)
--     -- TODO this? it seems like it's just one byte, might only be one byte if it's set to 0. find an example of this being filled out
--     do
--         local hex = self:decipher_chunk("hex", 1, 1)

--         self:add_data("component_priority", hex)
--     end

--     -- default state, always is 4-bytes, refers to the UID of the state in question
--     -- can be 00 00 00 00 happily, seems like it'll default to the first state if none are set here
--     do
--         self:add_data("default_state", self:decipher_chunk("hex", 1, 4))
--     end

--         -- next are the images
--     -- starts with a counter for num-of-images; if it's 0, well, there are none!
--     do
--         local len = self:decipher_chunk("int16", 1, 4)
--         --print("images length: "..len)

--         -- TODO this better
--         local images = {}
--         for i = 1, len do
--             local image = {}

--             -- next 4 bytes are the UID for this image
--             image.uid = self:decipher_chunk("hex", 1, 4)

--             -- between 126-130 there's a new string here, worry about it later
--             image.b_sth = ""
--             if v_num >= 126 and v_num < 130 then
--                 image.b_sth = ""
--             end

--             -- grab the image path; might be 00 00
--             local path = ""
--             local path_len = self:decipher_chunk("len", 1, 2)

--             if path_len == 0 then
--                 path = "00 00"
--             else
--                 path = self:decipher_chunk("str", 1, path_len)
--             end

--             image.path = path

--             -- get the width/height, 4-bytes eacah, int16
--             local w,h = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
--             image.width, image.height = w,h

--             -- there's a final byte that's usually just 00
--             image.extra = self:decipher_chunk("hex", 1, 1)

--             images[#images+1] = image
--         end

--         self:add_data("images", images)
--     end

--     -- "mask image" next; refers to UID of an image. if none, then there is no mask.
--     -- dunno if this even works!
--     do
--         self:add_data("mask_image", self:decipher_chunk("hex", 1, 4))
--     end

--     -- "b5" next; only available between 70-110
--     -- undeciphered, obvo
--     do
--         local b5 = ""
--         if v_num >= 70 and v_num < 110 then
--             b5 = self:decipher_chunk("hex", 1, 4)
--         end

--         self:add_data("b5", b5)
--     end

--     -- "b_sth2" next; 126-130
--     -- undeciphered, 16 bytes evidently
--     do
--         local b_sth2 = ""
--         if v_num >= 126 and v_num < 130 then
--             b_sth2 = self:decipher_chunk("hex", 1, 16)
--         end

--         self:add_data("b_sth2", b_sth2)
--     end

--     -- next up are states! :D
--     do
--         local num_states = self:decipher_chunk("len", 1, 4)

--         local states = {}

--         for i = 1, 1 do
--             local state = {}

--             -- first 4 are UID, doi
--             state.uid = self:decipher_chunk("hex", 1, 4)

--             -- b_sth next 16-bytes
--             state.b_sth = ""
--             if v_num >= 126 and v_num < 130 then
--                 state.b_sth = self:decipher_chunk("hex", 1, 16)
--             end

--             -- name next, using len
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.name = self:decipher_chunk("str", 1, len)
--             end

--             -- create the width/height bits
--             local w,h = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
--             state.width, state.height = w,h

--             -- text; str16!
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.text = ""
--                 if len == 0 then
--                     -- bloop
--                     state.text = "00 00"
--                 else
--                     state.text = self:decipher_chunk("str16", 1, len*2)
--                 end
--             end

--             -- tooltip text; str16!
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.tooltip_text = ""
--                 if len == 0 then
--                     -- bloop
--                     state.tooltip_text = "00 00"
--                 else
--                     state.tooltip_text = self:decipher_chunk("str16", 1, len*2)
--                 end
--             end

--             -- text bounds; 4-bytes and 4-bytes
--             do
--                 local w,h = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
--                 local hor,ver = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)

--                 state.text_bounds = {
--                     w = w,
--                     h = h,
--                 }

--                 state.text_align = {
--                     hor = hor, -- 0 - left, 1 - center, 2 - right
--                     ver = ver, -- 1 - top, 2 - middle, 3 - bottom
--                 }
--             end

--             -- texthbehavior (??)
--             state.b1 = self:decipher_chunk("hex", 1, 1)

--             -- text label
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.text_label = ""
--                 if len == 0 then
--                     state.text_label = "00 00"
--                 else
--                     state.text_label = self:decipher_chunk("str16", 1, len*2)
--                 end
--             end

--             -- b3(?) and localised text (the localised key for the text)
--             do
--                 if v_num <= 115 then
--                     -- b3 first, then localised
--                     state.b3 = self:decipher_chunk("hex", 1, 2)
                    
--                     local len = self:decipher_chunk("len", 1, 2)
--                     state.localised = ""
--                     if len == 0 then
--                         state.localised = "00 00"
--                     else
--                         state.localised = self:decipher_chunk("str16", 1, len*2)
--                     end
--                 else
--                     -- the opposite             
--                     local len = self:decipher_chunk("len", 1, 2)
--                     state.localised = ""
--                     if len == 0 then
--                         state.localised = "00 00"
--                     else
--                         state.localised = self:decipher_chunk("str16", 1, len*2)
--                     end

--                     state.b3 = self:decipher_chunk("hex", 1, 2)
--                 end
--             end

--             -- tooltip label + b5 + b4, whatever they are
--             -- "imagedock9patch, blockedanims"?
--             do -- TODO make utf8 strings better than this nonsense, this is SPAGOOT
--                 state.tooltip_id = ""
--                 state.b4 = ""
--                 state.b5 = ""

--                 if v_num >= 70 and v_num < 90 then
--                     local len = self:decipher_chunk("len", 1, 2)

--                     if len == 0 then
--                         state.tooltip_id = "00 00"
--                     else
--                         state.tooltip_id = self:decipher_chunk("str16", 1, len*2)
--                     end
--                 elseif v_num >= 90 and v_num < 110 then
--                     local len = self:decipher_chunk("len", 1, 2)

--                     if len == 0 then
--                         state.tooltip_id = "00 00"
--                     else
--                         state.tooltip_id = self:decipher_chunk("str16", 1, len*2)
--                     end

--                     do
--                         local len = self:decipher_chunk("len", 1, 2)

--                         if len == 0 then
--                             state.b5 = "00 00"
--                         else
--                             state.b5 = self:decipher_chunk("str", 1, len)
--                         end
--                     end
--                 elseif v_num >= 110 and v_num < 120 then
--                     if v_num <= 115 then
--                         state.b4 = self:decipher_chunk("hex", 1, 4)
--                     end
--                 elseif v_num == 121 or v_num == 129 then
--                     local len = self:decipher_chunk("len", 1, 2)

--                     if len == 0 then
--                         state.b5 = "00 00"
--                     else
--                         state.b5 = self:decipher_chunk("str", 1, len)
--                     end
--                 end
--             end

--             -- font name; opt -- TODO it's not optional!
--             do
--                 local len = self:decipher_chunk("len", 1, 2)
                
--                 if len == 0 then
--                     state.font_name = "00 00"
--                 else
--                     state.font_name = self:decipher_chunk("str", 1, len)
--                 end
--             end

--             -- font size, leading, tracking and colour; all 4-bytes
--             do
--                 -- TODO make this prettier?
--                 local size,leading,tracking = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)

--                 state.font_size, state.font_leading, state.font_tracking = size,leading,tracking

--                 -- next 4 bytes are the colour, in RGBA.
--                 local colour = self:decipher_chunk("hex", 1, 4)

--                 state.font_colour = colour
--             end

--             -- font category name
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.fontcat_name = self:decipher_chunk("str", 1, len)
--             end

--             -- the text offset; four 4-byte ints.
--             -- left-offset, right-offset, top-offset, botom-offset, I *think*
--             do
--                 -- it was just two ints for these versions
--                 if v >= 70 and v < 80 then
--                     local x,y = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
--                     state.text_offset = {
--                         x = x,
--                         y = y
--                     }
--                 elseif v >= 80 and v <= 130 then
--                     -- four ints; left, right, top, bottom
--                     local l,r,t,b = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4) -- TODO GOD THIS SUCKS
--                     state.text_offset = {
--                         l=l,
--                         r=r,
--                         t=t,
--                         b=b,
--                     }
--                 end
--             end

--             -- b7, undeciphered
--             -- focustype(?): interactive, disabled, pixelcollision
--             do
--                 state.b7 = ""
--                 if v >= 70 and v < 80 then
--                     state.b7 = self:decipher_chunk("hex", 1, 7) -- dunno what this did, huh
--                 elseif v >= 90 and v < 130 then
--                     -- TODO the second byte sets interactive (00 = uninteractive, etc)
--                     state.b7 = self:decipher_chunk("hex", 1, 4)
--                 end
--             end

--             -- shader name, https://chadvandy.github.io/tw_modding_resources/campaign/uicomponent.html#section:uicomponent:Shader%20Techniques
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.shader_name = self:decipher_chunk("str", 1, len)
--             end 

--             -- TODO these are actually floats not ints!
--             -- TODO same for text shader vars
--             -- shader variables; int16
--             do
--                 local one,two,three,four =
--                     self:decipher_chunk("int16", 1, 4),
--                     self:decipher_chunk("int16", 1, 4),
--                     self:decipher_chunk("int16", 1, 4),
--                     self:decipher_chunk("int16", 1, 4)

--                 state.shader_vars = {
--                     one,
--                     two,
--                     three,
--                     four
--                 }
--             end

--             -- ditto as the same two above, but for text!
--             do
--                 local len = self:decipher_chunk("len", 1, 2)

--                 state.text_shader_name = self:decipher_chunk("str", 1, len)
--             end

--             -- bloopadoop
--             do
--                 local one,two,three,four =
--                     self:decipher_chunk("int16", 1, 4),
--                     self:decipher_chunk("int16", 1, 4),
--                     self:decipher_chunk("int16", 1, 4),
--                     self:decipher_chunk("int16", 1, 4)

--                 state.text_shader_vars = {
--                     one,
--                     two,
--                     three,
--                     four
--                 }
--             end

--             -- ComponentStateImages set on this image; can be zero
--             do
--                 local num_state_images = self:decipher_chunk("len", 1, 4)

--                 local state_images = {}

--                 for j = 1, num_state_images do
--                     local state_image = {}

--                     -- references the UID of the ComponentImage in the UIC itself; MUST match one!
--                     state_image.uid = self:decipher_chunk("hex", 1, 4)

--                     -- dunno, undeciphered
--                     if v >= 126 and v < 130 then
--                         state_image.b_sth = self:decipher_chunk("hex", 1, 16)
--                     else
--                         state_image.b_sth = ""
--                     end

--                     do -- x/y offset from 0,0 (top left corner of parent)
--                         local x,y = self:decipher_chunk("int16", 1, 4),self:decipher_chunk("int16", 1, 4)
--                         state_image.offset = {
--                             x=x,
--                             y=y,
--                         }
--                     end

--                     do -- dimensions, width + height
--                         local w,h = self:decipher_chunk("int16", 1, 4),self:decipher_chunk("int16", 1, 4)
--                         state_image.dimensions = {
--                             w=w,
--                             h=h
--                         }
--                     end

--                     do -- colour; RGBA
--                         state_image.colour = self:decipher_chunk("hex", 1, 4)
--                     end

--                     do -- ui_colour_preset_type_key (?)
--                         state_image.str_sth = ""
--                         if v>=119 and v<130 then
--                             local len = self:decipher_chunk("len", 1, 2)
--                             state_image.str_sth = self:decipher_chunk("str", 1, len)
--                         end
--                     end
                    
--                     do -- boolean, whether it's a tiled image (ie. repeats upon margins) or isn't
--                         state_image.tiled = self:decipher_chunk("bool", 1, 1)
--                     end

--                     do -- another boolean, for "is flipped on x-axis"
--                         state_image.x_flipped = self:decipher_chunk("bool", 1, 1)
--                     end

--                     do -- well
--                         state_image.y_flipped = self:decipher_chunk("bool", 1, 1)
--                     end

--                     do -- get the docking point; 4-bytes
--                         local hex = self:decipher_chunk("hex", 1, 4)

--                         -- cut so it's just the first byte (dock is only 0-9)
--                         hex = string.sub(hex, 1,2)
                        
--                         hex = tonumber(hex, 16)
--                         state_image.docking_point = hex
--                     end

--                     do -- docking offset
--                         local x,y = self:decipher_chunk("int16", 1, 4),
--                             self:decipher_chunk("int16", 1, 4)

--                         state_image.dock_offset = {
--                             x=x,
--                             y=y
--                         }

--                         -- TODO this might be CanResizeWidth/Height
--                         -- dock right/bottom; they seem to be bools?
--                         state_image.dock = {
--                             right = self:decipher_chunk("bool", 1, 1),
--                             left = self:decipher_chunk("bool", 1, 1),
--                         }
--                     end

--                     do -- rotation angle and pivot points

--                         -- TODO this is 4 bytes; no idea how it's turned into an angle.
--                         -- rotation is in radians in TW UI, for future reference
--                         state_image.rotation_angle = self:decipher_chunk("hex", 1, 4)

--                         -- TODO this again; check what kind of ints they are, later on
--                         state_image.pivot_point = {
--                             x = self:decipher_chunk("hex", 1, 4),
--                             y = self:decipher_chunk("hex", 1, 4),
--                         }
--                     end

--                     do -- rotation axis & shader name
--                         -- rot axis is 3 floats

--                         if v >= 103 then
--                             state_image.rotation_axis = {
--                                 self:decipher_chunk("int16", 1, 4),
--                                 self:decipher_chunk("int16", 1, 4),
--                                 self:decipher_chunk("int16", 1, 4),
--                             }

--                             local shader_name = ""

--                             local len = self:decipher_chunk("len", 1, 2)

--                             if len == 0 then
--                                 shader_name = "00 00"
--                             else
--                                 shader_name = self:decipher_chunk("str", 1, len)
--                             end
                            
--                             state_image.shader_name = shader_name
--                         else
--                             local shader_name = ""

--                             local len = self:decipher_chunk("len", 1, 2)

--                             if len == 0 then
--                                 shader_name = "00 00"
--                             else
--                                 shader_name = self:decipher_chunk("str", 1, len)
--                             end
                            
--                             state_image.shader_name = shader_name

--                             state_image.rotation_axis = {
--                                 self:decipher_chunk("int16", 1, 4),
--                                 self:decipher_chunk("int16", 1, 4),
--                                 self:decipher_chunk("int16", 1, 4),
--                             }
--                         end
--                     end

--                     -- b4, undeciphered. always 00 00 00 00(?)
--                     do
--                         if v <= 102 then
--                             state_image.b4 = self:decipher_chunk("hex", 1, 4)
--                         end
--                     end

--                     -- margin / b5 / shader tech vars
--                     do
--                         if v == 79 then
--                             state_image.b5 = self:decipher_chunk("hex", 1, 8)
--                         elseif v >= 70 and v < 80 then
--                             state_image.b5 = self:decipher_chunk("hex", 1, 9)
--                         elseif v >= 80 and v < 95 then
--                             if v == 92 or v == 93 then
--                                 state_image.margin = {
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                 }
--                             else
--                                 state_image.margin = {
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                 }
--                             end
--                         else
--                             if v >= 103 then
--                                 -- TODO:
--                                 --[[			
--                                     if ($v >= 103){
--                                         $this->shadertechnique_vars = my_unpack_array($my, 'f4', fread($h, 4 * 4));
--                                         foreach ($this->shadertechnique_vars as &$a){ $a = round($a * 10000000) / 10000000; }
--                                         unset($a);
--                                     }
--                                 ]]

--                                 state_image.shadertechnique_vars = {
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                     self:decipher_chunk("hex", 1, 4),
--                                 }
--                             end

--                             state_image.margin = {
--                                 self:decipher_chunk("hex", 1, 4),
--                                 self:decipher_chunk("hex", 1, 4),
--                                 self:decipher_chunk("hex", 1, 4),
--                                 self:decipher_chunk("hex", 1, 4),
--                             }

--                             if v >= 125 and v < 130 then
--                                 state_image.b5 = self:decipher_chunk("hex", 1, 1)
--                             end
--                         end
--                     end

--                     state_images[#state_images+1] = state_image
--                 end

--                 state.state_images = state_images
--             end

--             -- mouse stuff
--             do
--                 --[[		
--                     // stateeditordisplaypos (2 ints)
--                     $this->b_mouse = tohex(fread($h, 8)); // unknown
--                 ]]
--                 state.b_mouse = self:decipher_chunk("hex", 1, 8)

--                 local num_mouse = self:decipher_chunk("len", 1, 4)

--                 local mouses = {}
--                 if num_mouse == 0 then
--                     -- no mouse objects!
--                 else
--                     local mouse = {}
                    
--                     mouse.mouse_state = self:decipher_chunk("hex", 1, 4)

--                     mouse.state_uid = self:decipher_chunk("hex", 1, 4)

--                     if v>= 122 and v < 130 then
--                         mouse.b_sth = self:decipher_chunk("hex", 1, 16)
--                     end

--                     mouse.b0 = self:decipher_chunk("hex", 1, 4)

                    

--                     mouses[#mouses+1] = mouse
--                 end
--             end

--             states[#states+1] = state
--         end
--         self:add_data("states", states)
--     end

--     self.deciphered = true
-- end

--

return Component