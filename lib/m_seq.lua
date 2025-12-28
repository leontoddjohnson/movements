-- sequence operations

m_seq = {}

-----------------------------------------------------------------
-- BUILD PARAMETERS
-----------------------------------------------------------------

function m_seq.build_params()
  p_options.PLAY_ORDER = {'forward', 'backward', 'random'}

  -- Forward/reverse (in order of selection), random
  params:add_option('play_order', 'play order', p_options.PLAY_ORDER, 1)

  -- scale type for interval
  params:add_option('scale_type', 'scale type', {'major', 'minor'}, 1)
  params:set_action('scale_type', 
  function (v)
    if v == 1 then
      param_levels.interval = {2, 4, 5, 7, 9, 11, 0}
    elseif v == 2 then
      -- natural minor
      param_levels.interval = {2, 3, 5, 7, 8, 10, 0}
    end
  end
  )

  build_param_patterns()

end

-- make "empty" patterns with default parameters for each step
function build_param_patterns()

  param_pattern = {}

  -- [track][bank][step]: in [0, 1], (default 1)
  -- *needs to be converted to decibels between specs.AMP.minval and 0*
  param_pattern.amp = m_seq.pattern_init(track_param_default.amp)

  -- [track][bank][step]: in [0, 1], (default is 0, but set pattern to 1)
  -- amount to send to engine/softcut delay
  param_pattern.delay = m_seq.pattern_init(1)

  -- [track][bank][step]: in [-1, 1] defaults to 0
  param_pattern.pan = m_seq.pattern_init(track_param_default.pan)

  -- [track][bank][step]: in [20, 20k] defaults to 20000
  param_pattern.filter = m_seq.pattern_init(track_param_default.filter_freq)

  -- [track][bank][step]: in 0, 1, 2, ..., 5 defaults to 2
  -- see param_levels for more
  param_pattern.scale = m_seq.pattern_init(track_param_default.scale)

  -- [track][bank][step]: see `param_levels.interval` for options, init to `nil`
  param_pattern.interval = m_seq.pattern_init(nil)

  -- [track][bank][step]: in [0, 1] default to 1
  param_pattern.prob = m_seq.pattern_init(track_param_default.prob)

end

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_seq.init()
  -- options (samples or slices) to cycle through for each track.
  -- track_pool[track]
  -- for SAMPLE: this gives timber sample_id
  -- for TAPE: this gives slice_id (where `slices[slice_id]` == [start, stop])
  track_pool = {{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}}
  track_pool_i = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}  -- init'd with 0s

  -- "saved" or "cued" track pools for each [track][bank]
  track_pool_cue = {}
  for t = 1,11 do track_pool_cue[t] = {{}, {}, {}, {}} end

  -- clock routines for each track
  transport = {}

  -- current *active* step/bar for each track
  step = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}

  -- optional selection of steps to sequence through on seq page
  -- {0, 0} for no step range.
  step_range = {
    {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0},
    {0, 0}, {0, 0}, {0, 0}, {0, 0}
  }

  -- options for num beats/secs per step for each track
  clock_fraction = {1/8, 1/7, 1/6, 1/5, 1/4, 1/3, 1/2, 1, 2, 3, 4, 5, 6}

  -- range of options for random beats/seconds
  -- defaults to just {1} (from `clock_fraction`)
  clock_range = {
    {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8},
    {8, 8}, {8, 8}, {8, 8}, {8, 8}
  }

  -- time type for transport: either 'beats' or 'seconds'
  time_type = {
    'beats', 'beats', 'beats', 'beats', 'beats', 'beats', 'beats',
    'beats', 'beats', 'beats', 'beats'
  }

  -- the pattern of active steps to trigger for each track sequence.
  -- pattern[track][bank][step] = 1 or 0 (active step or not)
  pattern = m_seq.pattern_init(0)

  -- pattern of steps to **record** based on time of current track.
  -- if `record_pattern[step] == 1`, then activate record at that step.
  record_pattern = empty_pattern(0)

  -- current pattern bank loaded (the last four indicate tape partitions)
  bank = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}

  -- `play_trigger[i] == j`: track `i` plays at step 1 once track `j` does
  -- otherwise, is nil.
  play_trigger = {}

  -- `stop_trigger[i] == 1`: track `i` stops at the end of the current bar
  -- otherwise, is nil
  stop_trigger = {}

  -- `play_cue.bank == {i, j}`: sample tracks switch to bank `i` when track `j` 
  -- reaches step 1. Analogously for `play_cue.partition`.
  play_cue = {
    bank = {},
    partition = {}
  }

  -- define metronome clock routine
  metronome = nil
  metronome_flash = 0
  last_time_type = 'beats'
  last_clock_fraction = 8  -- 1 beat
  m_seq.start_metronome()

