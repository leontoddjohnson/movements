-- sequence operations

d_seq = {}

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_seq.init()
  -- clock routines for each track
  transport = {}

  -- current *active* step/bar for each track
  step = {1, 1, 1, 1, 1, 1, 1, 1, 1}

  -- options for num beats/secs per step for each track
  clock_fraction = {1/8, 1/7, 1/6, 1/5, 1/4, 1/3, 1/2, 1, 2, 3, 4, 5, 6}

  -- range of options for random beats/seconds
  -- defaults to just {1} (from `clock_fraction`)
  clock_range = {
    {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8},
    {8, 8}, {8, 8}
  }

  -- offset fraction for each transport -0.5 < offset < 0.5 (strict)
  -- does not apply to a step at t == 0 (when clock is run)
  offset = {0, 0, 0, 0, 0, 0, 0, 0, 0}

  -- time type for transport: either 'beats' or 'seconds'
  time_type = {
    'beats', 'beats', 'beats', 'beats', 'beats', 'beats', 'beats',
    'beats', 'beats'
  }

  -- pat[track][bank][step] = 1 or 0 (mult by param value). 
  -- rec tracks only have one bank
  pattern = d_seq.pattern_init()

  pattern_mult = {
    amp = {}
  }

  -- current pattern bank loaded (rec tracks always "bank 1")
  bank = {1, 1, 1, 1, 1, 1, 1, 1, 1}

end


-----------------------------------------------------------------
-- CLOCK ROUTINES
-----------------------------------------------------------------

-- transport 1-7 = sample
-- transport 8-9 = rec
function d_seq.start_transport(i)
  if span(pattern[i][bank[i]]) > 0 then
    transport[i] = clock.run(d_seq.play_transport, i)
  else
    print("Pattern ".. i .. " is empty.")
  end
end

function d_seq.play_transport(i)
  local wait = nil

  while true do
    -- TODO: make new function to play sample/slice/etc.
    -- step starts at 0, then waits before next step
    if pattern[i][bank[i]][step[i]] > 0 then
      print("play track " .. i .. " step " .. step[i])
    end

    -- choose clock_fraction index from selected option range
    wait = math.random(clock_range[i][1], clock_range[i][2])
    wait = clock_fraction[wait]

    if time_type[i] == 'beats' then
      clock.sync(wait, wait * offset[i])
    else
      clock.sleep(wait, wait * offset[i])
    end

    -- increase step until the 16th step of the last bar
    step[i] = util.wrap(step[i] + 1, 1, n_bars(i) * 16)

    grid_dirty = true
  end

end

function d_seq.stop_transport(i)
  clock.cancel(transport[i])
  transport[i] = nil
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- TODO: figure this one out ...
function random_offset(wait)
end

-- index of last non-zero value in table (pattern)
function span(p)
  local span_ = 0
  for i=1,#p do
    span_ = p[i] ~= 0 and i or span_
  end
  return span_
end

-- one empty pattern: 8 bars * 16 steps of 0 values
function empty_pattern()
  local pattern_ = {}
  for i = 1,16*8 do
    pattern_[i] = 0
  end
  return pattern_
end

function d_seq.pattern_init()
  local pattern = {}

  -- transports 1-7 for samples, 8-9 for recordings
  for t = 1,9 do
    pattern[t] = {}
    if t < 8 then
      -- single pattern for each sample bank
      for b = 1,4 do
        pattern[t][b] = empty_pattern()
      end
    else
      -- only "bank 1" for recordings
      pattern[t][1] = empty_pattern()
    end
  end

  return pattern
end

-- last non-empty pattern bar for track i. 
-- 1-7 for sample, 8-9 for rec
function n_bars(i)
  local span_ = span(pattern[i][bank[i]])
  -- fix for when span_ == 0
  return math.abs(span_ - 1) // 16 + 1
end

return d_seq