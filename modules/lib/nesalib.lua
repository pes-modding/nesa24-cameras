--[[
nesalib: A library of common functions for memory/code modification modules.
--]]

local m = {}
m.version = "1.0"
local hex = memory.hex


function m.helper(version, ini_filename, overlay_states, game_info)
    --[[
    overlay_states is expected to be a table like:
    {
        { ui = "Penalty Height: %0.2f", prop = "Penalty_height", decr = -0.2, incr = 0.2 },
        { ui = "Penalty Zoom: %0.2f", prop = "Penalty_zoom", decr = -0.3, incr = 0.3 },
    }

    game_info is expected to be a table like:
    {
        Penalty_zoom = { base = "pzoom", offs = 0x00, format = "f", len = 4, def = 17.60000038, save_as = "%0.2f" },
        Penalty_height   = { base = "pheight", offs = 0x00, format = "f", len = 4, def = 3, save_as = "%0.2f" },
    }
    --]]
 
    local t = {
        RESTORE_KEY = { name='8', code=0x38 },
        PREV_PROP_KEY = { name='9', code=0x39 },
        NEXT_PROP_KEY = { name='0', code=0x30 },
        PREV_VALUE_KEY = { name='-', code=0xbd },
        NEXT_VALUE_KEY = { name='+', code=0xbb },
    }

    local delta = 0
    local frame_count = 0
     
    local overlay_curr = 1
    local version = version
 

    local ui_lines = {}
    local bases = {}

    local settings
    local header_comment = "# Settings: " .. tostring(ini_filename)


    function t.set_ini_comment(value)
        header_comment = value
    end


    function t.set_base(name, value)
        bases[name] = value
    end


    function t.get_base(name)
        return bases[name]
    end


    function t.get_settings()
        return settings
    end


    function t.save_ini(ctx)
        local f,err = io.open(ctx.sider_dir .. "\\" .. ini_filename, "wt")
        if not f then
            log(string.format("PROBLEM saving settings: %s", tostring(err)))
            return
        end
        f:write(string.format("# %s\n\n", header_comment))
        local names = {}
        for k,_ in pairs(game_info) do
            names[#names + 1] = k
        end
        table.sort(names)
        for _,k in ipairs(names) do
            local v = settings[k] or game_info[k].def
            f:write(string.format("%s = %s\n", k, string.format(game_info[k].save_as, v)))
        end
        f:write("\n")
        f:close()
    end
 

    function t.load_ini(ctx)
        settings = {}
        -- initialize with defaults
        for prop,info in pairs(game_info) do
            settings[prop] = info.def
        end
        -- now try to read ini-file, if present
        local f,err = io.open(ctx.sider_dir .. "\\" .. ini_filename)
        if not f then
            return
        end
        f:close()
        for line in io.lines(ctx.sider_dir .. "\\" .. ini_filename) do
            local name, value = string.match(line, "^([%w_]+)%s*=%s*([-%w%d.]+)")
            if name and value then
                value = tonumber(value) or value
                settings[name] = value
                log(string.format("loaded setting: %s = %s", name, value))
            end
        end
    end
 

    function t.apply_settings(ctx, log_it, save_it)
        for name,value in pairs(settings) do
            local entry = game_info[name]
            if entry then
                local base = bases[entry.base]
                if base then
                    if entry.value_map then
                        value = entry.value_map[value]
                    end
                    local addr = base + entry.offs
                    local old_value, new_value
                    if entry.format ~= "" then
                        old_value = memory.unpack(entry.format, memory.read(addr, entry.len))
                        memory.write(addr, memory.pack(entry.format, value))
                        new_value = memory.unpack(entry.format, memory.read(addr, entry.len))
                        if log_it then
                            log(string.format("%s: changed at %s: %s --> %s",
                                name, hex(addr), old_value, new_value))
                        end
                    else
                        old_value = memory.read(addr, entry.len)
                        memory.write(addr, value)
                        new_value = memory.read(addr, entry.len)
                        if log_it then
                            log(string.format("%s: changed at %s: %s --> %s",
                                name, hex(addr), hex(old_value), hex(new_value)))
                        end
                    end
                end
            end
        end
        if save_it then
            t.save_ini(ctx)
        end
    end

 
    function t.repeat_change(ctx, after_num_frames, change)
        if change ~= 0 then
            frame_count = frame_count + 1
            if frame_count >= after_num_frames then
                local s = overlay_states[overlay_curr]
                settings[s.prop] = settings[s.prop] + change
                t.apply_settings(ctx, false) -- apply
            end
        end
    end
     

    function t.overlay_on(ctx)
        -- repeat change from gamepad, if delta exists
        t.repeat_change(ctx, 30, delta)
        -- construct ui text
        for i,v in ipairs(overlay_states) do
            local s = overlay_states[i]
            local setting = string.format(s.ui, settings[s.prop])
            if i == overlay_curr then
                ui_lines[i] = string.format("\n---> %s <---", setting)
            else
                ui_lines[i] = string.format("\n     %s", setting)
            end
        end
        return string.format([[version %s
    Keys: [%s][%s] - choose setting, [%s][%s] - modify value, [%s] - restore defaults
    Gamepad: RS up/down - choose setting, RS left/right - modify value
    %s]], version, t.PREV_PROP_KEY.name, t.NEXT_PROP_KEY.name,
            t.PREV_VALUE_KEY.name, t.NEXT_VALUE_KEY.name, t.RESTORE_KEY.name,
            table.concat(ui_lines))
    end


    function t.key_down(ctx, vkey)
        if vkey == t.NEXT_PROP_KEY.code then
            if overlay_curr < #overlay_states then
                overlay_curr = overlay_curr + 1
            end
        elseif vkey == t.PREV_PROP_KEY.code then
            if overlay_curr > 1 then
                overlay_curr = overlay_curr - 1
            end
        elseif vkey == t.NEXT_VALUE_KEY.code then
            local s = overlay_states[overlay_curr]
            if s.incr ~= nil then
                settings[s.prop] = settings[s.prop] + s.incr
            elseif s.nextf ~= nil then
                settings[s.prop] = s.nextf(settings[s.prop])
            end
            t.apply_settings(ctx, false, true)
        elseif vkey == t.PREV_VALUE_KEY.code then
            local s = overlay_states[overlay_curr]
            if s.decr ~= nil then
                settings[s.prop] = settings[s.prop] + s.decr
            elseif s.prevf ~= nil then
                settings[s.prop] = s.prevf(settings[s.prop])
            end
            t.apply_settings(ctx, false, true)
        elseif vkey == t.RESTORE_KEY.code then
            for i,s in ipairs(overlay_states) do
                settings[s.prop] = game_info[s.prop].def
            end
            t.apply_settings(ctx, false, true)
        end
    end
 

    function t.gamepad_input(ctx, inputs)
        local v = inputs["RSy"]
        if v then
            if v == -1 and overlay_curr < #overlay_states then -- moving down
                overlay_curr = overlay_curr + 1
            elseif v == 1 and overlay_curr > 1 then -- moving up
                overlay_curr = overlay_curr - 1
            end
        end
     
        v = inputs["RSx"]
        if v then
            if v == -1 then -- moving left
                local s = overlay_states[overlay_curr]
                if s.decr ~= nil then
                    settings[s.prop] = settings[s.prop] + s.decr
                    -- set up the repeat change
                    delta = s.decr
                    frame_count = 0
                elseif s.prevf ~= nil then
                    settings[s.prop] = s.prevf(settings[s.prop])
                end
                t.apply_settings(ctx, false, false) -- apply
            elseif v == 1 then -- moving right
                local s = overlay_states[overlay_curr]
                if s.decr ~= nil then
                    settings[s.prop] = settings[s.prop] + s.incr
                    -- set up the repeat change
                    delta = s.incr
                    frame_count = 0
                elseif s.nextf ~= nil then
                    settings[s.prop] = s.nextf(settings[s.prop])
                end
                t.apply_settings(ctx, false, false) -- apply
            elseif v == 0 then -- stop change
                delta = 0
                t.apply_settings(ctx, false, true) -- apply and save
            end
        end
    end

    return t
end


local function search_process(pattern, start_from)
    if not start_from then
        return memory.search_process(pattern)
    end
    -- more localized search: starting from a specific addr
    local pinfo = memory.get_process_info()
    for i,section in ipairs(pinfo.sections) do
        if start_from < section.finish then
            local start_addr = section.start
            if start_addr < start_from then
                start_addr = start_from
            end
            local addr = memory.search(pattern, start_addr, section.finish)
            if addr then
                return addr, section
            end
        end
    end
end


function m.cache(ctx, module_name)
    local t = {}
    local cache_file = ctx.sider_dir .. module_name:gsub("%.lua", ".cache")
    local locs = {}

    t.find_pattern = function(pattern, cache_id, start_from)
        if cache_id then
            -- check the cached location first: it might match
            local f = io.open(cache_file, "rb")
            if f then
                local cache_data = f:read("*all")
                f:close()
                local hint = string.sub(cache_data, (cache_id-1)*8+1, (cache_id-1)*8+8)
                if hint and hint ~= "" then
                    local addr = memory.unpack("i64", hint)
                    if addr and addr ~= 0 then
                        local data = memory.read(addr, #pattern)
                        if pattern == data then
                            log(string.format("matched cache hint #%s", cache_id))
                            locs[cache_id] = addr
                            return addr
                        end
                    end
                end
            end
            -- no cache, or no match: search the process
            local addr = search_process(pattern, start_from)
            if addr then
                locs[cache_id] = addr
                return addr
            end
        end
    end

    t.save = function()
        local f = io.open(cache_file, "wb")
        for i=1,#locs do
            addr = locs[i] or 0
            f:write(memory.pack("u64", addr))
        end
        f:close()
    end

    return t
end


function m.init(ctx)
    ctx.nesalib = m
end


return m
