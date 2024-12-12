local settle = {}

function settle.addWinlist(uid, coin, free)
	uid = math.floor(uid)
	if free == 0 then
	    local date=os.date("%Y-%m-%d");
	    local rank = do_redis({ "zrank", "winlist:"..date, uid}, nil)
	    if rank then
	        do_redis({ "zincrby", "winlist:"..date , coin, uid}, nil)
	    else
	        do_redis({ "zadd", "winlist:"..date , coin, uid}, nil)
	    end
	end
end

return settle