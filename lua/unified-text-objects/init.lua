local M = {}

local config = {
    bindings = {},
    enable_next = true,
    enable_last = true,
    enable_every = true,
}

local function register_binding(mode, selector, object, name, callback, options)
    local left = mode .. selector .. object

    options = options or {}
    options.desc = "<name of " .. mode .. "> <name of " .. selector .. "> " .. name

    vim.keymap.set("o", left, function() callback(false) end, options)
    vim.keymap.set("x", left, function() callback(true) end, options)
end

local function select(first_line, start_column, last_line, end_column, visual, line_mode)
    print(tostring(first_line) .. ":" .. tostring(last_line))

    local mode = "v"
    if visual then
        mode = ""
    end

    local visual_mode = ""
    if line_mode then
        visual_mode = "V"
    end

    vim.cmd("norm! " ..
        first_line ..
        "gg" .. start_column .. "|" .. mode .. "o" .. last_line .. "gg" .. end_column .. "|" .. visual_mode)
end

M.register_binding = function(binding)
    -- TODO: validate modes
    -- i.e. cannot be 'n', 'l', 'e' (or 'w', 'W', or anything else that already has a meaning in operator pending mode)

    for _, mode in ipairs(binding.modes) do
        register_binding(mode, "", binding.key, binding.name, function(visual)
            local object = binding.callback(mode, "cursor")

            if object then
                select(object.first_line, object.start_column, object.last_line, object.end_column, visual,
                    binding.visual_mode == "linewise")
            end
        end)

        if config.enable_next then
            register_binding(mode, "n", binding.key, binding.name, function(visual)
                local object = binding.callback(mode, "next")

                if object then
                    select(object.first_line, object.start_column, object.last_line, object.end_column, visual,
                        binding.visual_mode == "linewise")
                end
            end)
        end

        if config.enable_last then
            register_binding(mode, "l", binding.key, binding.name, function(visual)
                local object = binding.callback(mode, "last")

                if object then
                    select(object.first_line, object.start_column, object.last_line, object.end_column, visual,
                        binding.visual_mode == "linewise")
                end
            end)
        end

        if config.enable_every then
            register_binding(mode, "e", binding.key, binding.name, function(visual)
                local objects = binding.callback(mode, "every")

                -- Generate targets for hop
                local generator = function()
                    local cursor_position = vim.api.nvim_win_get_cursor(0)
                    local buffer = vim.api.nvim_get_current_buf()
                    local window = vim.api.nvim_get_current_win()
                    local jump_targets = {}
                    local indirect_jump_targets = {}

                    for _, object in ipairs(objects) do
                        table.insert(jump_targets, {
                            buffer = buffer,
                            line = object.first_line - 1,
                            length = 1,
                            column = object.start_column,
                            window = window,
                            object = object,
                        })

                        table.insert(indirect_jump_targets, {
                            index = #jump_targets,
                            score = math.abs(cursor_position[1] - object.first_line) -- TODO: subtract cursor column as well
                        })
                    end

                    return {
                        jump_targets = jump_targets,
                        indirect_jump_targets = indirect_jump_targets,
                    }
                end

                require("hop").hint_with_callback(generator, nil, function(target)
                    local object = target.object
                    select(object.first_line, object.start_column, object.last_line, object.end_column, visual,
                        binding.visual_mode == "linewise")
                end)
            end)
        end
    end
end

M.setup = function( --[[ config ]])
    for _, binding in ipairs(config.bindings) do
        M.register_binding(binding)
    end
end

return M
