#%% 生成数据集
import numpy as np
import matplotlib.pyplot as plt
import time
import struct
from glob import glob
import sys
import os
import random

sys.path.append("../../load_sample")
sys.path.append("../../serial")
sys.path.append("../../mfcc")
import load_sample

# 加载所有的样本
# TimeRange: 考察的范围，78帧
# GenderEnable: 是否要考虑性别
def load_all_sr_samples(file_path, music_path, TimeRange=78, nCeps=22, GenderEnable=False, rand=True, displacement=True, **kwarg):
	if displacement==True:
		_, _, sample_label, sample_name, _, sample_snr, sample_mfcc_cut, _, _ = load_sample.load_all_samples_bgnoise_displace(file_path=file_path, music_path=music_path, Time_Range=TimeRange, nCeps=nCeps, Cut_MFCC_Enable=True, **kwarg)
	else:
		_, _, sample_label, sample_name, _, sample_snr, sample_mfcc_cut, _, _ = load_sample.load_all_samples_bgnoise(file_path=file_path, music_path=music_path, Time_Range=TimeRange, nCeps=nCeps, Cut_MFCC_Enable=True, **kwarg)
	# 
	sample_image = np.zeros((len(sample_mfcc_cut), TimeRange, sample_mfcc_cut[0].shape[1], 1))
	# 首先截断mfcc
	for i in range(len(sample_mfcc_cut)):
		sample_image[i, :, :, 0] = sample_mfcc_cut[i]
	'''
	'''
	
	# 然后是打乱所有样本的顺序
	#随即打乱
	order = np.arange(len(sample_mfcc_cut))
	if rand:
		random.shuffle(order)
	
	print(order)
	sample_image = sample_image[order,:,:,:]
	sample_label = np.array([sample_label[order[i]] for i in range(0, len(order))])
	sample_snr = np.array([sample_snr[order[i]] for i in range(0, len(order))])
	
	return sample_image, sample_label, sample_name, sample_snr
	
	
##############

# 主函数
# 测试用
if __name__ == '__main__':
	# 测试load_sample库是否正确？
	#sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut = load_sample.load_all_samples_agwn("../../../../database/cxd-shu/train", Time_Range=78, Cut_MFCC_Enable=True, window_width=256, window_shift=100, nFilter=64, nActual=64, nCeps=48, DCTen=True)
	# 测试本库是否正确
	sample_image, sample_label, sample_name, sample_snr = load_all_sr_samples(file_path="../../../../database/cxd-shu/train", music_path="../../../../database/cxd-shu/music", window_width=256, window_shift=100, nFilter=64, nActual=64, nCeps=48, DCTen=True)
	