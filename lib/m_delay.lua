-- half sec loop 75% decay

local m_delay = {}

-- starting place on buffer for delay. the rest is for tape.
BUFFER_START = 322  

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_delay.build_params()
  params:add_group("halfsecond",4)

  params:add{id="tape_delay", name="tape delay",
		type="control", 
    controlspec=controlspec.new(0,1,'lin',0,0.5,""),
    action=function(x) softcut.level(1,x) end}

  params:add{id="tape_delay_rate", name="tape delay rate",
		type="control", 
    controlspec=controlspec.new(0.5,2.0,'lin',0,1,""),
    action=function(x) softcut.rate(1,x) end}

  params:add{id="tape_delay_feedback", name="tape delay feedback", 
		type="control", 
    controlspec=controlspec.new(0,1.0,'lin',0,0.75,""),
    action=function(x) softcut.pre_level(1,x) end}

end

function m_delay.init()


  softcut.level(1,1.0)
  softcut.level_slew_time(1,0.25)
	-- softcut.level_input_cut(1, 1, 1.0)
	-- softcut.level_input_cut(2, 1, 1.0)
	softcut.pan(1, 0.0)

  softcut.play(1, 1)
	softcut.rate(1, 1)
  softcut.rate_slew_time(1,0.25)
	softcut.loop_start(1, 1)
	softcut.loop_end(1, 1.5)
	softcut.loop(1, 1)
	softcut.fade_time(1, 0.1)
	softcut.rec(1, 1)
	softcut.rec_level(1, 1)
	softcut.pre_level(1, 0.75)
	softcut.position(1, 1)
	softcut.enable(1, 1)

	softcut.filter_dry(1, 0.125);
	softcut.filter_fc(1, 1200);
	softcut.filter_lp(1, 0);
	softcut.filter_bp(1, 1.0);
	softcut.filter_rq(1, 2.0);
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------


return m_delay