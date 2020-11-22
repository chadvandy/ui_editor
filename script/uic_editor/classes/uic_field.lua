-- this is the Lua object for the "uic_field" bit of data within the UIC layout files.
-- this is done for a few reasons: to store accessible data easily in tables like this (which are easy to garbage collect), to make it more accessible and less hard-coded, and it's partially just for the fun of it if I'm being honest

local uic_field = {}

function uic_field.new(key, value, hex, is_deciphered)
    local o = {}
    setmetatable(o, {__index = uic_field})

    o.key = key
    o.value = value
    o.hex = hex
    o.is_deciphered = is_deciphered
end

function uic_field:get_key()
    return self.key
end

function uic_field:get_value()
    return self.value
end

function uic_field:get_hex()
    return self.hex
end

function uic_field:get_is_deciphered()
    return self.is_deciphered
end

-- TODO uic_field:display()?
-- TODO how will uic_field work with a table as value?
-- TODO make it work with every value, g'damnit

return uic_field