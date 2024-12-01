-- dots
--
-- See docs.

-- norns `require` statements
-- x = require('module')

engine.name = "d_Timber"

-- script components
d_rec = include 'lib/d_rec'
d_sample = include 'lib/d_sample'
d_seq = include 'lib/d_seq'
d_grid = include 'lib/d_grid'
d_ui = include 'lib/d_ui'

HOLD_K1 = false
REDRAW_FRAMERATE = 30  -- same for grid and screen
DISPLAY_ID = 1
PAGE_ID = 1

-- parameter options for all non-timber parameters
p_options = {}

-- track defaults. 
track_param_default = {
  amp = 1,
  length = 1,
  pan = 0,
  filter = 20000,
  scale = 1,
  rate = 1,
  prob = 1,
  midi_transpose = 1,
  midi_2 = 0,
  midi_3 = 0
}

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()

  d_sample.build_params()
  d_seq.build_params()

  d_sample.init()
  d_seq.init()
  d_ui.init()
  d_grid.init()
  
  -- redraw clock
  screen_dirty = true
  grid_dirty = true
  clock.run(redraw_clock)
end

-----------------------------------------------------------------
-- UI
-----------------------------------------------------------------

function redraw()
  screen.clear()

  display[DISPLAY_ID]:redraw()
  d_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_redraw"]()

  screen.update()
end

function key(n, z)
  if n == 1 then
    if z == 1 then
      HOLD_K1 = true
    else
      HOLD_K1 = false
    end
  end

  d_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_key"](n,z)

  -- !! "screen_dirty" decided in primary function !!
end

function enc(n, d)
  if n == 1 then
    if HOLD_K1 then
      DISPLAY_ID = util.clamp(DISPLAY_ID + d, 1, #display_names)
      PAGE_ID = 1
    else
      display[DISPLAY_ID]:set_index_delta(d, false)
      PAGE_ID = display[DISPLAY_ID].index
    end
    screen_dirty = true
  end

  d_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_enc"](n,d)

  -- !! "screen_dirty" decided in primary function !!
end

function redraw_clock()
  while true do
    clock.sleep(1/REDRAW_FRAMERATE)
    
    if screen_dirty then
      redraw()
      screen_dirty = false
    end

    if grid_dirty then
      d_grid:grid_redraw()
      grid_dirty = false
    end

  end
end
