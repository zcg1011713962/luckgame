import sys, MySQLdb

# ***/python ***/event.py xhw_ninja refreshShop 1 1 0 0
if len(sys.argv) > 8:
    print "param more than 8"
else:
    dbname = sys.argv[1]
    event = sys.argv[2]
    param1 = "0"
    param2 = "0"
    param3 = "0"
    param4 = "0"
    param5 = "0"
    if len(sys.argv) >= 4:
        param1 = sys.argv[3]
    if len(sys.argv) >= 5:
        param2 = sys.argv[4]
    if len(sys.argv) >= 6:
        param3 = sys.argv[5]
    if len(sys.argv) >= 7:
        param4 = sys.argv[6]
    if len(sys.argv) >= 8:
        param5 = sys.argv[7]

    try:
        conn = MySQLdb.connect(host="192.168.0.150",user="root",passwd="123456",port=3306,charset='utf8')
        cur = conn.cursor()

        conn.select_db(dbname)
        value=[event,param1,param2,param3,param4,param5]
        cur.execute('insert into d_schedule_event(`event`,`param1`,`param2`,`param3`,`param4`,`param5`,`inputTime`) values(%s,%s,%s,%s,%s,%s,unix_timestamp())',value)
        conn.commit()
        cur.close()
        conn.close()

    except MySQLdb.Error,e:
         print "Mysql Error %d: %s" % (e.args[0], e.args[1])
