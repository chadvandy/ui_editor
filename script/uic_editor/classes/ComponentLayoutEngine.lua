local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentLayoutEngine = {
    type = "UIED_ComponentLayoutEngine",
}

setmetatable(ComponentLayoutEngine, BaseClass)

ComponentLayoutEngine.__index = ComponentLayoutEngine
ComponentLayoutEngine.__tostring = BaseClass.__tostring

function ComponentLayoutEngine:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentLayoutEngine:decipher(my_type)
    local v = parser.root_uic:get_version()


    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    -- I believe these are column widths? number of columns and each width?
    local num_sth = deciph("num_sth", "int32", 4):get_value()

    for i = 1, num_sth do
        deciph("column_"..i, "float", 4)
    end

    deciph("b0","int32", 4)
    deciph("b1","int32", 4)

    deciph("b2", "bool", 1)

    deciph("b3", "int32", 4)

    if v >= 91 and v < 97 then
        deciph("bit", "hex", 1)

        if v == 96 then
            deciph("bit_hex_0", "hex", 5)
        end

        deciph("bit_hex_1", "hex", 2)
    elseif v >= 97 and v < 100 then
        deciph("b4", "hex", 6)
        deciph("b5", "str")
        deciph("b6", "hex", 5)
    else

        deciph("b4", "hex", 2)

        -- margins?
        deciph("b5_01", "int32", 4)
        deciph("b5_02", "int32", 4)
        deciph("b5_03", "int32", 4)
        deciph("b5_04", "int32", 4)


        if my_type == "List" then
            -- TODO this really sucks
            local len = 19

            if v >= 100 and v < 110 then
                if v >= 100 and v <= 101 then
                    len = 2
                elseif v >= 102 and v <= 104 then
                    len = 6
                elseif v == 105 then
                    len = 11
                elseif v == 106 then
                    len = 10
                end
            elseif v == 113 then
                len = 14;
            elseif v >= 110 and v < 120 then
                len = 19
            elseif v >= 122 and v < 127 then
                len = 26 
            elseif v >= 127 and v < 130 then 
                len = 29
            end

            deciph("b6", "hex", len)

            if v == 106 or v >= 110 and v < 130 then
                deciph("b7", "str")
            end

            if v == 106 then
                deciph("b8", "hex", 7)
            end
        elseif my_type == "HorizontalList" then
            deciph("b6", "int32", 4)
            deciph("b7", "str")

            if v == 105 then
                deciph("b8", "int32", 4)
                deciph("b9", "hex", 1)
            elseif v >= 106 then
                deciph("b8", "int32", 4)

                deciph("b9", "str")
                deciph("b10", "hex", 7)

                if v >= 122 and v < 130 then
                    deciph("b11", "hex", 10)
                end
            end

            if v >= 110 and v < 130 then
                deciph("final_str", "str")
            end
        end
    end

    return self
end

return ComponentLayoutEngine