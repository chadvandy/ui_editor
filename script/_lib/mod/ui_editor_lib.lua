local ui_editor_lib = {
    loaded_uic = nil,
    loaded_uic_path = nil,
}

function ui_editor_lib.init()
    local path = "script/uic_editor/classes/"

    ui_editor_lib.parser =      require(path.."layout_parser") -- the manager for deciphering the hex and turning it into more accessible objects
    ui_editor_lib.ui =          require(path.."ui_panel") -- the in-game UI panel manager

    ui_editor_lib.uic_class =   require(path.."uic_class") -- the class def for the UIComponent type - main boy with names, events, offsets, states, images, children, etc
    ui_editor_lib.uic_field =   require(path.."uic_field") -- the class def for UIComponent fields - ie., "offset", "width", "is_interactive" are all fields
end

function ui_editor_lib.load_uic_with_path(path)
    if not is_string(path) then
        -- errmsg
        return false
    end

    local file = assert(io.open(path, "rb+"))
    if not file then
        ModLog("file not found!")
        return false
    end

    local data = ""
    local nums = {}
    --local location = 1

    local block_num = 10
    while true do
        local bytes = file:read(block_num)
        if not bytes then break end

        for b in string.gfind(bytes, ".") do
            local byte = string.format("%02X", string.byte(b))

            data = data .. " " .. byte
            nums[#nums+1] = byte
        end
    end

    file:close()

    local uic = ui_editor_lib.uic_class:new_with_data(data, nums)
    ui_editor_lib.loaded_uic = uic
    ui_editor_lib.loaded_uic_path = path

    ui_editor_lib.ui:load_uic()
end

core:add_static_object("ui_editor_lib", ui_editor_lib)

ui_editor_lib.init()