
local skynet    = require "skynet"

local AUTO_OUTTIME = 20

return function(user, send_msg, deskobj)
    
    local origin_send = user.send

    local function out_cards()
        local card = user.info.hand[#user.info.hand]
        -- assert(card)
        if not card then
            LOG_WARNING("card is nil ", user)
            return
        end
        if user.is_auto and user.info.can_out then
            local req = {
                c = 228,
                card = card,
                uid = user.uid,
                is_auto = true,
            }
            send_msg(req, user)
        end
    end
    
    local function select_action()
        local huaction = user.info.select_action.hu
        local req = {
            c = 229,
            uid = user.uid,
            is_auto = true,
            select_type = 'guo', -- 直接过
        }
        if huaction then
            req.select_type = 'hu'
            send_msg(req, user)
        else
            if next(user.info.select_action) then
                send_msg(req, user)
            end
        end
    end
    
    -- 收到信息
    local function recv_nextrurn(data)
        if data.uid  == user.uid then
            out_cards()
        end
    end

    local function recv_select()
        select_action()
    end
    
    local CMD = {
        [PDEFINE.NOTIFY.MLMJ_NEXT_TURN] = recv_nextrurn,
        [PDEFINE.NOTIFY.MLMJ_SELECT_ACTION] = recv_select,
    }
    
    function user.change_auto(is_auto)
        if not is_auto then
            user:stop_action('AUTO')
        end
        if is_auto ~= user.is_auto then
            user.is_auto = is_auto
            local _, idx = deskobj.select_userinfo(user.uid)
            user.is_auto = is_auto
            local retobj = {
                c = PDEFINE.NOTIFY.MLMJ_AUTO,
                uid = user.uid,
                is_auto = is_auto,
            }
            deskobj:broadcastdesk(retobj)
        end
    end

    local function recv_msg(data)
        local c = data.c
        local f = CMD[data.c]
        if not f then
            return
        end
        if not data.uid or data.uid == user.uid then
            user:stop_action('AUTO')
            user.auto_fun = function()
                f(data)
            end
            if user.is_auto then
                user:auto_action('AUTO', 2, function()
                    local fun = user.auto_fun
                    user.auto_fun = nil
                    user.change_auto(true)
                    if fun then fun() end
                end)
            else
                user:auto_action('AUTO', AUTO_OUTTIME, function()
                    user.change_auto(true)
                    local fun = user.auto_fun
                    user.auto_fun = nil
                    if fun then fun() end
                end)
            end
        end
    end

    function user:send(data)
        origin_send(user, data)
        recv_msg(data)
    end

end