end


-----------------------------------------------------------------
-- CLOCK ROUTINES
-----------------------------------------------------------------

-- transport 1-7 = sample
-- transport 8-11 = rec
function m_seq.start_transport(i)
  if span(pattern[i][bank[i]])[2] > 0 then
    play_trigger[i] = nil  -- remove any trigger
    transport[i] = clock.run(m_seq.play_transport, i)
  else
    print("Pattern ".. i .. " is empty.")
  end
end

function m_seq.play_transport(i)
  local wait = nil
  local playing = true
  local prob_track, prob_step, prob

  while playing do
    -- step plays, then waits before playing next step
    if pattern[i][bank[i]][step[i]] > 0 and #track_pool[i] > 0 then
      prob_track = params:get('track_' .. i .. '_prob')
      prob_step = param_pattern.prob[i][bank[i]][step[i]]
      prob = m_seq.squelch_prob(1, prob_track, prob_step)

      if math.random() <= prob then
        m_seq.play_track_pool(i)
      end
    end

    -- choose clock_fraction index from selected option range
    wait = math.random(clock_range[i][1], clock_range[i][2])
    wait = clock_fraction[wait]

    if time_type[i] == 'beats' then
      clock.sync(wait)
    else
      clock.sleep(wait)
    end

    if step_range[i][1] > 0 then
      step[i] = util.wrap(step[i] + 1, step_range[i][1], step_range[i][2])
    else
      -- increase step until the 16th step of the last bar
      step[i] = util.wrap(step[i] + 1, 1, n_bars(i) * 16)
    end

    -- update grid to follow transport of current track if in play mode
    if PLAY_MODE 
    and TRACK == i 
    and (step[i] <= (SEQ_BAR - 1) * 16 or step[i] > SEQ_BAR * 16) then
      SEQ_BAR = (step[i] - 1) // 16 + 1
    end

    -- stop transport if set to stop at end of bar
    if step[i] % 16 == 1 and stop_trigger[i] then
      m_seq.stop_transport(i)
      stop_trigger[i] = nil
      playing = false
    end

    if step[i] % 16 == 1 then
      -- play cued tracks from step 1
      for j=1,11 do
        if play_trigger[j] == i then
          step[j] = 1
          m_seq.start_transport(j)
        end
      end

      -- if play_cue is set, then switch valid tracks to new bank/partition
      if (#play_cue.bank == 2 and play_cue.bank[2] == i)
        or (#play_cue.partition == 2 and play_cue.partition[2] == i) then
        
        -- sample tracks
        if i < 8 then
          BANK = play_cue.bank[1]
          for j=1,7 do
            if #track_pool_cue[j][BANK] > 0 then
              m_seq.load_track_pool(j)
            end
          end
          play_cue.bank = {}  -- reset bank cue
        -- tape tracks
        else
          PARTITION = play_cue.partition[1]
          for j=8,11 do
            if #track_pool_cue[j][PARTITION] > 0 then
              m_seq.load_track_pool(j)
            end
          end
          play_cue.partition = {}  -- reset partition cue
        end
      end
    end

    grid_dirty = true
  end

end

function m_seq.stop_transport(i)
  clock.cancel(transport[i])
  transport[i] = nil

  -- stop anything still playing
  local pool_ = track_pool[i]
  local pool_i = track_pool_i[i]

  if i < 8 then
    m_sample.note_off(pool_[pool_i])
  end

  if i > 7 then
    m_tape.stop_track(i)
  end
  
end

function m_seq.start_metronome()
  metronome = clock.run(m_seq.metronome)
end

function m_seq.stop_metronome()
  clock.cancel(metronome)
  metronome = nil
end

function m_seq.metronome()
  while true do
    metronome_flash = (metronome_flash + 1) % 2
    local wait = clock_fraction[last_clock_fraction]

    if last_time_type == 'beats' then
      clock.sync(wait)
    else
      clock.sleep(wait)
    end

    grid_dirty = true

  end
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------
-- if step == 0, send to 1. if step == 1 then send to 0.
function m_seq.toggle_pattern_step(track, step)
  local default
  local empty_step = pattern[track][bank[track]][step] == 0
  pattern[track][bank[track]][step] = empty_step and 1 or 0

  if empty_step then
    -- set default parameter values for new step
    for i,p in ipairs(p_options.PARAMS) do
      if p == 'filter' then
        -- set to most extreme frequency based on low pass/high pass
        local filter_type = params:get('track_' .. track .. '_filter_type')
        default = filter_type == 1 and 20000 or 20
      elseif p == 'delay' then
        -- set to 1; default for track is 0, so it will be squelched at first
        default = 1
      elseif p == 'interval' then
        -- initialize to using track value only
        default = nil
      else
        default = track_param_default[p]
      end
      param_pattern[p][track][bank[track]][step] = default
    end
  end
end

-- load `track_pool` from `track_pool_cue` into current BANK
function m_seq.load_track_pool(track)

  local bp  -- bank or partition, depending on track number

  if track < 8 then
    -- kill samples from "current" pool
    for i = 1,#track_pool[track] do
      m_sample.note_off(track_pool[track][i])
    end

    -- reset samples in last track_pool
    m_sample.sample_params_to_default(track_pool[track])

    -- squelch samples in track_cue
    m_sample.sample_params_to_track(track_pool_cue[track][BANK], track)
    
    bp = BANK

  else
    -- kill voice of current track
    for i = 1,#track_pool[track] do
      m_tape.stop_track(track)
    end

    -- reset slices in last track_pool
    m_tape.slice_params_to_default(track_pool[track])

    -- squelch slices in track_cue
    m_tape.slice_params_to_track(track_pool_cue[track][PARTITION], track)

    bp = PARTITION
  end

  -- fill track pool with cue (but don't link arrays)
  track_pool[track] = {}
  for i,x in ipairs(track_pool_cue[track][bp]) do track_pool[track][i] = x end

  -- assign current bank/partition for track
  bank[track] = bp

end

-- play the cue from the track pool, and cycle through
function m_seq.play_track_pool(track)
  local pool_ = track_pool[track]
  local pool_i = track_pool_i[track]
  local order_ = params:get('play_order')
  local order_ = p_options.PLAY_ORDER[order_]
  local next_pool_i

  if order_ == 'forward' then
    next_pool_i = util.wrap(pool_i + 1, 1, #pool_)
  elseif order_ == 'backward' then
    next_pool_i = util.wrap(pool_i - 1, 1, #pool_)
  elseif order_ == 'random' then
    next_pool_i = math.random(#pool_)
  end

  local next_id = pool_[next_pool_i]
  
  -- SAMPLES
  if track < 8 then
    -- tracks only play one thing at a time
    if pool_i > 0 and sample_status[pool_[pool_i]] == 1 then 
      m_sample.note_off(pool_[pool_i])
    end
    
    if PLAY_MODE and track == TRACK then m_sample.set_sample_id(next_id) end

    m_seq.set_step_params(next_id, track, step[track])
    m_sample.note_on(next_id)
    track_pool_i[track] = next_pool_i

  -- SLICES
  -- if not already recording, then play or record next slice
  elseif voice_state[track - 7] < 2 then
    -- record on current slice if record_pattern indicates matching step
    if (record_pattern[step[track]] > 0) and (track == TRACK) and next_id then
      m_tape.record_section(track, slices[next_id])

      -- also record stereo if current track is stereo-pair-LEFT
      local track_pair = m_tape.stereo_pair(track)
      if track_pair and track_pair > track then
        m_tape.record_section(track_pair, slices[next_id])
      end

      -- remove recording step after recording is initiated
      record_pattern[step[track]] = 0

    else
      m_seq.set_step_params(next_id, track, step[track])
      m_tape.play_slice(track, next_id)
    end

    if PLAY_MODE and track == TRACK then m_tape.set_slice_id(next_id) end

    track_pool_i[track] = next_pool_i
  end
  
end

-- update all sample parameters for a sample `id` loaded in a `track_`
-- at some `step_`.
function m_seq.set_step_params(id, track_, step_)
  local play_params = {'amp', 'pan', 'filter', 'delay', 'scale', 'interval'}

  for k, p in pairs(play_params) do
    m_seq.set_step_param(id, p, track_, bank[track_], step_)
  end

end

-- update parameter value for sample loaded in a step.
-- `param` is in {amp, delay, pan, filter, scale, interval, prob}
function m_seq.set_step_param(id, param, track_, bank_, step_)

  -- AMP
  if param == 'amp' then
    amp_max = params:get('track_' .. track_ .. '_amp')  -- defined for track
    amp_step = param_pattern.amp[track_][bank_][step_]  -- defined at step

    if track_ < 8 then
      amp = m_seq.squelch_amp(1, amp_max, amp_step, true)
      params:set('amp_' .. id, amp)  -- timber sample
    else
      amp = m_seq.squelch_amp(1, amp_max, amp_step, false)
      slice_params[id]['amp'] = amp  -- softcut slice
    end
  
  -- PAN
  elseif param == 'pan' then
    track_pan = params:get('track_' .. track_ .. '_pan')
    pan_step = param_pattern.pan[track_][bank_][step_]

    if track_pan == 0 then
      pan_def = {0, 1}
    else
      -- TODO: consider making the "1/2" here a custom pan width
      pan_def = {track_pan, 1/2}
    end

    pan = m_seq.squelch_pan({0, 1}, pan_def, pan_step)

    if track_ < 8 then
      params:set('pan_' .. id, pan)
    else
      slice_params[id]['pan'] = pan
    end

  elseif param == 'filter' then
    track_freq = params:get('track_' .. track_ .. '_filter_freq')
    track_type = params:get('track_' .. track_ .. '_filter_type')
    sign = track_type == 1 and 1 or -1

    freq_track = sign * track_freq
    freq_step = param_pattern.filter[track_][bank_][step_]
    
    cutoff = freq_track > 0 and 20000 or -20

    freq = m_seq.squelch_filter(cutoff, freq_track, freq_step)

    if track_ < 8 then
      params:set('filter_freq_' .. id, freq)
      params:set('filter_type_' .. id, freq_track > 0 and 1 or 2)
    else
      slice_params[id]['filter_freq'] = freq
      slice_params[id]['filter_type'] = freq_track > 0 and 1 or 2
    end
  
  -- DELAY
  elseif param == 'delay' then
    delay_max = params:get('track_' .. track_ .. '_delay')
    delay_step = param_pattern.delay[track_][bank_][step_]

    -- squelch using track param default
    delay = m_seq.squelch_amp(1, delay_max, delay_step)

    if track_ < 8 then
      params:set('delay_' .. id, delay)
    else
      slice_params[id]['delay'] = delay
    end

  -- SCALE (and INTERVAL)
  elseif param == 'scale' or param == 'interval' then
    track_scale = params:get('track_' .. track_ .. '_scale')
    scale_step = param_pattern.scale[track_][bank_][step_]

    -- this is nil if using track value
    interval = param_pattern.interval[track_][bank_][step_]

    -- input is full range, centered at 2 (no scale)
    -- output is within two scale points of track
    scale = m_seq.squelch_scale({2, 3}, {track_scale, 2}, scale_step)
    transpose_out = scale_to_transpose(scale, track_, interval)

    if track_ < 8 then
      params:set('transpose_' .. id, transpose_out)
    else
      slice_params[id]['transpose'] = transpose_out
    end

  end
  
end

-- SQUELCHERS ------------------------------------------------------------- --

-- linear mapping: [0, `input_max`] --> [0, `output_max`]
-- `db_out` is boolean. If true, return the value in decibels with `ampdb`.
function m_seq.squelch_amp(input_max, output_max, value, db_out)

  if value == 0 and input_max ~= 1 then
    -- use track level if not a zero pattern step (value == 0 & input_max == 1)
    amp = output_max
  else
    -- squelch using new maximum
    amp = util.linlin(0, input_max, 0, output_max, value)
  end

  if db_out then
    -- sample amp can be between specs.AMP.minval and 16 (Timber), keep to 0 max
    amp = util.clamp(ampdb(amp), specs.AMP.minval, 0)
  end

  return amp
end

-- this is just a linlin transformation between 0 and the maximum
function m_seq.squelch_prob(input_max, output_max, value)

  prob = util.linlin(0, input_max, 0, output_max, value)

  return prob
end

-- `*_def` = [center, range_radius]
-- linearly translate from `input_` neighborhood to `output_` neighborhood
-- clamping to [-1, 1]
function m_seq.squelch_pan(input_def, output_def, value)
  local input_range, output_range

  input_range = {input_def[1] - input_def[2], input_def[1] + input_def[2]}
  output_range = {output_def[1] - output_def[2], output_def[1] + output_def[2]}

  pan_out = util.linlin(input_range[1], input_range[2], 
                        output_range[1], output_range[2], 
                        value)
  
  return util.clamp(pan_out, -1, 1)
end

-- use input and output to convert current freq (e.g. `value`) accordingly.
-- `*_cutoff` > 0 --> "Low Pass", with maximum at `*_cutoff`.
-- `*_cutoff` < 0 --> "High Pass", with minimum at |`*_cutoff`|.
-- the same holds true for `value`.
-- min freq = 20, max freq = 20000 (in Hz)
function m_seq.squelch_filter(input_cutoff, output_cutoff, value)
  freq_in = math.abs(value)

  -- low pass to low pass -> simple squelch
  if input_cutoff > 0 and output_cutoff > 0 then
    freq_out = util.linlin(20, input_cutoff,
                           20, output_cutoff, freq_in)
    
  -- high pass to high pass -> simple squelch
  elseif input_cutoff < 0 and output_cutoff < 0 then
    freq_out = util.linlin(-1 * input_cutoff, 20000, 
                           -1 * output_cutoff, 20000, freq_in)
  
  -- simply swapping between high pass and low pass
  elseif math.abs(input_cutoff) == math.abs(output_cutoff) then
    freq_out = freq_in
  
  -- low pass to high pass -> quasi-mirror then squelch
  elseif input_cutoff > 0 and output_cutoff < 0 then
    freq_out = util.linlin(20, input_cutoff, 
                           -1 * output_cutoff, 20000, freq_in)

  -- high pass to low pass -> quasi-mirror then squelch
  elseif input_cutoff < 0 and output_cutoff > 0 then
    freq_out = util.linlin(-1 * input_cutoff, 20000,
                           20, output_cutoff, freq_in)
  end

  return freq_out
end

-- similar to pan
-- `*_def` = [center, range_radius]
-- linearly translate from `input_` neighborhood to `output_` neighborhood
-- clamping to [0, 5]
function m_seq.squelch_scale(input_def, output_def, value)
  local input_range, output_range

  input_range = {input_def[1] - input_def[2], input_def[1] + input_def[2]}
  output_range = {output_def[1] - output_def[2], output_def[1] + output_def[2]}

  out = util.linlin(input_range[1], input_range[2], 
                    output_range[1], output_range[2], 
                    value)

  return util.clamp(util.round(out), 0, 5)
end

-- return a "slice" of a table, from `first` to `last`.
-- this returns `{t[first], t[first + 1], ..., t[last]}`
function table_slice(t, first, last)
  local sub = {}

  for i=first,last do
    table.insert(sub, t[i])
  end

  return sub
end

-- span of non-zero values in table
-- span[0] indexes the first non-zero value (or 0 for none)
-- span[1] indexes the last non-zero value (or 0 for none)
function span(t)
  local span_l = 0
  local span_r = 0

  for i=1,#t do
    if t[i] ~= 0 and span_l == 0 then
      span_l = i
    end

    span_r = t[i] ~= 0 and i or span_r
  end

  return {span_l, span_r}
end

-- one "empty" pattern: 8 bars * 16 steps containing value `v`
function empty_pattern(v)
  local pattern_ = {}
  for i = 1,16*8 do
    pattern_[i] = v
  end
  return pattern_
end

-- empty pattern for each track-bank combination, with value `v` as default
function m_seq.pattern_init(v)
  local pattern = {}

  -- transports 1-7 for samples, 8-11 for recordings
  for t = 1,11 do
    pattern[t] = {}

    -- single pattern for each sample bank
    for b = 1,4 do
      pattern[t][b] = empty_pattern(v)
    end
  end

  return pattern
end

-- last non-empty pattern bar for track i. 
-- 1-7 for sample, 8-11 for rec
function n_bars(i)
  local span_ = span(pattern[i][bank[i]])[2]
  -- fix for when span_ == 0
  return math.abs(span_ - 1) // 16 + 1
end

function random_float(min, max)
  return min + math.random() * (max - min);
end

-- convert a `clock_fraction` value to a fraction string
function format_clock_fraction(v, units)
  units = units or "beats"

	for i, frac in ipairs(clock_fraction) do
		if v == frac then
			if v >= 1 then
				return v .. " " .. units
			else
				return "1/" .. (9 - i) .. " " .. units
			end
		end
	end
end

return m_seq