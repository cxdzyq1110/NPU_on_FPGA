# -*- coding: utf-8 -*-
"""
Created on Fri Jun  8 14:57:45 2018

@author: xdche
"""
############ 测试keras的函数是怎么运算的
import numpy as np
from keras.models import Sequential, Model
from keras.layers import Input, Dense, TimeDistributed, LSTM, Dropout, Activation, Permute
from keras.layers import Convolution2D, MaxPooling2D, Flatten
from keras.layers.normalization import BatchNormalization
from keras.layers.advanced_activations import ELU
from keras.callbacks import ModelCheckpoint
from keras.callbacks import TensorBoard
from keras import backend
from keras.utils import np_utils
from keras import regularizers
import tensorflow as tf
from os.path import isfile
from scipy import signal
# dims：整数tuple，指定重排的模式，不包含样本数的维度。重拍模式的下标从1开始。
# 例如（2，1）代表将输入的第二个维度重拍到输出的第一个维度，而将输入的第一个维度重排到第二个维度
#%%
N = 2; T = 5; K = 5; C = 2;
input_shape = (T, K, C)
nb_filter = 3
kerne_size = [3, 3]

#%%
model = Sequential()
model.add(Convolution2D(nb_filter, kerne_size[0], kerne_size[1], border_mode='valid', input_shape=input_shape,name="CONV"))
model.add(Permute((3, 1, 2)))
model.add(Flatten(name="FLATTEN"))
#%% 设定输入输出
input_val = np.random.randn(N, input_shape[0], input_shape[1], input_shape[2])

strip_val = model.predict(input_val)
conv_val = Model(inputs=model.input, outputs=model.get_layer('CONV').output).predict(input_val)

#%% 提取神经网络的参数
paras = model.get_weights()
filter_val = paras[0]
bias_val = paras[1]
#%% 验证计算过程
# 对于每个batch都要运算
# 首先验证convolution+bias
for batch in range(0, input_val.shape[0]):
    #print("----- * * * ----\nbatch: %d"%(batch))
    for n in range(0, filter_val.shape[3]):
        sum_conv_m_n = 0    # 要把累加求和的步骤清零
        for m in range(0, filter_val.shape[2]):
            #print("--------\n%d-->%d"%(m, n))
            #print("A=")
            #print(input_val[batch, :, :, m]) # 第m个输入样本
            #print("B=")
            # 旋转卷积核180°，这里使用flipud(fliplr(A))来实现！
				# 注意这里一定要旋转180度，因为tensorflow下面的tf.nn.conv2d和一般的卷积实现不一样
				# reference : https://www.tensorflow.org/versions/r1.3/api_docs/python/tf/nn/conv2d
            kernel = filter_val[:, :, m, n]
            kernel = np.flipud(np.fliplr(kernel))
            #print(kernel)   # 第(m, n)个卷积核
            #print("in scipy.signal.convolve2d")
            test_res = signal.convolve2d(input_val[batch, :, :, m], kernel, 'valid')    # 卷积过程
            #print(test_res)
            sum_conv_m_n = sum_conv_m_n + test_res  # 累加
        
        sum_conv_m_n = sum_conv_m_n + bias_val[n]
			
        print("in convolve2d")
        print(sum_conv_m_n)
            
        print("in tensorflow")
        print(conv_val[batch, :, :, n])
        
#%% 然后验证压平层

# 然后验证reshape
for batch in range(0, conv_val.shape[0]):
    print("------- * * * ------------")
    print("in numpy")
    for n in range(0, conv_val.shape[3]):
        print("n=", n)
        for h in range(conv_val.shape[1]):
            print(conv_val[batch, h, :, n])
    print("in tensorflow\n", strip_val[batch])