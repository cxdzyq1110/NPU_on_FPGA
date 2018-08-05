import math
import numpy as np
from scipy import signal
#%% 全自动的数据生成
M = 16; N = 100; 
AddImm = 1000;
MAT_M = 3; MAT_N = 5; MAT_P = 7;
Pm = 5; Pn = 5;
Km = 5; Kn = 5;
MODE = 1;

fpp = open("./npu_verification_para.list", "w")
fpp.write("%d\n"%(M))
fpp.write("%d\n"%(N))
fpp.write("%d\n"%(AddImm))
fpp.write("%d\n"%(MAT_M))
fpp.write("%d\n"%(MAT_N))
fpp.write("%d\n"%(MAT_P))
fpp.write("%d\n"%(Km))
fpp.write("%d\n"%(Kn))
fpp.write("%d\n"%(Pm))
fpp.write("%d\n"%(Pn))
fpp.write("%d\n"%(MODE))
fpp.close()
#%%
fpd = open("./source_sram_dq.list", "w")

#%% 首先是原始的图像数据
Dollar1 = np.random.randint(-50,-1, size=(M,N))*2**16
fpd.write("@%X\n"%(2*0x010000))
for i in range(0, M):
	for j in range(0, N):
		tmp_v = int(Dollar1[i, j])
		if tmp_v<0:
			tmp_v = tmp_v + 0x100000000
		fpd.write("%04X\n"%((tmp_v >> 0)&0xFFFF))
		fpd.write("%04X\n"%((tmp_v >> 16)&0xFFFF))
		
#%% 另一张图像的数据		
Dollar22 = np.random.randint(-15,-10, size=(M,N))*2**16
fpd.write("@%X\n"%(2*0x020000))
for i in range(0, M):
	for j in range(0, N):
		tmp_v = int(Dollar22[i, j])
		if tmp_v<0:
			tmp_v = tmp_v + 0x100000000
		fpd.write("%04X\n"%((tmp_v >> 0)&0xFFFF))
		fpd.write("%04X\n"%((tmp_v >> 16)&0xFFFF))

#%% 然后是图像的加减乘
fp_add = open("./fp_add_test.txt", "w")
fp_addi = open("./fp_addi_test.txt", "w")
fp_sub = open("./fp_sub_test.txt", "w")
fp_dot = open("./fp_dot_test.txt", "w")
# 输出到文本
for i in range(0, len(Dollar1)):
	for j in range(0, len(Dollar1[0])):
		add_value = int((Dollar1[i, j]+Dollar22[i, j]))
		addi_value = int((Dollar1[i, j]+AddImm))
		sub_value = int((Dollar1[i, j]-Dollar22[i, j]))
		dot_value = int((Dollar1[i, j]/2**16*Dollar22[i, j]))
		fp_add.write("%d\n"%(add_value))
		fp_sub.write("%d\n"%(sub_value))
		fp_dot.write("%d\n"%(dot_value))
		fp_addi.write("%d\n"%(addi_value))
		
fp_add.close()
fp_addi.close()
fp_sub.close()
fp_dot.close()

#%% 矩阵转置变换
fp_tran = open("./fp_tran_test.txt", "w")
# 输出到文本
for j in range(0, len(Dollar1[0])):
	for i in range(0, len(Dollar1)):
		tran_value = int((Dollar1[i, j]))
		fp_tran.write("%d\n"%(tran_value))

fp_tran.close()

#%% 卷机运算卷积核
kernel = np.random.randint(-15,10, size=(Km,Kn))*2**16
fpd.write("@%X\n"%(2*0x030000))
for i in range(0, len(kernel)):
	for j in range(0, len(kernel[0])):
		tmp_v = int(kernel[i, j])
		if tmp_v<0:
			tmp_v = tmp_v + 0x100000000
		fpd.write("%04X\n"%((tmp_v >> 0)&0xFFFF))
		fpd.write("%04X\n"%((tmp_v >> 16)&0xFFFF))
		
d1 = Dollar1
d2 = kernel

d1x = d1/2**16;
d2x = d2/2**16;

dcx = (signal.convolve2d(d1x, d2x, 'valid') * 2**16).astype(np.int)
# 输出到文本
fp_conv = open("./fp_conv_test.txt", "w")
for i in range(0, len(dcx)):
	for j in range(0, len(dcx[0])):
		conv_value = int(dcx[i, j])
		fp_conv.write("%d\n"%(conv_value))

fp_conv.close()

