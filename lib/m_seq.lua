-- sequence operations

m_seq = {}

-----------------------------------------------------------------
-- BUILD PARAMETERS
-----------------------------------------------------------------

function m_seq.build_params()
  p_options.PLAY_ORDER = {'forward', 'reverse', 'random'}

  -- Forward/reverse (in order of selection), random
  params:add_option('sample_play_order', 'sample play order',
                    p_options.PLAY_ORDER, 1)

  build_param_patterns()

end

-- make "empty" patterns with default parameters for reach step
function build_param_patterns()

  param_pattern = {}

  -- [track][bank][step]: in [0, 1], (default 1)
  -- *needs to be converted to decibels between -48 and 0*
  param_pattern.amp = m_seq.pattern_init(track_param_default.amp)

  -- [track][bank][step]: in [0, 1], (default 0)
  -- amount to send to engine/softcut delay
  param_pattern.delay = m_seq.pattern_init(track_param_default.delay)

  -- [track][bank][step]: in [-1, 1] defaults to 0
  param_pattern.pan = m_seq.pattern_init(track_param_default.pan)

  -- [track][bank][step]: in [20, 20k] defaults to 20000
  param_pattern.filter = m_seq.pattern_init(track_param_default.filter_freq)

  -- [track][bank][step]: in -3, -2, -1, 0, 1, 2, 3 defaults to 0
  -- steps (or halfsteps) from an unchanged pitch
  param_pattern.scale = m_seq.pattern_init(track_param_default.scale)

  -- [track][bank][step]: in -2, -1, -1/2, 0, 1/2, 1, 2 default to 1
  param_pattern.rate = m_seq.pattern_init(track_param_default.rate)

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

  -- offset fraction for each transport -0.5 < offset < 0.5 (strict)
  -- does not apply to a step at t == 0 (when clock is run)
  -- translates to "life". apply to every k steps, or random steps
  offset = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

  -- time type for transport: either 'beats' or 'seconds'
  time_type = {
    'beats', 'beats', 'beats', 'beats', 'beats', 'beats', 'beats',
    'beats', 'beats', 'beats', 'beats'
  }

  -- pat[track][bank][step] = 1 or 0 (mult by param value). 
  -- rec tracks only have one bank
  pattern = m_seq.pattern_init()

  -- current pattern bank loaded (the last four indicate tape partitions)
  bank = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}

end


-----------------------------------------------------------------
-- CLOCK ROUTINES
-----------------------------------------------------------------

-- transport 1-7 = sample
-- transport 8-11 = rec
function m_seq.start_transport(i)
  if span(pattern[i][bank[i]])[2] > 0 then
    transport[i] = clock.run(m_seq.play_transport, i)
  else
    print("Pattern ".. i .. " is empty.")
  end
end

function m_seq.play_transport(i)
  local wait = nil

  while true do
    -- step starts at 0, then waits before playing next step
    if pattern[i][bank[i]][step[i]] > 0 and #track_pool[i] > 0 then
      m_seq.play_track_pool(i)
    end

    -- choose clock_fraction index from selected option range
    wait = math.random(clock_range[i][1], clock_range[i][2])
    wait = clock_fraction[wait]

    if time_type[i] == 'beats' then
      clock.sync(wait, wait * offset[i])
    else
      clock.sleep(wait, wait * offset[i])
    end

    if step_range[i][1] > 0 then
      step[i] = util.wrap(step[i] + 1, step_range[i][1], step_range[i][2])
    else
      -- increase step until the 16th step of the last bar
      step[i] = util.wrap(step[i] + 1, 1, n_bars(i) * 16)
    end

    grid_dirty = true
  end

end

