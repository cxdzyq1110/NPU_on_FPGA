# -*- coding:utf-8 -*-
#####################################
# import TensorFlow

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
####################################
class cnn_user:
	def __init__(self):
		self.model = None
		self.checkpointer = None
		
	def	create_cnn(self, conf, epsilon, keep_prob_, stddev=0.1):
		with tf.name_scope('cnn_components'):
			for layer in range(0, len(conf)):
				#print(conf[layer]) 
				# 卷积层
				with tf.name_scope('layer-%d'%(layer)):
					if conf[layer][0]=='I':
						self.model = Sequential()
						# 获取输入图像尺寸和通道数量
						self._input_shape_ = (conf[layer][1], conf[layer][2], conf[layer][3])
						# 并且清除“存在卷积”的标志位
						self._conv_exist_ = 0
					elif conf[layer][0]=='C':
						r = conf[layer][1] 	# 卷积核的行
						c = conf[layer][2] 	# 卷积核的列
						n = conf[layer][3]	# 卷积核的个数
						func = conf[layer][4] # 激活函数
						# 如果是第一个卷积层
						# 添加正则化项
						if self._conv_exist_==0:
							self.model.add(Convolution2D(n, r, c, border_mode='valid', input_shape=self._input_shape_, kernel_regularizer=regularizers.l2(epsilon)))
							self._conv_exist_ = 1
						# 添加正则化项
						else:
							self.model.add(Convolution2D(n, r, c, border_mode='valid', kernel_regularizer=regularizers.l2(epsilon)))
						# 然后是激活函数
						if func=="sigmoid":
							self.model.add(Activation('sigmoid'))
						elif func=="tanh":
							self.model.add(Activation('tanh'))
						elif func=="relu":
							self.model.add(Activation('relu'))
						else:
							self.model.add(Activation('sigmoid'))
					# 下采样层
					elif conf[layer][0]=='S':
						r = conf[layer][1] 	# 下采样的行
						c = conf[layer][2] 	# 下采样的列
						self.model.add(MaxPooling2D(pool_size=(r, c)))
						if conf[layer][3]=="dropout":
							self.model.add(Dropout(keep_prob_))
					# 全连接层
					elif conf[layer][0]=='FC':
						m = conf[layer][1] 	# 输入向量长度
						n = conf[layer][2] 	# 输出向量长度
						func = conf[layer][3] # 激活函数
						# 链接权值
						self.model.add(Dense(n, kernel_regularizer=regularizers.l2(epsilon)))
						# 然后是激活函数
						if func=="sigmoid":
							self.model.add(Activation('sigmoid'))
						elif func=="tanh":
							self.model.add(Activation('tanh'))
						elif func=="relu":
							self.model.add(Activation('relu'))
						else:
							self.model.add(Activation('sigmoid'))
						##########
						if conf[layer][4]=="dropout":
							self.model.add(Dropout(keep_prob_))
					# 压平层
					elif conf[layer][0]=='STRIP':
						# dims：整数tuple，指定重排的模式，不包含样本数的维度。重拍模式的下标从1开始。
						# 例如（2，1）代表将输入的第二个维度重拍到输出的第一个维度，而将输入的第一个维度重排到第二个维度
						# 这里的重排很重要！不然就会发现计算顺序很奇怪！
						self.model.add(Permute((3, 1, 2)))
						self.model.add(Flatten())
						if conf[layer][2]=="dropout":
							self.model.add(Dropout(keep_prob_))
			#############
			# 最后添加一层softmax
			with tf.name_scope('layer-%d'%(len(conf))):
				self.model.add(Activation('softmax'))
	# 断点
	def check_point(self, filename='../model/model_weights.hdf5'):
		with tf.name_scope('model_parameter'):
			# Initialize weights using checkpoint if it exists. (Checkpointing requires h5py)
			self.checkpoint_filepath = filename
			print("Looking for previous weights...")
			if ( isfile(self.checkpoint_filepath) ):
				print ('Checkpoint file detected. Loading weights.')
				self.model.load_weights(self.checkpoint_filepath)
			else:
				print ('No checkpoint file detected.  Starting from scratch.')
			self.checkpointer = ModelCheckpoint(filepath=self.checkpoint_filepath, verbose=1, save_best_only=True)
	# 将历史数据存储，用于tensorboard可视化
	def visualization(self, log_filepath="../logs"):
		self.tensorboard_cb = TensorBoard(log_dir=log_filepath, write_images=0, histogram_freq=0)
###############################