import matplotlib.pyplot as plt
import numpy as np
import sys
sys.path.append("../serial")
sys.path.append("../mfcc")
import analysis
import my_mfcc
import os
import librosa
import random
import wave
# 带入训练数据文件夹，即可实现训练
# 首尾补齐
def load_all_samples(path, Pad_Zero_Enable=False, Pad_Zero_Length=8000, Use_Label_Enable=False, wav_file=True, **kwarg):
	# 首先进入到数据所在文件夹
	dirs = os.listdir(path)
	# # 构造样本名称的list
	sample_name = list()
	for i in range(0, len(dirs)):
		sample_name.append(dirs[i])
	# 然后遍历所有的文件夹（样本序号）
	sample_wave = list()
	sample_mfcc = list()
	sample_label = list()
	for i in range(0, len(dirs)):
		print("going into %s"%(dirs[i]))
		path_sample = path+"/"+dirs[i]
		files = os.listdir(path_sample)
		#print(files)
		# 遍历所有的文件
		for filename in files:
			#print(filename)
			if "ima" in filename:
				file_t = filename.split(".")[0]
				print(file_t)
				# 加载波形
				Xt = analysis.decompress_ima_file(path_sample+"/"+file_t+".ima")
				# 如果标定文件存在
				if os.path.exists(path_sample+"/"+file_t+".txt") and Use_Label_Enable:
					start, end = analysis.get_start_end_time(path_sample+"/"+file_t+".txt")
					# 前后补零
					if Pad_Zero_Enable==True:
						# 生成start到end的均匀采样
						pts = np.linspace(start, end, num=Pad_Zero_Length, endpoint=True, retstep=False, dtype=np.int)
						Xt = Xt[:, pts]
					else:
						Xt = np.array([Xt[0][start:end]])
				# 保存文件
				if wav_file==True:
					analysis.make_wav_file(Xt[0], filename=path_sample+"/"+file_t+".wav")
				# 提取MFCC特征
				MFCC_t = my_mfcc.MFCC_Extract(Xt[0], **kwarg)
				#MFCC_t = librosa.feature.mfcc(y=Xt[0], sr=8e3, n_fft=256, hop_length=100, power=2, n_mels=64, n_mfcc=12).T
				# 加入最后的样本序列
				sample_wave.append(Xt)
				sample_mfcc.append(MFCC_t)
				sample_label.append(i)
	
	#
	return sample_wave, sample_mfcc, sample_label, sample_name
	
	
#######################

# for signal, power is: Ps = \sigma_{t=0~T-1}{s[t]}/T
# for noise, power is: Pn = \sigma_{t=0~T-1}{n[t]}/T\
# and SNR (signal/noise ratio) = 10*log10(Ps/Pn)

#######################

