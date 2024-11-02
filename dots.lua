-- dots
--
-- See docs.

-- norns `require` statements
-- x = require('module')

engine.name = "d_Timber"

-- script components
d_ui = include 'lib/d_ui'
d_input = include 'lib/d_input'
-- grid_ = include 'lib/d_grid'

page_i = 1
page = d_ui.pages[page_i]

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

  d_ui.draw_nav(page)
  d_ui[page .. '_redraw']()
  d_ui.draw_params(page)

  screen.update()
end

function enc(n, d)
  if n == 1 then
    page_i = util.wrap(page_i + d, 1, #d_ui.pages)
    page = d_ui.pages[page_i]
  end
end

