local uic = {}

function uic:new()
    local o = {}
    setmetatable(o, {__index = uic})

    o.bytes = {}

    o.location = 1

    o.version = 0
    o.uid = 0

    o.b0 = nil
    o.b1 = nil
    o.b_01 = nil

    o.events = nil

    o.offsets = {
        x = 0,
        y = 0,
    }
    
    o.indexes = {}
    o.data = {}

    o.children = {}

    return o
end

-- converts a series of hexadecimal bytes (between j and k) into a string
function uic:chunk_to_str(j, k)
    -- adds each hexadecimal byte into a table
    local block = {}
    for i = j, k do
        block[i] = self.bytes[i]
    end

    -- run through that table and convert the hex into formatted strings (\x56 from 56, for instance)
    local str = ""
    for i = j, k do
        str = str .. "\\x" .. block[i]
    end

    -- for each pattern of formatted strings (`\x56`), convert it into its char'd form
    -- tonumber(x,16) changes the number (56) to its place in binary (86) into the ASCII char (V)
    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)

    ---- this was within the above function(x) to test the statements
    -- local first = true
    -- if first then print(x) print(tonumber(x,16)) print(string.char(tonumber(x,16))) first = false end
    return str
end

function uic:chunk_to_str16(j, k)
    local block = {}
    for i = j,k do
        block[i] = self.bytes[i]
    end

    local str = ""
    for i = j,k,2 do -- the "2" iterates by 2 instead of 1, so it'll skip every unwanted 00
        str = str .. "\\x" .. block[i]
    end

    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x,16)) end)

    return str
end

function uic:chunk_to_hex(j, k)
    local block = {}
    for i = j,k do
        block[i] = self.bytes[i]
    end

    -- turn the table of numbers (ie. {84, 03, 00, 00}) into a string with spaces between each (ie. "84 03 00 00")
    local str = table.concat(block, " ", j, k)

    return str
end

-- take a chunk of the bytes and turn them into a length number
-- always an unsigned int4, which means it's a hex byte converted into a number followed by an empty 00 (or three empty 00's)
-- ie., 56 00 is translated into 86 length (as is 56 00 00 00)
function uic:chunk_to_len(j, k)

    -- get the hex string for this section
    local len = self:chunk_to_hex(j, k)

    -- cut out the "00"
    len = string.sub(len, 1, 2)

    -- turn the hex string into the real number (ie. 56 -> 86)
    len = tonumber(len, 16)

    return len
end

-- convert a 4-byte hex section into an integer
-- this part is a little weird, since integers like this are actually read backwards in hex (little-endian). ie., 84 03 00 00 in hex is read as 00 00 03 84, which ends up being 03 84, which is converted into 900
function uic:chunk_to_int16(j, k)
    local block = {}
    for i = j,k do
        block[i] = self.bytes[i]
    end

    local str = ""

    for i = k,j, -1 do
        str = str .. block[i]
    end

    str = tonumber(str, 16)
    return str
end

-- convert a single byte into true or false. 00 for false, 01 for true
function uic:chunk_to_boolean(j, k)
    local hex = self:chunk_to_hex(j, k)

    local ret = false
    if hex == "01" then
        ret = true
    end

    return ret
end

function uic:decipher_chunk(format, j, k)
    j = j + self.location - 1
    k = k + self.location - 1

    --print(j)
    --print(k)

    local format_to_func = {
        str = uic.chunk_to_str,
        str16 = uic.chunk_to_str16,
        hex = uic.chunk_to_hex,
        len = uic.chunk_to_len,
        int16 = uic.chunk_to_int16,
        bool = uic.chunk_to_boolean
    }

    local func = format_to_func[format]
    if not func then print("func not found") return end

    local retval = func(self, j, k)

    -- set location to k+1, for next chunk_to_str call
    self.location = k+1

    return retval
end

