-- this is the Lua object for the "uic_field" bit of data within the UIC layout files.
-- this is done for a few reasons: to store accessible data easily in tables like this (which are easy to garbage collect), to make it more accessible and less hard-coded, and it's partially just for the fun of it if I'm being honest


-- TODO make this comparable to BaseClass - use data as a table instead of value as a changable type; use an array 

local ui_editor_lib = core:get_static_object("ui_editor_lib")
local parser = ui_editor_lib.parser

local uic_field = {}
-- setmetatable(uic_field, uic_field)
uic_field.__index = uic_field

function uic_field:__tostring()
    return "UI_Field" -- TODO this shouldn't be "UIED" should it?
end

function uic_field:new(key, value, hex)
    local o = {}
    setmetatable(o, self)
    -- ModLog("Testing new UIC Field: "..tostring(o))
    -- self.__index = self

    o.key = key
    o.value = value
    o.hex = hex
    o.uic = nil

    o.native_type = "" -- native type is the actual data type being used - int16, str, etc

    return o
end

-- TODO this attempts a change of a value; returns true, or a string displaying some sort of error.
function uic_field:test_change(val)
    -- TODO test val against native type; ie., if it's a string, or if it's too long of an integer, etc etc

    return true
end

function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

-- TODO this should only work for copied_uic?
function uic_field:change_val(new_val)
    if self:test_change(new_val) == true then
        -- TODO assume it's a string for right now, lul
        local new_hex = parser:str16_to_chunk(new_val)
        ModLog("New hex: "..new_hex)

        -- local new_file = io.open("data/ui/templates/TEST", "w+b")
        -- new_file:write(self.hex)

        self.value = new_val
        self.hex = new_hex

        

        ui_editor_lib.print_copied_uic()

        -- new_file:write(self.hex)

        -- new_file:close()
    end
end

function uic_field:get_native_type()
    return self.native_type
end

-- TODO this also needs to work for things like "state_ui-id", so it references a non-native type. New field? o.special_type or whatever? o.reference?
function uic_field:set_native_type(new_type)
    -- TODO errcheck
        -- check if it fits in one of the previous types

    self.native_type = new_type
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

function uic_field:get_uic()
    local uic = self.uic
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    return self.uic
end

function uic_field:set_uic(uic)
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    self.uic = uic
end

function uic_field:set_state(state)
    local uic = self:get_uic()

    if is_uicomponent(uic) then
        if state == "open" then
            -- set uic to visible!
            uic:SetVisible(true)
        else
            uic:SetVisible(false)
        end
    end
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