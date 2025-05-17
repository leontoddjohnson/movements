-- tape

-- softcut buffer length = 5 minutes 49.52 seconds
-- first 320 (80 * 4) seconds for tape, last 20 seconds for delay

local m_tape = {}

local Formatters = require "formatters"
local music = require 'musicutil'

-- 128 slices. These are represented in 4 partitions, where
-- the `n`th partition starts with slice #(`n` - 1) * 32 + 1.
-- `slices[i]` gives {start, stop} for that slice in seconds.
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
-- to 1. This happens at the end of a clip.
-- voice_state[voice] where
-- stopped == 0, playing == 1, recording (no loop) == 2, recording (loop) == 3
voice_state = {}

-- **range** for recording started, awaiting buffer render for each **voice**
-- `await_render[voice] = [start, stop]`
await_render = {}

-- voice positions for each *voice* (1-4)
positions = {}

-- `buffer_waveform[ch][frame]` is the level at that frame for that channel.
-- I *believe* the sign (+/-) indicates phase, so amplitude above or below 0.
-- **The buffer is rendered at 60 frames per second.**
-- Each channel has 19,200 samples, i.e., the first 320s (up to delay portion)
-- 19200 = 60 samples/sec * 2.5 sec/slice * 32 slice/partition * 4 partitions
buffer_waveform = {{}, {}}

-- `buffer_view[ch][pixel] == 1` if there is audio in that portion, else `nil`.
-- Each pixel represents one 128th of a partition, so the first 128 portions are
-- in the first partition. `buffer_view[1][148]` indicates if there is audio
-- in the 20th portion of the first channel of the buffer.
buffer_view = {{}, {}}

-- `partition_view[partition] == 1` if there is audio in that partition.
-- Otherwise, this is `nil`. This is updated in `m_tape.update_partition_view`.
partition_view = {}

-- `buffer_slice_view[ch][slice_id] == 1` if there is audio in that slice
-- on that buffer channel `ch`. Otherwise, this is `nil`. Updated with
-- `m_tape.update_slice_view`.
buffer_slice_view = {{}, {}}

-- buffers assigned for each track
-- `track_buffer[track]` == 1 for left, and == 2 for right
track_buffer = {}

-- table of files loaded into each buffer:
-- `loaded_files[buffer][i] = {<filename>, <start>, <stop>}`
-- UI will show the *latest* loaded of these.
loaded_files = {{}, {}}

PARTITION = 1  -- current recording partition, each strictly 80 seconds long
SLICE = {0, 5}  -- currently selected slice [start, stop]
SLICE_ID = 1  -- currently selected slice id (**1-indexed**)

MIN_SLICE_LENGTH = 1  -- currently set based on best waveform fidelity

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
  params:set_action('rec_threshold',
    function(v)
      m_tape.reset_buffer_view()
      screen_dirty = true
      grid_dirty = true
    end)

end

