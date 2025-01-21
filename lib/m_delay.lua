-- softcut delay for tape
-- **USES VOICES 5 AND 6**

local m_delay = {}

-- starting place on buffer for delay. the rest is for tape.
BUFFER_SPLIT = 322

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_delay.build_params()
  params:add_separator("Delay")

	params:add_group("Tape Delay", 5)
  params:add{id="tape_delay_level", name="tape delay level",
		type="control", 
    controlspec=controlspec.new(0,1,'lin',0,0.5,""),
    action=function(x) 
			softcut.level(5, x) 
			softcut.level(6, x)
			end}

	params:add{id="tape_delay_time_l", name="tape delay time (L)",
		type="control", 
    controlspec=controlspec.new(0.1, 10, 'lin', 0, 0.5, "s"),
    action=function(x) softcut.loop_end(5, BUFFER_SPLIT + x) end}

	params:add{id="tape_delay_time_r", name="tape delay time (R)",
		type="control", 
    controlspec=controlspec.new(0.1, 10, 'lin', 0, 0.5, "s"),
    action=function(x) softcut.loop_end(6, BUFFER_SPLIT + x) end}

  params:add{id="tape_delay_feedback_l", name="tape delay feedback (L)", 
		type="control", 
    controlspec=controlspec.new(0,1.0,'lin',0,0.5,""),
    action=function(x) softcut.pre_level(5, x) end}

	params:add{id="tape_delay_feedback_r", name="tape delay feedback (R)", 
		type="control", 
    controlspec=controlspec.new(0,1.0,'lin',0,0.5,""),
    action=function(x) softcut.pre_level(6, x) end}

end

function m_delay.init()

	for v=5,6 do
		ch = (v + 1) % 2 + 1

		softcut.enable(v, 1)
		softcut.buffer(v, ch)
		softcut.level_input_cut(ch, v, 1)
		softcut.level(v, 1.0)
		softcut.level_slew_time(v, 0.1)
		softcut.pan(v, v == 5 and -1 or 1)

		softcut.rate(v, 1)
		softcut.loop_start(v, BUFFER_SPLIT)
		softcut.loop_end(v, BUFFER_SPLIT + 0.5)
		softcut.loop(v, 1)
		softcut.position(v, BUFFER_SPLIT)
		softcut.fade_time(v, 0.1)
		softcut.rec_level(v, 1)
		softcut.pre_level(v, 0.5)
		softcut.play(v, 1)
		softcut.rec(v, 1)
	
	end
	
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------


return m_delay