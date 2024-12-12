#-*- coding:utf-8 -*-
import sys, xlrd
if len(sys.argv) < 1:
    print("param less than 1. Usage: python3 jackpot_reset.py xxxx.xlsx")
    sys.exit(1)

xlsxFile = sys.argv[1]
data_excel=xlrd.open_workbook(xlsxFile)
table=data_excel.sheets()[0]
n_rows=table.nrows #第1个sheet中的行数
for i in range(n_rows):
    row_data=table.row_values(i,start_colx=0,end_colx=None) #第1行的所有数据列表
    gameid = int(row_data[0])
    jackpot = row_data[1]
    jp_unlock_lv = row_data[2]
    print('update s_game set jackpot="{0}", jp_unlock_lv="{1}" where id={2};'.format(jackpot,jp_unlock_lv,gameid))