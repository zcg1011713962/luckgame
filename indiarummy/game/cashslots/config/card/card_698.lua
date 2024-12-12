-- 630
local cardMap = {
    [1]= {min=3, mult = {[3] =7500,[4] =20000,[5] =40000}, double = {}, comment = "中东男"},
    [2]= {min=3, mult = {[3] =5000,[4] =15000,[5] =30000}, double = {}, comment = "中东女"},
    [3]= {min=3, mult = {[3] =5000,[4] =10000,[5] =20000}, double = {}, comment = "卡通马"},
    [4]= {min=3, mult = {[3] =3000,[4] =7500,[5] =15000}, double = {minCnt = 3, value = 2}, comment = "卡通鸡"},
    [5]= {min=3, mult = {[3] =2000,[4] =5000,[5] =7500}, double = {minCnt = 3, value = 2}, comment = "卷轴"},
    [6]= {min=3, mult = {[3] =2500,[4] =5000,[5] =7500}, double = {minCnt = 3, value = 2}, comment = "羽毛宝石"},
    [7]= {min=3, mult = {[3] =1250,[4] =3750,[5] =5000}, double = {minCnt = 3, value = 2}, comment = "小刀"},
    [8]= {min=3, mult = {[3] =1250,[4] =2500,[5] =3000}, double = {minCnt = 3, value = 2}, comment = "绿色头冠"},
    [9]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {minCnt = 3, value = 2}, comment = "scatter茶壶"},
    [10]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {minCnt = 3, value = 2}, comment = "大胡子精灵"},
}
return cardMap
