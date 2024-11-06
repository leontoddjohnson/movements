-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local d_grid = {}

g = grid.connect()



function d_grid.grid_redraw()
  g:all(0)

  -- stuff

  g:refresh()
end


return d_grid