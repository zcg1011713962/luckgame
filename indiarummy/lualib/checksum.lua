
local function byte2short(b1, b2)
    return b1*256 + b2
end

local function byte2int(b1, b2, b3, b4)
    return b1*256*256*256 + b2*256*256 + b3*256 + b4
end

local function number2short(value)
    local b1 = value >> 8
    local b2 = value & (0xFF)
    return byte2short(b1, b2)
end

local function genSum(data, size)
    local sum = 65535
    for i = 1, size do
        local byte = string.byte(data, i)
        sum = sum ~ byte
        if sum & 1 == 0 then
            sum = (sum >> 1)
        else
            sum = (sum >> 1) ~ (0x70B1)
        end
    end
    return number2short(sum)
end

local function check(head, body)
    local size = byte2short(string.byte(head, 1), string.byte(head, 2))
    local checksum = byte2short(string.byte(head, 3), string.byte(head, 4))
    local time = byte2int(string.byte(head, 5), string.byte(head, 6), string.byte(head, 7), string.byte(head, 8))
    local crc = genSum(body, math.min(size, 128))
    if checksum ~= crc then
        LOG_DEBUG("checkCrc", "size", size, "checksum", checksum, "time", time, "crc", crc)
    end
    return checksum == crc
end

return {
    check = check
}