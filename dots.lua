-- dots
--
-- See docs.

-- norns `require` statements
-- x = require('module')

-- script components
ui = include 'lib/d_ui'
d_input = include 'lib/d_input'
-- grid_ = include 'lib/d_grid'

page_i = 1
page = ui.pages[page_i]

---------------------- INIT ---------------------

function build_params()
  d_input.build_params()
end

function init()
  build_params()
  d_input.init()
  redraw()
end

----------------------- UI -----------------------

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