#%% 然后是计算pooling
fp_pool = open("./fp_pool_test.txt", "w")
dpx = np.zeros((M//Pm, N//Pn))
for i in range(0, M//Pm):
	for j in range(0, N//Pn):
		if MODE==0:
			dpx[i, j] = np.mean(d1x[Pm*i:Pm*i+Pm, Pn*j:Pn*j+Pn])
		elif MODE==1:
			dpx[i, j] = np.max(d1x[Pm*i:Pm*i+Pm, Pn*j:Pn*j+Pn])
			
		pool_value = int(2**16*dpx[i, j])
		fp_pool.write("%d\n"%(pool_value))

fp_pool.close()

#%% 然后是要验证MULT矩阵乘法指令
mat1 = np.random.randint(-1,2, size=(MAT_M,MAT_N))
mat2 = np.random.randint(-2,-1, size=(MAT_N,MAT_P))
mat1_216 = 2**16*mat1
mat2_216 = 2**16*mat2
mat3 = np.dot(mat1, mat2)

fpd.write("@%X\n"%(2*0x040000))
# 矩阵乘法的源数据
for i in range(0, len(mat1)):
	for j in range(0, len(mat1[0])):
		mult_value = int(2**16*mat1[i, j])
		fpd.write("%04X\n"%((mult_value >> 0)&0xFFFF))
		fpd.write("%04X\n"%((mult_value >> 16)&0xFFFF))
		
fpd.write("@%X\n"%(2*0x050000))
for i in range(0, len(mat2)):
	for j in range(0, len(mat2[0])):
		mult_value = int(2**16*mat2[i, j])
		fpd.write("%04X\n"%((mult_value >> 0)&0xFFFF))
		fpd.write("%04X\n"%((mult_value >> 16)&0xFFFF))
		
		
# 输出到文本
fp_mult = open("./fp_mult_test.txt", "w")
for i in range(0, len(mat3)):
	for j in range(0, len(mat3[0])):
		mult_value = int(2**16*mat3[i, j])
		fp_mult.write("%d\n"%(mult_value))

fp_mult.close()
#%% 
######################
fp_tanh = open("./fp_tanh_test.txt", "w")
Dollar2 = np.random.randn(M,N)*2**16
fpd.write("@%X\n"%(2*0x060000))
for i in range(0, M):
	for j in range(0, N):
		tmp_v = int(Dollar2[i, j])
		if tmp_v<0:
			tmp_v = tmp_v + 0x100000000
			
		fpd.write("%04X\n"%((tmp_v >> 0)&0xFFFF))
		fpd.write("%04X\n"%((tmp_v >> 16)&0xFFFF))
		
		tanh_value = int(2**16*math.tanh(Dollar2[i, j]/(2**16)))
			
		fp_tanh.write("%d\n"%(tanh_value))
		
fp_tanh.close()

#%% 矩阵±标量的运算
fp_adds = open("./fp_adds_test.txt", "w")
Dollar2_ini = Dollar2[0, 0]
# 输出到文本
for i in range(0, len(Dollar1)):
	for j in range(0, len(Dollar1[0])):
		adds_value = int((Dollar1[i, j] + Dollar2_ini))
		fp_adds.write("%d\n"%(adds_value))

fp_adds.close()

#%% RGB565转灰度图函数变换
fp_gray = open("./fp_gray_test.txt", "w")
fpd.write("@%X\n"%(2*0x070000))
red = np.random.randint(0,2**5, size=(M,N))
green = np.random.randint(0,2**6, size=(M,N))
blue = np.random.randint(0,2**5, size=(M,N))
rgb565 = red*2**11 + green*2**5 + blue
# 输出到文本
for i in range(0, len(rgb565)):
	for j in range(0, len(rgb565[0])):
		r = ((rgb565[i][j]>>11) & 0x1F) *8
		g = ((rgb565[i][j]>>5) & 0x3F) *4
		b = ((rgb565[i][j]>>0) & 0x1F) *8
		gray_value = int((r*66 + g*129 + b*25)/256) + 16
		if gray_value<16:
			gray_value = 16
		elif gray_value>235:
			gray_value = 235
		
		# 吸入文件中
		fpd.write("%04X\n"%((rgb565[i][j] >> 0)&0xFFFF))
		fpd.write("%04X\n"%((rgb565[i][j] >> 16)&0xFFFF))
		fp_gray.write("%d\n"%(gray_value))

fp_gray.close()

#%% 关闭所有文件

fpd.close()