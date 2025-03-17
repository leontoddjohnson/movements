-- tape

-- softcut buffer length = 5 minutes 49.52 seconds
-- first 320 (80 * 4) seconds for tape, last 20 seconds for delay

local m_tape = {}

local Formatters = require "formatters"
local music = require 'musicutil'

-- 128 slices. these are represented in 4 partitions, where
-- the `n`th partition starts with slice #(`n` - 1) * 32 + 1.
-- slices[i] gives {start, stop} for that slice.
slices = {}

-- all parameters for slices (including `play_mode`)
-- indexed by slice_id. See `track_param_default` for names.
slice_params = {}

-- `slice_reversed[id]` indicates whether slice `id` is to play in reverse
-- `nil` indicates play normally, 1 indicates reverse
slice_reversed = {}

-- voice_slice_loc[voice][slice_id] where:
-- 1: voice head is *playing* (not recording) in that slice range, and
-- 0: voice head is not in that range.
voice_slice_loc = {{}, {}, {}, {}}

-- **Last update made to** the voice state. It is possible for a voice to
-- stopped (i.e., the position is not moving) while the `voice_state` is set
-- to 1 or 2. 
-- voice_state[voice] stopped == 0, playing == 1, recording == 2
voice_state = {}

-- **range** for recording started, awaiting buffer render for each **voice**
-- `await_render[voice] = [start, stop]`
await_render = {}

-- voice positions for each *voice* (1-4)
positions = {}

-- up to 19200 samples (min slice = 1s, 60 samples per waveform)
-- only loads when a slice is recorded from [a, a+dur]
-- stores frames/samples for the whole 320s buffer (up to delay)
buffer_waveform = {{}, {}}

-- buffers assigned for each track
-- `track_buffer[track]` == 1 for left, and == 2 for right
track_buffer = {}

armed = {}  -- 1 or 0 for whether armed[track] is armed for recording

PARTITION = 1  -- currently selected record partition
SLICE = {0, 5}  -- currently selected slice [start, stop]
SLICE_ID = 1  -- currently selected slice id (**1-indexed**)

-----------------------------------------------------------------
-- BUILD PARAMETERS
-----------------------------------------------------------------

function m_tape.build_params()

	params:add_option("tape_audio_in", "tape audio in", 
    {'none', 'input', 'samples', 'input+samples'}, 2)
	params:set_action("tape_audio_in", 
    function(x)
      if x == 1 then
        audio.level_adc_cut(0)
        audio.level_eng_cut(0)
      elseif x == 2 then
        audio.level_adc_cut(1)
        audio.level_eng_cut(0)
      elseif x == 3 then
        audio.level_adc_cut(0)
        audio.level_eng_cut(1)
      else
        audio.level_adc_cut(1)
        audio.level_eng_cut(1)
      end
    end)

  params:add_control('rec_threshold', 'rec threshold',
    controlspec.DB,
    function(p) return util.round(p:get(), 0.1) .. ' db' end)

end

