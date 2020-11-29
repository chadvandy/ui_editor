-- this is the Lua object for the "uic_field" bit of data within the UIC layout files.
-- this is done for a few reasons: to store accessible data easily in tables like this (which are easy to garbage collect), to make it more accessible and less hard-coded, and it's partially just for the fun of it if I'm being honest


-- TODO make this comparable to BaseClass - use data as a table instead of value as a changable type; use an array 

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local uic_field = {}
-- setmetatable(uic_field, uic_field)
uic_field.__index = uic_field

function uic_field:__tostring()
    return "UI_Field" -- TODO this shouldn't be "UIED" should it?
end

function uic_field:new(key, value, hex)
    local o = {}
    setmetatable(o, self)
    ModLog("Testing new UIC Field: "..tostring(o))
    -- self.__index = self

    o.key = key
    o.value = value
    o.hex = hex

    return o
end

function uic_field:get_type()
    return "UI_Field"
end

function uic_field:get_key()
    return self.key
end

function uic_field:get_value()
    return self.value
end

function uic_field:get_hex()
    return self.hex or "no hex found"
end

function uic_field:get_is_deciphered()
    return self.is_deciphered
end

-- returns the localised text + tooltip text for this field, using the "key" field
function uic_field:get_display_text()
    local key = self:get_key()

    local text = effect.get_localised_string("layout_parser_"..key.."_text")
    local tt   = effect.get_localised_string("layout_parser_"..key.."_tt")

    local value = self:get_value()
    local value_str
    if is_table(value) then

        -- construct the string from the table
        local str = ""
        for k,v in pairs(value) do
            str = str .. tostring(k) .. ": ".. tostring(v) .. " "
        end
        value_str = str
    else
        value_str = tostring(value)
    end

    if not text or text == "" then
        text = key
    end
    
    if not tt or tt == "" then
        tt = "Tooltip not found"
    end

    return text,tt,value_str
end

return uic_field