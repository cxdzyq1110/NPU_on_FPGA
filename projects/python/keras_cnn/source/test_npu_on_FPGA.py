# -*- coding: utf-8 -*-
"""
Created on Tue Jun  5 20:11:29 2018

@author: xdche
"""

import numpy as np
import scipy.fftpack
import sys
sys.path.append("../../serial")
import sample
import matplotlib.pyplot as plt
import os
import time
#############################################
# 这是测试NPU硬件化的直接途径，直接串口配置SRAM的CNN参数/输入，发送NPU指令，启动运算，读取运算结果
############
#%% 首先测试SRAM读写正确性
sample.exec_cmd("random_wr 1000")
#%% 发射指令
print("---------- * * * ----------")
print("sending NPU instructions ", end="")
dir_path = "../isa-npu"
# 复位NPU指令
lines = "00000000000000000000000000000001"
sample.exec_cmd("inst "+lines[0:8])
sample.exec_cmd("inst "+lines[8:16])
sample.exec_cmd("inst "+lines[16:24])
sample.exec_cmd("inst "+lines[24:32])
# 闲置20ms
time.sleep(0.1)
# 首先读取NPU的指令
fp = open(dir_path+"/inst.txt", "r")
cnt = 1
for lines in fp:
    if "@" in lines:
        print(lines)
    else:
        # 发送指令
        sample.exec_cmd("inst "+lines[0:8])
        sample.exec_cmd("inst "+lines[8:16])
        sample.exec_cmd("inst "+lines[16:24])
        sample.exec_cmd("inst "+lines[24:32])
        # 闲置20ms
        time.sleep(0.1)
        #####
        if cnt%10==0:
            print(".", end="")
        cnt = cnt + 1
    
# 发送NPU空指令
lines = "00000000000000000000000000000000"
sample.exec_cmd("inst "+lines[0:8])
sample.exec_cmd("inst "+lines[8:16])
sample.exec_cmd("inst "+lines[16:24])
sample.exec_cmd("inst "+lines[24:32])
# 闲置20ms
time.sleep(0.02)
print(" Done!")
fp.close()
#%% 配置CNN参数
print("---------- * * * ----------")
print("configure CNN parameters ", end="")
dir_path = "../isa-npu"
fp = open(dir_path+"/para.txt", "r")
cnt = 1
for lines in fp:
    if "@" in lines:
        # 解析地址
        addr = int(lines[1:], 16)
    else:
        # 获取数据
        data = int(lines, 16)
        cmd = "swrite %X %X"%(addr, data)
        #print(cmd)
        addr = addr + 1
        sample.exec_cmd(cmd)
        ####
        if cnt%200==0:
            print(".", end="")
        cnt = cnt + 1

print(" Done!")
fp.close()
#%% 串口配置MFCC特征
dir_path = "../isa-npu/sim_source_fpga"
files = os.listdir(dir_path)
right_cnt = 0
for idx in range(0, len(files)):
    print("---------- * * * ----------")
    print("sample: "+files[idx]+" ", end="")
    print("\nsending CNN input image ", end="")
    cnt = 1
    fp = open(dir_path+"/"+files[idx], "r")
    for lines in fp:
        if "@" in lines:
            # 解析地址
            addr = int(lines[1:], 16)
        else:
            # 获取数据
            data = int(lines, 16)
            cmd = "swrite %X %X"%(addr, data)
            #print(cmd)
            addr = addr + 1
            sample.exec_cmd(cmd)
            ####
            if cnt%100==0:
                print(".", end="")
            cnt = cnt + 1
    
    print(" Done!")
    fp.close()
    # 发送NPU计算指令
    lines = "00000000000000000000000000000002"
    # 启动NPU计算
    sample.exec_cmd("inst "+lines[0:8])
    sample.exec_cmd("inst "+lines[8:16])
    sample.exec_cmd("inst "+lines[16:24])
    sample.exec_cmd("inst "+lines[24:32])
    # 闲置20ms
    time.sleep(0.02)
    # 闲置一会儿读取CNN运算结果
    time.sleep(1)
    result = np.zeros((10))
    for i in range(0, 10):
        addr = 0x00018000 + i
        cmd = "sread %X"%(addr)
        result[i] = sample.exec_cmd(cmd)
    result[result>=0x80000000] = result[result>=0x80000000]-0x100000000
    result = result/65536
    # 然后要和python的结果比较，计算绝对误差
    p_fp_name = "../isa-npu/ver_compare"+"/"+files[idx][:-5]+"-result.txt"
    #print(p_fp_name)
    fp = open(p_fp_name, "r")
    line = fp.readline().split(",")
    p_res = np.zeros(result.shape)
    for k in range(result.shape[0]):
        p_res[k] = float(line[k])
    print("compare fpga and python result ... ", end="")
    max_abs_error = np.max(np.absolute(result-p_res))
    print("MAE = %f "%(max_abs_error), end="")
    if max_abs_error<1e-2:
        print("PASS!")
        right_cnt = right_cnt + 1
    else:
        print("FAIL!")

# 汇总
print("--------- * * * ------------")
print("TEST on FPGA finished, correct / total = %d / %d"%(right_cnt, len(files)))