# 加载所有的数据，并且加入AGWN（高斯白噪声）
# 返回样本特征，以及是否有效语音节点
# Label： 表示是否引用标定数据（用于确定语音始末点，增加噪音用），默认语音的能量是最大的X[t]?
def load_all_samples_agwn(file_path, window_width=256, window_shift=100, SNR=[100, 20, 5, 0], label=True, Time_Range=160, Cut_MFCC_Enable=False, Random_Bias=0, **kwarg):
	# 首先进入到数据所在文件夹
	dirs = os.listdir(file_path)
	# # 构造样本名称的list
	sample_name = list()
	for i in range(0, len(dirs)):
		sample_name.append(dirs[i])
	# 然后遍历所有的文件夹（样本序号）
	sample_wave = list()
	sample_mfcc = list()	 # mfcc特征
	sample_valid = list() # 是否有效语音
	sample_label = list()
	sample_snr = list()	# SNR标签
	for i in range(0, len(dirs)):
		print("going into %s"%(dirs[i]))
		path_sample = file_path+"/"+dirs[i]
		files = os.listdir(path_sample)
		#print(files)
		# 遍历所有的文件
		for filename in files:
			#print(filename)
			if "ima" in filename:
				file_t = filename.split(".")[0]
				#print(file_t)
				# 加载波形
				Xt = analysis.decompress_ima_file(path_sample+"/"+file_t+".ima")
				if label==True:
					start, end = analysis.get_start_end_time(path_sample+"/"+file_t+".txt")
				else:
					#print(np.argmax(Xt[:, :]**2, axis=1))
					start = max([np.argmax(Xt[:, :]**2, axis=1)[0]-2, 0])
					end = min([np.argmax(Xt[:, :]**2, axis=1)[0]+2, Xt.shape[1]])
					#print(start, end)
				# 计算X的平均功率
				PX = (np.mean(Xt[:, start:end]**2, axis=1))
				###########
				# 添加不同SNR的噪声
				for snr_elem in SNR:
					# 添加噪声
					A = np.sqrt(10**(-snr_elem/10)*PX[0])
					x = Xt + A*np.random.randn(Xt.shape[0], Xt.shape[1])
					# 提取MFCC特征
					MFCC_t = my_mfcc.MFCC_Extract(x[0], window_width=window_width, window_shift=window_shift, **kwarg)
					# 加入最后的样本序列
					sample_wave.append(x)
					sample_mfcc.append(MFCC_t)
					sample_valid.append(np.array([int((start-window_width)/window_shift)-1, int((end-window_width)/window_shift)-1]))
					sample_label.append(i)
					sample_snr.append(snr_elem)
					
	# 然后要截取MFCC特征
	sample_mfcc_cut = []
	TimeRange = Time_Range
	if Cut_MFCC_Enable:
		for i in range(len(sample_mfcc)):
			EndFrame = sample_valid[i][1] + random.randint(-Random_Bias, Random_Bias)
			if EndFrame<TimeRange:
				delta = TimeRange - EndFrame
				sample_mfcc_cut.append(np.concatenate((np.tile(sample_mfcc[i][0], (delta, 1)), sample_mfcc[i][0 : EndFrame, :]), axis=0))
			elif EndFrame>=sample_mfcc[i].shape[0]:
				delta = EndFrame - sample_mfcc[i].shape[0]
				sample_mfcc_cut.append(np.concatenate((sample_mfcc[i][EndFrame-TimeRange : , :], np.tile(sample_mfcc[i][-1], (delta, 1))), axis=0))
			else:
				#print(sample_valid[i], sample_mfcc[i].shape, sample_mfcc[i][sample_valid[i][1]-TimeRange : sample_valid[i][1], :].shape)
				sample_mfcc_cut.append(sample_mfcc[i][EndFrame-TimeRange : EndFrame, :])
	#
	return sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut

