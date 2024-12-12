# -*- coding: UTF-8 -*-
import os
import sys
import shutil
from os.path import join, getsize

CUR_DIR = os.getcwd()
dirs = os.walk(CUR_DIR)

ignore_paths = ['.git', '.vscode']

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("exec: python3 compile_lua.py src_path dest_path")
        exit(1)
    # 传入的路径参数，可为相对路径
    src_path = sys.argv[1]
    dest_path = sys.argv[2]
    # 相对路径转成绝对路径
    src_path = os.path.realpath(src_path)
    dest_path = os.path.realpath(dest_path)
    # 确定路径，开始编译
    print("src path: ", src_path)
    print("dest path: ", dest_path)
    print("start compile...")
    for root, dirs, files in os.walk(src_path):
        skip = False
        for ignore_path in ignore_paths:
            if root.find(ignore_path) != -1:
                skip = True
                break
        # 跳过git目录
        if skip:
            continue
        # 创建目录
        for d in dirs:
            src_dir_path = os.path.join(root, d)
            dest_dir_path = src_dir_path.replace(src_path, dest_path)
            print("mkdir", dest_dir_path)
            os.makedirs(dest_dir_path)
        # 编译文件, 拷贝文件
        for f in files:
            if f.endswith('.git'):
                continue
            src_file = os.path.join(root, f)
            dest_file = src_file.replace(src_path, dest_path)
            if f.endswith('.lua'):
                cmd = "luac -o " + dest_file + " " + src_file
                print("compile file", src_file, "-->", dest_file)
                os.system(cmd)
            else:
                print("copy file", src_file, "-->", dest_file)
                shutil.copyfile(src_file, dest_file)