--[[
=========================
CommonCam module and Game research by: nesa24, pedritoperez, juce
Requires: sider.dll 6.2.3+
modified to use nesalib by juce

Affects common camera that is used in game
for "Midrange","Long","Wide" and "Pitch (Field) Side" and "Custom" presets
=========================
--]]

local m = { version = "2.1" }
local hex = memory.hex
local helper

local overlay_states = {
    { ui = "Camera Zoom: %0.2f", prop = "zoom", decr = -0.5, incr = 0.5 },
    { ui = "Camera Height: %0.2f", prop = "height", decr = -0.01, incr = 0.01 },
    { ui = "Camera Angle: %0.2f", prop = "angle", decr = -0.01, incr = 0.01 },
    { ui = "Camera Pitch: %0.2f", prop = "pitch", decr = -0.1, incr = 0.1 },
}

local game_info = {
    zoom = { base = "cbase", offs = 0x28, format = "f", len = 4, def = 19.05, save_as = "%0.2f" },
    height = { base = "cbase", offs = 0x2c, format = "f", len = 4, def = 0.3, save_as = "%0.2f" },
    pitch = { base = "cbase", offs = 0x30, format = "f", len = 4, def = 0.5, save_as = "%0.2f" },
    angle  = { base = "cbase", offs = 0x44, format = "f", len = 4, def = 1.3, save_as = "%0.2f" },
}

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\CommonCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Common Camera Settings")

    local loc
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- Camera base
    -- 00000001471242FF | 84 C0                              | test al,al                             |
    -- 0000000147124301 | B9 06 00 00 00                     | mov ecx,6                              |
    -- 0000000147124306 | 0F 45 D9                           | cmovne ebx,ecx                         |
    -- 0000000147124309 | F3 0F 10 5F 0C                     | movss xmm3,dword ptr ds:[rdi+C]        |
    -- 000000014712430E | 48 8D 0D 5B 12 48 FB               | lea rcx,qword ptr ds:[1425A5570]       |
    loc = cache.find_pattern(
        "\x84\xc0" ..
        "\xb9\x06\x00\x00\x00" ..
        "\x0f\x45\xd9" ..
        "\xf3\x0f\x10\x5f\x0c" ..
        "\x48\x8d\x0d", 1)
    if loc then
        local offset = memory.unpack("i32", memory.read(loc + 0x12))
        local addr = loc + 0x16 + offset
        log(string.format("common camera base addr: %s", hex(addr)))
        helper.set_base("cbase", addr)
    else
        error("unable to find common camera base addr")
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
