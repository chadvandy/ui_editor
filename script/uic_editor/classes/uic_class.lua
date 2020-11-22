local ui_editor_lib = core:get_static_object("ui_editor_lib")

local uic_class = {}

-- TODO when it comes to internal fields, it should just be a "o.data" table, which is a table of tables, sorted numerically
-- each independent table within has a "key" and "value" field, for the key of the field and the value of the field (gasp)

function uic_class:new(key)
    local o = {}
    setmetatable(o, {__index = uic_class})

    o.key = key
    o.data = {} -- an array (ordered numerically, from 1 up) of tables, each with a .key index and a .value index. each .value is the different Lua object - ie., uic_field
    o.version = 0

    return o
end

function uic_class:get_version()
    return self.version
end

function uic_class:get_key()
    return self.key
end

function uic_class:get_data()
    return self.data
end

function uic_class:add_field(obj)
    local key = obj:get_data()

    self.data[#self.data+1] = {key=key,value=obj}

    return obj
end

function uic_class:set_version(verzh)
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

-- TODO add parser-deciphered fields into the uic_class
-- TODO add uic_class:display() or some such, which acts as the ui panel creator for this uicomponent - takes the list_box UIC component, and runs through this UIC object's data

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

-- "data_type" can be "header" or "table" (for now), empty for regular
function uic_class:add_data(index, value, data_type)
    self.indexes[#self.indexes+1] = index
    
    self.data[index] = {
        value = value,
        data_type = data_type,
    }
end

-- TODO move this entirely to layout_parser
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

        self:add_data("offsets", {x=x,y=y}, "table")

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
            do
                --[[		
                    // stateeditordisplaypos (2 ints)
                    $this->b_mouse = tohex(fread($h, 8)); // unknown
                ]]
                state.b_mouse = self:decipher_chunk("hex", 1, 8)

                local num_mouse = self:decipher_chunk("len", 1, 4)

                local mouses = {}
                if num_mouse == 0 then
                    -- no mouse objects!
                else
                    local mouse = {}
                    
                    mouse.mouse_state = self:decipher_chunk("hex", 1, 4)

                    mouse.state_uid = self:decipher_chunk("hex", 1, 4)

                    if v>= 122 and v < 130 then
                        mouse.b_sth = self:decipher_chunk("hex", 1, 16)
                    end

                    mouse.b0 = self:decipher_chunk("hex", 1, 4)

                    

                    mouses[#mouses+1] = mouse
                end
            end

            states[#states+1] = state
        end
        self:add_data("states", states)
    end

    self.deciphered = true
end

--

return uic_class