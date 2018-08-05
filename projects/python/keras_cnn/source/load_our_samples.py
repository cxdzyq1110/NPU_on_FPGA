from keras.datasets import mnist
import numpy as np
##################################################################
def load_all_mnist_samples(padHeight = 4, padWidth = 4):
	# the data, split between train and test sets
	(xx_train, yy_train), (xx_test, yy_test) = mnist.load_data()
	# 裁剪/扩充
	x_train = np.zeros((xx_train.shape[0], padHeight+xx_train.shape[1], padWidth+xx_train.shape[2], 1), dtype=np.uint8)
	y_train = yy_train
	x_test = np.zeros((xx_test.shape[0], padHeight+xx_test.shape[1], padWidth+xx_test.shape[2], 1), dtype=np.uint8)
	y_test = yy_test
	# 
	index_height_start = padHeight//2 
	index_height_end = padHeight//2 + xx_train.shape[1]
	index_width_start = padWidth//2 
	index_width_end = padWidth//2 + xx_train.shape[2]
	for strain in range(xx_train.shape[0]):
		x_train[strain][index_height_start:index_height_end, index_width_start:index_width_end, 0] = xx_train[strain]
	for stest in range(xx_test.shape[0]):
		x_test[stest][index_height_start:index_height_end, index_width_start:index_width_end, 0] = xx_test[stest]
	# 返回
	return x_train, y_train, x_test, y_test
#################################################################
# 主函数
# 测试用
if __name__ == '__main__':
	x_train, y_train, x_test, y_test = load_all_mnist_samples()