-- user interface
-- i.e., redraw, key, and enc for each page

-- each page should be paired with a grid page
-- "shift" on grid associated with K1
-- E1 changes page
-- each page only uses E/K 2 and 3

-- not sure about this yet ...:
-- grid page change --> affect display page
-- display page change --> NO grid page change

local m_ui = {}

local UI = require "ui"

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_ui.init()
  display = {}
  display[1] = UI.Pages.new(1, 5)  -- sample
  display[2] = UI.Pages.new(2, 1)  -- tape
  display[3] = UI.Pages.new(3, 1)  -- delay

  -- display info in order
  display_names = {'sample', 'tape', 'delay'}
end

-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

-- main navigation bar
function m_ui.draw_nav(header)
  y = 5  -- default text hight
  glyph_buffer = 2

  for i = 1,#display_names do
    x = (i - 1) * glyph_buffer
    screen.move(x, y)
    screen.level(i == DISPLAY_ID and 15 or 2)
    screen.text("|")
  end

  -- current display header
  screen.move_rel(glyph_buffer * 2, 0)

  if display_names[DISPLAY_ID] == 'sample' then
    if TRACK > 7 then
      -- switching functionalities
      m_ui.set_functionality('sample')
    end
    screen.text(TRACK .. " • " .. BANK .. " • " .. header)
  elseif display_names[DISPLAY_ID] == 'tape' then
    if TRACK <= 7 then 
      -- switching functionalities
      m_ui.set_functionality('tape')
    end
    screen.text(header)
  else
    screen.text(header)
  end

  screen.stroke()
end

-----------------------------------------------------------------
-- SAMPLE
-----------------------------------------------------------------

-- 1: TRACK POOL SELECTION --------------------------------------

