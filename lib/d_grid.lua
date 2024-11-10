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
  bank_selected = 8,
  nav_page_inactive = 2,
  nav_page_active = 5,
  mode_focus = 0,
  mode_play = 10,
  alt_off = 0,
  alt_on = 15
}

g_pages = {
  'sample_seq', 'sample_time', 'sample_config', 'sample_levels',
  'rec_config', 'rec_levels'
}

G_PAGE = 'sample_config'
PLAY_MODE = false
ALT = false

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
-- NAVIGATION
-----------------------------------------------------------------

function d_grid.draw_nav()
  local origin = {9, 8}
  
  -- pages
  for i = 1, #g_pages do
    x, y = global_xy(origin, i, 1)

    if G_PAGE == g_pages[i] then
      g:led(x, y, g_brightness.nav_page_active)
    else
      g:led(x, y, g_brightness.nav_page_inactive)
    end
  end

  -- mode
  if PLAY_MODE then
    g:led(15, 8, g_brightness.mode_play)
  else
    g:led(15, 8, g_brightness.mode_focus)
  end

  -- alt
  if ALT then
    g:led(16, 8, g_brightness.alt_on)
  else
    g:led(16, 8, g_brightness.alt_off)
  end

end

function d_grid.nav_key(x, y, z)

  -- page selection
  if 9 <= x and x < 15 and y == 8 then
    if z == 1 then
      G_PAGE = g_pages[x - 8]
    end
  
  -- mode
  elseif x == 15 and y == 8 then
    if z == 1 then
      PLAY_MODE = not PLAY_MODE
    end
  
  -- alt
  elseif x == 16 and y == 8 then
    if z == 1 then
      ALT = true
    else
      ALT = false
    end
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE SEQ 
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.sample_seq_redraw()

  for x = 1,16 do
    g:led(x, 1, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.sample_seq_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE TIME
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.sample_time_redraw()

  for x = 1,16 do
    g:led(x, 2, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.sample_time_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
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

function d_grid.sample_config_redraw()
  d_grid.draw_bank(BANK)
end

function d_grid.sample_config_key(x, y, z)

  -- bank selection
  if 12 < x and y == 5 then
    if z == 1 then
      origin = {13, 5}
      BANK, _ = rel_xy(origin, x, y)
    end
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE LEVELS
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.sample_levels_redraw()

  for x = 1,16 do
    g:led(x, 4, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.sample_levels_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REC CONFIG
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.rec_config_redraw()

  for x = 1,16 do
    g:led(x, 5, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.rec_config_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REC LEVELS
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.rec_levels_redraw()

  for x = 1,16 do
    g:led(x, 6, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.rec_levels_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REDRAW
-----------------------------------------------------------------

function d_grid:grid_redraw()
  g:all(0)
  d_grid[G_PAGE .. '_redraw']()
  d_grid.draw_nav()
  g:refresh()
end


function g.key(x, y, z)

  if x > 8 and y == 8 then
    d_grid.nav_key(x, y, z)
  else
    d_grid[G_PAGE .. '_key'](x, y, z)
  end

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