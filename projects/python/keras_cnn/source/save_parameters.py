# -*- coding:utf-8 -*-
#####################################
import shutil 
import os
import numpy as np

#%% we use cnn，首先加载CNN模型
import generate_cnn_layers as gen_cnn
H = gen_cnn.generate_cnn()
# 创建CNN模型
import cnn_user as cu
# 添加正则化项，改善测试集性能
epsilon = 1e-4
keep_prob = 0.5
cnn = cu.cnn_user()
cnn.create_cnn(H, epsilon, keep_prob, stddev=0.1)
cnn.model.compile(loss='categorical_crossentropy',
          optimizer='adadelta',
          metrics=['mse', 'acc'])
cnn.model.summary()
# 如果模型参数存在的话，就要载入
cnn.check_point()
#%%
# 如果模型参数存在的话，就要载入
if os.path.exists("../model/model_weights.hdf5"):
	print("model exists, reading parameters...")
	# 然后需要保存每一层的参数
	# 首先获取CNN里面的权值和偏置
	paras = cnn.model.get_weights()
	#print(CNN_W[0].shape, CNN_b)
	layer = 1	# 去掉输入层
	para_cnt = 0
	while para_cnt<len(paras):
		# 卷积层
		if H[layer][0]=='C':
			print("convolution")
			print("layer %d:"%(layer))
			for n in range(0, paras[para_cnt].shape[3]):
				for m in range(0, paras[para_cnt].shape[2]):
					print("conv_kernel:%d->%d"%(m, n))
					print(paras[para_cnt][:,:,m,n])
					# 保存到csv文件中
					filename = "../para/conv-kernel-L%d-I%d-O%d.csv"%(layer, m, n)
					# tensorflow下面的卷机运算和一般的2d卷积不一样，这里一定要先将卷积核旋转180度保存
					kernel = np.flipud(np.fliplr(paras[para_cnt][:,:,m,n]))
					np.savetxt(filename, kernel, delimiter=",", fmt='%f')
					#np.savetxt(filename, CNN_W[layer][:,:,m,n], delimiter=",", fmt='%f')
					#
				print("bias-->%d:"%(n))
				print(paras[para_cnt+1].shape)
				print(paras[para_cnt+1][n])
				# 保存到csv文件中
				filename = "../para/conv-bias-L%d-O%d.csv"%(layer, n)
				np.savetxt(filename, [paras[para_cnt+1][n]], delimiter=",", fmt='%f')
			#
			para_cnt = para_cnt + 2
			layer = layer + 1
			
		# 全连接层
		elif H[layer][0]=='FC':
			FC_W = paras[para_cnt]
			FC_b = paras[para_cnt+1]
			print("fully_connection")
			print("weight:")
			print(FC_W)
			# 保存到csv文件中
			filename = "../para/fc-weight-L%d.csv"%(layer)
			np.savetxt(filename, FC_W, delimiter=",", fmt='%f')
			#
			print("bias:")
			print(FC_b)
			# 保存到csv文件中
			filename = "../para/fc-bias-L%d.csv"%(layer)
			np.savetxt(filename, FC_b, delimiter=",", fmt='%f')
			para_cnt = para_cnt + 2
			layer = layer + 1
		##
		else:
			layer = layer + 1
	
else:
	print("no model exists, run CNN-training first...")