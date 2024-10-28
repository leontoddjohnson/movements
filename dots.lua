-- dots
--
-- See docs.

-- norns `require` ...
-- x = require('module')

ui = include 'lib/d_ui'
-- grid_ = include 'lib/d_grid'

-- page functionality
d_input = include 'lib/d_input'
-- d_blank = include 'lib/d_blank'

page_i = 1
page = ui.pages[page_i]

move_time = 0.5
move_length = 0.1
positions = {0, 0, 0, 0}
reverse_rate = 0.5

poll_time = 0.5
amp_threshold = 0.01

amp_l = 0
amp_r = 0

function init()
  audio.level_adc_cut(1)

  -- track amplitude for input page
  poll_amp_l = poll.set("amp_in_l", update_amp_l)
  poll_amp_l.time = poll_time
  poll_amp_l:start()

  poll_amp_r = poll.set("amp_in_r", update_amp_r)
  poll_amp_r.time = poll_time
  poll_amp_r:start()

  -- set move times
  time = metro.init()
  time.time = move_time
  time.event = move
  time:start()

  build_params()
  sc_reset()
  redraw()
end

function update_amp_l(a)
  amp_l = a
  sound = amp_l + amp_r >= amp_threshold
end

function update_amp_r(a)
  amp_r = a
  sound = amp_l + amp_r >= amp_threshold
end

function move()
  local p = nil
  for i = 3,4 do
    if sound then
      p = math.random() * (params:get('loop_length') - move_length)
      softcut.position(i, p)
      softcut.loop_end(i, p + move_length)
      softcut.play(i, 1)
    else
      p = 0
      softcut.position(i, p)
      softcut.loop_end(i, p + move_length)
      softcut.play(i, 0)
    end
  end
  redraw()
end

function build_params()

  params:add_number('loop_length', 'loop_length', 0, 10, 3)

end

function sc_reset()
  softcut.buffer_clear()

  for i=1,4 do
    -- init
    softcut.enable(i, 1)
    softcut.buffer(i, 1)
    softcut.level(i, 1)
    softcut.rate(i, 1)
    softcut.loop(i, 1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, params:get('loop_length'))
    softcut.position(i, 0)
    softcut.play(i, 0)
    softcut.fade_time(i, 0.1)
    softcut.pan(i, i % 2 == 0 and 1 or -1)

    -- watch position
    softcut.phase_quant(i, 0.01)
    softcut.event_phase(update_position)
    softcut.poll_start_phase()

    if i < 2 then
      softcut.rec_level(i, 1)
      softcut.pre_level(i, 0)
      softcut.level_input_cut(i, i, 1)
      softcut.rec(i, 1)
      softcut.play(i, 1)
    end
  end
end

function update_position(i,pos)
  positions[i] = pos
  redraw()
end

-- position of voice i in terms of 1 to 100 pixels
function position_to_pixels(i)
  local p = positions[i]
  -- the line is 100 pixels long
  return (p / params:get('loop_length')) * 100
end

function redraw()
  screen.clear()

  ui.draw_nav(page)
  ui[page .. '_redraw']()
  ui.draw_params(page)

  screen.update()
end

function enc(n, d)
  if n == 1 then
    page_i = util.wrap(page_i + d, 1, #ui.pages)
    page = ui.pages[page_i]
  end
end