function uic:add_data(index, value)
    self.indexes[#self.indexes+1] = index
    
    self.data[index] = value
end

function uic:decipher(binary_data)
    self.bytes = binary_data

    -- first 10 bytes are always the version string - "Version102"
    local v = self:decipher_chunk("str", 1, 10)

    -- grab the last 3 digits and set it as version
    local v_num = tonumber(string.sub(v, 8, 10))
    local v = v_num
    self:add_data("version", v)

    -- next 4 bytes are the UI-ID for the component
    self:add_data("uid", self:decipher_chunk("hex", 1, 4))

    -- next 2 bytes are the length for the next string (unsigned int followed by 00), followed by the string itself (the UIC name)
    do
        local len = self:decipher_chunk("len", 1, 2) -- 1,2) used so the location goes beyond the 00
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

    -- next are the images
    -- starts with a counter for num-of-images; if it's 0, well, there are none!
    do
        local len = self:decipher_chunk("int16", 1, 4)
        --print("images length: "..len)

        -- TODO this better
        local images = {}
        for i = 1, len do
            local image = {}

            -- next 4 bytes are the UID for this image
            image.uid = self:decipher_chunk("hex", 1, 4)

            -- between 126-130 there's a new string here, worry about it later
            image.b_sth = ""
            if v_num >= 126 and v_num < 130 then
                image.b_sth = ""
            end

            -- grab the image path; might be 00 00
            local path = ""
            local path_len = self:decipher_chunk("len", 1, 2)

            if path_len == 0 then
                path = "00 00"
            else
                path = self:decipher_chunk("str", 1, path_len)
            end

            image.path = path

            -- get the width/height, 4-bytes eacah, int16
            local w,h = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
            image.width, image.height = w,h

            -- there's a final byte that's usually just 00
            image.extra = self:decipher_chunk("hex", 1, 1)

            images[#images+1] = image
        end

        self:add_data("images", images)
    end

    -- "mask image" next; refers to UID of an image. if none, then there is no mask.
    -- dunno if this even works!
    do
        self:add_data("mask_image", self:decipher_chunk("hex", 1, 4))
    end

    -- "b5" next; only available between 70-110
    -- undeciphered, obvo
    do
        local b5 = ""
        if v_num >= 70 and v_num < 110 then
            b5 = self:decipher_chunk("hex", 1, 4)
        end

        self:add_data("b5", b5)
    end

    -- "b_sth2" next; 126-130
    -- undeciphered, 16 bytes evidently
    do
        local b_sth2 = ""
        if v_num >= 126 and v_num < 130 then
            b_sth2 = self:decipher_chunk("hex", 1, 16)
        end

        self:add_data("b_sth2", b_sth2)
    end

    -- next up are states! :D
    do
        local num_states = self:decipher_chunk("len", 1, 4)

        local states = {}

        for i = 1, 1 do
            local state = {}

            -- first 4 are UID, doi
            state.uid = self:decipher_chunk("hex", 1, 4)

            -- b_sth next 16-bytes
            state.b_sth = ""
            if v_num >= 126 and v_num < 130 then
                state.b_sth = self:decipher_chunk("hex", 1, 16)
            end

            -- name next, using len
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.name = self:decipher_chunk("str", 1, len)
            end

            -- create the width/height bits
            local w,h = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
            state.width, state.height = w,h

            -- text; str16!
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.text = ""
                if len == 0 then
                    -- bloop
                    state.text = "00 00"
                else
                    state.text = self:decipher_chunk("str16", 1, len*2)
                end
            end

            -- tooltip text; str16!
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.tooltip_text = ""
                if len == 0 then
                    -- bloop
                    state.tooltip_text = "00 00"
                else
                    state.tooltip_text = self:decipher_chunk("str16", 1, len*2)
                end
            end

            -- text bounds; 4-bytes and 4-bytes
            do
                local w,h = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
                local hor,ver = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)

                state.text_bounds = {
                    w = w,
                    h = h,
                }

                state.text_align = {
                    hor = hor, -- 0 - left, 1 - center, 2 - right
                    ver = ver, -- 1 - top, 2 - middle, 3 - bottom
                }
            end

            -- texthbehavior (??)
            state.b1 = self:decipher_chunk("hex", 1, 1)

            -- text label
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.text_label = ""
                if len == 0 then
                    state.text_label = "00 00"
                else
                    state.text_label = self:decipher_chunk("str16", 1, len*2)
                end
            end

            -- b3(?) and localised text (the localised key for the text)
            do
                if v_num <= 115 then
                    -- b3 first, then localised
                    state.b3 = self:decipher_chunk("hex", 1, 2)
                    
                    local len = self:decipher_chunk("len", 1, 2)
                    state.localised = ""
                    if len == 0 then
                        state.localised = "00 00"
                    else
                        state.localised = self:decipher_chunk("str16", 1, len*2)
                    end
                else
                    -- the opposite             
                    local len = self:decipher_chunk("len", 1, 2)
                    state.localised = ""
                    if len == 0 then
                        state.localised = "00 00"
                    else
                        state.localised = self:decipher_chunk("str16", 1, len*2)
                    end

                    state.b3 = self:decipher_chunk("hex", 1, 2)
                end
            end

            -- tooltip label + b5 + b4, whatever they are
            -- "imagedock9patch, blockedanims"?
            do -- TODO make utf8 strings better than this nonsense, this is SPAGOOT
                state.tooltip_id = ""
                state.b4 = ""
                state.b5 = ""

                if v_num >= 70 and v_num < 90 then
                    local len = self:decipher_chunk("len", 1, 2)

                    if len == 0 then
                        state.tooltip_id = "00 00"
                    else
                        state.tooltip_id = self:decipher_chunk("str16", 1, len*2)
                    end
                elseif v_num >= 90 and v_num < 110 then
                    local len = self:decipher_chunk("len", 1, 2)

                    if len == 0 then
                        state.tooltip_id = "00 00"
                    else
                        state.tooltip_id = self:decipher_chunk("str16", 1, len*2)
                    end

                    do
                        local len = self:decipher_chunk("len", 1, 2)

                        if len == 0 then
                            state.b5 = "00 00"
                        else
                            state.b5 = self:decipher_chunk("str", 1, len)
                        end
                    end
                elseif v_num >= 110 and v_num < 120 then
                    if v_num <= 115 then
                        state.b4 = self:decipher_chunk("hex", 1, 4)
                    end
                elseif v_num == 121 or v_num == 129 then
                    local len = self:decipher_chunk("len", 1, 2)

                    if len == 0 then
                        state.b5 = "00 00"
                    else
                        state.b5 = self:decipher_chunk("str", 1, len)
                    end
                end
            end

            -- font name; opt -- TODO it's not optional!
            do
                local len = self:decipher_chunk("len", 1, 2)
                
                if len == 0 then
                    state.font_name = "00 00"
                else
                    state.font_name = self:decipher_chunk("str", 1, len)
                end
            end

            -- font size, leading, tracking and colour; all 4-bytes
            do
                -- TODO make this prettier?
                local size,leading,tracking = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)

                state.font_size, state.font_leading, state.font_tracking = size,leading,tracking

                -- next 4 bytes are the colour, in RGBA.
                local colour = self:decipher_chunk("hex", 1, 4)

                state.font_colour = colour
            end

            -- font category name
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.fontcat_name = self:decipher_chunk("str", 1, len)
            end

            -- the text offset; four 4-byte ints.
            -- left-offset, right-offset, top-offset, botom-offset, I *think*
            do
                -- it was just two ints for these versions
                if v >= 70 and v < 80 then
                    local x,y = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4)
                    state.text_offset = {
                        x = x,
                        y = y
                    }
                elseif v >= 80 and v <= 130 then
                    -- four ints; left, right, top, bottom
                    local l,r,t,b = self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4), self:decipher_chunk("int16", 1, 4) -- TODO GOD THIS SUCKS
                    state.text_offset = {
                        l=l,
                        r=r,
                        t=t,
                        b=b,
                    }
                end
            end

            -- b7, undeciphered
            -- focustype(?): interactive, disabled, pixelcollision
            do
                state.b7 = ""
                if v >= 70 and v < 80 then
                    state.b7 = self:decipher_chunk("hex", 1, 7) -- dunno what this did, huh
                elseif v >= 90 and v < 130 then
                    -- TODO the second byte sets interactive (00 = uninteractive, etc)
                    state.b7 = self:decipher_chunk("hex", 1, 4)
                end
            end

            -- shader name, https://chadvandy.github.io/tw_modding_resources/campaign/uicomponent.html#section:uicomponent:Shader%20Techniques
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.shader_name = self:decipher_chunk("str", 1, len)
            end 

            -- TODO these are actually floats not ints!
            -- TODO same for text shader vars
            -- shader variables; int16
            do
                local one,two,three,four =
                    self:decipher_chunk("int16", 1, 4),
                    self:decipher_chunk("int16", 1, 4),
                    self:decipher_chunk("int16", 1, 4),
                    self:decipher_chunk("int16", 1, 4)

                state.shader_vars = {
                    one,
                    two,
                    three,
                    four
                }
            end

            -- ditto as the same two above, but for text!
            do
                local len = self:decipher_chunk("len", 1, 2)

                state.text_shader_name = self:decipher_chunk("str", 1, len)
            end

            -- bloopadoop
            do
                local one,two,three,four =
                    self:decipher_chunk("int16", 1, 4),
                    self:decipher_chunk("int16", 1, 4),
                    self:decipher_chunk("int16", 1, 4),
                    self:decipher_chunk("int16", 1, 4)

                state.text_shader_vars = {
                    one,
                    two,
                    three,
                    four
                }
            end

            -- ComponentStateImages set on this image; can be zero
            do
                local num_state_images = self:decipher_chunk("len", 1, 4)

                local state_images = {}

                for j = 1, num_state_images do
                    local state_image = {}

                    -- references the UID of the ComponentImage in the UIC itself; MUST match one!
                    state_image.uid = self:decipher_chunk("hex", 1, 4)

                    -- dunno, undeciphered
                    if v >= 126 and v < 130 then
                        state_image.b_sth = self:decipher_chunk("hex", 1, 16)
                    else
                        state_image.b_sth = ""
                    end

                    do -- x/y offset from 0,0 (top left corner of parent)
                        local x,y = self:decipher_chunk("int16", 1, 4),self:decipher_chunk("int16", 1, 4)
                        state_image.offset = {
                            x=x,
                            y=y,
                        }
                    end

                    do -- dimensions, width + height
                        local w,h = self:decipher_chunk("int16", 1, 4),self:decipher_chunk("int16", 1, 4)
                        state_image.dimensions = {
                            w=w,
                            h=h
                        }
                    end

                    do -- colour; RGBA
                        state_image.colour = self:decipher_chunk("hex", 1, 4)
                    end

                    do -- ui_colour_preset_type_key (?)
                        state_image.str_sth = ""
                        if v>=119 and v<130 then
                            local len = self:decipher_chunk("len", 1, 2)
                            state_image.str_sth = self:decipher_chunk("str", 1, len)
                        end
                    end
                    
                    do -- boolean, whether it's a tiled image (ie. repeats upon margins) or isn't
                        state_image.tiled = self:decipher_chunk("bool", 1, 1)
                    end

                    do -- another boolean, for "is flipped on x-axis"
                        state_image.x_flipped = self:decipher_chunk("bool", 1, 1)
                    end

                    do -- well
                        state_image.y_flipped = self:decipher_chunk("bool", 1, 1)
                    end

                    do -- get the docking point; 4-bytes
                        local hex = self:decipher_chunk("hex", 1, 4)

                        -- cut so it's just the first byte (dock is only 0-9)
                        hex = string.sub(hex, 1,2)
                        
                        hex = tonumber(hex, 16)
                        state_image.docking_point = hex
                    end

                    do -- docking offset
                        local x,y = self:decipher_chunk("int16", 1, 4),
                            self:decipher_chunk("int16", 1, 4)

                        state_image.dock_offset = {
                            x=x,
                            y=y
                        }

                        -- TODO this might be CanResizeWidth/Height
                        -- dock right/bottom; they seem to be bools?
                        state_image.dock = {
                            right = self:decipher_chunk("bool", 1, 1),
                            left = self:decipher_chunk("bool", 1, 1),
                        }
                    end

                    do -- rotation angle and pivot points

                        -- TODO this is 4 bytes; no idea how it's turned into an angle.
                        -- rotation is in radians in TW UI, for future reference
                        state_image.rotation_angle = self:decipher_chunk("hex", 1, 4)

                        -- TODO this again; check what kind of ints they are, later on
                        state_image.pivot_point = {
                            x = self:decipher_chunk("hex", 1, 4),
                            y = self:decipher_chunk("hex", 1, 4),
                        }
                    end

                    do -- rotation axis & shader name
                        -- rot axis is 3 floats

                        if v >= 103 then
                            state_image.rotation_axis = {
                                self:decipher_chunk("int16", 1, 4),
                                self:decipher_chunk("int16", 1, 4),
                                self:decipher_chunk("int16", 1, 4),
                            }

                            local shader_name = ""

                            local len = self:decipher_chunk("len", 1, 2)

                            if len == 0 then
                                shader_name = "00 00"
                            else
                                shader_name = self:decipher_chunk("str", 1, len)
                            end
                            
                            state_image.shader_name = shader_name
                        else
                            local shader_name = ""

                            local len = self:decipher_chunk("len", 1, 2)

                            if len == 0 then
                                shader_name = "00 00"
                            else
                                shader_name = self:decipher_chunk("str", 1, len)
                            end
                            
                            state_image.shader_name = shader_name

                            state_image.rotation_axis = {
                                self:decipher_chunk("int16", 1, 4),
                                self:decipher_chunk("int16", 1, 4),
                                self:decipher_chunk("int16", 1, 4),
                            }
                        end
                    end

                    -- b4, undeciphered. always 00 00 00 00(?)
                    do
                        if v <= 102 then
                            state_image.b4 = self:decipher_chunk("hex", 1, 4)
                        end
                    end

                    -- margin / b5 / shader tech vars
                    do
                        if v == 79 then
                            state_image.b5 = self:decipher_chunk("hex", 1, 8)
                        elseif v >= 70 and v < 80 then
                            state_image.b5 = self:decipher_chunk("hex", 1, 9)
                        elseif v >= 80 and v < 95 then
                            if v == 92 or v == 93 then
                                state_image.margin = {
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                }
                            else
                                state_image.margin = {
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                }
                            end
                        else
                            if v >= 103 then
                                -- TODO:
                                --[[			
                                    if ($v >= 103){
                                        $this->shadertechnique_vars = my_unpack_array($my, 'f4', fread($h, 4 * 4));
                                        foreach ($this->shadertechnique_vars as &$a){ $a = round($a * 10000000) / 10000000; }
                                        unset($a);
                                    }
                                ]]

                                state_image.shadertechnique_vars = {
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                    self:decipher_chunk("hex", 1, 4),
                                }
                            end

                            state_image.margin = {
                                self:decipher_chunk("hex", 1, 4),
                                self:decipher_chunk("hex", 1, 4),
                                self:decipher_chunk("hex", 1, 4),
                                self:decipher_chunk("hex", 1, 4),
                            }

                            if v >= 125 and v < 130 then
                                state_image.b5 = self:decipher_chunk("hex", 1, 1)
                            end
                        end
                    end

                    state_images[#state_images+1] = state_image
                end

                state.state_images = state_images
            end

            -- mouse stuff
            --[[		
                // stateeditordisplaypos (2 ints)
                $this->b_mouse = tohex(fread($h, 8)); // unknown
            ]]
            do
                state.b_mouse = self:decipher_chunk("hex", 1, 8)

                
            end

            states[#states+1] = state
        end
        self:add_data("states", states)
    end
end


function uic:print()
    local indexes = self.indexes
    local data = self.data

    local tab = ""

    local function print_datum(str, datum)
        if type(datum) == "string" then
            str = str .. datum
        elseif type(datum) == "table" then
            str = str .. "{"

            local old_tab = tab

            -- test if it's an array or a k/v, by testing index [1]
            -- imperfect, but it works for my needs!
            if datum[1] ~= nil then
                -- it's an array; print it all in line
                for i = 1, #datum do
                    local val = datum[i]
                    str = print_datum(str, val)
                    if i ~= #datum then
                        str = str .. ", "
                    end
                end
            else
                tab = tab .. "\t"
                for k,v in pairs(datum) do
                    str = str .. "\n"
    
                    str = str .. k .. ": "
    
                    str = print_datum(str.."\n" ..tab, v)
                end
            end

            tab = old_tab
            str = str .. "}"
            
        elseif type(datum) == "number" then
            str = str .. tostring(datum)
        elseif type(datum) == "boolean" then
            str = str .. tostring(datum)
        else
            -- error!
        end

        return str
    end

    local ret = ""
   
    for i = 1, #indexes do
        local index = indexes[i]
        local datum = data[index]

        local str = print_datum(index..": ", datum)

        ret = ret .. str .. "\n"
    end

    print(ret)

    --[[print("Version: "..self.version)
    print("UID: "..self.uid)
    print("Name: "..self.name)
    print("b0: "..self.b0)
    print("events: "..self.events)

    print("Offsets: "..self.offsets.x..", "..self.offsets.y)
    print("b1: "..self.b1)
    print("b_01: "..self.b_01)
    print("visible: "..tostring(self.visible))
    print("b_02: "..self.b_02)
    
    print("tooltip text: "..self.tooltip_text)
    print("tooltip id: "..self.tooltip_id)

    print("docking point: "..self.docking_point)
    print("docking offset: "..self.dock_offsets.x .. ", "..self.dock_offsets.y)

    print("component priority: "..self.component_priority)
    print("default state: "..self.default_state)

    print("num images: "..#self.images)
    tab = "\t"
    for i = 1, #self.images do
        local image = self.images[i]
        print("image uid: "..image.uid)
        print("image b_sth:" ..image.b_sth)
        print("path: "..image.path)
        print("w: "..image.width)
        print("h: "..image.height)
        print("extra: "..image.extra)
    end
    tab = ""

    print("b5: "..self.b5)
    print("b_sth2: "..self.b_sth2)

    print("num states: "..#self.states)
    tab = "\t"
    for i = 1, #self.states do
        local state = self.states[i]

        print("uid: "..state.uid)
        print("name: "..state.name)
        print("bounds: "..state.width .. ", "..state.height)

        print("text: "..state.text)
        print("tooltip: "..state.tooltip_text)

        print("text bounds: "..state.text_bounds.w..", "..state.text_bounds.h)
        print("text align: "..state.text_align.hor..", "..state.text_align.ver)
        
        print("text label: "..state.text_label)

        print("b1: "..state.b1)
        print("b3: "..state.b3)

        print("localised key: "..state.localised)

        print("tooltip_text: "..state.tooltip_id)
        print("b4: "..state.b4)
        print("b5: "..state.b5)

        print("font name: "..state.font_name)

        print("font size: "..state.font_size)
        print("font lead: "..state.font_leading)
        print("font track: "..state.font_tracking)
        print("font colour: "..state.font_colour)

        print("fontcat: "..state.fontcat_name)

        print("text offset: ")
        for k,v in pairs(state.text_offset) do
            print("\t"..k ..": "..v)
        end

        print("b7: "..state.b7)

        print("shader name: "..state.shader_name)
        print("shader vars: ")
        for l = 1, #state.shader_vars do
            print("\t"..state.shader_vars[l])
        end

        print("num ComponentStateImages: "..#state.state_images)

        tab = tab .. "\t"
        for l = 1, #state.state_images do
            local state_image = state.state_images[l]

            print("uid: "..state_image.uid)
            print("bsth: "..state_image.b_sth)
            print("offset: ")
            for k,v in pairs(state_image.offset) do
                print("\t"..k..": "..v)
            end

            print("dimensions:")
            for k,v in pairs(state_image.dimensions) do
                print("\t"..k..": "..v)
            end

            print("colour: "..state_image.colour)
            print("??: "..state_image.str_sth)
            print("is tiled: "..tostring(state_image.tiled))
            print("is x-flipped: "..tostring(state_image.x_flipped))
            print("is y-flipped: "..tostring(state_image.y_flipped))

            print("dock point: "..state_image.docking_point)

            print("dock offset: ")
            for k,v in pairs(state_image.dock_offset) do
                print("\t"..k..": "..v)
            end

            print("dock(?): ")
            for k,v in pairs(state_image.dock) do
                print("\t"..k..": "..tostring(v))
            end
        end
        tab = "\t"
    end
    tab = ""]]
end

local function decipher_file(file_path)
    print("deciphering: "..file_path)

    local file = assert(io.open(file_path, "rb+"))

    local data = {}

    local block_num = 10

    while true do
        local bytes = file:read(block_num)
        if not bytes then break end

        for b in string.gfind(bytes, ".") do
            local byte = string.format("%02X", string.byte(b))

            data[#data+1] = byte
        end
    end

    file:close()

    local root = uic:new()
    root:decipher(data)

    root:print()
end

decipher_file("ui/bullet_point")
decipher_file("ui/button_cycle")

return uic