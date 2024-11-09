-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local d_grid = {}

local g_map = {
  sample_seq = {},
  sample_time = {},
  sample_config = {},
  sample_levels = {},
  rec_config = {},
  rec_levels = {}
}

g = grid.connect()  -- requires 8x16 grid

g_brightness = {
  bank_sample_empty = 0,
  bank_sample_loaded = 7,
  bank_sample_selected = 15,
  bank_empty = 2,
  bank_loaded = 4,
  bank_selected = 8
}

G_PAGE = 'sample_config'

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_grid.init()
  -- -- sample.config sections
  -- g_map.sample.config = {
  --   origin = 
  -- }
end





-----------------------------------------------------------------
-- SAMPLE CONFIG 
-----------------------------------------------------------------

function d_grid.draw_bank(bank)
  local origin = {9, 1}

  -- draw bank samples
  for row = 1,4 do
    for col = 1,8 do
      x, y = global_xy(origin, col, row)
      if banks[bank][row][col] then
        g:led(x, y, g_brightness.bank_sample_loaded)
      else
        g:led(x, y, g_brightness.bank_sample_empty)
      end
    end
  end

  -- draw bank indicators
  origin = {13, 5}
  for bank_ = 1,4 do
    x, y = global_xy(origin, bank_, 1)
    if bank_folders[bank_] then
      g:led(x, y, g_brightness.bank_loaded)
    elseif BANK == bank_ then
      g:led(x, y, g_brightness.bank_selected)
    else
      g:led(x, y, g_brightness.bank_empty)
    end
  end

end

function d_grid.redraw_sample_config()
  d_grid.draw_bank(BANK)
end

function d_grid.sample_config_key(x, y, z)

  -- bank selection
  if 12 < x and y == 5 then
    if z == 1 then
      origin = {13, 5}
      BANK, _ = rel_xy(origin, x, y)
      g:led(x, y, g_brightness.bank_selected)
    end
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- REDRAW
-----------------------------------------------------------------

function d_grid:grid_redraw()
  g:all(0)

  if G_PAGE == 'sample_config' then
    self.redraw_sample_config()
  end

  g:refresh()
end


function g.key(x, y, z)
  d_grid[G_PAGE .. '_key'](x, y, z)
end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- "global" grid x and y from *relative* x and y from origin. 
-- origin is {n_cols, n_rows} and this is *1-indexed*
function global_xy(origin, x_rel, y_rel)
  x = origin[1] - 1 + x_rel
  y = origin[2] - 1 + y_rel
  return x, y
end 

-- "relative" grid x and y from *global* x and y given origin. 
-- origin is {n_cols, n_rows} and this is *1-indexed*
function rel_xy(origin, x_global, y_global)
  x = x_global - origin[1] + 1
  y = y_global - origin[2] + 1
  return x, y
end

return d_grid