function m_tape.build_tape_track_params()

  for t = 8, 11 do
    params:add_group("Track " .. t, 10)  -- # of track parameters

    -- AMPLITUDE
    params:add_control('track_' .. t .. '_amp', 'track_' .. t .. '_amp',
                       controlspec.AMP, Formatters.round(0.01))
    params:set_action('track_' .. t .. '_amp', 
      function(value)
        last_value = track_param_level[t]['amp']

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id
          amp_in = slice_params[id]['amp']
          amp_out = m_seq.squelch_amp(last_value, value, amp_in)
          slice_params[id]['amp'] = amp_out

          softcut.level(t - 7, amp_out)
        end

        track_param_level[t]['amp'] = value
        grid_dirty = true
      end
    )

    -- PANNING
    params:add_control('track_' .. t .. '_pan', 'track_' .. t .. '_pan', 
                       controlspec.PAN, Formatters.round(0.01))
    params:set_action('track_' .. t .. '_pan', 
      function(value)
        local last_value = track_param_level[t]['pan']
        local ranges = {}  -- ranges for `last_value` and `value`

        for i, v in ipairs({last_value, value}) do
          if v < 0 then
            ranges[i] = {-1, v + 1/3}
          elseif v > 0 then
            ranges[i] = {v - 1/3, 1}
          else
            ranges[i] = {-1, 1}
          end
        end

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_pan(ranges[1], ranges[2], id)
        -- end

        track_param_level[t]['pan'] = value
        grid_dirty = true
      end
    )

    -- FILTER TYPE
    params:add_option('track_' .. t .. '_filter_type', 
                      'track_' .. t .. '_filter_type',
                      options.FILTER_TYPE, 1)
    params:set_action('track_' .. t .. '_filter_type',
      function(value)
        last_value = track_param_level[t]['filter_type']
        local freq = track_param_level[t]['filter_freq']
        sign_in = last_value == 1 and 1 or -1
        sign_out = value == 1 and 1 or -1

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_filter(freq * sign_in, freq * sign_out, id)
        -- end

        track_param_level[t]['filter_type'] = value
        grid_dirty = true
      end
    )

    -- FILTER FREQ
    params:add_control('track_' .. t .. '_filter_freq', 
                       'track_' .. t .. '_filter_freq',
                       specs.FILTER_FREQ)
    params:set_action('track_' .. t .. '_filter_freq', 
      function(value)
        last_value = track_param_level[t]['filter_freq']
        local pass = track_param_level[t]['filter_type']
        local sign = pass == 1 and 1 or -1

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_filter(last_value * sign, value * sign, id)
        -- end

        track_param_level[t]['filter_freq'] = value
        grid_dirty = true
      end
    )

    -- FILTER RESONANCE
    params:add_control('track_' .. t .. '_filter_resonance', 
                       'track_' .. t .. '_filter_resonance',
                       specs.FILTER_RESONANCE)
    params:set_action('track_' .. t .. '_filter_resonance', 
      function(value)
        -- -- set samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   params:set('filter_resonance_' .. id, value)
        -- end
      end
    )

    -- DELAY
    params:add_control('track_' .. t .. '_delay', 
                       'track_' .. t .. '_delay',
                       controlspec.AMP)
    params:set_action('track_' .. t .. '_delay', 
    function(value)
        -- -- set samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   params:set('delay_' .. id, value)
        -- end
      end
    )

    -- SCALE
    params:add_number('track_' .. t .. '_scale', 
                      'track_' .. t .. '_scale',
                      0, 5, 2)
                      
    params:add_option('track_' .. t .. '_scale_type', 
                      'track_' .. t .. '_scale_type',
                       {"Forward", "Reverse"}, 1)
    params:set_action('track_' .. t .. '_scale_type',
      function(value)

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          m_tape.reverse_slice(id)
        end

        screen_dirty = true
        grid_dirty = true
      end
    )
    
    -- INTERVAL
    params:add_number('track_' .. t .. '_interval',
                       'track_' .. t .. '_interval',
                       1, 11, 7, 
      function(param)
        v = param:get()
        if v == 2 then return '2nd'
        elseif v == 3 then return '3rd'
        elseif v == 5 then return '4th'
        elseif v == 7 then return '5th'
        elseif v == 9 then return '6th'
        elseif v == 11 then return '7th'
        else return v .. ' st' end
      end)

    -- PROBABILITY
    params:add_control('track_' .. t .. '_prob',
                       'track_' .. t .. '_prob',
                       controlspec.AMP, Formatters.percentage)
    -- TAG: param 5, add params ABOVE.
  
  end

end

-- set ALL **voice** params for a `slice_id` using `slice_params`.
function m_tape.set_voice_params(voice, slice_id)
  -- AMP
  softcut.level(voice, slice_params[slice_id]['amp'])
  -- DELAY (left)
  softcut.level_cut_cut(voice, 5, slice_params[slice_id]['delay'])
  -- DELAY (right)
  softcut.level_cut_cut(voice, 6, slice_params[slice_id]['delay'])
  -- PAN
  softcut.pan(voice, slice_params[slice_id]['pan'])
  -- FILTER FREQ
  softcut.post_filter_fc(voice, slice_params[slice_id]['filter_freq'])
  -- FILTER TYPE
  if slice_params[slice_id]['filter_type'] == 1 then
    softcut.post_filter_lp(voice, 1)
    softcut.post_filter_hp(voice, 0)
  else
    softcut.post_filter_lp(voice, 0)
    softcut.post_filter_hp(voice, 1)
  end
  -- SCALE (TRANSPOSE)
  local ratio = music.interval_to_ratio(slice_params[slice_id]['transpose'])
  softcut.rate(voice, ratio)
