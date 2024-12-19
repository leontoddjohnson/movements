-- tape

-- softcut buffer length = 5 minutes 49.52 seconds
-- first 20 for delay, start at 30 for the rest.

local m_tape = {}

-- {start, stop} for each partion. use [partition][row][col].
-- (samples use `banks`)
partitions = {
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}}
}

PARTITION = 1  -- currently selected record partition
SLICE = nil  -- currently selected slice

-----------------------------------------------------------------
-- BUILD PARAMETERS
-----------------------------------------------------------------


-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

-- TODO : instead of sample_ids, use {start_time, stop_time}


return m_tape

