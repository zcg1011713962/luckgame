


-- 统一调度每一个座子的调度

local desk_aimgr_map = {}

local function register_desk(deskid, desk_control)
    desk_aimgr_map[deskid] = desk_control
end

return {
    register_desk = register_desk,
}





