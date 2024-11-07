-- DOTS effect
-- all the stuff that drives this ...

-- TODO: add reverse functionality (later)

local d_dots = {}

d_dots.positions = {0, 0, 10, 10}
d_dots.moving = false

---------------------- PARAMETERS ---------------------
amp_l = 0
amp_r = 0

function d_dots.build_params()

  params:add_separator('dots', 'dots')
  params:add_number('dots_loop_length', 'loop length', 0, 10, 5,
    function(p) return p:get() .. ' s' end)
  params:add_control('dots_move_time', 'dots move time', 
    controlspec.new(0.1, 1, 'lin', 0.1, 0.2, 's', 0.1))
  params:add_control('dots_check_time', 'dots check time', 
    controlspec.new(0.1, 2, 'lin', 0.1, 1, 's', 0.1))
  params:set_action('dots_check_time', update_amp_poll_times)
  params:add_control('dots_amp_threshold', 'amp threshold',
    controlspec.new(0.001, 0.2, 'lin', 0, 0.05, '', 0.05, false))
  params:add_option('dots_input_on', 'send input to dots', {'on', 'off'}, 2)

  -- TODO: see norns docs for .action_write/_read to save tables

end

------------------------- INIT ------------------------

function d_dots.init()
  -- input level
  audio.level_adc_cut(1)

  -- track amplitude for dots page
  poll_amp_l = poll.set("amp_in_l", update_amp_l)
  poll_amp_l.time = params:get('dots_check_time')

  poll_amp_r = poll.set("amp_in_r", update_amp_r)
  poll_amp_r.time = params:get('dots_check_time')

  -- TODO: use `amp_out_l/r` poll for tracking engine input

end

-------------------- FUNCTIONALITY -------------------

function d_dots:start()
  self.input_poll(true)
  self.sc_start()
  self.clock = clock.run(d_dots.move_dots)
  self.moving = true
end

function d_dots:stop()
  self.sc_stop()
  self.input_poll(false)
  clock.cancel(self.clock)
  self.moving = false
  screen_dirty = true
end

function d_dots.input_poll(start)
  if start then
    poll_amp_l:start()
    poll_amp_r:start()
  else
    poll_amp_l:stop()
    poll_amp_r:stop()
  end
end

function d_dots.sc_stop()
  for i=1,4 do
    softcut.rec(i, 0)
    softcut.play(i, 0)
    softcut.enable(i, 0)

    -- input
    if i < 3 then
      softcut.position(i, 0)
      d_dots.positions[i] = 0

    -- dots
    else
      softcut.position(i, params:get('dots_loop_length'))
      d_dots.positions[i] = params:get('dots_loop_length')
    end
  end

  softcut.poll_stop_phase()
  softcut.buffer_clear()
end

function d_dots.sc_start()
  softcut.buffer_clear()

  for i=1,4 do
    -- init for all four
    softcut.enable(i, 1)
    softcut.buffer(i, 1)
    softcut.rate(i, 1)
    softcut.loop(i, 1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, params:get('dots_loop_length'))
    softcut.fade_time(i, 0.1)
    softcut.pan(i, i % 2 == 0 and 1 or -1)

    -- watch position
    softcut.phase_quant(i, 0.01)

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
      softcut.position(i, params:get('dots_loop_length'))
      d_dots.positions[i] = params:get('dots_loop_length')
    end
  end

  softcut.event_phase(d_dots.update_position)
  softcut.poll_start_phase()
end

function d_dots.move_dots()
  while true do
    clock.sleep(params:get('dots_move_time'))
    local p = nil
    for i = 3,4 do
      -- choose a dot start location somewhere in the loop (not the end)
      p = math.random() * (params:get('dots_loop_length') - 0.1)

      if sound then
        softcut.position(i, p)
        softcut.loop(i, 1)
        softcut.play(i, 1)
      else
        softcut.loop(i, 0)
      end
    end
    screen_dirty = true
  end
end

function d_dots.update_position(i,pos)
  softcut.loop_end(i, params:get('dots_loop_length'))
  d_dots.positions[i] = pos
  screen_dirty = true
end

function update_amp_l(a)
  amp_l = a
  sound = amp_l + amp_r >= params:get('dots_amp_threshold')
end

function update_amp_r(a)
  amp_r = a
  sound = amp_l + amp_r >= params:get('dots_amp_threshold')
end

function update_amp_poll_times(t)
  poll_amp_l.time = t
  poll_amp_r.time = t
end

return d_dots

