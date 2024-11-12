-- sample pages

d_sample = {}

local MusicUtil = require "musicutil"
local Formatters = require "formatters"
local BeatClock = require "beatclock"

local Timber = include "lib/d_timber"

local NUM_SAMPLES = 128  -- max 256

local beat_clock
local note_queue = {}

-- sample_status[sample_id] playing == 1, stopped == 0
sample_status = {}
STATUS = {
  STOPPED = 0,
  PLAYING = 1
}

-- sample IDs for each bank. use [bank][row][col].
banks = {
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}}
}
bank_folders = {}


BANK = 1  -- currently selected sample bank
TRACK = 1  -- currently selected track
SAMPLE = nil  -- currently selected sample

-----------------------------------------------------------------
-- PARAMETERS
-----------------------------------------------------------------

function d_sample.build_params()

  Timber.add_params()

  params:add_separator("Samples")
  
  -- Index zero to align with MIDI note numbers
  for i = 0, NUM_SAMPLES - 1 do
    local extra_params = {
      {type = "option", id = "launch_mode_" .. i, name = "Launch Mode", options = {"Gate", "Toggle"}, default = 1, action = function(value)
        Timber.setup_params_dirty = true
      end}
    }
    Timber.add_sample_params(i, true, extra_params)
  end
end

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_sample.init()

  for i = 0, NUM_SAMPLES - 1 do sample_status[i] = STATUS.STOPPED end

  -- Timber callbacks
  Timber.sample_changed_callback = function(id)
    
    -- Set loop default based on sample length or name
    if Timber.samples_meta[id].manual_load and Timber.samples_meta[id].streaming == 0 and Timber.samples_meta[id].num_frames / Timber.samples_meta[id].sample_rate < 1 and string.find(string.lower(params:get("sample_" .. id)), "loop") == nil then
      params:set("play_mode_" .. id, 3) -- One shot
    end
    
    -- grid_dirty = true
    -- callback_set_screen_dirty(id)
  end

  Timber.meta_changed_callback = function(id)
    if Timber.samples_meta[id].playing then
      sample_status[id] = STATUS.PLAYING
    else
      sample_status[id] = STATUS.STOPPED
    end
    -- grid_dirty = true
    -- callback_set_screen_dirty(id)
  end

  Timber.waveform_changed_callback = callback_set_waveform_dirty
  Timber.play_positions_changed_callback = callback_set_waveform_dirty
  Timber.views_changed_callback = callback_set_screen_dirty
  
end


-----------------------------------------------------------------
-- SAMPLE: CONFIG
-----------------------------------------------------------------

-- convert bank <rowcol> syntax to 0-indexed id for timber
-- going L->R, Top->Bottom down 4 4x8 matrices, 0-indexed
function rowcol_id(rowcol, bank)
  rowcol = tonumber(rowcol)
  local n_rows_above = (rowcol - 10) // 10  -- in bank
  local n_cols_over = rowcol % 10
  local bank_id = 8 * n_rows_above + n_cols_over - 1 -- 0-index
  return 32 * (bank - 1) + bank_id
end

