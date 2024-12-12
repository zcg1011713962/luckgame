#!/bin/bash
#项目目录
PROJECT_PATH=$(cd "$(dirname "$0")"; pwd)

echo 'run: game_master ./etc/config.ai pid: 22317'
ps -ef |grep game_master | grep config.ai | awk {'print$2'} | xargs kill -9
#kill -9 22317

echo 'run: game_master ./etc/config.api pid: 22293'
#kill -9 22293
ps -ef |grep game_master | grep config.api | awk {'print$2'} | xargs kill -9

echo 'run: game_master ./etc/config.game pid: 22341'
#kill -9 22341
ps -ef |grep game_master | grep config.game | awk {'print$2'} | xargs kill -9

echo 'run: game_login ./etc/wsconfig.login pid: 22365'
#kill -9 22365
ps -ef |grep game_login | grep wsconfig.login | awk {'print$2'} | xargs kill -9

echo 'run: game_master ./etc/config.master pid: 22268'
#kill -9 22268
ps -ef |grep game_master | grep config.master | awk {'print$2'} | xargs kill -9

echo 'run: game_node ./etc/wsconfig.node pid: 22390'
#kill -9 22390
ps -ef |grep game_node | grep wsconfig.node | awk {'print$2'} | xargs kill -9