end

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_tape.init()
  -- send levels
	audio.level_cut(1)

  -- set callbacks
  softcut.event_render(wave_render)

  -- waveform setup
  waveform_samples = {}
  wave_gain = {}

  -- only tape tracks 8-11
  for i = 8, 11 do
    waveform_samples[i] = {}
    wave_gain[i] = {}
    track_buffer[i] = i % 2 + 1  -- track 8 is "L"
  end

  m_tape.init_slices()

  -- init softcut
  m_tape.sc_init()

end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- default slices
function m_tape.init_slices()

  for s=1,128 do 
    slices[s] = {(s - 1) * 2.5, s * 2.5}
    
    slice_params[s] = {}
    for k,v in pairs(track_param_default) do
      slice_params[s][k] = v
    end

    slice_params[s]['play_mode'] = "1-Shot"
  end

end

-- return buffer waveform samples for a `slice_id`, on buffer `ch`
function m_tape.slice_buffer(slice_id, ch)
  local slice = slices[slice_id]

  local start_frame = util.round(60 * slice[1], 1) + 1  -- 60 frames per second
  local end_frame = util.round(60 * slice[2], 1)

  left_buffer = table_slice(buffer_waveform[1], start_frame, end_frame)
  right_buffer = table_slice(buffer_waveform[2], start_frame, end_frame)

  slice_buffer = {left_buffer, right_buffer}
  return slice_buffer[ch]

end

-- arm a track for recording
function m_tape.arm(track)
  
  -- arm ...

end

-- disarm a track from recording
function m_tape.disarm(track)
  -- ...

  -- stop sending audio to delay if nothing is armed

end

function m_tape.set_slice_id(id)
  SLICE_ID = id
  SLICE = slices[SLICE_ID]

  -- update play mode options on grid
  g_play_modes = shallow_copy(g_play_modes_all.tape_slice)

end

-- function m_tape.sc_stop()
--   for i=1,4 do
--     softcut.rec(i, 0)
--     softcut.play(i, 0)
--     softcut.enable(i, 0)

--     -- input
--     if i < 3 then
--       softcut.position(i, 0)
--       m_dots.positions[i] = 0

--     -- dots
--     else
--       softcut.position(i, params:get('dots_loop_length'))
--       m_dots.positions[i] = params:get('dots_loop_length')
--     end
--   end

--   softcut.poll_stop_phase()
--   softcut.buffer_clear()
-- end

function m_tape.sc_init()
  softcut.buffer_clear()

  local track = nil

  for i=1,4 do
    track = i + 7

    -- init
    softcut.enable(i, 1)
    softcut.phase_quant(i, 1 / REDRAW_FRAMERATE)
    positions[i] = 0

    softcut.buffer(i, track_buffer[track])
    softcut.rate(i, 1)
    softcut.loop(i, 0)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 0)
    softcut.position(i, 0)
    softcut.fade_time(i, 0.1)
    softcut.pan(i, 0)

    softcut.rec_level(i, 1)
    softcut.pre_level(i, 0)
    softcut.level_input_cut(track_buffer[track], i, 1)
    softcut.level(i, 1)
    softcut.play(i, 0)
    softcut.rec(i, 0)
    voice_state[i] = 0
  end

end

function m_tape.watch_positions()
  softcut.event_phase(m_tape.update_position)
  softcut.poll_start_phase()
end

function m_tape.ignore_positions()
  softcut.poll_stop_phase()
end

function m_tape.update_position(i,pos)
  positions[i] = pos

  -- indicate if slice contains time for a voice that is playing
  for j=1,128 do
    if slices[j][1] <= pos and pos < slices[j][2] and voice_state[i] > 0 then
      voice_slice_loc[i][j] = 1
    else
      voice_slice_loc[i][j] = 0
    end
  end

  -- render if finished recording range
  if await_render[i] and pos >= await_render[i][2] then
    render_slice(await_render[i], track_buffer[i + 7])
    await_render[i] = nil
  end

  grid_dirty = true
  screen_dirty = true
end

function m_tape.play_section(track, range, loop)
  local voice = track - 7
  local loop = loop or 0

  softcut.rec(voice, 0)
  softcut.play(voice, 0)
  
  softcut.buffer(voice, track_buffer[track])
  softcut.loop(voice, loop)
  softcut.loop_start(voice, range[1])
  softcut.loop_end(voice, range[2])
  softcut.position(voice, range[1])
  softcut.play(voice, 1)

  voice_state[voice] = 1
