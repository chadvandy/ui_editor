local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib:get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ui_editor_lib:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local Component = {
    type = "UIED_Component",
}

setmetatable(Component, BaseClass)

Component.__index = Component
Component.__tostring = BaseClass.__tostring

function Component:new(o)
    o = BaseClass:new(o)
    
    setmetatable(o, self)

    -- o.data = {}
    -- o.key = nil
    -- o.uic = nil

    o.version = 0
    o.b_is_root = false

    return o
end

function Component:set_is_root(b)
    self.b_is_root = b
end

function Component:is_root()
    return self.b_is_root
end

function Component:get_version()
    if self:is_root() then
        return self.version
    else
        return parser.root_uic:get_version()
    end
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
        local field = dec(key, format, k, self)
        -- if this field is a child of root, set it to uneditable, forever
        if self:is_root() then
            field:set_editable(false)
        else
            field:set_editable(true)
        end
        return field
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
        -- TODO guaranteed to have a num_events of 1 in v 113; add an optional end arg to decipher_collection with "num_items"?
        parser:decipher_collection("ComponentEvent", self)
    end

    -- next section is the offsets tables
    do
        deciph("offsets", "int32", {x = 4, y = 4})
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
        deciph("tooltip_text", "utf8", -1)
    end

    -- next bit is tooltip_id; optional again
    do
        deciph("tooltip_id", "utf8", -1) 
    end

    -- next bit is docking point, a little-endian int32 (so 01 00 00 00 turns into 00 00 00 01 turns into 1)
    do
        deciph("docking_point", "int32", 4)
    end

    -- next bit is docking offset (x,y)
    do
        deciph("dock_offsets", "int32", {x=4, y=4})
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
        local num_child = deciph("num_children", "int32", 4):get_value() --parser:decipher_chunk("int32", 1, 4)
        ui_editor_lib:log("VANDY NUM CHILDREN: "..tostring(num_child))

        -- TODO templates and UIC's are really the same thing, don't treat them differently like this
        for i = 1, num_child do
            local bits,hex = parser:decipher_chunk("hex", 1, 2)

            -- local bits = deciph("bits", "hex", 2):get_value() --parser:decipher_chunk("hex", 1, 2)
            if bits == "00 00" then
                local new_field = ui_editor_lib.classes.Field:new("bits", bits, hex)
                self:add_data(new_field)

                ui_editor_lib:log("deciphering new component within "..self:get_key())

                local child = ui_editor_lib:new_obj("Component")
                child:decipher()

                ui_editor_lib:log("component deciphered with key ["..child:get_key().."]")

                ui_editor_lib:log("adding them to the current obj, "..self:get_key())
                self:add_data(child)
            else
                parser.location = parser.location -2

                -- TODO this shouldn't be separate
                local template = ui_editor_lib:new_obj("ComponentTemplate")
                template:decipher()

                self:add_data(template)
            end
        end
    else
        ui_editor_lib:log("is this ever called?")
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

    -- I believe this is a check to tell if there's a LayoutEngine
    -- TODO
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
        if type == "List" or type == "HorizontalList" then
            local new_type = ui_editor_lib:new_obj("ComponentLayoutEngine")
            local val = new_type:decipher(type)

            self:add_data(val)

            has_type = true
        end

        -- TODO RadialList / Table

        -- if type == "List" then -- 451
        --     has_type = true
        -- elseif type == "HorizontalList" then -- 541
        --     has_type = true
        -- elseif type == "RadialList" then -- 603
        --     has_type = true
        -- elseif type == "Table" then -- 615
        --     has_type = true
        -- else
        -- end

        if has_type and v >= 100 and v < 110 then -- 645
            -- do nothing
        else
            deciph("after_b1", "str", -1)

            local bit = deciph("after_bit", "hex", 1)
            bit = bit:get_value()

            if bit == '01' then
                local int = parser:decipher_chunk("int32", 1, 4)
                for i = 1, int do
                    deciph("after_bit_"..i, "hex", 4)
                end
            end

            if v == 97 and not has_type then
                local bit2 = deciph("after_2_bit", "hex", 1)
                bit2 = bit2:get_value()

                if bit2 == '01' then
                    local len = deciph("after_2_bit_int1", "int32", 4):get_value()
                    deciph("after_2_bit_int2", "int32", 4)

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
                local len = deciph("after_3_bit_b1", "int32", 4):get_value()

                for i = 1, len do
                    deciph("after_3_bit_model"..i.."str1", "str", -1)
                    deciph("after_3_bit_model"..i.."str2", "str", -1)
                    deciph("after_3_bit_model"..i.."hex1", "hex", 1)

                    local len = deciph("after_3_bit_anim_num", "int32", 4):get_value()
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
                deciph("after_3_bit_f1", "int32", 4)
                deciph("after_3_bit_f2", "int32", 4)
                deciph("after_3_bit_f3", "int32", 4)
            end
        end) if not ok then ui_editor_lib:log(err) end
        end
    end

    -- if parent_obj then
    --     ui_editor_lib:log("adding UIC ["..current_uic:get_key().."] as child to parent ["..parent_obj:get_key().."].")

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

    ui_editor_lib:log("Component created with name ["..self:get_key().."]. Looping through data:")
    for i = 1, #d do
        ui_editor_lib:log("Data at "..tostring(i).." is ["..tostring(d[i]).."].")
        if tostring(d[i]) == "UIED_Component" then
            ui_editor_lib:log("Key is: "..d[i]:get_key())
        end
    end

    return self
end

return Component