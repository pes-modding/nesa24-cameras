--[[
=========================
VerticalCam module and Game research by: nesa24
Requires: sider.dll 6.2.3+
modified to use nesalib by juce
=========================
--]]

local m = { version = "2.0" }
local hex = memory.hex
local helper

local overlay_states = {
    { ui = "Vertical Height: %0.2f", prop = "vert_height", decr = -0.01, incr = 0.01 },
    { ui = "Vertical Zoom: %0.2f", prop = "vert_zoom", decr = -0.10, incr = 0.10 },
    { ui = "Vertical Angle: %0.2f", prop = "vert_angle", decr = -0.01, incr = 0.01 },
    { ui = "Vertical Pitch: %0.2f", prop = "vert_pitch", decr = -0.50, incr = 0.50 },
}

local game_info = {
    vert_height = { base = "vbase", offs = 0x08, format = "f", len = 4, def = 0.3, save_as = "%0.2f" },
    vert_pitch = { base = "vbase", offs = 0x0c, format = "f", len = 4, def = 35, save_as = "%0.2f" },
    vert_zoom = { base = "vbase", offs = 0x10, format = "f", len = 4, def = 16.01, save_as = "%0.2f" },
    vert_angle  = { base = "vangle", offs = 0x00, format = "f", len = 4, def = 0.83, save_as = "%0.2f" },
}

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\VerticalCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Vertical Camera Settings")

    local loc
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- Height/Zoom/Pitch
    -- 0000000146D88764 | 48 8B 7C 24 60                     | mov rdi,qword ptr ss:[rsp+60]          |
    -- 0000000146D88769 | 48 8B 74 24 58                     | mov rsi,qword ptr ss:[rsp+58]          |
    -- 0000000146D8876E | 48 8B 5C 24 50                     | mov rbx,qword ptr ss:[rsp+50]          |
    -- 0000000146D88773 | 83 F8 07                           | cmp eax,7                              |
    -- 0000000146D88776 | 75 19                              | jne pes2020.146D88791                  |
    -- 0000000146D88778 | 4C 8D 05 D1 B4 81 FB               | lea r8,qword ptr ds:[1425A3C50]        |
    loc = cache.find_pattern(
        "\x48\x8b\x7c\x24\x60" ..
        "\x48\x8b\x74\x24\x58" ..
        "\x48\x8b\x5c\x24\x50" ..
        "\x83\xf8\x07" ..
        "\x75\x19" ..
        "\x4c\x8d\x05", 1)
    if loc then
        local offset = memory.unpack("i32", memory.read(loc + 0x17))
        local addr = loc + 0x1b + offset
        log(string.format("vertical camera height/zoom/pitch base addr: %s", hex(addr)))
        helper.set_base("vbase", addr)
    else
        error("unable to find stadium camera angle addr")
    end

    -- Angle
    -- 0000000146D84D54 | F3 0F 11 85 BC 00 00 00            | movss dword ptr ss:[rbp+BC],xmm0       |
    -- 0000000146D84D5C | F3 0F 11 8D C0 00 00 00            | movss dword ptr ss:[rbp+C0],xmm1       |
    -- 0000000146D84D64 | F3 0F 11 95 C4 00 00 00            | movss dword ptr ss:[rbp+C4],xmm2       |
    -- 0000000146D84D6C | E9 52 FE FF FF                     | jmp pes2020.146D84BC3                  |
    -- 0000000146D84D71 | 0F 28 C8                           | movaps xmm1,xmm0                       |
    -- 0000000146D84D74 | F3 0F 59 0D E8 F0 81 FB            | mulss xmm1,dword ptr ds:[1425A3E64]    |
    loc = cache.find_pattern(
        "\xf3\x0f\x11\x85\xbc\x00\x00\x00" ..
        "\xf3\x0f\x11\x8d\xc0\x00\x00\x00" ..
        "\xf3\x0f\x11\x95\xc4\x00\x00\x00" ..
        "\xe9", 2)
    if loc then
        local offset = memory.unpack("i32", memory.read(loc + 0x24))
        local addr = loc + 0x28 + offset
        log(string.format("vertical camera angle addr: %s", hex(addr)))
        helper.set_base("vangle", addr)
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
