# -*- coding:utf-8 -*-
#####################################

import generate_cnn_layers as gen_cnn

import numpy as np

##########################################

# 要产生NPU指令
PARA_BIAS = 0x00040000>>2	# 参数的偏移量, 0.25 MB ~ 0.5MB ==> 0.25 MB / 4B = 64K个参数
DIST_BIAS = 0x00000000>>2	# 输出数据，0MB
DATA_BIAS = 0x00080000>>2	# 中间运算数据缓存的偏移量, 0.5MB
SORC_BIAS_0 = 0x00100000>>2	# 输入的数据#0，1.0MB
SORC_BIAS_1 = 0x00180000>>2	# 输入数据#1，1.5MB
####
MAT_WIDTH = 0x00004000>>2	# 每个矩阵的大小（16KB）
#####################
# 指令集
INST_SET = {"ADD": 0, "ADDi": 1, "SUB": 2, "SUBi": 3, "MULT":4, "MULTi": 5, 
			"DOT": 6, "CONV": 7, "POOL": 8, "SIGM": 9, "RELU": 10, "TANH": 11,
			"GRAY": 12, "TRAN": 13, "ADDs": 14, "SUBs": 15}
#%%
##########################################
def generate_npu_inst(H, value_enable=False):
	# 返回指令集
	inst_set = []
	ddr_write_set = []
	# 卷积层中，偏移量直接进入IMM立即数运算，不必存入内存
	# 全连接中，偏移量作为向量运算，需要写入内存
	# 使用字典来记录 
	dict_para_addr = dict()		# 记录各个参数所处的位置
	dict_para_val = dict()		# 记录各个参数所取得的值
	para_cnt = 0
	para_addr = PARA_BIAS	# 首先从PARA_BIAS存放起
	for layer in range(0, len(H)):
		if H[layer][0]=='I':
			output_num = H[layer][3]
		elif H[layer][0]=='C':
			# 先要遍历输入的变量
			for n in range(0, H[layer][3]):
				for m in range(0, output_num):
					conv_kernel_size = H[layer][1]*H[layer][2]	# 卷积核的大小，
					name = "conv-kernel-L%d-I%d-O%d"%(layer, m, n)
					dict_para_addr[name] = para_addr	# 参数存储的内存地址
					# 加载参数
					if value_enable:
						dict_para_val[name] = np.loadtxt("../para/"+name+".csv", delimiter=",")
					# 更新一下下一个参数的地址和占用的有空间综合
					para_addr = para_addr + conv_kernel_size	# 每个参数有conv_kernel_size的空间				
					para_cnt = para_cnt + H[layer][1]*H[layer][2]	# 统计卷积核占用的存储空间
				# 然后是卷积的偏置量
				conv_bias_size = 1
				name = "conv-bias-L%d-O%d"%(layer, n)
				dict_para_addr[name] = para_addr
				# 加载参数
				if value_enable:
					dict_para_val[name] = np.loadtxt("../para/"+name+".csv", delimiter=",")
				# 更新一下下一个参数的地址和占用的有空间综合
				para_addr = para_addr + conv_bias_size	# 每个参数有conv_bias_size的空间				
				para_cnt = para_cnt + 1	# 统计卷积偏置占用的存储空间
				
			# 更新输出数量
			output_num = H[layer][3]
			
		elif H[layer][0]=='FC':
			# 首先是链接权值
			fc_weight_size = H[layer][1]*H[layer][2]	# 连接矩阵的大小
			name = "fc-weight-L%d"%(layer)
			dict_para_addr[name] = para_addr
			# 加载参数
			if value_enable:
				dict_para_val[name] = np.loadtxt("../para/"+name+".csv", delimiter=",")
			# 更新一下下一个参数的地址和占用的有空间综合
			para_addr = para_addr + fc_weight_size	# 每个参数有fc_weight_size的空间			
			para_cnt = para_cnt + H[layer][1]*H[layer][2]	# 统计FC层连接矩阵占用的存储空间
			# 然后是连接偏置
			fc_bias_size = H[layer][2]	# 连接偏置的大小
			name = "fc-bias-L%d"%(layer)
			dict_para_addr[name] = para_addr
			# 加载参数
			if value_enable:
				dict_para_val[name] = np.loadtxt("../para/"+name+".csv", delimiter=",")
			# 更新一下下一个参数的地址和占用的有空间综合
			para_addr = para_addr + fc_bias_size	# 每个参数有fc_bias_size的空间
			para_cnt = para_cnt + H[layer][2]	# 统计FC层偏置占用的存储空间
			
	#print(hex(PARA_BIAS + para_num*MAT_WIDTH))
	# 构造NPU指令
	# 卷积核
	# 用来累计DDR的读写次数
	DDR_READ = 0; DDR_WRITE = 0;
	# 存储NPU指令
	npu_inst = [0, 0, 0, 0]
	# 对于卷积层，l-层-m-输入-n-输出，参数所在的位置是 ()
	for layer in range(0, len(H)):
		if H[layer][0]=='I':
			print("layer %d: input"%(layer))
			# 然后初始化输入输出的内存空间偏移量 
			INP_BIAS = SORC_BIAS_0
			OUT_BIAS = SORC_BIAS_1
			# 初始化每一层的输入通道数量
			input_num = H[layer][3]
			input_size = [H[layer][1], H[layer][2]]
		# 卷积层
		elif H[layer][0]=='C':
			print("layer %d: convolution"%(layer))
			Km = H[layer][1]
			Kn = H[layer][2]
			# 首先计算每个input_map和conv_kernel的卷积结果
			for n in range(0, H[layer][3]):
				# 计算每个输入和对应核的卷积，存储到数据缓存空间
				for m in range(0, input_num):
					# 对于每个input_map进行计算
					name = "conv-kernel-L%d-I%d-O%d"%(layer, m, n)
					print("CONV, @%08X, @%08X, @%08X, M=%d, N=%d, Km=%d, Kn=%d"%(INP_BIAS+m*MAT_WIDTH, dict_para_addr[name], DATA_BIAS+m*MAT_WIDTH, input_size[0], input_size[1], Km, Kn))
					
					# 翻译成指令
					D1 = int((INP_BIAS+m*MAT_WIDTH))
					D2 = int(dict_para_addr[name])
					D3 = int(DATA_BIAS+m*MAT_WIDTH)
					M = int(input_size[0])
					N = int(input_size[1])
					npu_inst[0] = (INST_SET["CONV"]<<28)|(D1>>4)
					npu_inst[1] = (D1<<28)|(D2>>4) 
					npu_inst[2] = (D2<<28)|(D3>>4) 
					npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)|(Km<<5)|(Kn)
					print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
					inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
					
					# 累计DDR读写次数
					DDR_READ = DDR_READ + input_size[0]*input_size[1] + Km*Kn
					DDR_WRITE = DDR_WRITE + (input_size[0]-Km+1)*(input_size[1]-Kn+1)
					ddr_write_set.append(DDR_WRITE)
				# 对于数据缓存空间中（m个）卷积结果进行累加，缓存
				for m in range(1, input_num):
					print("ADD, @%08X, @%08X, @%08X, M=%d, N=%d"%(DATA_BIAS+0*MAT_WIDTH, DATA_BIAS+m*MAT_WIDTH, DATA_BIAS+0*MAT_WIDTH, (input_size[0]-Km+1), (input_size[1]-Kn+1)))
					
					# 翻译成指令
					D1 = int(DATA_BIAS+0*MAT_WIDTH)
					D2 = int(DATA_BIAS+m*MAT_WIDTH)
					D3 = int(DATA_BIAS+0*MAT_WIDTH)
					M = int(input_size[0]-Km+1)
					N = int(input_size[1]-Kn+1)
					npu_inst[0] = (INST_SET["ADD"]<<28)|(D1>>4)
					npu_inst[1] = (D1<<28)|(D2>>4) 
					npu_inst[2] = (D2<<28)|(D3>>4) 
					npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
					print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
					inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
					
					# 累计DDR读写次数
					DDR_READ = DDR_READ + (input_size[0]-Km+1)*(input_size[1]-Kn+1)*2
					DDR_WRITE = DDR_WRITE + (input_size[0]-Km+1)*(input_size[1]-Kn+1)
					ddr_write_set.append(DDR_WRITE)
				# 然后加上偏置
				name2 = "conv-bias-L%d-O%d"%(layer, n)
				print("ADDs, @%08X, @%08X, @%08X, M=%d, N=%d"%(DATA_BIAS+0*MAT_WIDTH, dict_para_addr[name2], DATA_BIAS+0*MAT_WIDTH, (input_size[0]-Km+1), (input_size[1]-Kn+1)))
				
				# 翻译成指令
				D1 = int(DATA_BIAS+0*MAT_WIDTH)
				D2 = int(dict_para_addr[name2])
				D3 = int(DATA_BIAS+0*MAT_WIDTH)
				M = int(input_size[0]-Km+1)
				N = int(input_size[1]-Kn+1)
				npu_inst[0] = (INST_SET["ADDs"]<<28)|(D1>>4)
				npu_inst[1] = (D1<<28)|(D2>>4) 
				npu_inst[2] = (D2<<28)|(D3>>4) 
				npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
				print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
				inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
				
				# 累计DDR读写次数
				DDR_READ = DDR_READ + (input_size[0]-Km+1)*(input_size[1]-Kn+1) + 1
				DDR_WRITE = DDR_WRITE + (input_size[0]-Km+1)*(input_size[1]-Kn+1)
				ddr_write_set.append(DDR_WRITE)
				# 然后是激活函数
				if H[layer][4]=="sigmoid":
					# 然后是sigmoid非线性映射
					print("SIGM, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+0*MAT_WIDTH, OUT_BIAS+n*MAT_WIDTH, (input_size[0]-Km+1), (input_size[1]-Kn+1)))
					ACTIVATE = "SIGM"
				elif H[layer][4]=="relu":
					# 然后是relu非线性映射
					print("RELU, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+0*MAT_WIDTH, OUT_BIAS+n*MAT_WIDTH, (input_size[0]-Km+1), (input_size[1]-Kn+1)))
					ACTIVATE = "RELU"
				elif H[layer][4]=="tanh":
					# 然后是tanh非线性映射
					print("TANH, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+0*MAT_WIDTH, OUT_BIAS+n*MAT_WIDTH, (input_size[0]-Km+1), (input_size[1]-Kn+1)))
					ACTIVATE = "TANH"
				else:
					# 然后是sigmoid非线性映射
					print("SIGM, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+0*MAT_WIDTH, OUT_BIAS+n*MAT_WIDTH, (input_size[0]-Km+1), (input_size[1]-Kn+1)))
					ACTIVATE = "SIGM"
				
				# 翻译成指令
				D1 = int(DATA_BIAS+0*MAT_WIDTH)
				D2 = int(0)
				D3 = int(OUT_BIAS+n*MAT_WIDTH)
				M = int(input_size[0]-Km+1)
				N = int(input_size[1]-Kn+1)
				npu_inst[0] = (INST_SET[ACTIVATE]<<28)|(D1>>4)
				npu_inst[1] = (D1<<28)|(D2>>4) 
				npu_inst[2] = (D2<<28)|(D3>>4) 
				npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
				print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
				inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
				
				# 累计DDR读写次数
				DDR_READ = DDR_READ + (input_size[0]-Km+1)*(input_size[1]-Kn+1)
				DDR_WRITE = DDR_WRITE + (input_size[0]-Km+1)*(input_size[1]-Kn+1)
				ddr_write_set.append(DDR_WRITE)
			# 最后交换一下INP_BIAS/OUT_BIAS两个输入/输出的地址
			TMP = OUT_BIAS
			OUT_BIAS = INP_BIAS
			INP_BIAS = TMP
			# 更新一下每一层的输入通道数量，以及输入图像的尺寸
			input_num = H[layer][3]
			input_size = [input_size[0]-Km+1, input_size[1]-Kn+1]
		# 池化层
		elif H[layer][0]=='S':
			Pm = H[layer][1]
			Pn = H[layer][2]
			print("layer %d: pooling"%(layer))
			# 使用POOL指令计算每个输入的pooling结果，缓存
			for m in range(0, input_num):
				# 对于每个input_map进行计算
				print("POOL, @%08X, MAX, @%08X, M=%d, N=%d, Pm=%d, Pn=%d"%(INP_BIAS+m*MAT_WIDTH, OUT_BIAS+m*MAT_WIDTH, input_size[0], input_size[1], Pm, Pn))
				
				# 翻译成指令
				D1 = int(INP_BIAS+m*MAT_WIDTH)
				D2 = int(1)
				D3 = int(OUT_BIAS+m*MAT_WIDTH)
				M = int(input_size[0])
				N = int(input_size[1])
				npu_inst[0] = (INST_SET["POOL"]<<28)|(D1>>4)
				npu_inst[1] = (D1<<28)|(D2>>4) 
				npu_inst[2] = (D2<<28)|(D3>>4) 
				npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)|(Pm<<5)|Pn
				print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
				inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
				
				# 累计DDR读写次数
				DDR_READ = DDR_READ + (input_size[0])*(input_size[1])
				DDR_WRITE = DDR_WRITE + int(input_size[0]/Pm)*int(input_size[1]/Pn)
				ddr_write_set.append(DDR_WRITE)
			# 最后交换一下INP_BIAS/OUT_BIAS两个输入/输出的地址
			TMP = OUT_BIAS
			OUT_BIAS = INP_BIAS
			INP_BIAS = TMP
			# 更新一下每一层的输入通道数量，以及输入图像的尺寸
			input_num = input_num
			input_size = [input_size[0]/Pm, input_size[1]/Pn]
		# 压平层
		elif H[layer][0]=='STRIP':
			print("layer %d: strip"%(layer))
			# 使用POOL指令计算每个输入的pooling结果，缓存
			for m in range(0, input_num):
				# 对于每个input_map进行计算
				space_for_each_img = int(H[layer][1]/input_num)	 # 32-bit data format
				print("ADDi, @%08X, #%08X, @%08X, M=%d, N=%d"%(INP_BIAS+m*MAT_WIDTH, 0, OUT_BIAS+m*(space_for_each_img), input_size[0], input_size[1]))
				
				# 翻译成指令
				D1 = int(INP_BIAS+m*MAT_WIDTH)
				D2 = int(0)
				D3 = int(OUT_BIAS+m*(space_for_each_img))
				M = int(input_size[0])
				N = int(input_size[1])
				npu_inst[0] = (INST_SET["ADDi"]<<28)|(D1>>4)
				npu_inst[1] = (D1<<28)|(D2>>4) 
				npu_inst[2] = (D2<<28)|(D3>>4) 
				npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
				print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
				inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
				
				# 累计DDR读写次数
				DDR_READ = DDR_READ + (input_size[0])*(input_size[1])
				DDR_WRITE = DDR_WRITE + (input_size[0])*(input_size[1])
				ddr_write_set.append(DDR_WRITE)
			# 最后交换一下INP_BIAS/OUT_BIAS两个输入/输出的地址
			TMP = OUT_BIAS
			OUT_BIAS = INP_BIAS
			INP_BIAS = TMP
			# 更新一下每一层的输入通道数量
			input_num = 1
			input_size = [1, H[layer][1]]
		# 全连接层
		elif H[layer][0]=='FC':
			print("layer %d: fully_connection"%(layer))
			# 使用MULT矩阵乘法指令
			name = "fc-weight-L%d"%(layer)
			print("MULT, @%08X, @%08X, @%08X, M=%d, N=%d, P=%d"%(INP_BIAS, dict_para_addr[name], DATA_BIAS, input_size[0], input_size[1], H[layer][2]))
			
			# 翻译成指令
			D1 = int(INP_BIAS)
			D2 = int(dict_para_addr[name])
			D3 = int(DATA_BIAS)
			M = int(input_size[0])
			N = int(input_size[1])
			P = int(H[layer][2])
			npu_inst[0] = (INST_SET["MULT"]<<28)|(D1>>4)
			npu_inst[1] = (D1<<28)|(D2>>4) 
			npu_inst[2] = (D2<<28)|(D3>>4) 
			npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)|(P<<1)
			print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
			inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
			
			# 累计DDR读写次数
			DDR_READ = DDR_READ + (input_size[0])*(input_size[1])*H[layer][2]
			DDR_WRITE = DDR_WRITE + input_size[0]*H[layer][2]
			ddr_write_set.append(DDR_WRITE)
			# 矩阵乘法完成后，运算结果的尺寸变成了【input_size[0]xH[layer][2]】
			# 然后执行一下矩阵加法（加上连接偏置）
			name = "fc-bias-L%d"%(layer)
			print("ADD, @%08X, @%08X, @%08X, M=%d, N=%d"%(DATA_BIAS, dict_para_addr[name], DATA_BIAS+MAT_WIDTH, input_size[0], H[layer][2]))
			
			# 翻译成指令
			D1 = int(DATA_BIAS)
			D2 = int(dict_para_addr[name])
			D3 = int(DATA_BIAS+MAT_WIDTH)
			M = int(input_size[0])
			N = int(H[layer][2])
			npu_inst[0] = (INST_SET["ADD"]<<28)|(D1>>4)
			npu_inst[1] = (D1<<28)|(D2>>4) 
			npu_inst[2] = (D2<<28)|(D3>>4) 
			npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
			print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
			inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
			
			# 累计DDR读写次数
			DDR_READ = DDR_READ + (input_size[0])*H[layer][2]*2
			DDR_WRITE = DDR_WRITE + input_size[0]*H[layer][2]
			ddr_write_set.append(DDR_WRITE)
			# 最后，激活函数映射
			if H[layer][3]=="sigmoid":
				# 然后是sigmoid非线性映射
				print("SIGM, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+MAT_WIDTH, OUT_BIAS, input_size[0], H[layer][2]))
				ACTIVATE = "SIGM"
			elif H[layer][3]=="relu":
				# 然后是relu非线性映射
				print("RELU, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+MAT_WIDTH, OUT_BIAS, input_size[0], H[layer][2]))
				ACTIVATE = "RELU"
			elif H[layer][3]=="tanh":
				# 然后是tanh非线性映射
				print("TANH, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+MAT_WIDTH, OUT_BIAS, input_size[0], H[layer][2]))
				ACTIVATE = "TANH"
			else:
				# 然后是sigmoid非线性映射
				print("SIGM, @%08X, xx, @%08X, M=%d, N=%d"%(DATA_BIAS+MAT_WIDTH, OUT_BIAS, input_size[0], H[layer][2]))
				ACTIVATE = "SIGM"
			
			# 翻译成指令
			D1 = int(DATA_BIAS+MAT_WIDTH)
			D2 = int(0)
			D3 = int(OUT_BIAS)
			M = int(input_size[0])
			N = int(H[layer][2])
			npu_inst[0] = (INST_SET[ACTIVATE]<<28)|(D1>>4)
			npu_inst[1] = (D1<<28)|(D2>>4) 
			npu_inst[2] = (D2<<28)|(D3>>4) 
			npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
			print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
			inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
			
			# 累计DDR读写次数
			DDR_READ = DDR_READ + (input_size[0])*H[layer][2]
			DDR_WRITE = DDR_WRITE + input_size[0]*H[layer][2]
			ddr_write_set.append(DDR_WRITE)
			# 最后交换一下INP_BIAS/OUT_BIAS两个输入/输出的地址
			TMP = OUT_BIAS
			OUT_BIAS = INP_BIAS
			INP_BIAS = TMP
			# 更新一下每一层的输入通道数量
			input_num = 1
			input_size = [1, H[layer][2]]
			
	### 最后的最后，需要将运算结果，通过ADDi拷贝到 DIST_BIAS
	print("finnally copy results")
	print("ADDi, @%08X, #%08X, @%08X, M=%d, N=%d"%(INP_BIAS, 0, DIST_BIAS, input_size[0], input_size[1]))
	# 翻译成指令
	D1 = int(INP_BIAS)
	D2 = int(0)
	D3 = int(DIST_BIAS)
	M = int(input_size[0])
	N = int(input_size[1])
	npu_inst[0] = (INST_SET["ADDi"]<<28)|(D1>>4)
	npu_inst[1] = (D1<<28)|(D2>>4) 
	npu_inst[2] = (D2<<28)|(D3>>4) 
	npu_inst[3] = (D3<<28)|(M<<19)|(N<<10)
	print("\tinst=%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF))
	inst_set.append(("%08X%08X%08X%08X"%(npu_inst[0]&0xFFFFFFFF, npu_inst[1]&0xFFFFFFFF, npu_inst[2]&0xFFFFFFFF, npu_inst[3]&0xFFFFFFFF)))
	
	# 累计DDR读写次数
	DDR_READ = DDR_READ + (input_size[0])*(input_size[1])
	DDR_WRITE = DDR_WRITE + (input_size[0])*(input_size[1])
	ddr_write_set.append(DDR_WRITE)
	
	#################
	# 最后评估一下整个系统的DDR读写负荷
	print("\n\n[estimated in 50MBps DDR bandwidth]")
	print("DDR-READ = %d, DDR_WRITE=%d, \nTOTAL-TIME=%f ms, \nTOTAL-PARA-SPACE=%d (float number)\nTOTAL inst number=%d"%(DDR_READ, DDR_WRITE, (DDR_READ+DDR_WRITE)*4/50e6*1e3, para_cnt, len(inst_set)))

	return dict_para_addr, dict_para_val, inst_set, ddr_write_set

#########################################
# 测试用
if __name__ == '__main__':
	#%% 用H表征网络结构，P来表征参数，用D来表征数据
	H = gen_cnn.generate_cnn()
	# 
	dict_para_addr, dict_para_val, inst_set, ddr_write_set = generate_npu_inst(H, value_enable=True)
	#print(inst_set)
	# 将指令保存到c_api文件中
	fp = open("../isa-npu/inst.txt", "w")
	for i in range(0, len(inst_set)):
		fp.write("%s\n"%(inst_set[i]))
	fp.close()
	
	# 记录每条指令完成DDR写入的数量
	fp = open("../isa-npu/ddr_write.txt", "w")
	for i in range(0, len(inst_set)):
		fp.write("[%d] ==> %s\n"%(i, ddr_write_set[i]))
	fp.close()
	

	# 参数所在的位置是
	# 创建一个内存初始化文件
	fp = open("../isa-npu/para.txt", "w")
	# 首先将参数存储起来
	for para in dict_para_addr:
		# 参数所在的地址
		fp.write("@%08X\n"%(dict_para_addr[para]))
		para_val = dict_para_val[para]
		# 如果参数是矩阵
		if len(para_val.shape)==2:
			for m in range(0, para_val.shape[0]):
				for n in range(0, para_val.shape[1]):
					DAT = int(para_val[m][n]*65536)
					fp.write("%08X\n"%(DAT&0xFFFFFFFF))
		# 如果参数是向量
		elif len(para_val.shape)==1:
			for m in range(0, para_val.shape[0]):
				DAT = int(para_val[m]*65536)
				fp.write("%08X\n"%(DAT&0xFFFFFFFF))
		# 如果参数是标量
		elif len(para_val.shape)==0:
			DAT = int(para_val*65536)
			fp.write("%08X\n"%(DAT&0xFFFFFFFF))
	# 关闭文件
	fp.close()
