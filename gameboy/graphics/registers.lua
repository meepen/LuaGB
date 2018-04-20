local bit32 = require("bit")
local ffi   = require "ffi"

local function new_registers(registers, cache)
  for k,v in pairs {
    display_enabled = true,
    window_tilemap = cache.map_0,
    window_attr = cache.map_0_attr,
    window_enabled = true,
    tile_select = 0x9000,
    background_tilemap = cache.map_0,
    background_attr = cache.map_0_attr,
    large_sprites = false,
    sprites_enabled = true,
    background_enabled = true,
    oam_priority = false,
    status = {
      --status.SetMode = function(mode)
      mode = 2,
      lyc_interrupt_enabled = false,
      oam_interrupt_enabled = false,
      vblank_interrupt_enabled = false,
      hblank_interrupt_enabled = false
    } 
  } do
    registers[k] = v
  end
end

if (ffi) then
  function new_registers(registers, cache)
    registers = registers or ffi.new "LuaGBGraphicRegisters"
    registers.display_enabled = true
    registers.window_tilemap = cache.map_0
    registers.window_attr = cache.map_0_attr
    registers.window_enabled = true
    registers.tile_select = 0x9000
    registers.background_tilemap = cache.map_0
    registers.background_attr = cache.map_0_attr
    registers.large_sprites = false
    registers.sprites_enabled = true
    registers.background_enabled = true
    registers.oam_priority = false
    registers.status = {
      --status.SetMode = function(mode)
      mode = 2,
      lyc_interrupt_enabled = false,
      oam_interrupt_enabled = false,
      vblank_interrupt_enabled = false,
      hblank_interrupt_enabled = false
    }
    return registers
  end
end

local Registers = {}

function Registers.new(registers, g, gameboy, cache)
  local io = gameboy.io
  local ports = io.ports

  registers = new_registers(registers, cache)
  local status = registers.status

  io.write_logic[ports.LCDC] = function(byte)
    io[1][ports.LCDC] = byte

    -- Unpack all the bit flags into lua variables, for great sanity
    registers.display_enabled = bit32.band(0x80, byte) ~= 0
    registers.window_enabled  = bit32.band(0x20, byte) ~= 0
    registers.large_sprites   = bit32.band(0x04, byte) ~= 0
    registers.sprites_enabled = bit32.band(0x02, byte) ~= 0

    if gameboy.type == gameboy.types.color then
      registers.oam_priority = bit32.band(0x01, byte) == 0
    else
      registers.background_enabled = bit32.band(0x01, byte) ~= 0
    end

    if bit32.band(0x40, byte) ~= 0 then
      registers.window_tilemap = cache.map_1
      registers.window_attr = cache.map_1_attr
    else
      registers.window_tilemap = cache.map_0
      registers.window_attr = cache.map_0_attr
    end

    if bit32.band(0x10, byte) ~= 0 then
      if registers.tile_select == 0x9000 then
        -- refresh our tile indices, they'll all need recalculating for the new offset
        registers.tile_select = 0x8000
        cache.refreshTileMaps()
      end
    else
      if registers.tile_select == 0x8000 then
        -- refresh our tile indices, they'll all need recalculating for the new offset
        registers.tile_select = 0x9000
        cache.refreshTileMaps()
      end
    end

    if bit32.band(0x08, byte) ~= 0 then
      registers.background_tilemap = cache.map_1
      registers.background_attr = cache.map_1_attr
    else
      registers.background_tilemap = cache.map_0
      registers.background_attr = cache.map_0_attr
    end
  end

  status.SetMode = function(mode)
    status.mode = mode
    io[1][ports.STAT] = bit32.band(io[1][ports.STAT], 0xFC) + bit32.band(mode, 0x3)
  end


  io.write_logic[ports.STAT] = function(byte)
    io[1][ports.STAT] = bit32.band(byte, 0x78)
    status.lyc_interrupt_enabled = bit32.band(byte, 0x40) ~= 0
    status.oam_interrupt_enabled = bit32.band(byte, 0x20) ~= 0
    status.vblank_interrupt_enabled = bit32.band(byte, 0x10) ~= 0
    status.hblank_interrupt_enabled = bit32.band(byte, 0x08) ~= 0
  end

  return registers
end

return Registers
