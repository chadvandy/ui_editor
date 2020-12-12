local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib:get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    -- ui_editor_lib:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentState = {
    type = "UIED_ComponentState",
}

setmetatable(ComponentState, BaseClass)

ComponentState.__index = ComponentState
ComponentState.__tostring = BaseClass.__tostring



function ComponentState:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentState:decipher()
    local v_num = parser.root_uic:get_version()

    -- local obj = ui_editor_lib:new_obj("ComponentState")

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("ui-id", "hex", 4)

    if v_num >= 126 and v_num < 130 then
        deciph("b_sth", "hex", 16)
    end

    deciph("name", "str", -1)

    deciph("width", "int32", 4)
    deciph("height", "int32", 4)

    -- localised text
    deciph("text", "utf8", -1)
    deciph("tooltip", "utf8", -1)

    -- text bounds
    deciph("text_width", "int32", 4)
    deciph("text_height", "int32", 4)

    -- text alignment -- TODO figure out translation, ie. 1 = Top or whatever
    deciph("text_valign", "int32", 4)
    deciph("text_halign", "int32", 4)

    -- texthbehavior(?) TODO decode
    deciph("b1", "hex", 1)

    deciph("text_label", "utf8", -1)

    -- they swap order between versions
    if v_num <= 115 then
        deciph("b3", "hex", 2)
        deciph("tooltip_localised", "utf8", -1)
    else        
        deciph("tooltip_localised", "utf8", -1)
        deciph("b3", "hex", 2)
    end

    -- TODO this seems wrong, shouldn't they all have tt label?
    -- tooltip_label + two undeciphered fields
    if v_num >= 70 and v_num < 90 then
        deciph("tooltip_id", "utf8")
    elseif v_num >= 90 and v_num < 110 then
        deciph("tooltip_id", "utf8")
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
    deciph("font_size", "int32", 4)
    deciph("font_leading", "int32", 4)
    deciph("font_tracking", "int32", 4)
    deciph("font_colour", "hex", 4)

    -- font category
    deciph("fontcat_name", "str")

    -- text offsets!
    -- first is only two ints - x and y offset; second is four, with left/right/top/bottom offsets
    if v_num >= 70 and v_num < 80 then
        deciph("text_offset", "int32", {x=4,y=4})
    elseif v_num >= 80 and v_num <= 130 then
        deciph("text_offset", "int32", {l=4,r=4,t=4,b=4})
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
    -- shader variables; int32
    deciph("shader_vars", "float", {one=4,two=4,three=4,four=4})

    deciph("text_shader_name", "str")
    -- TODO these are actually floats not ints!
    -- shader variables; int32
    deciph("text_shader_vars", "float", {one=4,two=4,three=4,four=4})

    parser:decipher_collection("ComponentImageMetric", self)

    -- stuff before the mouse, 8 bytes
    deciph("b_mouse", "hex", 8)

    parser:decipher_collection("ComponentMouse", self)

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

    return self
end




return ComponentState