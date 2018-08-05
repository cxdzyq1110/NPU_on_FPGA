# -*- coding:utf-8 -*-
#####################################

import generate_cnn_layers as gen_cnn
import os
import subprocess
import numpy as np
from load_our_samples import *
import numpy as np
###############################################
# 要产生NPU指令
PARA_BIAS = 0x00040000>>2    # 参数的偏移量, 0.25 MB
DIST_BIAS = 0x00060000>>2    # 输出数据，0.375MB
DATA_BIAS = 0x00080000>>2    # 中间运算数据缓存的偏移量, 0.5MB
SORC_BIAS_0 = 0x00100000>>2    # 输入的数据#0，1.0MB
SORC_BIAS_1 = 0x00180000>>2    # 输入数据#1，1.5MB
####
MAT_WIDTH = 0x00004000>>2    # 每个矩阵的大小（16KB）
import generate_npu_inst
#########################################
#%% 生成比对测试文件
from scipy import signal
def generate_test_file(image, H, filename):
    fp = open(filename, "w")
    # 构造NPU指令
    # 卷积核
    Km = 3; Kn = 3; Pm = 2; Pn = 2;
    # 对于卷积层，l-层-m-输入-n-输出，参数所在的位置是 ()
    for layer in range(0, len(H)):
        fp.write("\n")
        if H[layer][0]=='I':
            # 初始化每一层的输入通道数量
            input_num = H[layer][3]
            input_size = [H[layer][1], H[layer][2]]
            # 输入图像
            input_img = [image[:, :, i] for i in range(0, H[layer][3])]
        # 卷积层
        elif H[layer][0]=='C':
            input_img_tmp = []
            # 首先计算每个input_map和conv_kernel的卷积结果
            for n in range(0, H[layer][3]):
                # 计算每个输入和对应核的卷积，存储到数据缓存空间
                conv_m_n = []
                for m in range(0, input_num):
                    # 对于每个input_map进行计算
                    name = "conv-kernel-L%d-I%d-O%d"%(layer, m, n)
                    kernel_m_n = np.loadtxt("../para/"+name+".csv", delimiter=",")
                    # print(kernel_m_n)
                    conv_res_m_n = signal.convolve2d(input_img[m], kernel_m_n, 'valid')
                    #print(conv_res_m_n.shape)
                    # 输出运算结果
                    for i in range(conv_res_m_n.shape[0]):
                        for j in range(conv_res_m_n.shape[1]):
                            fp.write("%d\n"%(int(conv_res_m_n[i][j]*2**16)))
                    ##
                    conv_m_n.append(conv_res_m_n)
                    
                # 对于数据缓存空间中（m个）卷积结果进行累加，缓存
                # print(conv_m_n[0].shape)
                sum_conv_m_n = conv_m_n[0]
                for m in range(1, input_num):
                    sum_conv_m_n = sum_conv_m_n + conv_m_n[m]
                    # 输出运算结果
                    for i in range(sum_conv_m_n.shape[0]):
                        for j in range(sum_conv_m_n.shape[1]):
                            fp.write("%d\n"%(int(sum_conv_m_n[i][j]*2**16)))
                    
                # 然后加上偏置
                name2 = "conv-bias-L%d-O%d"%(layer, n)
                bias_n = np.loadtxt("../para/"+name2+".csv", delimiter=",")
                sum_conv_m_n = sum_conv_m_n + bias_n
                # 输出运算结果
                for i in range(sum_conv_m_n.shape[0]):
                    for j in range(sum_conv_m_n.shape[1]):
                        fp.write("%d\n"%(int(sum_conv_m_n[i][j]*2**16)))
                
                # 激活函数映射
                if H[layer][4]=="sigmoid":
                    # 然后是sigmoid非线性映射
                    activate_n = 1/(1+np.exp(-sum_conv_m_n))
                elif H[layer][4]=="relu":
                    # 然后是relu非线性映射
                    sum_conv_m_n[sum_conv_m_n<0]=0
                    activate_n = sum_conv_m_n
                elif H[layer][4]=="tanh":
                    # 然后是sigmoid非线性映射
                    activate_n = np.tanh(sum_conv_m_n)
                else:
                    # 然后是sigmoid非线性映射
                    activate_n = 1/(1+np.exp(-sum_conv_m_n))
                # 输出运算结果
                for i in range(activate_n.shape[0]):
                    for j in range(activate_n.shape[1]):
                        fp.write("%d\n"%(int(activate_n[i][j]*2**16)))
                input_img_tmp.append(activate_n)
            
            # 更新一下每一层的输入通道数量，以及输入图像的尺寸
            input_num = H[layer][3]
            input_size = [input_size[0]-Km+1, input_size[1]-Kn+1]
            # 输入图像
            input_img = input_img_tmp
            
        # 池化层
        elif H[layer][0]=='S':
            # 使用POOL指令计算每个输入的pooling结果，缓存
            input_img_tmp = []
            for m in range(0, input_num):
                # 对于每个input_map进行计算
                # print(input_img[m])
                pool_m = np.zeros((int(input_size[0]/2), int(input_size[1]/2)))
                for i in range(0, int(input_size[0]/2)):
                    for j in range(0, int(input_size[1]/2)):
                        pool_m[i, j] = np.max(input_img[m][2*i:2*i+2, 2*j:2*j+2])
                input_img_tmp.append(pool_m)
                
                # 输出运算结果
                for i in range(pool_m.shape[0]):
                    for j in range(pool_m.shape[1]):
                        fp.write("%d\n"%(int(pool_m[i][j]*2**16)))
            # 更新一下每一层的输入通道数量，以及输入图像的尺寸
            input_num = input_num
            input_size = [input_size[0]/Pm, input_size[1]/Pn]
            # 输入图像
            input_img = input_img_tmp
        # 压平层
        elif H[layer][0]=='STRIP':
            strip_tmp = np.zeros((input_num, int(H[layer][1]/input_num)))
            # 使用POOL指令计算每个输入的pooling结果，缓存
            for m in range(0, input_num):
                # 对于每个input_map进行计算
                strip_tmp[m] = input_img[m].reshape((int(H[layer][1]/input_num)))
            # 打印
            #print(strip_tmp)
            # 输出运算结果
            for i in range(strip_tmp.shape[0]):
                for j in range(strip_tmp.shape[1]):
                    fp.write("%d\n"%(int(strip_tmp[i][j]*2**16)))
            # 更新一下每一层的输入通道数量
            input_num = 1
            input_size = [1, H[layer][1]]
            input_img = strip_tmp.reshape((H[layer][1]))
        # 全连接层
        elif H[layer][0]=='FC':
            # 使用MULT矩阵乘法指令
            name = "fc-weight-L%d"%(layer)
            weight = np.loadtxt("../para/"+name+".csv", delimiter=",")
            input_img = np.dot(input_img, weight)
            
            # 输出运算结果
            for i in range(input_img.shape[0]):
                fp.write("%d\n"%(int(input_img[i]*2**16)))
                    
            # 矩阵乘法完成后，运算结果的尺寸变成了【input_size[0]xH[layer][2]】
            # 然后执行一下矩阵加法（加上连接偏置）
            name = "fc-bias-L%d"%(layer)
            bias = np.loadtxt("../para/"+name+".csv", delimiter=",")
            #print(input_img)
            input_img = input_img + bias
            #print(input_img)
            #print("---------")
            
            # 输出运算结果
            for i in range(input_img.shape[0]):
                fp.write("%d\n"%(int(input_img[i]*2**16)))
                
                
            # 激活函数映射
            if H[layer][3]=="sigmoid":
                # 然后是sigmoid非线性映射
                input_img = 1/(1+np.exp(-input_img))
            elif H[layer][3]=="relu":
                # 然后是relu非线性映射
                input_img[input_img<0]=0
                input_img = input_img
            elif H[layer][3]=="tanh":
                # 然后是sigmoid非线性映射
                input_img = np.tanh(input_img)
            else:
                # 然后是sigmoid非线性映射
                input_img = 1/(1+np.exp(-input_img))
            
            
            # 输出运算结果
            for i in range(input_img.shape[0]):
                fp.write("%d\n"%(int(input_img[i]*2**16)))
                
            # 更新一下每一层的输入通道数量
            input_num = 1
            input_size = [1, H[layer][2]]
    #############
    # 最后，需要将CNN的输出再统一传输到DIST_BIAS地址
    
    
    ####################
    fp.close()
    
    return input_img

