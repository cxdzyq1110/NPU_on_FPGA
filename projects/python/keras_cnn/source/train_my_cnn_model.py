# -*- coding:utf-8 -*-
#####################################
#%% 区分是训练，还是测试
import sys
if sys.argv[1]=='train':
	train_mode = 1
elif sys.argv[1]=='test':
	train_mode = 0
#%%
# 指定GPU
import os
os.environ["CUDA_VISIBLE_DEVICES"] = "0"

#%% delete directory & files inside
import shutil
logs_dir = "../logs"
if train_mode==1:
	#% remove logs
	# 创建/移除logs文件夹
	if os.path.exists(logs_dir):
		shutil.rmtree(logs_dir)
		
#%% we use cnn，首先加载CNN模型
import generate_cnn_layers as gen_cnn
H = gen_cnn.generate_cnn()
# 创建CNN模型
import cnn_user as cu
from keras import optimizers
# 添加正则化项，改善测试集性能
epsilon = 1e-4
keep_prob = 0.5
cnn = cu.cnn_user()
cnn.create_cnn(H, epsilon, keep_prob, stddev=0.1)
cnn.model.compile(loss='categorical_crossentropy',
          optimizer='adadelta',
          metrics=['accuracy'])
cnn.model.summary()
# 如果模型参数存在的话，就要载入
cnn.check_point()
# tensorboard可视化
cnn.visualization(log_filepath=logs_dir)
##########

#%% 加载图像数据&标签数据
from load_our_samples import *
import numpy as np

# 编码方式
OneHot = [[j==i for j in range(0, H[-1][2])] for i in range(0, H[-1][2])]
OneHot = (np.array(OneHot))*1.0
#

TimeRange = H[0][1]
nCeps = H[0][2]
SNR=[50, 20, 5, 0]
opt_step = 1
kwarg = {"SNR": SNR, "TimeRange": TimeRange, "nCeps": nCeps, "window_width": 256, "window_shift": 100, "nFilter": 64, "nActual": 64, "DCTen": True}
if train_mode==1:
	sample_image, sample_label, sample_name, sample_snr = load_all_sr_samples(file_path="../../../../database/cxd-shu/train", music_path="../../../../database/music-tiny", displacement=False, **kwarg)
	#verify_image, verify_label, verify_name, verify_snr = load_all_sr_samples(file_path="../../../../database/cxd-shu/test", music_path="../../../../database/music-tiny", displacement=False, **kwarg)
	'''
	'''
	sample_label_one_hot = np.array([OneHot[sample_label[i]] for i in range(0, len(sample_label))])
	# 然后设置一下训练集和测试集
	ratio = 0.8
	train_num = int(ratio*sample_image.shape[0])
	verify_image = sample_image[train_num:, :, :, :]
	verify_label_one_hot = sample_label_one_hot[train_num:, :]
	verify_label = sample_label[train_num:]
	verify_name = sample_name
	sample_image = sample_image[:train_num, :, :, :]
	sample_label_one_hot = sample_label_one_hot[:train_num, :]
	sample_label = sample_label[:train_num]
	'''
	'''
	# 把verify_label对其到sample_label
	verify_label = np.array([sample_name.index(verify_name[verify_label[i]]) for i in range(len(verify_label))])
	verify_label_one_hot = np.array([OneHot[verify_label[i]] for i in range(0, len(verify_label))])
	## 生成样本
	train_image = sample_image
	train_label_one_hot = sample_label_one_hot
	train_label = sample_label
	test_image = verify_image
	test_label_one_hot = verify_label_one_hot
	test_label = verify_label
else:
	# 原始数据测试
	total_image, total_label, total_name, total_snr = load_all_sr_samples(file_path="../../../../database/cxd-shu/train", music_path="../../../../database/music-tiny", displacement=True, **kwarg)
	total_image = total_image
	# 编码方式
	OneHot = [[j==i for j in range(0, H[-1][2])] for i in range(0, H[-1][2])]
	OneHot = (np.array(OneHot))*1.0
	total_label_one_hot = np.array([OneHot[total_label[i]] for i in range(0, len(total_label))])
	

# Mark[2018/6/8]绘制混淆矩阵
import confusion_matrix
###################################
#%% 如果在训练模式
if train_mode==1:
	#% train and score the model
	batch_size = 512
	nb_epoch = 1000
	cnn.model.fit(train_image, train_label_one_hot, batch_size=batch_size, nb_epoch=nb_epoch,
		  verbose=1, validation_data=(test_image, test_label_one_hot), callbacks=[cnn.checkpointer, cnn.tensorboard_cb])
	predict_label_one_hot = cnn.model.predict(test_image, verbose=0)
	score = cnn.model.evaluate(test_image, test_label_one_hot, verbose=0)
	print('Test score:', score[0])
	print('Test accuracy:', score[1])
	#% Mark[2018/6/8] 绘制混淆矩阵
	confusion_matrix.confusion_matrix_plot(predict_label_one_hot, test_label_one_hot, sample_name, "../model/model_test_cm.jpg")
# 否则是在测试模式
else:
	# 对于不同的SNR分别统计
	for snr in SNR:
		predict_label_one_hot = cnn.model.predict(total_image[total_snr==snr], verbose=0)
		score = cnn.model.evaluate(total_image[total_snr==snr], total_label_one_hot[total_snr==snr], verbose=0)
		print("------ * * * -------")
		print("snr = %d dB"%(snr))
		print('Total score:', score[0])
		print('Total accuracy:', score[1])
		#% Mark[2018/6/8] 绘制混淆矩阵
		confusion_matrix.confusion_matrix_plot(predict_label_one_hot, total_label_one_hot[total_snr==snr], total_name, "../model/model_total_cm-snr[%d dB].jpg"%(snr))