function m_tape.build_tape_track_params()

  specs.FADE = controlspec.new(0, 5, 'lin', 0, 0.1, "sec", 1/50)

  for t = 8, 11 do
    params:add_group("Track " .. t, 12)  -- # of track parameters

    -- AMPLITUDE
    params:add_control('track_' .. t .. '_amp', 'track_' .. t .. '_amp',
                       specs.AMP1)
    params:set_action('track_' .. t .. '_amp', 
      function(value)
        last_value = track_param_level[t]['amp']

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id
          amp_in = slice_params[id]['amp']
          amp_out = m_seq.squelch_amp(last_value, value, amp_in)
          slice_params[id]['amp'] = amp_out
        end

        softcut.level(t - 7, value)

        track_param_level[t]['amp'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- PANNING
    params:add_control('track_' .. t .. '_pan', 'track_' .. t .. '_pan', 
                       controlspec.PAN, 
                       Formatters.round(0.01))
    params:set_action('track_' .. t .. '_pan', 
      function(value)
        local last_value = track_param_level[t]['pan']
        local pan_in, pan_out

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- slice id
          pan_in = slice_params[id]['pan']
          pan_out = m_seq.squelch_pan({last_value, 1}, {value, 1}, pan_in)
          slice_params[id]['pan'] = pan_out
        end

        softcut.pan(t - 7, value)

        track_param_level[t]['pan'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- FILTER TYPE
    params:add_option('track_' .. t .. '_filter_type', 
                      'track_' .. t .. '_filter_type',
                      options.FILTER_TYPE, 1)
    params:set_action('track_' .. t .. '_filter_type',
      function(value)

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          slice_params[id]['filter_type'] = value
        end

        softcut.post_filter_lp(t - 7, value == 1 and 1 or 0)
        softcut.post_filter_hp(t - 7, value == 1 and 0 or 1)
        softcut.post_filter_dry(t - 7, 0)

        track_param_level[t]['filter_type'] = value
        screen_dirty = true
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
        local freq

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- slice id
          freq_in = slice_params[id]['filter_freq']
          freq = m_seq.squelch_filter(last_value * sign, value * sign, freq_in)
          slice_params[id]['filter_freq'] = freq
        end

        softcut.post_filter_fc(t - 7, value)

        track_param_level[t]['filter_freq'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- FILTER RESONANCE
    params:add_control('track_' .. t .. '_filter_resonance', 
                       'track_' .. t .. '_filter_resonance',
                       specs.FILTER_RESONANCE_SC)
    params:set_action('track_' .. t .. '_filter_resonance', 
      function(value)
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          slice_params[id]['filter_resonance'] = value
        end

        softcut.post_filter_rq(t - 7, value)

        screen_dirty = true
      end
    )

    -- DELAY
    params:add_control('track_' .. t .. '_delay', 
                       'track_' .. t .. '_delay',
                       specs.AMP0)
    params:set_action('track_' .. t .. '_delay', 
    function(value)
      last_value = track_param_level[t]['delay']

      for i = 1, #track_pool[t] do
        id = track_pool[t][i]
        delay_in = slice_params[id]['delay']
        delay_out = m_seq.squelch_amp(last_value, value, delay_in, false)
        slice_params[id]['delay'] = delay_out
      end

      softcut.level_cut_cut(t - 7, 5, value)  -- left
      softcut.level_cut_cut(t - 7, 6, value)  -- right

      track_param_level[t]['delay'] = value
      screen_dirty = true
      grid_dirty = true
      end
    )

    -- SCALE
    params:add_number('track_' .. t .. '_scale', 
                      'track_' .. t .. '_scale',
                      0, 5, 2)
    params:set_action('track_' .. t .. '_scale',
    function(value)
      local last_value = track_param_level[t]['scale']
      local ratio, transpose

      for i = 1, #track_pool[t] do
        id = track_pool[t][i]
        transpose_in = slice_params[id]['transpose']
        scale_in = transpose_to_scale(transpose_in, t)
        scale = m_seq.squelch_scale({last_value, 5}, {value, 5}, scale_in)
        transpose_out = scale_to_transpose(scale, t)
        slice_params[id]['transpose'] = transpose_out
      end

      transpose = scale_to_transpose(value, t)
      ratio = music.interval_to_ratio(transpose)
      softcut.rate(t - 7, ratio)

      -- check for stereo pair
      local pair = m_tape.stereo_pair(t)
      if pair and pair > t then softcut.rate(pair - 7, ratio) end

      track_param_level[t]['scale'] = value
      screen_dirty = true
      grid_dirty = true
    end
    )
    
    -- SCALE TYPE (forward or reverse)
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
        if v == param_levels.interval[1] then return '2nd'
        elseif v == param_levels.interval[2] then return '3rd'
        elseif v == param_levels.interval[3] then return '4th'
        elseif v == param_levels.interval[4] then return '5th'
        elseif v == param_levels.interval[5] then return '6th'
        elseif v == param_levels.interval[6] then return '7th'
        else return v .. ' st' end
      end)
    params:set_action('track_' .. t .. '_interval',
      function(value)

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          transpose_in = slice_params[id]['transpose']
          -- new interval is used in the next two functions
          scale_in = transpose_to_scale(transpose_in, t)
          transpose_out = scale_to_transpose(scale_in, t)
          slice_params[id]['transpose'] = transpose_out
        end

        track_param_level[t]['interval'] = value
        screen_dirty = true
        grid_dirty = true
      end
      )

    -- PROBABILITY
    params:add_control('track_' .. t .. '_prob',
                       'track_' .. t .. '_prob',
                       specs.AMP1, Formatters.percentage)
  
    -- PRESERVE
    params:add_control('track_' .. t .. '_pre', 
                       'track_' .. t .. '_pre',
                       specs.AMP0)
    params:set_action('track_' .. t .. '_pre', 
    function(value)
        softcut.pre_level(t - 7, value)
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- CROSSFADE
    params:add_control('track_' .. t .. '_crossfade', 
                       'track_' .. t .. '_crossfade',
                       specs.FADE)
    params:set_action('track_' .. t .. '_crossfade', 
    function(value)
        softcut.fade_time(t - 7, value)
        screen_dirty = true
      end
    )

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
  -- FILTER RESONANCE
  softcut.post_filter_rq(voice, slice_params[slice_id]['filter_resonance'])
  -- FILTER TYPE
  local low_pass = slice_params[slice_id]['filter_type'] == 1
  softcut.post_filter_lp(voice, low_pass and 1 or 0)
  softcut.post_filter_hp(voice, low_pass and 0 or 1)
  softcut.post_filter_dry(voice, 0)

  -- SCALE (TRANSPOSE)
  local ratio = music.interval_to_ratio(slice_params[slice_id]['transpose'])
  if slice_reversed[slice_id] then ratio = -ratio end

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

  -- only tape tracks 8-11
  for i = 8, 11 do
    track_buffer[i] = i % 2 + 1  -- track 8 is "L"
  end

  m_tape.init_slices()

  -- init softcut
  m_tape.sc_init()

end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

function m_tape.load_file(file_path)
  file_select_active = false
  if file_path ~= 'cancel' and file_path ~= "" then
    local ch, n_samples, rate = audio.file_info(file_path)

    if ch > 0 and tab.contains({44100, 48000}, rate) then
      local split_at = string.match(file_path, "^.*()/")
      local filename = string.sub(file_path, split_at + 1)
      split_at = string.match(filename, "()%.")
      filename = string.sub(filename, 1, split_at - 1)
      
      local len = n_samples / rate
      local start = SLICE[1]
      local dur = math.min(PARTITION * 80 - start, len)
      local pre = params:get("track_" .. TRACK .. "_pre")

      local buffer = track_buffer[TRACK]

      if ch > 1 then
        if m_tape.stereo_pair(TRACK) then
          -- load stereo into partition
          softcut.buffer_read_stereo(file_path, 0, start, dur, pre, 1)

          render_slice({start, start + dur})

          table.insert(loaded_files[1], {filename, start, start + dur})
          table.insert(loaded_files[2], {filename, start, start + dur})
        else
          -- force stereo track into mono, halve each channel level
          softcut.buffer_read_mono(file_path, 
            0, start, dur, 1, buffer, pre, util.dbamp(-3))
          softcut.buffer_read_mono(file_path, 
            0, start, dur, 2, buffer, pre, util.dbamp(-3))

          render_slice({start, start + dur})
          table.insert(loaded_files[buffer], {filename, start, start + dur})
        end
      else
        softcut.buffer_read_mono(file_path, 
          0, start, dur, 1, buffer, pre, 1)

        render_slice({start, start + dur}, buffer)
        table.insert(loaded_files[buffer], {filename, start, start + dur})
      end

    else
      print("Invalid sample:")
      print(
        "ch: " .. ch .. 
        " | n_samples: " .. n_samples .. 
        " | rate: " .. rate)
    end
  end
  screen_dirty = true
  grid_dirty = true
end

-- default slices
function m_tape.init_slices()

  for s=1,128 do 
    slices[s] = {(s - 1) * 2.5, s * 2.5}
    
    slice_params[s] = {}
    for k,v in pairs(track_param_default) do
      if k == 'filter_resonance' then
        -- softcut has different tolerable resonance scale
        slice_params[s][k] = specs.FILTER_RESONANCE_SC.default
      else
        slice_params[s][k] = v
      end
    end

    slice_params[s]['play_mode'] = "1-Shot"
  end

end

function m_tape.set_slice_id(id)
  SLICE_ID = id
  SLICE = slices[SLICE_ID]

  -- update play mode options on grid
  g_play_modes = shallow_copy(g_play_modes_all.tape_slice)

end

-- mute all voices from 1-4
function m_tape.sc_stop()
  for i=1,4 do
    softcut.rec(i, 0)
    softcut.level(i, 0)
  end
end

-- clear buffer on channel `ch` within `range`
function m_tape.clear_buffer(ch, range, files_only)
  if not files_only then
    softcut.buffer_clear_region_channel(ch, range[1], range[2] - range[1], 0, 0)
  end

  -- update loaded files list
  for i,f in ipairs(loaded_files[ch]) do
    local file_start = f[2]
    local file_end = f[3]
    local new_f
    
    -- whole file in range
    if range[1] <= file_start and file_end <= range[2] then
      table.remove(loaded_files[ch], i)

    -- cut off the beginning
    elseif range[1] < file_start and file_start < range[2] then
      loaded_files[ch][i][2] = range[2]

    -- cut off the end
    elseif range[1] < file_end and file_end < range[2] then
      loaded_files[ch][i][3] = range[1]

    -- cut out the middle
    elseif file_start < range[1] and range[2] < file_end then
      new_f = {loaded_files[ch][i][1], range[2], loaded_files[ch][i][3]}

      loaded_files[ch][i][3] = range[1]
      table.insert(loaded_files[ch], i + 1, new_f)
    end
  end
end

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
    softcut.level_slew_time(i, 0.1)
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
    softcut.play(i, 1)
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
    elseif voice_slice_loc[i] then
      voice_slice_loc[i][j] = 0
    end
  end

  -- render slice if awaiting it
  if await_render[i] then
    -- fix position if needed
    if pos < await_render[i][1] or await_render[i][2] < pos then
      softcut.position(i, await_render[i][1])
    end

    -- indicate "end" of recording range
    local end_range = {
      await_render[i][2] - 1/(REDRAW_FRAMERATE - 1),
      await_render[i][2]
    }
    
    -- render if finished recording range
    if end_range[1] <= pos and pos <= end_range[2] then
      render_slice(await_render[i], track_buffer[i + 7])

      -- if not loop: stop waiting for next render and stop recording
      if voice_state[i] < 3 then
        await_render[i] = nil
        softcut.rec(i, 0)
        voice_state[i] = 0
      end
    end
  end

  grid_dirty = true
  screen_dirty = true
end

function m_tape.play_section(track, range, loop, reverse)
  local voice = track - 7
  local loop = loop and 1 or 0
  local pos

  softcut.buffer(voice, track_buffer[track])
  softcut.loop(voice, loop)
  softcut.loop_start(voice, range[1])
  softcut.loop_end(voice, range[2])

  -- race condition recommendation by @dndrks
  -- rate set in `set_voice_params` (always set before this function)
  if reverse then pos = range[2] else pos = range[1] end

  clock.run(
    function()
      clock.sleep(0.001)
      softcut.position(voice, pos)
    end
  )

  voice_state[voice] = 1
end

-- play a `slice_id` on the voice of a `track`
function m_tape.play_slice(track, slice_id)
  local track_pair = m_tape.stereo_pair(track)
  local loop = slice_params[slice_id]['play_mode'] == 'Loop'
  local reversed = slice_reversed[slice_id]

  -- if stereo pair, then `track` is left, and `track_pair` is right
  if track_pair and track_pair > track then
    m_tape.stop_track(track)
    m_tape.stop_track(track_pair)

    -- `slice_id` corresponds to `track` (hard left); set pair to hard right
    m_tape.set_voice_params(track - 7, slice_id)
    m_tape.set_voice_params(track - 6, slice_id)  
    softcut.pan(track - 6, 1)

    m_tape.play_section(track, slices[slice_id], loop, reversed)
    m_tape.play_section(track_pair, slices[slice_id], loop, reversed)
  
  -- otherwise, set and play as usual
  else
    m_tape.stop_track(track)
    m_tape.set_voice_params(track - 7, slice_id)
    m_tape.play_section(track, slices[slice_id], loop, reversed)
  end
end

function m_tape.stop_track(track)
  local voice = track - 7

  softcut.rec(voice, 0)
  softcut.loop(voice, 0)
  softcut.level(voice, 0)

  voice_state[voice] = 0
end

function m_tape.record_section(track, range, loop)
  local voice = track - 7
  local loop = loop and 1 or 0
  local pre = params:get('track_' .. track .. '_pre')

  -- if overwriting, update `loaded_files`
  if pre == 0 then
    m_tape.clear_buffer(track_buffer[track], range, true)
  end

  -- temporary level and rate while recording (updated at play time)
  softcut.level(voice, pre)
  softcut.rate(voice, 1)
  softcut.rec(voice, 1)

  softcut.buffer(voice, track_buffer[track])
  softcut.level_input_cut(track_buffer[track], voice, 1)
  softcut.loop(voice, loop)
  softcut.loop_start(voice, range[1])
  softcut.loop_end(voice, range[2])

  -- race condition recommendation by @dndrks
  clock.run(
    function()
      clock.sleep(0.001)
      softcut.position(voice, range[1])
      clock.sleep(0.001)
      await_render[voice] = range
    end
  )

  if loop == 1 then
    voice_state[voice] = 3
  else
    voice_state[voice] = 2
  end

end

-- reverse start and stop for a slice
function m_tape.reverse_slice(id)

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

    for p,v in pairs(track_param_default) do
      if p == 'filter_resonance' then
        -- softcut has a different resonance measure?
        slice_params[id][p] = specs.FILTER_RESONANCE_SC.default

      elseif p == 'transpose' then
        -- check for reversal
        if slice_reversed[id] then m_tape.reverse_slice(id) end
        slice_params[id][p] = v

      elseif p ~= 'noise' then
        slice_params[id][p] = v

      end
    end

  end

end

-- set a collection of slice ids to the track levels
function m_tape.slice_params_to_track(slice_ids, track)
  local id

  for i = 1,#slice_ids do
    id = slice_ids[i]

    local params_ = {
      "amp", "pan", "filter_freq", "filter_type", "filter_resonance", 'delay'
    }

    for i,p in ipairs(params_) do
      slice_params[id][p] = params:get('track_' .. track .. '_' .. p)
    end

    -- get scale and direction
    scale = params:get('track_' .. track .. '_scale')
    scale_type = params:get('track_' .. track .. '_scale_type')

    -- revert to main octave, set scale, then direction
    transpose = scale_to_transpose(scale, track)
    slice_params[id]['transpose'] = transpose

    if slice_reversed[id] then
      if scale_type == 1 then m_tape.reverse_slice(id) end
    elseif scale_type == 2 then
      m_tape.reverse_slice(id)
    end

  end
end


-- If there is audio in any portion of the `partition`, then this will 
-- update `partition_view` and `buffer_view` accordingly.
function m_tape.update_partition_view(partition)
  local start_frame, stop_frame

  -- define pixel bounds for the partition UI
  local start_pixel = (partition - 1) * 128 + 1
  local stop_pixel = partition * 128
  local frames_per_pixel = (80 * 60) / 128  -- 1 partition
  local ch = 1

  local floor = math.floor
  local ceil = math.ceil

  partition_view[partition] = nil

  while ch <= 2 do
    -- check for audio within each pixel for the partition UI
    for pixel = start_pixel, stop_pixel do
      start_frame = floor((pixel - 1) * frames_per_pixel + 1)
      stop_frame = ceil(pixel * frames_per_pixel)
      if m_tape.buffer_contains_audio(ch, start_frame, stop_frame) then
        buffer_view[ch][pixel] = 1
        partition_view[partition] = 1
      end
    end
    ch = ch + 1
  end
end

-- If there is audio in the slice with id `slice_id`, then this will 
-- update `buffer_slice_view` accordingly. If `ch` is given, this will
-- only update that channel. Otherwise, update **both** channels.
function m_tape.update_slice_view(slice_id, ch)
  local channels = ch and {ch} or {1, 2}
  local slice = slices[slice_id]

  -- 60 frames per second ...
  local start_frame = util.round(60 * slice[1], 1) + 1
  local stop_frame = util.round(60 * slice[2], 1)

  for i,channel in ipairs(channels) do
    if m_tape.buffer_contains_audio(channel, start_frame, stop_frame) then
      buffer_slice_view[channel][slice_id] = 1
    else
      buffer_slice_view[channel][slice_id] = nil
    end
  end
end

-- Reset `partition_view`, `buffer_view`, and `buffer_slice_view`.
-- If `ch` is given, this will only update that channel of `buffer_slice_view`,
-- otherwise, this will reset and update both channels.
function m_tape.reset_buffer_view(ch)
  partition_view = {}

  if ch and ch == 1 then
    buffer_slice_view[1] = {}
    buffer_view[1] = {}
  elseif ch and ch == 2 then
    buffer_slice_view[2] = {}
    buffer_view[2] = {}
  else
    buffer_slice_view = {{}, {}}
    buffer_view = {{}, {}}
  end

  for p=1,4 do
    m_tape.update_partition_view(p)
  end

  for id=1,128 do
    m_tape.update_slice_view(id, ch)
  end
end

-- Return 1 if there is a level between `start_frame` and `stop_frame`
-- greater than the `rec_threshold` set in PARAMS. This references
-- the current `buffer_waveform` channel `ch`.
function m_tape.buffer_contains_audio(ch, start_frame, stop_frame)
  local i = start_frame
  local thresh = util.dbamp(params:get('rec_threshold'))
  local abs = math.abs
  
  while i <= stop_frame do
    if buffer_waveform[ch][i] and abs(buffer_waveform[ch][i]) > thresh then
      return 1
    end
    i = i + 1
  end
end

-- convert seconds to frame count, given a sample rate of 60 samples per second
-- **for any "start" frame, add 1**.
function m_tape.seconds_to_frame(sec)
  local sample_rate = 60
  return util.round(sample_rate * sec, 1)
end

-- return the stereo pair for `track`, if it exists. Otherwise, return `nil`.
-- note: only possible pairs are 8-9 and 10-11. So, for example, 
-- `stereo_pair(9) ==> 8` (if they are set as a pair)
function m_tape.stereo_pair(track)
  local track_side = track % 2 + 1

  -- invalid track side configuration
  if track_side ~= track_buffer[track] then
    track_side = -1
  end

  -- current track is left, and next track is right
  if track_side == 1 
    and track_buffer[track + 1] == 2
    and params:get('track_' .. track .. "_pan") == -1
    and params:get('track_' .. track + 1 .. "_pan") == 1 then
      return track + 1

  -- current track is right, and previous track is left
  elseif track_side == 2
    and track_buffer[track - 1] == 1
    and params:get('track_' .. track - 1 .. "_pan") == -1
    and params:get('track_' .. track .. "_pan") == 1 then
      return track - 1
  
  -- treat as mono track
  else
    return nil

  end
end

-- WAVEFORM (cr: sonocircuit) -----------------------------------

function wave_render(ch, start, rate, samples)
  -- rate should be 1/60 seconds per sample (60 samples per second)
  -- keep 1-index
  local start_frame = util.round(start / rate, 1) + 1

  for i,s in ipairs(samples) do
    buffer_waveform[ch][start_frame - 1 + i] = s
  end

  -- clear current "view" of what portions of the buffer contain audio
  m_tape.reset_buffer_view(ch)

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