# 加载所有的数据，并且加入MUSIC（背景音乐）
# 返回样本特征，以及是否有效语音节点
# Label： 表示是否引用标定数据（用于确定语音始末点，增加背景音乐用），默认语音的能量是最大的X[t]?
def load_all_samples_music(file_path, music_path="./music", window_width=256, window_shift=100, SNR=[100, 20, 5, 0], label=True, Time_Range=160, Cut_MFCC_Enable=False, Random_Bias=0, **kwarg):
	# 首先进入到数据所在文件夹
	dirs = os.listdir(file_path)
	# 提取music的文件名称
	music_wave = []
	music_length = []
	music_name = []
	for name in os.listdir(music_path):
		if name[-4:]==".wav":
			# 加载波形
			wavfile =  wave.open(music_path+"/"+name, "rb")
			params = wavfile.getparams()
			framech, framesra,frameswav= params[0], params[2],params[3]
			datawav = wavfile.readframes(frameswav)
			wavfile.close()
			datause = np.fromstring(datawav,dtype = np.short)
			datause.shape = -1, framech
			datause = datause.T * 1.0
			time = np.arange(0, frameswav) * (1.0/framesra)
			# 然后是需要下采样
			# 首先计算音乐的Fs和我们语音采集的8KHz之间的倍数
			fractor = int(framesra/8e3)
			# 
			subsample_pts = np.arange(start=0, stop=frameswav, step=fractor)
			
			music_wave.append(datause[0][subsample_pts])
			music_length.append(subsample_pts.shape[0])
			music_name.append(name)
	
	print("music are loaded...")
	# # 构造样本名称的list
	sample_name = list()
	for i in range(0, len(dirs)):
		sample_name.append(dirs[i])
	# 然后遍历所有的文件夹（样本序号）
	sample_wave = list()
	sample_mfcc = list()	 # mfcc特征
	sample_valid = list() # 是否有效语音
	sample_label = list()
	sample_snr = list()	# SNR标签
	sample_music = list()	# 添加的音乐名称
	for i in range(0, len(dirs)):
		print("going into %s"%(dirs[i]))
		path_sample = file_path+"/"+dirs[i]
		files = os.listdir(path_sample)
		#print(files)
		# 遍历所有的文件
		for filename in files:
			#print(filename)
			if "ima" in filename:
				file_t = filename.split(".")[0]
				#print(file_t)
				# 加载波形
				Xt = analysis.decompress_ima_file(path_sample+"/"+file_t+".ima")
				if label==True:
					start, end = analysis.get_start_end_time(path_sample+"/"+file_t+".txt")
				else:
					#print(np.argmax(Xt[:, :]**2, axis=1))
					start = max([np.argmax(Xt[:, :]**2, axis=1)[0]-2, 0])
					end = min([np.argmax(Xt[:, :]**2, axis=1)[0]+2, Xt.shape[1]])
					#print(start, end)
				# 计算X的功率
				PX = (np.mean(Xt[:, start:end]**2, axis=1))
				###########
				# 每个样本添加掺杂了背景音乐的噪声
				# 添加不同SNR的背景音乐
				for idx in range(len(music_wave)):
					for snr_elem in SNR:
						# 加载音乐
						mu_wave_total = music_wave[idx]
						# 首先随机抽取音乐
						music_start = random.randint(mu_wave_total.shape[0]>>2, (mu_wave_total.shape[0]>>2)*3-Xt.shape[1])
						mu_wave_cut = mu_wave_total[music_start:music_start+Xt.shape[1]]
						# 统计音乐的功率
						Pmusic = (np.mean(mu_wave_cut**2, axis=0))
						# 叠加音乐					
						A = np.sqrt(10**(-snr_elem/10)*PX[0]/(Pmusic+1e-4))
						x = Xt + A*np.tile(mu_wave_cut, (Xt.shape[0], 1))
						# 提取MFCC特征
						MFCC_t = my_mfcc.MFCC_Extract(x[0], window_width=window_width, window_shift=window_shift, **kwarg)
						# 加入最后的样本序列
						sample_wave.append(x)
						sample_mfcc.append(MFCC_t)
						sample_valid.append(np.array([int((start-window_width)/window_shift)-1, int((end-window_width)/window_shift)-1]))
						sample_label.append(i)
						sample_snr.append(snr_elem)
						sample_music.append(idx)
					
	# 然后要截取MFCC特征
	sample_mfcc_cut = []
	TimeRange = Time_Range
	if Cut_MFCC_Enable:
		for i in range(len(sample_mfcc)):
			EndFrame = sample_valid[i][1] + random.randint(-Random_Bias, Random_Bias)
			if EndFrame<TimeRange:
				delta = TimeRange - EndFrame
				sample_mfcc_cut.append(np.concatenate((np.tile(sample_mfcc[i][0], (delta, 1)), sample_mfcc[i][0 : EndFrame, :]), axis=0))
			elif EndFrame>=sample_mfcc[i].shape[0]:
				delta = EndFrame - sample_mfcc[i].shape[0]
				sample_mfcc_cut.append(np.concatenate((sample_mfcc[i][EndFrame-TimeRange : , :], np.tile(sample_mfcc[i][-1], (delta, 1))), axis=0))
			else:
				#print(sample_valid[i], sample_mfcc[i].shape, sample_mfcc[i][sample_valid[i][1]-TimeRange : sample_valid[i][1], :].shape)
				sample_mfcc_cut.append(sample_mfcc[i][EndFrame-TimeRange : EndFrame, :])
	#
	return sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut, sample_music, music_name
	
