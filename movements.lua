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

-- track defaults across samples and recording
track_param_default = {
  amp = 1,
  delay = 0,
  pan = 0,
  filter = 20000,
  scale = 1,
  rate = 1,
  prob = 1,
  noise = 0,
  midi_1 = 1,
  midi_2 = 0,
  midi_3 = 0
}

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()

  manage_data()

  d_sample.build_params()
  d_seq.build_params()

  d_sample.init()
  d_seq.init()
  d_ui.init()
  d_grid.init()

  -- set default parameters
  for i, p in ipairs({'amp', 'pan'}) do
    for t=1,7 do
      params:set('track_' .. t .. "_" .. p, track_param_default[p])
    end
  end
  
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

-----------------------------------------------------------------
-- DATA
-----------------------------------------------------------------

function manage_data()

  -- save
  params.action_write = function(filename,name,number)
    print("finished writing '"..filename.."' as '"..name.."'", number)
    os.execute("mkdir -p "..norns.state.data.."/"..number.."/")

    d_data = {
      p_options = p_options,
      partitions = partitions,
      banks = banks,
      bank_folders = bank_folders,
      track_param_level = track_param_level,
      param_pattern = param_pattern,
      track_pool = track_pool,
      track_pool_cue = track_pool_cue,
      step = step,
      step_range = step_range,
      clock_range = clock_range,
      offset = offset,
      time_type = time_type,
      pattern = pattern,
      bank = bank
    }

    tab.save(d_data, norns.state.data.."/"..number.."/dots.data")

  end

  -- load
  params.action_read = function(filename,silent,number)
    print("finished reading '"..filename.."'", number)

    d_data = tab.load(norns.state.data.."/"..number.."/dots.data")

    p_options = d_data.p_options
    partitions = d_data.partitions
    banks = d_data.banks
    bank_folders = d_data.bank_folders
    track_param_level = d_data.track_param_level
    param_pattern = d_data.param_pattern
    track_pool = d_data.track_pool
    track_pool_cue = d_data.track_pool_cue
    step = d_data.step
    step_range = d_data.step_range
    clock_range = d_data.clock_range
    offset = d_data.offset
    time_type = d_data.time_type
    pattern = d_data.pattern
    bank = d_data.bank
    
  end

  -- delete
  params.action_delete = function(filename,name,number)
    print("finished deleting '"..filename, number)
    norns.system_cmd("rm -r "..norns.state.data.."/"..number.."/")
  end

end
