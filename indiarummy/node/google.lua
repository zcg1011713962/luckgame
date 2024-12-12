local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local snax = require "snax"
local cluster = require "cluster"
local webclient

-- google 支付服务端验证服务

local CMD = {}

function CMD.verify(data, sign, bundleid)
    assert(data)
    assert(sign)
    sign = string.gsub(sign, "+", "_") --先把加号全部换为_

    local API_ONLINE = ""
    if bundleid and PDEFINE.APPS.URLS[bundleid] then
        API_ONLINE = PDEFINE.APPS.URLS[bundleid]['verifypay']
    else
        local ok, paycfg = pcall(cluster.call, "master", ".configmgr", 'get', "payurl_google")
        API_ONLINE  = paycfg.v
    end

    local post = {}
    post["data"] = data
    post["sign"] = sign
    LOG_DEBUG("google post data", post, ' API_ONLINE:', API_ONLINE)
    local data = cjson.encode(post)
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
    local ok, body = skynet.call(webclient, "lua", "request", API_ONLINE, nil, data, false)
    LOG_DEBUG(" pay.ipayVerify CMD.verify google验证结果:", ok, body)
    if not ok then
        assert("Verify token from apple server error!")
    end

    local code = 500
    if body == "succ" then
        code = 200
    end

    return PDEFINE.RET.SUCCESS, code
end


--[[
    去谷歌验证id_token， 验证通过会返回信息
    验证的接口URL:
    https://oauth2.googleapis.com/tokeninfo?id_token=eyJhbGciOiJSUzI1NiIsImtpZCI6Ijc4M2VjMDMxYzU5ZTExZjI1N2QwZWMxNTcxNGVmNjA3Y2U2YTJhNmYiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI2ODczNzc2OTE0NzItaHA4cGNlY3RnY2dxMjM5YTg1MTk5bDdxY2NpaDU5ZnUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI2ODczNzc2OTE0NzItN2FrNGNrcGJtaDZqbDNlcWl1bnJramRiMXZocW9mcWUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDY1ODc0NjQwMDIzMzAyMDI0ODciLCJlbWFpbCI6Imxvbmcuamlhbm1pbi5manV0QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoibG9uZyBNUiIsInBpY3R1cmUiOiJodHRwczovL2xoNC5nb29nbGV1c2VyY29udGVudC5jb20vLXRMbjBMVEduY1c0L0FBQUFBQUFBQUFJL0FBQUFBQUFBQUFBL0FNWnV1Y25uQlk2dFphaXM2M1lrY29Lb1ZBSGtTTVpUZ3cvczk2LWMvcGhvdG8uanBnIiwiZ2l2ZW5fbmFtZSI6ImxvbmciLCJmYW1pbHlfbmFtZSI6Ik1SIiwibG9jYWxlIjoiZW4iLCJpYXQiOjE2MTA2OTkyMTcsImV4cCI6MTYxMDcwMjgxN30.AVuG9iC_bgufevxY0ypLtJETSbjbaV5NKvAhqLohGDeA-9Y6ZXoYy4qZtE8rzxtBXcV8fRFHMb4dYTwEoCDH24lnG6k4NYpwXQ7_dZkUOAssuYBN5ZLQxXhE9YeW6fNl-Ts0tcbg9HOuSjvP6EtC-i_MU36Er78ZTCZNV5ty0zdRgfoVfvx-YAKCQF6Ewt8DURrHRQjmL35GZRU-hcEQXwfKVmCKUWz2B22fTVFCz05GcLdqQwXTfwGAoVNtM_gAxokWgel_ZUaEVRi0YCmu2bVD6hVksKn1ZfOA6PXsL98YKAdXS67lfPg9gyhu3_D23sOl7dyFrRLphxpNGtGA6Q

    接口返回:
    {
      "iss": "https://accounts.google.com",
      "azp": "687377691472-hp8pcectgcgq239a85199l7qccih59fu.apps.googleusercontent.com",
      "aud": "687377691472-7ak4ckpbmh6jl3eqiunrkjdb1vhqofqe.apps.googleusercontent.com",
      "sub": "106587464002330202487",
      "email": "xxxxxx@gmail.com",
      "email_verified": "true",
      "name": "long MR",
      "picture": "https://lh4.googleusercontent.com/-tLn0LTGncW4/AAAAAAAAAAI/AAAAAAAAAAA/AMZuucnnBY6tZais63YkcoKoVAHkSMZTgw/s96-c/photo.jpg",
      "given_name": "long",
      "family_name": "MR",
      "locale": "en",
      "iat": "1610699217",
      "exp": "1610702817",
      "alg": "RS256",
      "kid": "783ec031c59e11f257d0ec15714ef607ce6a2a6f",
      "typ": "JWT"
    }
}
]]
function CMD.verifyAndGetInfo(userid, accesstoken)
    assert(accesstoken)
    if #accesstoken == 0 then
        assert("google verifyAndGetInfo failed because the accesstoken length equre zero!")
    end

    --获取user信息
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
    local ok, body = skynet.call(webclient, "lua", "request", "https://oauth2.googleapis.com/tokeninfo",{id_token=accesstoken}, nil,false)
    if not ok then
        assert("Get userinfo from google error!")
    end
    -- local resp = cjson.decode(body)
    local ok, resp = pcall(jsondecode, body)
    print("google userinfo resp:",resp)

    if resp.email ~= nil then
        assert("get userinfo from google error")
    end

    if resp.email == userid then
        local userinfo = { id = userid, name = resp.name, pic = resp.picture, sex= 0}
        return PDEFINE.RET.SUCCESS, userinfo
    end
    return PDEFINE.RET.FACEBOOK_AUTH_FAILD, nil
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(session, address, cmd, ...)
                local f = CMD[cmd]
                skynet.retpack(f(...))
            end
        )
        skynet.register(".google")
    end
)