######## 加载所有样本的函数，添加高斯白噪声、背景音乐噪声
def load_all_samples_bgnoise(file_path, music_path="./music", window_width=256, window_shift=100, SNR=[100, 20, 5, 0], label=True, Time_Range=160, Cut_MFCC_Enable=False, **kwarg):
	# 然后是加入背景音乐的
	sample_wave_2, sample_mfcc_2, sample_label_2, sample_name_2, sample_valid_2, sample_snr_2, sample_mfcc_cut_2, sample_music_2, music_name_2 = load_all_samples_music(file_path=file_path, music_path=music_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, **kwarg)
	# 首先是获取加入高斯白噪声的
	sample_wave_1, sample_mfcc_1, sample_label_1, sample_name_1, sample_valid_1, sample_snr_1, sample_mfcc_cut_1 = load_all_samples_agwn(file_path=file_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, **kwarg)
	sample_music_1 = [len(music_name_2) for i in range(len(sample_mfcc_1))]
	music_name_1 = ["gauss white.wav"]
	# 最难的是样本名称/标签的合并
	sample_name = sample_name_2
	# 把label_1合并到label_2
	sample_label_1 = [sample_name.index(sample_name_1[sample_label_1[i]]) for i in range(len(sample_label_1))]
	
	# 然后是合并
	sample_wave = sample_wave_1 + sample_wave_2
	sample_mfcc = sample_mfcc_1 + sample_mfcc_2
	sample_valid = sample_valid_1 + sample_valid_2
	sample_snr = sample_snr_1 + sample_snr_2
	sample_label = sample_label_1 + sample_label_2
	sample_mfcc_cut = sample_mfcc_cut_1 + sample_mfcc_cut_2
	sample_music = sample_music_1 + sample_music_2
	music_name = music_name_1 + music_name_2
	
	#########################################

#
	return sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut, sample_music, music_name
	
###################### 加载所有的样本，并且添加高斯白噪声，背景音乐噪声，最后随机平移
def load_all_samples_bgnoise_displace(file_path, music_path="./music", window_width=256, window_shift=100, SNR=[100, 20, 5, 0], label=True, Time_Range=160, Cut_MFCC_Enable=False, **kwarg):
	# 然后是加入背景音乐的
	_, _, sample_label_2, sample_name_2, _, sample_snr_2, sample_mfcc_cut_2, _, _ = load_all_samples_music(file_path=file_path, music_path=music_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, **kwarg)
	# 首先是获取加入高斯白噪声的
	_, _, sample_label_1, sample_name_1, _, sample_snr_1, sample_mfcc_cut_1 = load_all_samples_agwn(file_path=file_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, **kwarg)
	
	# 最难的是样本名称/标签的合并
	sample_name = sample_name_2
	# 把label_1合并到label_2
	sample_label_1 = [sample_name.index(sample_name_1[sample_label_1[i]]) for i in range(len(sample_label_1))]
	
	# 然后是合并
	sample_snr = sample_snr_1 + sample_snr_2
	sample_label = sample_label_1 + sample_label_2
	sample_mfcc_cut = sample_mfcc_cut_1 + sample_mfcc_cut_2
	
	##############
	# 然后是加入平移量
	
	_, _, sample_label_2, sample_name_2, _, sample_snr_2, sample_mfcc_cut_2, _, _ = load_all_samples_music(file_path=file_path, music_path=music_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, Random_Bias=50, **kwarg)
	sample_label_2 = [sample_name.index(sample_name_2[sample_label_2[i]]) for i in range(len(sample_label_2))]
	# 然后是合并
	sample_snr = sample_snr + sample_snr_2
	sample_label = sample_label + sample_label_2
	sample_mfcc_cut = sample_mfcc_cut + sample_mfcc_cut_2
	
	_, _, sample_label_2, sample_name_2, _, sample_snr_2, sample_mfcc_cut_2, _, _ = load_all_samples_music(file_path=file_path, music_path=music_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, Random_Bias=20, **kwarg)
	sample_label_2 = [sample_name.index(sample_name_2[sample_label_2[i]]) for i in range(len(sample_label_2))]
	# 然后是合并
	sample_snr = sample_snr + sample_snr_2
	sample_label = sample_label + sample_label_2
	sample_mfcc_cut = sample_mfcc_cut + sample_mfcc_cut_2
	
	_, _, sample_label_2, sample_name_2, _, sample_snr_2, sample_mfcc_cut_2 = load_all_samples_agwn(file_path=file_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, Random_Bias=50, **kwarg)
	sample_label_2 = [sample_name.index(sample_name_2[sample_label_2[i]]) for i in range(len(sample_label_2))]
	# 然后是合并
	sample_snr = sample_snr + sample_snr_2
	sample_label = sample_label + sample_label_2
	sample_mfcc_cut = sample_mfcc_cut + sample_mfcc_cut_2
	
	_, _, sample_label_2, sample_name_2, _, sample_snr_2, sample_mfcc_cut_2 = load_all_samples_agwn(file_path=file_path, window_width=window_width, window_shift=window_shift, SNR=SNR, label=label, Time_Range=Time_Range, Cut_MFCC_Enable=Cut_MFCC_Enable, Random_Bias=20, **kwarg)
	sample_label_2 = [sample_name.index(sample_name_2[sample_label_2[i]]) for i in range(len(sample_label_2))]
	# 然后是合并
	sample_snr = sample_snr + sample_snr_2
	sample_label = sample_label + sample_label_2
	sample_mfcc_cut = sample_mfcc_cut + sample_mfcc_cut_2
	
	return [], [], sample_label, sample_name, [], sample_snr, sample_mfcc_cut, [], []
	
