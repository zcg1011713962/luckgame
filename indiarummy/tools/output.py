
# coding: utf-8

from redisQueue import RedisQueue
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import json
import sys

# debug<info<warn<Error<Fatal;
# 0 < 1 < 2 < 3 < 4

logging.basicConfig(level=logging.DEBUG)

loggernodemap = {}

def getLogger(nodename):
	global loggernodemap
	if loggernodemap.has_key(nodename) == False:
		logFilePath = nodename + ".log"
		print logFilePath
		logger = logging.getLogger(nodename)
		handler = TimedRotatingFileHandler(logFilePath, when = 'midnight', interval = 1, backupCount=7)
		handler.setFormatter(logging.Formatter('[%(asctime)s- %(levelname)s-%(message)s]'))
		logger.addHandler(handler)
		loggernodemap[nodename] = logger
	return loggernodemap[nodename]

def loggerout(lev, logger, msg):
	# print lev, msg
	if lev == 1:
		logger.info(msg)
	elif lev == 2:
		logger.warn(msg)
	elif lev == 3:
		logger.error(msg)
	elif lev == 4:
		logger.critical(msg)
	else:
		logger.debug(msg)

def main(**redis_kwargs):
	q = RedisQueue('log', **redis_kwargs)
	while 1:
	    result = None
	    try:
	    	result = q.get_wait()
	    except Exception as e:
	    	# redis raise exception ?
	    	print "redis exception !!! ",e
	    	time.sleep(1)
	    try:
			msg = json.loads(result[1])
			lev = msg["lev"]
			mod = msg["mod"]
			print lev, mod
			logger = getLogger(mod)
			loggerout(lev, logger, msg['msg'])
	    except BaseException as e:
	    	print 'except', e

if __name__ == '__main__':
	if not len(sys.argv) == 5:
		print "error input argvs !! "
		print "demo: python output.py 127.0.0.1 6379 13 password"
	else:
		host = sys.argv[1]
		port = sys.argv[2]
		db = sys.argv[3]
		password = sys.argv[4]
		main(host=host, port=port, db=db, password=password)
