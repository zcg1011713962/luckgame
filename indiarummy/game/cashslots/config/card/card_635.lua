-- 635
local cardMap = {
    ["base"] = {
        [1]= {min=3, mult = {[3] =4000,[4] =20000,[5] =50000}, double = {}, comment = "Wild"},
        [2]= {min=3, mult = {[3] =4000,[4] =20000,[5] =50000}, double = {}, comment = "红龙"},
        [3]= {min=3, mult = {[3] =2000,[4] =10000,[5] =30000}, double = {}, comment = "粉龙"},
        [4]= {min=3, mult = {[3] =2000,[4] =10000,[5] =30000}, double = {}, comment = "紫龙"},
        [5]= {min=3, mult = {[3] =2000,[4] =10000,[5] =30000}, double = {}, comment = "蓝龙"},
        [6]= {min=3, mult = {[3] =2000,[4] =10000,[5] =30000}, double = {}, comment = "绿龙"},
        [7]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "A"},
        [8]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "K"},
        [9]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "Q"},
        [10]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "J"},
        [11]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "Scatter"},
        [12]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "龙珠"},
        [13]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "SpinFree+1"},
        [14]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "Multipler"}
    },
    ["free"] = {
        [1]= {min=3, mult = {[3] =2000,[4] =10000,[5] =25000}, double = {}, comment = "Wild"},
        [2]= {min=3, mult = {[3] =2000,[4] =10000,[5] =25000}, double = {}, comment = "红龙"},
        [3]= {min=3, mult = {[3] =1000,[4] =5000,[5] =15000}, double = {}, comment = "粉龙"},
        [4]= {min=3, mult = {[3] =1000,[4] =5000,[5] =15000}, double = {}, comment = "紫龙"},
        [5]= {min=3, mult = {[3] =1000,[4] =5000,[5] =15000}, double = {}, comment = "蓝龙"},
        [6]= {min=3, mult = {[3] =1000,[4] =5000,[5] =15000}, double = {}, comment = "绿龙"},
        [7]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "A"},
        [8]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "K"},
        [9]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "Q"},
        [10]= {min=3, mult = {[3] =1000,[4] =3000,[5] =10000}, double = {}, comment = "J"},
        [11]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "Scatter"},
        [12]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "龙珠"},
        [13]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "SpinFree+1"},
        [14]= {min=1000, mult = {[3] =0,[4] =0,[5] =0}, double = {}, comment = "Multipler"}
    },
}
return cardMap
