-- sequence operations

d_seq = {}

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_seq.init()
  -- clock routines for each track
  transport = {}

  -- current step/bar for each track
  step = {1, 1, 1, 1, 1, 1, 1, 1, 1}

  -- options for num beats/secs per step for each track
  clock_fraction = {1/8, 1/7, 1/6, 1/5, 1/4, 1/3, 1/2, 1, 2, 3, 4, 5, 6}

  -- range of options for random beats/seconds
  clock_range = {
    {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8}, {8, 8},
    {8, 8}, {8, 8}
  }

  -- offset fraction for each transport 0 <= offset < 1 (strict)
  offset = {0, 0, 0, 0, 0, 0, 0, 0, 0}
  time_type = {
    'beat', 'beat', 'beat', 'beat', 'beat', 'beat', 'beat',
    'beat', 'beat'
  }

  -- pat[track][bank][step] = 1 or nil (mult by param value). 
  -- rec tracks only have one bank
  pattern = {
    {{1, nil, 1, 1, nil, nil}, {}, {}, {}},
    {{}, {}, {}, {}},
    {{}, {}, {}, {}},
    {{}, {}, {}, {}},
    {{}, {}, {}, {}},
    {{}, {}, {}, {}},
    {{}, {}, {}, {}},
    {{}},
    {{}}
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
  if #pattern[i][bank[i]] > 0 then
    transport[i] = clock.run(d_seq.play_transport, i)
  else
    print("Pattern ".. i .. " is empty.")
  end
end

function d_seq.play_transport(i)
  local wait = nil

  while true do
    -- choose clock_fraction index from selected option range
    wait = math.random(clock_range[i][1], clock_range[i][2])
    wait = clock_fraction[wait]

    if time_type[i] == 'beat' then
      clock.sync(wait, wait * offset[i])
    else
      clock.sleep(wait, wait * offset[i])
    end

    step[i] = util.wrap(step[i] + 1, 1, n_bars(i) * 16)
  end

end

function d_seq.stop_transport(i)
  clock.cancel(transport[i])
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- TODO: figure this one out ...
function random_offset(wait)
end

-- counts last non-nil value in pattern
function n_bars(i)
  -- recall that pattern values are 1 or nil
  local last_step = #pattern[i][bank[i]]
  return (last_step - 1) // 16 + 1
end

return d_seq