function m_seq.stop_transport(i)
  clock.cancel(transport[i])
  transport[i] = nil

  -- stop anything still playing
  pool_ = track_pool[i]
  pool_i = track_pool_i[i]

  if i < 8 then
    m_sample.note_off(pool_[pool_i])
  end

  if i > 7 then
    -- ... stop softcut for track i
  end
  
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------
-- if step == 0, send to 1. if step == 1 then send to 0.
function m_seq.toggle_pattern_step(track, step)
  empty_step_ = pattern[track][bank[track]][step] == 0
  pattern[track][bank[track]][step] = empty_step_ and 1 or 0
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
  pool_ = track_pool[track]
  pool_i = track_pool_i[track]
  order_ = params:get('sample_play_order')
  order_ = p_options.PLAY_ORDER[order_]

  if order_ == 'forward' then
    next_pool_i = util.wrap(pool_i + 1, 1, #pool_)
  elseif order_ == 'backward' then
    next_pool_i = util.wrap(pool_i - 1, 1, #pool_)
  elseif order_ == 'random' then
    next_pool_i = math.random(#pool_)
  end

  -- SAMPLES
  if track < 8 then
    -- tracks only play one thing at a time
    -- TODO: figure out gated situation ...
    -- TODO: it's probably okay, but 1-shots will keep playing ...
    if pool_i > 0 and sample_status[pool_[pool_i]] == 1 then 
      m_sample.note_off(pool_[pool_i])
    end

    m_seq.set_step_params(pool_[next_pool_i], track, step[track])
    m_sample.note_on(pool_[next_pool_i])
    track_pool_i[track] = next_pool_i

  -- SLICES
  else
    print('play recorded slice')
  end
  
end

-- update all sample parameters for a sample `id` loaded in a `track_`
-- at some `step_`.
function m_seq.set_step_params(id, track_, step_)
  -- TAG: param 7
  local timber_params = {'amp', 'pan', 'filter'}

  for i = 1,#timber_params do
    m_seq.set_step_param(id, timber_params[i], track_, 
                              bank[track_], step_)
  end

end

-- update parameter value for sample loaded in a step.
-- `param` is in {amp, delay, pan, filter, scale, rate, prob}
function m_seq.set_step_param(id, param, track_, bank_, step_)

  -- AMP
  if param == 'amp' then
    amp_max = params:get('track_' .. track_ .. '_amp')  -- defined for track
    amp_step = param_pattern.amp[track_][bank_][step_]  -- defined at step

    -- squelch using track param default
    m_seq.squelch_amp(1, amp_max, id, amp_step)
  
  -- PAN
  elseif param == 'pan' then
    track_pan = params:get('track_' .. track_ .. '_pan')

    if track_pan < 0 then
      pan_range = {-1, track_pan + 1/3}
    elseif track_pan > 0 then
      pan_range = {track_pan - 1/3, 1}
    else
      pan_range = {-1, 1}
    end

    pan_step = param_pattern.pan[track_][bank_][step_]
    m_seq.squelch_pan({-1, 1}, pan_range, id, pan_step)

  -- TAG: param 6
  elseif param == 'filter' then
    track_freq = params:get('track_' .. track_ .. '_filter_freq')
    track_type = params:get('track_' .. track_ .. '_filter_type')
    sign = track_type == 1 and 1 or -1

    freq_track = sign * track_freq
    freq_step = param_pattern.filter[track_][bank_][step_]
    
    cutoff = freq_track > 0 and 20000 or -20

    m_seq.squelch_filter(cutoff, freq_track, id, sign * freq_step)

  end
  
end

-- SQUELCHERS ------------------------------------------------------------- --

-- squelch the amp of sample `id`. `value` is optional (e.g., step value)
-- linear mapping: [0, `input_max`] --> [0, `output_max`]
function m_seq.squelch_amp(input_max, output_max, id, value)
  v_sample = value or util.dbamp(params:get("amp_" .. id))  -- current value

  -- squelch using new maximum
  amp = util.linlin(0, input_max, 0, output_max, v_sample)
  
  -- sample amp can be between -48 and 16 (Timber), we keep to 0 max
  amp = util.clamp(ampdb(amp), -48, 0)
  params:set('amp_' .. id, amp)
end

-- given an `input_range` associated with `value` (or current pan of id),
-- return a new pan value on the same "scale" but in `output_range`
function m_seq.squelch_pan(input_range, output_range, id, value)
  pan_in = value or params:get("pan_" .. id)
  
  pan_out = util.linlin(input_range[1], input_range[2], 
                        output_range[1], output_range[2], 
                        pan_in)
  
  params:set('pan_' .. id, pan_out)
end

-- use input and output to convert current freq (e.g. `value`) accordingly.
-- `*_cutoff` > 0 --> "Low Pass", with maximum at `*_cutoff`.
-- `*_cutoff` < 0 --> "High Pass", with minimum at |`*_cutoff`|.
-- the same holds true for `value` (which is *optional*).
-- min freq = 20, max freq = 20000 (in Hz)
function m_seq.squelch_filter(input_cutoff, output_cutoff, id, value)
  freq_in = value and math.abs(value) or params:get("filter_freq_" .. id)

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

  params:set('filter_freq_' .. id, freq_out)

  -- see options.FILTER_TYPE
  if output_cutoff > 0 then
    params:set('filter_type_' .. id, 1)
  else
    params:set('filter_type_' .. id, 2)
  end

end


-- TODO: figure this one out ...
function random_offset(wait)
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

-- one "empty" pattern: 8 bars * 16 steps containing value `v` (or 0)
function empty_pattern(v)
  local pattern_ = {}
  for i = 1,16*8 do
    pattern_[i] = v or 0
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

return m_seq