local parser = core:get_static_object("layout_parser")

local uic_class = {}

-- create a new UIC with provided data (a large string with all the hexes) and a hex table
function uic_class:new_with_data(data, hex)
    local o = {}
    setmetatable(o, {__index = uic_class})

    o.bytes = hex
    o.data_string = data

    o.location = 1

    o.data = {}
    o.indexes = {}

    o.deciphered = false

    o:decipher()

    return o
end

function uic_class:decipher_chunk(format, j, k)
    j = j + self.location - 1
    k = k + self.location - 1

    --print(j)
    --print(k)

    local format_to_func = {
        str = parser.chunk_to_str,
        str16 = parser.chunk_to_str16,
        hex = parser.chunk_to_hex,
        len = parser.chunk_to_len,
        int16 = parser.chunk_to_int16,
        bool = parser.chunk_to_boolean
    }

    local func = format_to_func[format]
    if not func then ModLog("func not found") return end

    local retval = func(self, j, k)

    -- set location to k+1, for next decipher_chunk call
    self.location = k+1

    return retval
end

function uic_class:add_data(index, value)
    self.indexes[#self.indexes+1] = index
    
    self.data[index] = value
end

-- loops through all of the bytes within this UIC, and translates them into the actual data
function uic_class:decipher()
    if self.deciphered then
        -- errmsg
        return false
    end

    -- first 10 bytes are always the version string - "Version102"
    local v = self:decipher_chunk("str", 1, 10)

    -- grab the last 3 digits and set it as version
    local v_num = tonumber(string.sub(v, 8, 10))
    v = v_num
    self:add_data("version", v)

    -- next 4 bytes are the UI-ID for the component
    self:add_data("uid", self:decipher_chunk("hex", 1, 4))

    -- next 2 bytes are the length for the next string (unsigned int followed by 00), followed by the string itself (the UIC name)
    do
        local len = self:decipher_chunk("len", 1, 2) -- 1,2 used instead of 1,1 so the location goes past the 00
        --print(len)

        -- read the name by checking 1,len
        self:add_data("name", self:decipher_chunk("str", 1, len))
    end

    -- next 2 bytes are the length for the next string (b0, undeciphered), followed by the string itself
    -- this is optional, which means it might just be 00 00
    do
        local len = self:decipher_chunk("len", 1, 2)
        --print(len)

        local b0 = nil

        if len == 0 then
            -- there is nothing in this undeciphered chunk
            --print("there is nothing in this undeciphered chunk")
            b0 = "00 00"
        else
            b0 = self:decipher_chunk("str", 1, len)
            --print(b0)
        end

        self:add_data("b0", b0)
    end

    -- next section is the Events string

    -- between 100-110, there is no "num events"; it's just a single long string
    if v_num >= 100 and v_num < 110 then
        local len = self:decipher_chunk("len", 1, 2)

        --print(len)

        local events = "00 00"

        if len == 0 then
            print("no event found")
        else
            events = self:decipher_chunk("str", 1, len)
        end

        self:add_data("events", events)

    -- upwards, there is a "num events" integer, which is followed by that many individual strings with individual length indicators
    elseif v_num >= 110 and v_num < 130 then

    end

    -- next section is the offsets; two 4-byte sequences for the x-offset and y-offset
    -- they are int16's (4-byte, signed ie. positive or negative)
    do
        local x = self:decipher_chunk("int16", 1, 4)
        local y = self:decipher_chunk("int16", 1, 4)

        self:add_data("offsets", {x=x,y=y})

        --[[self.offsets = {
            x = x,
            y = y
        }]]
    end

    -- next section is undeciphered b1, which is only available between 70-89
    self.b1 = ""
    if v_num >= 70 and v_num < 90 then
        -- TODO dis
    end

    -- next 12 are undeciphered bytes
    -- jk first 6 are undeciphered, 7 in visibility, 8-12 are undeciphered
    do
        -- first 6, undeciphered
        local hex = self:decipher_chunk("hex", 1, 6)
        self:add_data("b_01", hex)
        
        -- 7, visibility
        local visible = self:decipher_chunk("hex", 1, 1)
        if visible == "01" then
            visible = true
        else
            visible = false
        end

        self:add_data("visible", visible)

        -- 8-12, undeciphered!
        self:add_data("b_02", self:decipher_chunk("hex", 1, 5))
    end

    -- next bit is tooltip text; optional, so it might just be 00 00
    do
        local len = self:decipher_chunk("len", 1, 2)

        local tooltip_text

        if len == 0 then
            -- do nothing
            tooltip_text = "00 00" -- two blank bytes
        else
            -- this is a weird string; it's a different type of char so it goes char-00-char-00
            -- ie., "Zoom" is "5A 00 6F 00 6F 00 6D 00", instead of just being "5A 6F 6F 6D"
            tooltip_text = self:decipher_chunk("str16", 1, len*2) -- len*2 is to make up for all the blank 00's
        end

        self:add_data("tooltip_text", tooltip_text)
    end

    -- next bit is tooltip_id; optional again
    do
        local len = self:decipher_chunk("len", 1, 2)

        local tooltip_id

        if len == 0 then
            tooltip_id = "00 00"
        else
            tooltip_id = self:decipher_chunk("str", 1, len)
        end

        self:add_data("tooltip_id", tooltip_id)
    end

    -- next bit is docking point, 4 bytes
    do
        local hex = self:decipher_chunk("hex", 1, 4)

        -- cut so it's just the first byte (dock is only 0-9)
        hex = string.sub(hex, 1,2)
        
        hex = tonumber(hex, 16)
        self:add_data("docking_point", hex)
    end

    -- next bit is docking offset (x,y)
    do
        local x = self:decipher_chunk("int16", 1, 4)
        local y = self:decipher_chunk("int16", 1, 4)

        self:add_data("dock_offsets", {x=x,y=y})
    end

    -- next bit is the component priority (where it's printed on the screen, higher = front, lower = back)
    -- TODO this? it seems like it's just one byte, might only be one byte if it's set to 0. find an example of this being filled out
    do
        local hex = self:decipher_chunk("hex", 1, 1)

        self:add_data("component_priority", hex)
    end

    -- default state, always is 4-bytes, refers to the UID of the state in question
    -- can be 00 00 00 00 happily, seems like it'll default to the first state if none are set here
    do
        self:add_data("default_state", self:decipher_chunk("hex", 1, 4))
    end

    self.deciphered = true
end

--

return uic_class