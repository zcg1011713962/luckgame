# coding: utf-8
import redis

class RedisQueue(object):

    def __init__(self, name, **redis_kwargs):

        check_params = redis_kwargs.has_key('host') and redis_kwargs.has_key('port') and redis_kwargs.has_key('db') and redis_kwargs.has_key('password')

        if not check_params:
            print "invalid params for redis connect !!!!!"

        host = redis_kwargs['host']
        port = redis_kwargs['port']
        db = redis_kwargs['db']
        password = redis_kwargs['password']

        print 'host', host, 'port', port, 'db', db, 'password', password

        self.__db= redis.Redis(host=host, port=port, db=db, password=password)
        self.key = 'queue:%s' %(name)

    def qsize(self):
        return self.__db.llen(self.key)

    # def put(self, item):
    #     self.__db.rpush(self.key, item)

    def get_wait(self, timeout=None):
        item = self.__db.blpop(self.key, timeout=timeout)
        return item

    # def get_nowait(self):
    #     item = self.__db.lpop(self.key)  
    #     return item

    def is_connect(self):
        # how to check python and redis is 
        return True