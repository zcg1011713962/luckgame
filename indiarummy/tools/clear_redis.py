import sys, redis

if len(sys.argv) < 4:
    print "param less than 4"
else:
    dbhost = sys.argv[1]
    dbindex = int(sys.argv[2])
    dbpwd = sys.argv[3]

    def clear_db_port(db_port):
        rc = redis.Redis(host=dbhost, port=db_port, db=dbindex, password=dbpwd)
        print "clear redis %d: %s" % (db_port, rc.flushdb())

    for i in range(4, len(sys.argv)):
        clear_db_port(int(sys.argv[i]))
