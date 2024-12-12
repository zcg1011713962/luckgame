#!/usr/bin/python3
from openpyxl import load_workbook
import sys
import re

def convert(filename):
    wb = load_workbook(filename = filename)
    pattern = re.compile(r'(\d+)')
    maintaskFile = open('maintaskCfg.lua', 'w')
    fieldName = []
    # 读取字段名称
    for idx, row in enumerate(wb.active.rows):
        item = "{"
        isRewards = False  # 判断是否是奖励字段
        for col, cell in enumerate(row):
            if idx == 0:
                fieldName.append(cell.value)
            else:
                if cell.value == None:
                    continue
                if col != 0:
                    item += ", "
                field = fieldName[col]
                if field == 'type' or field == 'count':
                    if not isRewards:
                        isRewards = True
                        item += "rewards={"
                    if field == 'type':
                        item += "{"
                else:
                    if isRewards:
                        item += "}, "
                        isRewards = False
                item += fieldName[col]
                item += "="
                if type(cell.value) == int:
                    item += str(cell.value)
                elif cell.value == '金币':
                    item += 'PROP_ID.COIN'
                elif cell.value == '钻石':
                    item += 'PROP_ID.DIAMOND'
                else:
                    item += '"'+cell.value+'"'
                if field == 'count':
                    item += "}"
                if fieldName[col] == 'desc':
                    result = pattern.findall(cell.value)
                    item += ", params={"
                    for k,v in enumerate(result):
                        if k != 0:
                            item += ","
                        item += str(v)
                    item += "}"
        if isRewards:
            item += "}},"
        else:
            item += "},"
        if idx > 0:
            maintaskFile.write(item)
            maintaskFile.write('\n')
    maintaskFile.close()

if __name__ == "__main__":
    if len(sys.argv) == 1:
        print("请选择需要转换的xlsx.")
    else:
        filename = sys.argv[1]
        convert(filename)