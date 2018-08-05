import math
import numpy as np
###############################################################
# 首先是CNN的参数配置
fpr = open("../../../python/keras_cnn/isa-npu/para.txt", "r")
fpw = open("../../04_scripts/cnn_parameter_rom.mif", "w")
para_val_str = []
# 首先加载数据
for lines in fpr:
	if "@" not in lines:
		lines = lines.split("\n")[0]
		para_val_str.append(lines)
# 然后将数据写入到mif文件中
fpw.write("DEPTH = %d;\n"%(int(2**np.ceil(math.log(len(para_val_str)+1)/math.log(2)))))
fpw.write("WIDTH = 32;\n")
fpw.write("ADDRESS_RADIX = HEX;\n")
fpw.write("DATA_RADIX = HEX;\n")
fpw.write("CONTENT\n")
fpw.write("BEGIN\n")
fpw.write("%X : %X;\n"%(0, len(para_val_str)))
for i in range(len(para_val_str)):
	fpw.write("%X : %s;\n"%(i+1, para_val_str[i]))
fpw.write("END;\n")
fpw.close()
#################################################################
# 然后是NPU的指令配置
fpr = open("../../../python/keras_cnn/isa-npu/inst.txt", "r")
fpw = open("../../04_scripts/cnn_instruction_rom.mif", "w")
inst_val_str = []
# 首先加载数据
for lines in fpr:
	if "@" not in lines:
		lines = lines.split("\n")[0]
		inst_val_str.append(lines)
# 然后将数据写入到mif文件中
fpw.write("DEPTH = %d;\n"%(int(2**np.ceil(math.log(len(inst_val_str))/math.log(2)))))
fpw.write("WIDTH = 128;\n")
fpw.write("ADDRESS_RADIX = HEX;\n")
fpw.write("DATA_RADIX = HEX;\n")
fpw.write("CONTENT\n")
fpw.write("BEGIN\n")
for i in range(0, len(inst_val_str)):
	fpw.write("%X : %s;\n"%(i, inst_val_str[i]))
fpw.write("END;\n")
fpw.close()