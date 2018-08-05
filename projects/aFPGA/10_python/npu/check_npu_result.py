import numpy as np
import matplotlib.pyplot as plt
#%# 测试
plt.figure(figsize=(8,8))
R = 5
C = 2
#%# 首先是ADD指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-add.txt')
python = np.loadtxt('./fp_add_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 1) 
plt.title('add inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是ADDi指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-addi.txt')
python = np.loadtxt('./fp_addi_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 2) 
plt.title('addi inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是tanh指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-tanh.txt')
python = np.loadtxt('./fp_tanh_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
ax1 = plt.subplot(R, C, 3) 
plt.title('tanh inst')
ax1.plot(np.arange(error_ratio.shape[0]), error_ratio, 'b')
ax2 = ax1.twinx()
ax2.plot(np.arange(error_ratio.shape[0]), error_abs/65536, 'r')
idx=np.argmax(error_ratio)
#%# 首先是dot指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-dot.txt')
python = np.loadtxt('./fp_dot_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 4) 
plt.title('dot inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是conv指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-conv.txt')
python = np.loadtxt('./fp_conv_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/(python))
plt.subplot(R, C, 5) 
plt.title('conv inst:%f'%(np.mean(error_ratio)))
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是pool指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-pool.txt')
python = np.loadtxt('./fp_pool_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 6) 
plt.title('pool inst:%f'%(np.mean(error_ratio)))
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是mult指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-mult.txt')
python = np.loadtxt('./fp_mult_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 7) 
plt.title('mult inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是tran指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-tran.txt')
python = np.loadtxt('./fp_tran_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 8) 
plt.title('tran inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是gray指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-gray.txt')
python = np.loadtxt('./fp_gray_test.txt')
modelsim = modelsim / 2**16
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 9) 
plt.title('gray inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#%# 首先是ADDs指令
modelsim = np.loadtxt('../../05_modelsim/npu_result-adds.txt')
python = np.loadtxt('./fp_adds_test.txt')
error = modelsim - python
error_abs = np.absolute(error)
error_ratio = np.absolute(error/python)
plt.subplot(R, C, 10) 
plt.title('adds inst')
plt.plot(error_ratio, 'o')
idx=np.argmax(error_ratio)
#######
plt.subplots_adjust(top=0.92, bottom=0.08, left=0.20, right=0.9, hspace=0.5, wspace=0.5)