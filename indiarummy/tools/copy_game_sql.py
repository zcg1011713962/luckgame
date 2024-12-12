# coding: utf-8
from shutil import copyfile
import os

gameId = ""
gameName = ""
gameFullName = ""
gameStr = ""
prevGame = ""


sql_str = """
-- {gameId} {gameName} {gameFullName}
INSERT INTO `s_sess` (gameid, title, basecoin, mincoin, leftcoin, hot, status, ord, free,level, param1, param2, param3,  param4,  revenue, seat )
SELECT 
    {gameId}, "{gameName}", basecoin, mincoin, leftcoin, hot, status, ord, free,level, param1, param2, param3,  param4,  revenue, seat
FROM 
    `s_sess`
WHERE 
    gameid = {prevGame}
LIMIT 1;

INSERT INTO `s_game` (id, title,allincontrol, ratefree, ratesub, jackpot, jp_unlock_lv)
SELECT
    {gameId}, "{gameStr}", allincontrol, ratefree, ratesub, jackpot, jp_unlock_lv
FROM
    `s_game`
WHERE
    id = {prevGame};
LIMIT 1;

INSERT INTO `s_game_type` (gametype, gameid, title, state, hot)
SELECT
    gametype, {gameId}, "{gameName}", state, hot
FROM
    `s_game_type`
WHERE
    gameid = {prevGame}
LIMIT 1;
"""

copyGameInfo = [
    {'prevGame': 491, 'gameId': 647, 'gameStr': 'DemeterGooddes', 'gameName': '德墨忒尔', 'gameFullName': "Demeter-Gooddes of fertility  "},
    {'prevGame': 456, 'gameId': 648, 'gameStr': 'Hermes', 'gameName': '赫尔墨斯', 'gameFullName': "Hermes-The Shepherd God"},
    {'prevGame': 509, 'gameId': 649, 'gameStr': 'Odysseus', 'gameName': '奥德修斯', 'gameFullName': "The wise and brave Odysseus"},
    {'prevGame': 508, 'gameId': 650, 'gameStr': 'Prometheus', 'gameName': '普罗米修斯', 'gameFullName': "Prometheus-The god of SelflessForesight"},
    {'prevGame': 501, 'gameId': 651, 'gameStr': 'Perseus', 'gameName': '帕修斯', 'gameFullName': "Perseus' Battlefield"},
    {'prevGame': 494, 'gameId': 652, 'gameStr': 'Sphinx', 'gameName': '狮身人面像', 'gameFullName': "Sphinx"},
    {'prevGame': 426, 'gameId': 653, 'gameStr': 'EemperorDevil', 'gameName': '曹操', 'gameFullName': "Eemperor devil"},
    {'prevGame': 502, 'gameId': 654, 'gameStr': 'MonkeyKing', 'gameName': '齐天大圣孙悟空', 'gameFullName': "monkey king"},
    {'prevGame': 499, 'gameId': 655, 'gameStr': 'Anaconda', 'gameName': '巨人族约尔孟甘德', 'gameFullName': "Huge Anaconda"},
    {'prevGame': 498, 'gameId': 656, 'gameStr': 'BirdWithNineHeads', 'gameName': '九头鸟', 'gameFullName': "Bird with Nine Heads"},
    {'prevGame': 487, 'gameId': 657, 'gameStr': 'MagicFrog', 'gameName': '魔法青蛙', 'gameFullName': "Magic Frog"},
    {'prevGame': 488, 'gameId': 658, 'gameStr': 'DwarfsAndPrincess', 'gameName': '矮人与公主', 'gameFullName': "Dwarfs and Princess"},
    {'prevGame': 448, 'gameId': 659, 'gameStr': 'LuckySanta', 'gameName': '幸运圣诞老人', 'gameFullName': "Lucky Santa"},
    {'prevGame': 505, 'gameId': 660, 'gameStr': 'ThePhoenix', 'gameName': '凤凰', 'gameFullName': "The Phoenix"},
    {'prevGame': 511, 'gameId': 661, 'gameStr': 'RobinHood', 'gameName': '侠盗罗宾逊', 'gameFullName': "Robin Hood"},
    {'prevGame': 497, 'gameId': 662, 'gameStr': 'BunnyGirl', 'gameName': '兔女郎', 'gameFullName': "Bunny Girl"},
    {'prevGame': 493, 'gameId': 663, 'gameStr': 'GoldMiner', 'gameName': '黄金矿工', 'gameFullName': "Gold Miner"},
    {'prevGame': 484, 'gameId': 664, 'gameStr': 'FatherOfInvention', 'gameName': '发明之父', 'gameFullName': "Father of Invention"},
    {'prevGame': 495, 'gameId': 665, 'gameStr': 'WestCowboy', 'gameName': '西部牛仔', 'gameFullName': "West Cowboy"},
    {'prevGame': 500, 'gameId': 666, 'gameStr': 'RisingSun', 'gameName': '德川家康', 'gameFullName': "Rising Sun The Great King"},
    {'prevGame': 507, 'gameId': 667, 'gameStr': 'PoliticalStrategist', 'gameName': '丰臣秀吉', 'gameFullName': "Political Strategist"},
    {'prevGame': 490, 'gameId': 668, 'gameStr': 'Mulan', 'gameName': '花木兰', 'gameFullName': "Mulan"},
    {'prevGame': 492, 'gameId': 669, 'gameStr': 'GenghisKhan', 'gameName': '成吉思汗', 'gameFullName': "Genghis Khan"},
]

for gameInfo in copyGameInfo:
    # 打印sql语句
    # print(sql_str.format(gameId=gameInfo["gameId"], gameStr=gameInfo["gameStr"], prevGame=gameInfo["prevGame"], gameFullName=gameInfo["gameFullName"], gameName=gameInfo["gameName"]))
    # 拷贝slot文件
    fatherPath = os.path.abspath(os.path.dirname(os.getcwd()))
    prevGame = gameInfo["prevGame"]
    gameId = gameInfo["gameId"]
    srcRtpFileName = os.path.join(fatherPath, "game", "cashslots", "rtp", f"rtp_{prevGame}.lua")
    destRtpFileName = os.path.join(fatherPath, "game", "cashslots", "rtp", f"rtp_{gameId}.lua")
    srcGameFileName = os.path.join(fatherPath, "game", "cashslots", "slots", f"slot_{prevGame}.lua")
    destGameFileName = os.path.join(fatherPath, "game", "cashslots", "slots", f"slot_{gameId}.lua")
    if os.path.exists(srcRtpFileName) and not os.path.exists(destRtpFileName):
        copyfile(srcRtpFileName, destRtpFileName)
    if os.path.exists(srcGameFileName) and not os.path.exists(destGameFileName):
        copyfile(srcGameFileName, destGameFileName)
    # 拷贝rtp文件

# python3 copy_game_sql.py > table_alter_20210615_copyGame.sql