function m_ui.sample_1_redraw()
  screen.aa(0)

  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  list_buffer = 8
  max_samples = 5
  text_width = 10

  local text = nil

  screen.move(60, 10)
  screen.line(60, 50)
  screen.stroke()

  -- track_cue
  screen.level(5)
  for i=1, math.min(#track_pool_cue[TRACK][BANK], max_samples) do
    screen.move(62, 10 + list_buffer * i)
    text = params:string('sample_' .. track_pool_cue[TRACK][BANK][i])
    if string.len(text) > text_width then
      text = string.sub(text, 1, text_width) .. " ..."
    end
    screen.text(text)
  end

  if #track_pool_cue[TRACK][BANK] > max_samples then
    screen.move(84, 54)
    screen.text_center(" . . . ")
  end
  
  -- track_pool
  screen.level(15)
  for i=1, math.min(#track_pool[TRACK], max_samples) do
    screen.move(1, 10 + list_buffer * i)
    text = params:string('sample_' .. track_pool[TRACK][i])
    if string.len(text) > text_width then
      text = string.sub(text, 1, text_width) .. " ..."
    end
    screen.text(text)
  end

  if #track_pool[TRACK] > max_samples then
    screen.move(30, 54)
    screen.text_center(" . . . ")
  end

  -- indicate bank folder for this track
  local folder = bank_folders[BANK]

  bank_text = "K2 to load bank"
  bank_text = folder ~= nil and folder or bank_text

  screen.level(5)
  screen.move(60, 61)
  screen.text_center(" -- " .. bank_text .. " --")

end

function m_ui.sample_1_key(n,z)

  if n == 2 and z == 1 then
    m_sample:load_bank(BANK)
  end

end

function m_ui.sample_1_enc(n,d)
  -- 
end

-- 2: TRACK PARAMS --------------------------------------------

function m_ui.sample_2_redraw()
  screen.aa(0)

  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  screen.level(12)

  -- p = params:get('track_' .. TRACK .. '_' .. PARAM)
  -- lookup = params:lookup_param('track_' .. TRACK .. '_' .. PARAM)
  -- min_ = lookup['controlspec']['minval']
  -- max_ = lookup['controlspec']['maxval']

  -- if PARAM == 'pan' then
  --   center = 0
  -- elseif tab.contains({'rate', 'scale'}, PARAM) then
  --   center = 1
  -- else
  --   center = nil
  -- end

  -- m_ui.draw_slider({10, 18}, min_, max_, p, 101, center)
  -- screen.stroke()

  -- current parameter
  screen.move(30, 36)
  screen.text_center(PARAM)
  screen.move(30, 50)

  if PARAM == 'filter' then
    screen.text_center(params:string('track_' .. TRACK .. '_filter_freq'))
    screen.move(30, 58)
    screen.text_center(params:string('track_' .. TRACK .. '_filter_type'))
  elseif PARAM == 'scale' then
    screen.text_center(params:string('track_' .. TRACK .. '_scale'))
    screen.move(30, 58)
    screen.text_center(params:string('track_' .. TRACK .. '_scale_type'))
  -- TAG: param 10 ... add here.
  else
    screen.text_center(params:string('track_' .. TRACK .. '_' .. PARAM))
  end
  
  -- extra parameter
  screen.move(90, 36)
  screen.text_center('noise')
  screen.move(90, 50)
  screen.text_center(params:string('track_' .. TRACK .. '_noise'))

end

function m_ui.sample_2_key(n,z)
  -- 
end

function m_ui.sample_2_enc(n,d)
  if n == 2 then
    params:delta('track_' .. TRACK .. '_' .. PARAM, d)
  elseif n == 3 then
    params:delta('track_' .. TRACK .. '_noise', d)
  end
  screen_dirty = true
end

-- 3: SAMPLE  ------------------------------------------------------
function m_ui.sample_3_redraw()
  local header = SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-"

  m_ui.draw_nav(header)

  waveform_view:update()
  waveform_view:redraw()

  screen.stroke()
end

function m_ui.sample_3_key(n,z)
  waveform_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_3_enc(n,d)
  waveform_view:enc(n, d)
  screen_dirty = true
end

-- 4: FILTER AMP --------------------------------------------------
function m_ui.sample_4_redraw()
  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  screen.aa(1)
  filter_amp_view:redraw()

  screen.stroke()
end

function m_ui.sample_4_key(n,z)
  -- for fine tuning
  if n == 1 then
    if z == 1 then
      Timber.shift_mode = true
    else
      Timber.shift_mode = false
    end
  end

  filter_amp_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_4_enc(n,d)
  filter_amp_view:enc(n, d)
  screen_dirty = true
end

-- 5: SAMPLE SETUP ---------------------------------------------------------- --
-- TODO: **this is temporary!!**
function m_ui.sample_5_redraw()
  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  screen.aa(0)
  sample_setup_view:redraw()

  screen.stroke()
end

function m_ui.sample_5_key(n,z)
  -- for fine tuning
  if n == 1 then
    if z == 1 then
      Timber.shift_mode = true
    else
      Timber.shift_mode = false
    end
  end

  sample_setup_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_5_enc(n,d)
  sample_setup_view:enc(n, d)
  screen_dirty = true
end



-----------------------------------------------------------------
-- TAPE
-----------------------------------------------------------------

-- 1: TRACK ----------------------------------------------------------------- --



-- 2: WAVEFORM ------------------------------------------------------
function m_ui.tape_1_redraw()
  m_ui.draw_nav(
    TRACK .. " • " .. 
    PARTITION .. " • " ..
    util.round(SLICE[1], 0.1) .. " - " .. util.round(SLICE[2], 0.1)
  )

  screen.move(64, 62)

  if await_render[TRACK - 7] then
    screen.text_center("•")
  else
    screen.text_center('')
  end

  screen.stroke()

  -- TODO: add some indicator here K2 == record mono, K3 == record stereo
  -- TODO: see sheets for recording on sequence page

  m_ui.draw_partition(PARTITION)
  m_ui.draw_waveform(SLICE)
end

function m_ui.tape_1_key(n,z)
  if n == 2 and z == 1 then
    -- record mono
    m_tape.record_section(TRACK, SLICE)

  elseif n == 3 and z == 1 then
    -- record stereo
    local track_pair = m_tape.stereo_pair(TRACK)
    
    if track_pair then
      m_tape.record_section(TRACK, SLICE)
      m_tape.record_section(track_pair, SLICE)
    end

  end

  screen_dirty = true
end

function m_ui.tape_1_enc(n,d)
  local partition = (SLICE_ID - 1) // 32 + 1
  local min_ = 80 * (partition - 1)
  local max_ = 80 * partition

  if n == 2 then
    new_start = util.clamp(SLICE[1] + d * 0.1, min_, max_)
    if SLICE[2] - new_start >= 1 then
      SLICE[1] = new_start
    end

  elseif n == 3 then
    new_end = util.clamp(SLICE[2] + d * 0.1, min_, max_)
    if new_end - SLICE[1] >= 1 then
      SLICE[2] = new_end
    end
  end
  
  grid_dirty = true
  screen_dirty = true
end


-- UTILITY ------------------------------------------------------------------ --

-- draw top lines for left and right buffers given the `partition`
-- only present line if there is audio.
function m_ui.draw_partition(partition)
  -- TODO: clamp first/last partition samples within the 80 seconds allowed

  local y_middle = 12
  local frame, thresh, start_frame, end_frame

  -- baseline
  screen.level(2)
  screen.move(0, y_middle - 1)
  screen.line(128, y_middle - 1)
  screen.move(0, y_middle + 1)
  screen.line(128, y_middle + 1)
  screen.stroke()

  -- selected slice
  if SLICE then
    start_frame = m_tape.seconds_to_frame(SLICE[1]) + 1
    end_frame = m_tape.seconds_to_frame(SLICE[2])
  end

  screen.level(12)
  for i=0,127 do
    frame = pixel_to_frame(i + 1, partition)

    -- minimum amplitude threshold
    thresh = util.dbamp(params:get('rec_threshold'))

    -- left buffer
    s = buffer_waveform[1][frame]
    if s ~= nil and math.abs(s) > thresh then
      screen.move(i, y_middle - 1)
      screen.line(i+1, y_middle - 1)
    end

    -- right buffer
    s = buffer_waveform[2][frame]
    if s ~= nil and math.abs(s) > thresh then
      screen.move(i, y_middle + 1)
      screen.line(i+1, y_middle + 1)
    end

    -- selected slice
    dodge = track_buffer[TRACK] == 1 and -3 or 3
    if SLICE and start_frame <= frame and frame <= end_frame then
      screen.move(i, y_middle + dodge)
      screen.line(i+1, y_middle + dodge)
    end

  end
  screen.stroke()

  -- track position
  if TRACK > 7 then
    local voice_x = positions[TRACK - 7] - (PARTITION - 1) * 80
    voice_x = voice_x * (128 / 80)

    if track_buffer[TRACK] == 1 then
      screen.move(voice_x, y_middle - 3)
      screen.line(voice_x, y_middle)
    else
      screen.move(voice_x, y_middle - 1)
      screen.line(voice_x, y_middle + 2)
    end

    screen.stroke()
  end

end

-- draw a waveform for a `range` **in seconds**.
-- waveform bars show level for the *start* of each of the 60 frames.
-- (*adapted* from cr: @markeats)
function m_ui.draw_waveform(range)
  screen.level(2)

  local WAVE_H = 24  -- wave height
  local WAVE_Y = 45  -- middle x-line for wave
  local frame, wave_x, bar_level
  local n_frames = (range[2] - range[1]) * 60  -- 60 frames per second
  local n_bars = (128 - 8) // 2  -- number of waveform bars to show

  -- draw waveform sample level for every other pixel in range
  for i = 1,n_bars do
    frame = (range[1]) * 60 + (i - 1) * (n_frames / n_bars) + 1
    frame = util.round(frame)
    sample = buffer_waveform[track_buffer[TRACK]][frame]
    wave_x = 4 + i * 2 - 0.5

    if sample then
      bar_level = math.min(math.abs(sample), 1)
      bar_level = util.linlin(0, 1, 1, WAVE_H // 2, bar_level)
      screen.move(wave_x, util.round(WAVE_Y - bar_level + 1))
      screen.line(wave_x, util.round(WAVE_Y + bar_level))
    else
      screen.move(wave_x, WAVE_Y)
      screen.line(wave_x, WAVE_Y + 1)
    end
  end
  screen.stroke()

  local pos = positions[TRACK - 7]

  -- track position
  if range[1] <= pos and pos <= range[2] then
    voice_x = util.linlin(range[1], range[2], 4, n_bars * 2, pos)
    screen.move(voice_x, WAVE_Y - WAVE_H // 2)
    screen.line(voice_x, WAVE_Y + WAVE_H // 2)
    screen.stroke()
  end

end


-----------------------------------------------------------------
-- DELAY
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------
function m_ui.delay_1_redraw()
  m_ui.draw_nav("delay 1")
  screen.move(64, 32)
  screen.text_center('delay!')

  if rec_toggle == 1 then
    screen.move(64, 50)
    screen.text_center('oh yeaaah!')
  end

  screen.stroke()
end

function m_ui.delay_1_key(n,z)
  if n == 3 and z == 1 then
    rec_toggle = rec_toggle ~ 1
    screen_dirty = true
  end
end

function m_ui.delay_1_enc(n,d)
  print('recording encoder')
end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- draw a minimal "slider", with a circle indicating the value `v`, and
-- two vertical lines on either side indicating `min` and `max` values.
-- `middle_left` is the location of the far left (middle) of the slider.
-- `center` divides the slider into two partitions. (e.g., 0 for pan).
-- |`v`| is in [`min`, `max`] with `v` < 0 indicating a right-bound line.
function m_ui.draw_slider(middle_left, min, max, v, width, center)

  height = 10
  width = width == nil and 64 or width
  middle_right = {middle_left[1] + width, middle_left[2]}

  top = middle_left[2] - (height - 1) / 2  -- highest position of slider bound

  v_abs = math.abs(v)
  v_x = util.linlin(min, max, middle_left[1], middle_right[1], v_abs)
  
  if center then
    div_x = util.linlin(min, max, middle_left[1], middle_right[1], center)
    screen.move(div_x, top)
    screen.line(div_x, top + 2)
    screen.move(div_x, top + height - 3)
    screen.line(div_x, top + height - 1)

    -- value
    k = v_abs > center and 1 or 0  -- adjust "starting" point for big pixels
    screen.move(div_x + k, middle_left[2])
    screen.line(v_x + k, middle_left[2])

  elseif v > 0 then
    -- left bound
    screen.move(middle_left[1], top)
    screen.line(middle_left[1], top + 2)
    screen.move(middle_left[1], top + height - 3)
    screen.line(middle_left[1], top + height - 1)

    -- value
    screen.move(middle_left[1], middle_left[2])
    screen.line(v_x, middle_left[2])

  elseif v < 0 then
    -- right bound
    screen.move(middle_left[1] + width, top)
    screen.line(middle_left[1] + width, top + 2)
    screen.move(middle_left[1] + width, top + height - 3)
    screen.line(middle_left[1] + width, top + height - 1)

    -- value
    screen.move(middle_left[1] + width, middle_left[2])
    screen.line(v_x, middle_left[2])

  end

end

-- returns the frame count associated with the *beginning* of the `p`th region, 
-- where there are 128 regions within the current partition.
function pixel_to_frame(p, partition)
  local n_frames = 80 * 60  -- per partition. see notes on `buffer_waveform`.

  frame = (partition - 1) * n_frames + (p - 1) * (n_frames / 128)
  return util.round(frame, 1) + 1
end

-- when moving between sample and tape on ui, set sample/slice
-- and grid accordingly.
function m_ui.set_functionality(func)
  if func == 'sample' then
    G_PAGE = 'sample_config'
    m_grid.set_track(1)
    m_sample.set_sample_id(SAMPLE)
  elseif func == 'tape' then
    G_PAGE = 'tape_config'
    m_grid.set_track(8)
    m_tape.set_slice_id(SLICE_ID)
  end
end

return m_ui