#########################################

# 测试用
if __name__ == '__main__':
    #%% 用H表征网络结构，P来表征参数，用D来表征数据
    H = gen_cnn.generate_cnn()
    
    dict_para_addr, dict_para_val, inst_set = generate_npu_inst.generate_npu_inst(H, value_enable=True)
    #print(inst_set)
    # 首先存储好NPU的指令
    fp = open("../isa-npu/sim_source/fpga-inst.list", "w")
    fp.write("@0\n")
    for inst in inst_set:
        fp.write("%s\n"%(inst))
    fp.write("%032X"%(0))
    fp.close()
    #%% 加载所有样本，并且生成所有的内存初始化文件
    kwarg = {"SNR": [100], "TimeRange": H[0][1], "nCeps": H[0][2], "window_width": 256, "window_shift": 100, "nFilter": 64, "nActual": 64, "DCTen": True}
    sample_image, sample_label, sample_name, sample_snr = load_all_sr_samples(file_path="../../../../database/cxd-shu/train", music_path="../../../../database/music-tiny", rand=True, displacement=False, **kwarg)
    # 不需要额外的归一化操作
    
    
    #%% 遍历所有的样本点
    SAMPLE_BIAS = 5
    TOTAL_NUM = 50
    true_cnt = 0
    for i in range(SAMPLE_BIAS+0, SAMPLE_BIAS+TOTAL_NUM): #sample_image.shape[0]):
        # 生成和verilog-NPU比对的测试文件
        image = sample_image[i, :, :, :]
        #print(image.shape)
        conv_out = generate_test_file(image, H, "../isa-npu/ver_compare/sp-%d.txt"%(i))
        print(np.argmax(conv_out)==sample_label[i], np.argmax(conv_out), sample_label[i])
        true_cnt = true_cnt + (np.argmax(conv_out)==sample_label[i])
        ########################################################################
        # 将测试结果全部写入到一个文本中，便于观察比对
        fp_spresult = open("../isa-npu/ver_compare/sp-%d-result.txt"%(i), "w")
        for k in range(conv_out.shape[0]):
            fp_spresult.write("%f, "%(conv_out[k]))
        fp_spresult.write("\n")
        fp_spresult.close()
        #####################################################################
        # 创建一个内存初始化文件
        fp = open("../isa-npu/sim_source/sp-%d.list"%(i), "w")
        # 首先是原始的灰度图
        fp.write("@%08X\n"%(SORC_BIAS_0<<1))
        for m in range(0, sample_image.shape[1]):
            for n in range(0, sample_image.shape[2]):
                DAT = int(sample_image[i][m][n][0]*2**16)
                # 先存储低字节
                fp.write("%04X\n"%(DAT&0xFFFF))
                fp.write("%04X\n"%((DAT&0xFFFF0000)>>16))
        # 然后关闭
        fp.close()
        # 创建FPGA仿真的数据样本
        fp = open("../isa-npu/sim_source_fpga/sp-%d.list"%(i), "w")
        # 首先是原始的灰度图
        fp.write("@%08X\n"%(SORC_BIAS_0))
        for m in range(0, sample_image.shape[1]):
            for n in range(0, sample_image.shape[2]):
                DAT = int(sample_image[i][m][n][0]*2**16)
                # 先存储低字节
                fp.write("%08X\n"%(DAT&0xFFFFFFFF))
        # 然后关闭
        fp.close()
        ################################## 下面是为了验证MFCC搬运，采用的代码
        # 创建一个内存初始化文件
        fp = open("../isa-npu/sim_source/sp-%d-exchg.list"%(i), "w")
        MFCC_ADDR = 0x00000080
        nDCT = 64
        # 首先是原始的灰度图
        fp.write("@%08X\n"%(MFCC_ADDR<<1))
        for m in range(0, sample_image.shape[1]):
            # 首先第0个元素被默认抹掉
            DAT = 0
            fp.write("%04X\n"%(DAT&0xFFFF))
            fp.write("%04X\n"%((DAT&0xFFFF0000)>>16))
            for n in range(0, sample_image.shape[2]):
                DAT = int(sample_image[i][m][n][0]*2**16)
                # 先存储低字节
                fp.write("%04X\n"%(DAT&0xFFFF))
                fp.write("%04X\n"%((DAT&0xFFFF0000)>>16))
            # 补足64-d
            for n in range(0, nDCT-1-sample_image.shape[2]):
                DAT = 0
                fp.write("%04X\n"%(DAT&0xFFFF))
                fp.write("%04X\n"%((DAT&0xFFFF0000)>>16))
        # 然后关闭
        fp.close()
        
    #################
        
    #############
    print("acc = %.2f"%(true_cnt*1.0/TOTAL_NUM))