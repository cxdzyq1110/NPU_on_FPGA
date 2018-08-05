# -*- coding:utf-8 -*-
#####################################

import generate_cnn_layers as gen_cnn

import numpy as np

##########################################

#%%
import generate_npu_inst as gen_inst
#########################################
# 测试用
if __name__ == '__main__':
	#%% 用H表征网络结构，P来表征参数，用D来表征数据
	H = gen_cnn.generate_cnn()

	dict_para_addr, dict_para_val, inst_set = gen_inst.generate_npu_inst(H, value_enable=False)