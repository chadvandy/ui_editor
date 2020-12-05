local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentMouseSth = {
    type = "ComponentMouseSth",
}

setmetatable(ComponentMouseSth, BaseClass)

ComponentMouseSth.__index = ComponentMouseSth
ComponentMouseSth.__tostring = BaseClass.__tostring

function ComponentMouseSth:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentMouseSth:decipher()
    local v = parser.root_uic:get_version()

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("hex1", "hex", 4)

    if v >= 122 and v < 130 then
        deciph("hex2", "hex", 16)
    end

    deciph("str1", "str", -1)
    deciph("str2", "str", -1)
    deciph("str3", "str", -1)

    -- idk what this actually does
    -- TODO decipher this

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

    return self
end

return ComponentMouseSth