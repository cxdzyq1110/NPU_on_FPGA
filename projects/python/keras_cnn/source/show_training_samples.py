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

# 采样频率
Fs = 8e3
window_width = 256
window_shift=100
SNR = [50, 20, 10, 5, 0]
Time_Range=78
nCeps=16
#################################################################
#%% 首先是不添加噪声的
# 创建文件夹
dir_path = "../samples/no-noise"
if not os.path.exists(dir_path):
	os.mkdir(dir_path)
# 加载数据
sample_wave, sample_mfcc, sample_label, sample_name = load_sample.load_all_samples(path="../../../../database/cxd-shu/train", wav_file=False, window_width=window_width, window_shift=window_shift, nFilter=64, nActual=64, nCeps=nCeps, DCTen=True)
#%% 首先对于不同的语音
for i in range(len(sample_name)):
	plt.figure(figsize=(6, 4))
	# 选择该类型下面的一个语音样本
	idx = sample_label.index(i)
	plt.subplot(211); plt.title("audio wave"); plt.plot(sample_wave[idx][0]);
	plt.subplot(212); plt.title("audio mfcc"); plt.imshow(sample_mfcc[idx].T, aspect="auto");
	plt.subplots_adjust(top=0.92, bottom=0.08, left=0.20, right=0.9, hspace=0.5, wspace=0.5)
	# 保存文件
	plt.savefig(dir_path+"/"+sample_name[i]+".jpg") 
	
#################################################################
#%% 然后是带上AGWN噪声的
dir_path = "../samples/agwn-noise"
if not os.path.exists(dir_path):
	os.mkdir(dir_path)
	
# 加载数据
sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut = load_sample.load_all_samples_agwn("../../../../database/cxd-shu/train", SNR=SNR, Time_Range=Time_Range, Cut_MFCC_Enable=True, window_width=window_width, window_shift=window_shift, nFilter=64, nActual=64, nCeps=nCeps, DCTen=True)
#%% 首先对于不同的语音
for i in range(len(sample_name)):
	# 选择该类型下面的一个语音样本
	idx = sample_label.index(i)
	# 遍历所有的噪声
	# 首先是波形 & MFCC
	plt.figure(figsize=(5*len(SNR), 4))
	for j in range(len(SNR)):
		plt.subplot(2,len(SNR), j+1); plt.title("audio wave [SNR=%d dB]"%(SNR[j])); plt.plot(sample_wave[idx+j][0]);
		plt.subplot(2,len(SNR), j+1+len(SNR)); plt.title("audio mfcc [SNR=%d dB]"%(SNR[j])); plt.imshow(sample_mfcc[idx+j].T, aspect="auto");
		plt.subplots_adjust(top=0.92, bottom=0.08, left=0.20, right=0.9, hspace=0.5, wspace=0.5)
	# 保存文件
	plt.savefig(dir_path+"/"+sample_name[i]+"-whole"+".jpg") 
	# 然后是有效时间区间内的MFCC
	plt.figure(figsize=(4*len(SNR), 3))
	for j in range(len(SNR)):
		plt.subplot(1,len(SNR), j+1); plt.title("audio mfcc [SNR=%d dB]"%(SNR[j])); plt.imshow(sample_mfcc_cut[idx+j].T, aspect="auto");
	# 保存文件
	plt.savefig(dir_path+"/"+sample_name[i]+"-valid"+".jpg") 
	
#%% 然后是带上背景音乐噪声的
dir_path = "../samples/bg-music"
if not os.path.exists(dir_path):
	os.mkdir(dir_path)
	
# 加载数据
sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut, sample_music, music_name = load_sample.load_all_samples_music(file_path="../../../../database/cxd-shu/train", music_path="../../load_sample/music", SNR=SNR, Time_Range=Time_Range, Cut_MFCC_Enable=True, window_width=window_width, window_shift=window_shift, nFilter=64, nActual=64, nCeps=nCeps, DCTen=True)
#%% 首先对于不同的语音
for i in range(len(sample_name)):
	# 选择该类型下面的一个语音样本
	idx = sample_label.index(i)
	# 遍历所有的音乐
	for j in range(len(music_name)):
		# 首先是波形 & MFCC
		plt.figure(figsize=(5*len(SNR), 4))
		# 遍历所有的SNR
		for k in range(len(SNR)):
			plt.subplot(2,len(SNR), k+1); plt.title("audio wave [SNR=%d dB]"%(SNR[k])); plt.plot(sample_wave[idx+j*len(SNR)+k][0]);
			plt.subplot(2,len(SNR), k+1+len(SNR)); plt.title("audio mfcc [SNR=%d dB]"%(SNR[k])); plt.imshow(sample_mfcc[idx+j*len(SNR)+k].T, aspect="auto");
			plt.subplots_adjust(top=0.92, bottom=0.08, left=0.20, right=0.9, hspace=0.5, wspace=0.5)
		# 保存文件
		plt.savefig(dir_path+"/"+sample_name[i]+"+"+music_name[j]+"-whole"+".jpg") 
		# 然后是有效时间区间内的MFCC
		plt.figure(figsize=(4*len(SNR), 3))
		for k in range(len(SNR)):
			plt.subplot(1,len(SNR), k+1); plt.title("audio mfcc [SNR=%d dB]"%(SNR[k])); plt.imshow(sample_mfcc_cut[idx+j*len(SNR)+k].T, aspect="auto");
		# 保存文件
		plt.savefig(dir_path+"/"+sample_name[i]+"+"+music_name[j]+"-valid"+".jpg") 
	
