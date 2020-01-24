--[[
=========================
FanView Camera module
Game research by: nesa24
Requires: sider.dll 6.0.1+ and nesalib
module written by juce
=========================
--]]

local m = { version = "2.2" }
local hex = memory.hex

local overlay_states = {
    { ui = "FanView camera zoom: %0.2f", prop = "fanview_camera_zoom", decr = -0.1, incr = 0.1 },
    { ui = "FanView camera height: %0.2f", prop = "fanview_camera_height", decr = -0.01, incr = 0.01 },
    { ui = "FanView camera angle: %0.2f", prop = "fanview_camera_angle", decr = -0.1, incr = 0.1 },
}

local game_info = {
    fanview_camera_zoom   = { base = "camera", offs = 0x08, format = "f", len = 4, def = 25.60, save_as = "%0.2f" },
    fanview_camera_height = { base = "camera", offs = 0x0c, format = "f", len = 4, def = 0.43, save_as = "%0.2f" },
    fanview_camera_angle  = { base = "camera", offs = 0x24, format = "f", len = 4, def = 1, save_as = "%0.2f" },
}

function m.set_teams(ctx, home, away)
    helper.apply_settings(ctx, true)
end

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\FanView.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("FanView Camera Settings")

    local loc
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- Camera base
    -- 0000000147E08772 | 0F 11 44 24 20                     | movups xmmword ptr ss:[rsp+20],xmm0    |
    -- 0000000147E08777 | 89 45 87                           | mov dword ptr ss:[rbp-79],eax          |
    -- 0000000147E0877A | 0F 11 4C 24 30                     | movups xmmword ptr ss:[rsp+30],xmm1    |
    loc = cache.find_pattern("\x0f\x11\x44\x24\x20\x89\x45\x87\x0f\x11\x4c\x24\x30", 1)
    if loc then
        local offset = memory.unpack("i32", memory.read(loc - 4, 4))
        local addr = loc + offset
        log(string.format("fanview camera base addr: %s", hex(addr)))
        helper.set_base("camera", addr)
    else
        error("unable to find fanview camera base addr")
    end

    -- save locations cache
    cache.save()

    -- apply our values
    helper.apply_settings(ctx, true)

    -- register for events
    ctx.register("set_teams", m.set_teams)
    ctx.register("overlay_on", helper.overlay_on)
    ctx.register("key_down", helper.key_down)
    ctx.register("gamepad_input", helper.gamepad_input)
end

return m