end

-- TODO: set this to happen when needed?
function m_tape.stop_track(track)
  local voice = track - 7

  softcut.play(voice, 0)
  softcut.rec(voice, 0)

  voice_state[voice] = 0
end

function m_tape.record_section(track, range)
  local voice = track - 7

  softcut.rec(voice, 0)
  softcut.play(voice, 0)

  softcut.buffer(voice, track_buffer[track])
  softcut.level_input_cut(track_buffer[track], voice, 1)
  softcut.loop(voice, 0)
  softcut.loop_start(voice, range[1])
  softcut.loop_end(voice, range[2])
  softcut.position(voice, range[1])
  softcut.rec(voice, 1)
  softcut.play(voice, 1)

  voice_state[voice] = 2
  await_render[voice] = range
end

-- reverse start and stop for a slice
function m_tape.reverse_slice(id)

  local start = slices[id][1]
  local stop = slices[id][2]

  slices[id][1] = stop
  slices[id][2] = start

  if slice_reversed[id] then
    slice_reversed[id] = nil
  else
    slice_reversed[id] = 1
  end
  
end

-- set a collection of slice ids back to default
function m_tape.slice_params_to_default(slice_ids)
  local id
  for i = 1,#slice_ids do
    id = slice_ids[i]

    -- TAG: param 8
    local params = {
      'amp', 'pan', 'filter_freq', 'filter_type', 'filter_resonance'
    }

    for i,p in ipairs(params) do
      slice_params[id][p] = track_param_default[p]
    end
  end

end

-- set a collection of slice ids to the track levels
function m_tape.slice_params_to_track(slice_ids, track)
  -- do this before a slice is added to a track_pool
  local id
  for i = 1,#slice_ids do
    id = slice_ids[i]

    -- TAG: param 2 - make sure this works, or add new above ...
    local params_ = {
      "amp", "pan", "filter_freq", "filter_type", "filter_resonance"
    }

    for i,p in ipairs(params_) do
      p_track = params:get('track_' .. track .. '_' .. p)
      slice_params[id][p] = p_track
    end
  end
end

-- span of values that are greater in magnitude than some threshold
-- **default `thresh` = params:get('rec_threshold')**
-- span[0] indexes the first sufficient value (or 0 for none)
-- span[1] indexes the last sufficient value (or 0 for none)
function span_thresh(t, thresh)
  local span_l = 0
  local span_r = 0

  thresh = thresh or util.dbamp(params:get('rec_threshold'))

  for i=1,#t do
    if math.abs(t[i]) > thresh and span_l == 0 then
      span_l = i
    end

    span_r = math.abs(t[i]) > thresh and i or span_r
  end

  return {span_l, span_r}
end

-- convert seconds to frame count, given a sample rate of 60 samples per second
-- **for any "start" frame, add 1**.
function m_tape.seconds_to_frame(sec)
  local sample_rate = 60
  return util.round(sample_rate * sec, 1)
end

-- WAVEFORM (cr: sonocircuit) -----------------------------------

function wave_render(ch, start, rate, samples)
  -- rate should be 1/60 seconds per sample (60 samples per second)
  -- keep 1-index
  local start_frame = util.round(start / rate, 1) + 1

  print("rendering buffer " .. ch)
  print("rate: ".. rate)
  print("n_samples: ".. #samples)
  print("start (s): " .. start)
  print("start frame: " .. start_frame)

  for i,s in ipairs(samples) do
    buffer_waveform[ch][start_frame - 1 + i] = s
  end

  screen_dirty = true
  grid_dirty = true
end

-- function wave_getmax(t)
--   local max = 0
--   for _,v in pairs(t) do
--     if math.abs(v) > max then
--       max = math.abs(v)
--     end
--   end
--   return util.clamp(max, 0.4, 1)
-- end

-- render a range for a buffer (or both).
-- if `ch` not provided, then render both buffers.
function render_slice(range, ch)

  -- 60 samples per second
  local duration = range[2] - range[1]
  local n_samples = 60 * duration

  if ch then
    softcut.render_buffer(ch, range[1], duration, n_samples)
  else
    for i=1,2 do
      softcut.render_buffer(i, range[1], duration, n_samples)
    end
  end
end

return m_tape

