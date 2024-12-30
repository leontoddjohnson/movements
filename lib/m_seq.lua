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

  -- [track][bank][step]: in [-20k, 20k] defaults to 20000
  -- v < 0 ==> high pass, v > 0 ==> low pass
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
  -- track_pool[track] gives list of sample ids.
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

  -- current pattern bank loaded
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

  -- kill samples from "current" pool
  if track < 8 then
    for i = 1,#track_pool[track] do
      m_sample.note_off(track_pool[track][i])
    end

    -- reset samples in last track_pool
    m_sample.sample_params_to_default(track_pool[track])

    -- squelch samples in track_cue
    m_sample.sample_params_to_track(track_pool_cue[track][BANK], track)
  end

  -- fill track pool with cue (but don't link arrays)
  track_pool[track] = {}
  for i,x in ipairs(track_pool_cue[track][BANK]) do track_pool[track][i] = x end

  -- assign current bank for track
  bank[track] = BANK
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

    m_sample.set_sample_step_params(pool_[next_pool_i], track, step[track])
    m_sample.note_on(pool_[next_pool_i])
    track_pool_i[track] = next_pool_i

  -- SLICES
  else
    print('play recorded slice')
  end
  
end

-- TODO: figure this one out ...
function random_offset(wait)
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