-- TODO: double triple verify these ...
-- return a string <bankrowcol> from the id number
function id_bankrowcol(id)
  local bank = (id // 32) + 1
  local row = (id - (bank - 1) * 32) // 8 + 1
  local col = (id - (bank - 1) * 32) % 8 + 1
  return bank, row, col
end


function d_sample:load_bank(bank)
  Timber.FileSelect.enter(_path.audio, function(file)
    file_select_active = false
    if file ~= "cancel" then
      self.load_folder(file, bank)
    end
  end)
end

function d_sample.load_folder(file, bank)
  
  -- first sample in bank
  local sample_id = (bank - 1) * 32
  
  Timber.clear_samples(sample_id, bank * 32 - 1)
  
  -- filename
  local split_at = string.match(file, "^.*()/")
  local folder = string.sub(file, 1, split_at)
  file = string.sub(file, split_at + 1)

  -- folder name
  local folder_ = string.sub(folder, 1, -2)
  split_at = string.match(folder_, "^.*()/")
  local folder_name = string.sub(folder_, split_at + 1)
  
  local found = false
  for k, v in ipairs(Timber.FileSelect.list) do
    if v == file then found = true end
    if found then
      -- get lowercase filename
      local lower_v = v:lower()
        
      -- find rowcol* if "<rowcol>*..." naming convention (* = space|-|_)
      local rowcol = string.match(lower_v, "^%d%d[%s-_]")
      
      if rowcol ~= nil then
        -- remove the split character
        rowcol = string.sub(rowcol, 1, 2)
        sample_id = rowcol_id(rowcol, bank)
      end

      if sample_id >= bank * 32 then
        print("Max files loaded in bank.")
        break
      end

      if string.match(lower_v, ".wav$") or string.match(lower_v, ".aif$") or string.match(lower_v, ".aiff$") or string.match(lower_v, ".ogg$") then
        Timber.load_sample(sample_id, folder .. v)
        bank_, row, col = id_bankrowcol(sample_id)

        if bank ~= bank_ then
          error("bank calculation is incorrect")
        end

        banks[bank][row][col] = sample_id
        sample_id = sample_id + 1

      else
        print("Skipped", v)
      end
    end
  end
  bank_folders[bank] = folder_name
  screen_dirty = true
  grid_dirty = true
end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

function d_sample.note_on(sample_id, vel)
  if (params:get('sample_' .. sample_id) ~= "-") 
      and (sum(sample_status) < 7) then

    print("note_on", sample_id)
    vel = vel or 1
    engine.noteOn(sample_id, MusicUtil.note_num_to_freq(60), vel, sample_id)
    sample_status[sample_id] = 1

    -- sample_status[sample_id] = STATUS.PLAYING
    -- global_view:add_play_visual()
    -- screen_dirty = true
    -- grid_dirty = true
  else
    print("too many samples, or no sample " .. sample_id)
  end
end

function d_sample.note_off(sample_id)
  print("note_off", sample_id)
  engine.noteOff(sample_id)
  sample_status[sample_id] = 0
  -- screen_dirty = true
  -- grid_dirty = true
end

function d_sample.note_kill_all()
  engine.noteKillAll()
  -- screen_dirty = true
  -- grid_dirty = true
end

-- calculate sum of numeric or boolean (true == 1) values
function sum(t)
  s = 0
  for i=1,#t do
    if t[i] == true then v = 1 else v = t[i] end
    s = s + v
  end
  return s
end

function callback_set_screen_dirty(id)
  -- if id == nil or id == SAMPLE then
  --   screen_dirty = true
  -- end
end

function callback_set_waveform_dirty(id)
  -- if (id == nil or id == SAMPLE) then
  --   screen_dirty = true
  -- end
end

-----------------------------------------------------------------
-- TIMBER (copy/paste what you need)
-----------------------------------------------------------------

-- function callback_set_screen_dirty(id)
--   if id == nil or id == current_sample_id or pages.index == 1 then
--     screen_dirty = true
--   end
-- end

-- function callback_set_waveform_dirty(id)
--   if (id == nil or id == current_sample_id) and pages.index == 3 then
--     screen_dirty = true
--   end
-- end


-- -- Timber callbacks
-- Timber.sample_changed_callback = function(id)
  
--   -- Set loop default based on sample length or name
--   if Timber.samples_meta[id].manual_load and Timber.samples_meta[id].streaming == 0 and Timber.samples_meta[id].num_frames / Timber.samples_meta[id].sample_rate < 1 and string.find(string.lower(params:get("sample_" .. id)), "loop") == nil then
--     params:set("play_mode_" .. id, 3) -- One shot
--   end
  
--   grid_dirty = true
--   callback_set_screen_dirty(id)
-- end
-- Timber.meta_changed_callback = function(id)
--   if Timber.samples_meta[id].playing and sample_status[id] ~= STATUS.STOPPING then
--     sample_status[id] = STATUS.PLAYING
--   elseif not Timber.samples_meta[id].playing and sample_status[id] ~= STATUS.STARTING then
--     sample_status[id] = STATUS.STOPPED
--   end
--   grid_dirty = true
--   callback_set_screen_dirty(id)
-- end
-- Timber.waveform_changed_callback = callback_set_waveform_dirty
-- Timber.play_positions_changed_callback = callback_set_waveform_dirty
-- Timber.views_changed_callback = callback_set_screen_dirty
  

local function set_sample_id(id)
  current_sample_id = id
  while current_sample_id >= NUM_SAMPLES do current_sample_id = current_sample_id - NUM_SAMPLES end
  while current_sample_id < 0 do current_sample_id = current_sample_id + NUM_SAMPLES end
  sample_setup_view:set_sample_id(current_sample_id)
  waveform_view:set_sample_id(current_sample_id)
  filter_amp_view:set_sample_id(current_sample_id)
  amp_env_view:set_sample_id(current_sample_id)
  mod_env_view:set_sample_id(current_sample_id)
  lfos_view:set_sample_id(current_sample_id)
  mod_matrix_view:set_sample_id(current_sample_id)
end

local function id_to_x(id)
  return (id - 1) % grid_w + 1
end
local function id_to_y(id)
  return math.ceil(id / grid_w)
end

local function note_on(sample_id, vel)
  if Timber.samples_meta[sample_id].num_frames > 0 then
    -- print("note_on", sample_id)
    vel = vel or 1
    engine.noteOn(sample_id, MusicUtil.note_num_to_freq(60), vel, sample_id)
    sample_status[sample_id] = STATUS.PLAYING
    global_view:add_play_visual()
    screen_dirty = true
    grid_dirty = true
  end
end

local function note_off(sample_id)
  -- print("note_off", sample_id)
  engine.noteOff(sample_id)
  screen_dirty = true
  grid_dirty = true
end

local function clear_queue()
  
  for k, v in pairs(note_queue) do
    if Timber.samples_meta[v.sample_id].playing then
      sample_status[v.sample_id] = STATUS.PLAYING
    else
      sample_status[v.sample_id] = STATUS.STOPPED
    end
  end
  
  note_queue = {}
end

local function queue_note_event(event_type, sample_id, vel)
  
  local quant = options.QUANTIZATION_DIVIDERS[params:get("quantization_" .. sample_id)]
  if params:get("quantization_" .. sample_id) > 1 then
    
    -- Check for already queued
    for i = #note_queue, 1, -1 do
      if note_queue[i].sample_id == sample_id then
        if note_queue[i].event_type ~= event_type then
          table.remove(note_queue, i)
          if Timber.samples_meta[sample_id].playing then
            sample_status[sample_id] = STATUS.PLAYING
          else
            sample_status[sample_id] = STATUS.STOPPED
          end
          grid_dirty = true
        end
        return
      end
    end
    
    if event_type == "on" or sample_status[sample_id] == STATUS.PLAYING then
      if Timber.samples_meta[sample_id].num_frames > 0 then
        local note_event = {
          event_type = event_type,
          sample_id = sample_id,
          vel = vel,
          quant = quant
        }
        table.insert(note_queue, note_event)
        
        if event_type == "on" then
          sample_status[sample_id] = STATUS.STARTING
        else
          sample_status[sample_id] = STATUS.STOPPING
        end
      end
    end
    
  else
    if event_type == "on" then
      note_on(sample_id, vel)
    else
      note_off(sample_id)
    end
  end
  grid_dirty = true
end

local function note_off_all()
  engine.noteOffAll()
  clear_queue()
  screen_dirty = true
  grid_dirty = true
end

local function note_kill_all()
  engine.noteKillAll()
  clear_queue()
  screen_dirty = true
  grid_dirty = true
end

local function set_pressure_voice(voice_id, pressure)
  engine.pressureVoice(voice_id, pressure)
end

local function set_pressure_sample(sample_id, pressure)
  engine.pressureSample(sample_id, pressure)
end

local function set_pressure_all(pressure)
  engine.pressureAll(pressure)
end

local function set_pitch_bend_voice(voice_id, bend_st)
  engine.pitchBendVoice(voice_id, MusicUtil.interval_to_ratio(bend_st))
end

local function set_pitch_bend_sample(sample_id, bend_st)
  engine.pitchBendSample(sample_id, MusicUtil.interval_to_ratio(bend_st))
end

local function set_pitch_bend_all(bend_st)
  engine.pitchBendAll(MusicUtil.interval_to_ratio(bend_st))
end

local function key_down(sample_id, vel)
  
  if pages.index == 2 then
    sample_setup_view:sample_key(sample_id)
  end
  
  if params:get("launch_mode_" .. sample_id) == 1 then
    queue_note_event("on", sample_id, vel)
    
  else
    if (sample_status[sample_id] ~= STATUS.PLAYING and sample_status[sample_id] ~= STATUS.STARTING) or sample_status[sample_id] == STATUS.STOPPING then
      queue_note_event("on", sample_id, vel)
    else
      queue_note_event("off", sample_id)
    end
  end
  
end

local function key_up(sample_id)
  if params:get("launch_mode_" .. sample_id) == 1 and params:get("play_mode_" .. sample_id) ~= 4 then
    queue_note_event("off", sample_id)
  end
end


return d_sample