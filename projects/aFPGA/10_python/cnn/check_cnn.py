import matplotlib.pyplot as plt
import numpy as np
#%%
# 删除文件中的空白行
# 参考：https://www.cnblogs.com/billyzh/p/5851429.html 
def delblankline(infile,outfile):
    infopen = open(infile,'r')
    outfopen = open(outfile,'w')
    lines = infopen.readlines()
    line_cnt = 0
    blank_line = []
    for line in lines:
        if line.split():
            outfopen.writelines(line)
            line_cnt = line_cnt + 1
        else:
            outfopen.writelines("")
            blank_line.append(line_cnt)
    infopen.close()
    outfopen.close()
    
    return np.array(blank_line)
#####################################
################## 删除空白行并且加载数据 ##########################
filename = '../../05_modelsim/cnn-result-data_under_test.txt'
delblankline(filename, filename+'.del.txt')
x = np.loadtxt(filename+'.del.txt')
filename = '../../../python/keras_cnn/isa-npu/ver_compare/sp-5.txt'
blank_line = delblankline(filename, filename+'.del.txt')[1:]
y = np.loadtxt(filename+'.del.txt')
layer = np.zeros(y.shape)
for t in range(blank_line.shape[0]):
    layer[blank_line[t]] = t
###################################################################
NO = 10	# 输出的向量维度
plt.figure(figsize=(9,9))
x2 = x
x = x[:y.shape[0]]
error = np.absolute(x-y)/2**16
error_rel = error/(y/2**16 + 1e-3)
error_out = np.absolute(x[x.shape[0]-NO:x.shape[0]]-y[y.shape[0]-NO:y.shape[0]])/2**16
plt.subplot(4,1,1); plt.plot(error); plt.title('absolute error for every step'); plt.xlabel('step'); plt.ylabel('absolute error');
plt.subplot(4,1,2); plt.plot(y/2**16); plt.title('float-point result for every step'); plt.xlabel('step'); plt.ylabel('fp result');
plt.subplot(4,1,3); plt.plot(error_rel); plt.title('relative error for every step [%f]'%(np.mean(error_rel))); plt.xlabel('step'); plt.ylabel('relative error'); plt.ylim((0, 5))
plt.subplot(4,1,4); plt.plot(error_out); plt.title('absolute error for output'); plt.xlabel('output index'); plt.ylabel('absolute error');
plt.subplots_adjust(top=0.92, bottom=0.08, left=0.20, right=0.9, hspace=0.6, wspace=0.5)