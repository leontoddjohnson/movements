-- movements
--
-- time allows for movement.

-- norns `require` statements
-- x = require('module')

engine.name = "m_Timber"

-- script components
m_tape = include 'lib/m_tape'
m_sample = include 'lib/m_sample'
m_seq = include 'lib/m_seq'
m_grid = include 'lib/m_grid'
m_ui = include 'lib/m_ui'
m_delay = include 'lib/m_delay'

HOLD_K1 = false
REDRAW_FRAMERATE = 30  -- same for grid and screen
DISPLAY_ID = 1
PAGE_ID = 1

-- parameter options for all non-timber parameters
p_options = {}

-- [0, 1] by 0.01 control spec with default 0
specs.AMP0 = controlspec.new(0, 1, 'lin', 0, 0, '', 0.01)

-- [0, 1] by 0.01 control spec with default 1
specs.AMP1 = controlspec.new(0, 1, 'lin', 0, 1, '', 0.01)

-- filter resonance for softcut, a bit different than the timber engine
specs.FILTER_RESONANCE_SC = controlspec.new(0.1, 4.0, 'exp', 0.01, 2.0, "")

-- track defaults across samples and recording
track_param_default = {
  amp = 1,
  delay = 0,
  pan = 0,
  filter_freq = 20000,
  filter_type = 1,
  filter_resonance = 0,  -- sample only. for SC, see `FILTER_RESONANCE_SC` above
  scale = 2,
  scale_type = 1,
  interval = 7,
  prob = 1,
  noise = 0,
  pre = 0,
  crossfade = 0.1,
  transpose = 0
}

file_select_active = false

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()

  -- MAIN INIT --------------------------------------------------
  m_seq.init()
  m_ui.init()
  m_grid.init()
  m_delay.init()
  m_tape.init()

  -- BUILD PARAMS -----------------------------------------------
  -- define track param levels (to squelch/adjust step values for tracks)
  -- use track_param_level[track][param]
  track_param_level = {{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}}

  for track = 1,11 do
    for k,v in pairs(track_param_default) do
      if k == 'filter_resonance' and track > 7 then
        -- different rq measure for softcut?
        track_param_level[track][k] = specs.FILTER_RESONANCE_SC.default
      else
        track_param_level[track][k] = v
      end
    end
  end

  -- save/load from PSET
  manage_data()

  -- define params
  params:add_separator("Global")
  m_seq.build_params()
  
  params:add_separator("Tape")
  m_tape.build_params()
  m_delay.build_params()

  params:add_separator("Sample Track Levels")
  m_sample.build_sample_track_params()

  params:add_separator("Tape Track Levels")
  m_tape.build_tape_track_params()

  m_sample.build_timber_params()
  m_sample.timber_init()  -- separate init for timber after params

  -- MAIN INIT --------------------------------------------------
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
  m_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_redraw"]()

  screen.update()
end

function key(n, z)
  if n == 1 then
    if z == 1 then
      HOLD_K1 = true
      screen_dirty = true
    else
      HOLD_K1 = false
      screen_dirty = true
    end
  end

  m_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_key"](n,z)

  -- !! "screen_dirty" decided in primary function !!
end

function enc(n, d)
  if n == 1 then
    if HOLD_K1 then
      DISPLAY_ID = util.clamp(DISPLAY_ID + d, 1, #display_names)
      PAGE_ID = display[DISPLAY_ID].index
      display[DISPLAY_ID]:set_index(PAGE_ID)
      m_ui.set_functionality()
    else
      display[DISPLAY_ID]:set_index_delta(d, false)
      PAGE_ID = display[DISPLAY_ID].index
    end

    grid_dirty = true
    screen_dirty = true
  end

  m_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_enc"](n,d)

  -- !! "screen_dirty" decided in primary function !!
end

function redraw_clock()
  while true do
    clock.sleep(1/REDRAW_FRAMERATE)
    
    if screen_dirty and not file_select_active then
      redraw()
      screen_dirty = false
    end

    if grid_dirty then
      m_grid:grid_redraw()
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
    local fpath = norns.state.data.."/"..number

    os.execute("mkdir -p " .. fpath .. "/")

    m_data = {
      track_param_level = track_param_level,
      sample_reversed = sample_reversed,
      banks = banks,
      bank_folders = bank_folders,
      param_pattern = param_pattern,
      track_pool = track_pool,
      track_pool_cue = track_pool_cue,
      step = step,
      step_range = step_range,
      clock_range = clock_range,
      time_type = time_type,
      pattern = pattern,
      record_pattern = record_pattern,
      bank = bank,
      buffer_waveform = buffer_waveform,
      slice_params = slice_params,
      slice_reversed = slice_reversed,
      track_buffer = track_buffer,
      loaded_files = loaded_files
    }

    tab.save(m_data, fpath .. "/movements.data")
    softcut.buffer_write_stereo(fpath .. "/audio.wav", 0, -1)

    print("finished writing '"..filename.."' as '"..name.."'", number)

  end

  -- load
  params.action_read = function(filename,silent,number)
    local fpath = norns.state.data.."/"..number

    m_data = tab.load(fpath .. "/movements.data")

    track_param_level = m_data.track_param_level
    sample_reversed = m_data.sample_reversed
    banks = m_data.banks
    bank_folders = m_data.bank_folders
    param_pattern = m_data.param_pattern
    track_pool = m_data.track_pool
    track_pool_cue = m_data.track_pool_cue
    step = m_data.step
    step_range = m_data.step_range
    clock_range = m_data.clock_range
    time_type = m_data.time_type
    pattern = m_data.pattern
    record_pattern = m_data.record_pattern
    bank = m_data.bank
    buffer_waveform = m_data.buffer_waveform
    slice_params = m_data.slice_params
    slice_reversed = m_data.slice_reversed
    track_buffer = m_data.track_buffer
    loaded_files = m_data.loaded_files

    softcut.buffer_read_stereo(fpath .. "/audio.wav", 0, 0, -1, 0, 1)
    print("finished reading '"..filename.."'", number)

    m_tape.reset_buffer_view()
    
  end

  -- delete
  params.action_delete = function(filename,name,number)
    local fpath = norns.state.data.."/"..number

    norns.system_cmd("rm -r ".. fpath .."/")
    print("finished deleting '"..filename, number)
  end

end
