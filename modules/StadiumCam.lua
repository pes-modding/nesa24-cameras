--[[
=========================
StadiumCam module and Game research by: nesa24
Requires: sider.dll 6.2.3+
modified to use nesalib by juce
=========================
--]]

local m = { version = "2.0" }
local hex = memory.hex
local helper

local overlay_states = {
    { ui = "StadiumCam Height: %0.2f", prop = "stad_height", decr = -0.01, incr = 0.01 },
    { ui = "StadiumCam Zoom: %0.2f", prop = "stad_zoom", decr = -0.25, incr = 0.25 },
    { ui = "StadiumCam Angle: %0.2f", prop = "stad_angle", decr = -0.01, incr = 0.01 },
    { ui = "StadiumCam Pitch: %0.2f", prop = "stad_pitch", decr = -0.01, incr = 0.01 },
}

local game_info = {
    stad_height   = { base = "sheight", offs = 0x00, format = "f", len = 4, def = 0.3, save_as = "%0.2f" },
    stad_zoom = { base = "szoom", offs = 0x00, format = "f", len = 4, def = 70, save_as = "%0.2f" },
    stad_angle  = { base = "sangle", offs = 0x00, format = "f", len = 4, def = 0.39, save_as = "%0.2f" },
    stad_pitch  = { base = "spitch", offs = 0x00, format = "f", len = 4, def = 0.5, save_as = "%0.2f" },
}

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\StadiumCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Stadium Camera Settings")

    local loc
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- Pitch
    -- 0000000149FB14E5 | 48 89 45 27                        | mov qword ptr ss:[rbp+27],rax          |
    -- 0000000149FB14E9 | 48 63 41 78                        | movsxd rax,dword ptr ds:[rcx+78]       |
    -- 0000000149FB14ED | 4C 8D 05 EC 3B 46 F9               | lea r8,qword ptr ds:[1434150E0]        |`
    loc = cache.find_pattern("\x48\x89\x45\x27\x48\x63\x41\x78\x4c\x8d\x05", 1)
    if loc then
        local rel_offset = memory.unpack("i32", memory.read(loc + 11, 4))
        local addr = loc + 15 + rel_offset
        -- pitch is the 4th float from the start addr
        addr = addr + 0x0c
        log(string.format("stadium camera pitch addr: %s", hex(addr)))
        helper.set_base("spitch", addr)
    else
        error("unable to find stadium camera pitch addr")
    end

    local start_from = loc

    -- Height
    -- 0000000149FB1633 | F3 0F 11 45 CF                     | movss dword ptr ss:[rbp-31],xmm0       |
    -- 0000000149FB1638 | EB 07                              | jmp pes2020.149FB1641                  |
    -- 0000000149FB163A | C7 45 CF 9A 99 99 3E               | mov dword ptr ss:[rbp-31],3E99999A     |
    loc = cache.find_pattern("\xf3\x0f\x11\x45\xcf\xeb\x07\xc7\x45\xcf", 2, start_from)
    if loc then
        local base_addr = loc + 10
        log(string.format("stadium camera height addr: %s", hex(base_addr)))
        helper.set_base("sheight", base_addr)
    else
        error("unable to find stadium camera height addr")
    end

    -- Zoom
    -- 0000000149FB172E | F3 0F 11 45 D7                     | movss dword ptr ss:[rbp-29],xmm0       |
    -- 0000000149FB1733 | EB 07                              | jmp pes2020.149FB173C                  |
    -- 0000000149FB1735 | C7 45 D7 00 00 8C 42               | mov dword ptr ss:[rbp-29],428C0000     |
    loc = cache.find_pattern("\xf3\x0f\x11\x45\xd7\xeb\x07\xc7\x45\xd7", 3, start_from)
    if loc then
        local base_addr = loc + 10
        log(string.format("stadium camera zoom addr: %s", hex(base_addr)))
        helper.set_base("szoom", base_addr)
    else
        error("unable to find stadium camera zoom addr")
    end

    -- Angle
    -- 0000000149FB17D1 | F3 0F 11 65 E7                     | movss dword ptr ss:[rbp-19],xmm4       |
    -- 0000000149FB17D6 | EB 07                              | jmp pes2020.149FB17DF                  |
    -- 0000000149FB17D8 | C7 45 E7 14 AE C7 3E               | mov dword ptr ss:[rbp-19],3EC7AE14     |
    loc = cache.find_pattern("\xf3\x0f\x11\x65\xe7\xeb\x07\xc7\x45\xe7", 4, start_from)
    if loc then
        local base_addr = loc + 10
        log(string.format("stadium camera angle addr: %s", hex(base_addr)))
        helper.set_base("sangle", base_addr)
    else
        error("unable to find stadium camera angle addr")
    end

    -- save locations cache
    cache.save()

    -- apply our values
    helper.apply_settings(ctx, true)

    -- register for events
    ctx.register("overlay_on", helper.overlay_on)
    ctx.register("key_down", helper.key_down)
    ctx.register("gamepad_input", helper.gamepad_input)
end

return m
