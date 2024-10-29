-- INPUT effect
-- all the stuff that drives this ...

-- TODO: add reverse functionality (later)

local input = {}

input.positions = {0, 0, 0, 0}

---------------------- INIT ---------------------
amp_l = 0
amp_r = 0

function input.build_params()

  -- TODO: fix these (e.g., look into lib.formatters)
  params:add_separator('input', 'input')
  params:add_number('input_loop_length', 'loop length', 0, 10, 5)
  params:add_number('input_move_time', 'dot move time', 0.1, 1, 0.2)
  params:set_action('input_move_time', function(x) time.time = x end)
  params:add_number('input_check_time', 'input check time', 0.1, 2, 1)
  params:set_action('input_check_time', update_amp_poll_times)
  params:add_control('input_amp_threshold', 'amp threshold',
    controlspec.new(0.001, 0.1, 'lin', 0, 0.01, '', 0.05, false))

end

function input.init()
  -- input level
  audio.level_adc_cut(1)

  -- track amplitude for input page
  poll_amp_l = poll.set("amp_in_l", update_amp_l)
  poll_amp_l.time = params:get('input_check_time')
  poll_amp_l:start()

  poll_amp_r = poll.set("amp_in_r", update_amp_r)
  poll_amp_r.time = params:get('input_check_time')
  poll_amp_r:start()

  -- set move_dots times
  time = metro.init()
  time.time = params:get('input_move_time')
  time.event = input.move_dots
  time:start()

  input.sc_reset()
end

-------------------- FUNCTIONALITY -------------------

function input.sc_reset()
  softcut.buffer_clear()

  for i=1,4 do
    -- init for all four
    softcut.enable(i, 1)
    softcut.buffer(i, 1)
    softcut.rate(i, 1)
    softcut.loop(i, 1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, params:get('input_loop_length'))
    softcut.fade_time(i, 0.1)
    softcut.pan(i, i % 2 == 0 and 1 or -1)

    -- watch position
    softcut.phase_quant(i, 0.01)
    softcut.event_phase(input.update_position)
    softcut.poll_start_phase()

    -- input
    if i < 3 then
      softcut.position(i, 0)
      softcut.rec_level(i, 1)
      softcut.pre_level(i, 0)
      softcut.level_input_cut(i, i, 1)
      softcut.level(i, 0)
      softcut.play(i, 1)
      softcut.rec(i, 1)

    -- dots
    else
      softcut.play(i, 0)
      softcut.level(i, 1)
      softcut.position(i, params:get('input_loop_length'))
      input.positions[i] = params:get('input_loop_length')
    end
  end
end

function input.move_dots()
  local p = nil
  for i = 3,4 do
    p = math.random() * (params:get('input_loop_length') - 0.1)

    if sound then
      softcut.position(i, p)
      softcut.loop(i, 1)
      softcut.play(i, 1)
    else
      softcut.loop(i, 0)
    end
  end
  redraw()
end

function input.update_position(i,pos)
  softcut.loop_end(i, params:get('input_loop_length'))
  input.positions[i] = pos
  redraw()
end

function update_amp_l(a)
  amp_l = a
  sound = amp_l + amp_r >= params:get('input_amp_threshold')
end

function update_amp_r(a)
  amp_r = a
  sound = amp_l + amp_r >= params:get('input_amp_threshold')
end

function update_amp_poll_times(t)
  poll_amp_l.time = t
  poll_amp_r.time = t
end

return input