#################################################################
# 主函数
# 测试用
if __name__ == '__main__':
	# 测试load_sample库是否正确？
	#sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut = load_all_samples_agwn("../../../database/cxd-shu/train", SNR=[100], Time_Range=78, Cut_MFCC_Enable=True, window_width=256, window_shift=100, nFilter=64, nActual=64, nCeps=48, DCTen=True)
	#sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut, sample_music, music_name = load_all_samples_music("../../../database/cxd-shu/train", SNR=[100, 50, 20, 5, 0], Time_Range=78, Cut_MFCC_Enable=True, window_width=256, window_shift=100, nFilter=64, nActual=64, nCeps=48, DCTen=True)
	sample_wave, sample_mfcc, sample_label, sample_name, sample_valid, sample_snr, sample_mfcc_cut, sample_music, music_name = load_all_samples_bgnoise("../../../database/cxd-shu/train", SNR=[100, 50, 20, 5, 0], Time_Range=78, Cut_MFCC_Enable=True, window_width=256, window_shift=100, nFilter=64, nActual=64, nCeps=48, DCTen=True)
	
	print("samples loaded...")
	#%%
	plt.figure(figsize=(12,12))
	k=-5
	plt.subplot(5,3,1); plt.title("SNR=100 dB wave"); plt.plot(sample_wave[k][0]);
	plt.subplot(5,3,2); plt.title("SNR=100 dB mfcc"); plt.imshow(sample_mfcc[k].T, aspect="auto");
	plt.subplot(5,3,3); plt.title("SNR=100 dB mfcc [1s before end]"); plt.imshow(sample_mfcc_cut[k].T, aspect="auto");
	k=k+1
	plt.subplot(5,3,4); plt.title("SNR=50 dB wave"); plt.plot(sample_wave[k][0]);
	plt.subplot(5,3,5); plt.title("SNR=50 dB mfcc"); plt.imshow(sample_mfcc[k].T, aspect="auto");
	plt.subplot(5,3,6); plt.title("SNR=50 dB mfcc [1s before end]"); plt.imshow(sample_mfcc_cut[k].T, aspect="auto");
	k=k+1
	plt.subplot(5,3,7); plt.title("SNR=20 dB wave"); plt.plot(sample_wave[k][0]);
	plt.subplot(5,3,8); plt.title("SNR=20 dB mfcc"); plt.imshow(sample_mfcc[k].T, aspect="auto");
	plt.subplot(5,3,9); plt.title("SNR=20 dB mfcc [1s before end]"); plt.imshow(sample_mfcc_cut[k].T, aspect="auto");
	k=k+1
	plt.subplot(5,3,10); plt.title("SNR=5 dB wave"); plt.plot(sample_wave[k][0]);
	plt.subplot(5,3,11); plt.title("SNR=5 dB mfcc"); plt.imshow(sample_mfcc[k].T, aspect="auto");
	plt.subplot(5,3,12); plt.title("SNR=5 dB mfcc [1s before end]"); plt.imshow(sample_mfcc_cut[k].T, aspect="auto");
	k=k+1
	plt.subplot(5,3,13); plt.title("SNR=0 dB wave"); plt.plot(sample_wave[k][0]);
	plt.subplot(5,3,14); plt.title("SNR=0 dB mfcc"); plt.imshow(sample_mfcc[k].T, aspect="auto");
	plt.subplot(5,3,15); plt.title("SNR=0 dB mfcc [1s before end]"); plt.imshow(sample_mfcc_cut[k].T, aspect="auto");
	analysis.make_wav_file(sample_wave[k][0], filename="0dB music.wav")
	
	plt.subplots_adjust(top=0.92, bottom=0.08, left=0.20, right=0.9, hspace=0.5, wspace=0.5)