import matplotlib.pyplot as plt
import itertools
# 混淆矩阵
def plot_sonfusion_matrix(cm, classes, normalize=False, title='Confusion matrix',cmap=plt.cm.Blues, filename="../model/model_confusion_matrix.jpg"):
	plt.figure(figsize=(8,8))
	plt.imshow(cm, interpolation='nearest', cmap=cmap)
	plt.title(title)
	plt.colorbar(shrink=0.75)
	tick_marks = np.arange(len(classes))
	plt.xticks(tick_marks, classes, rotation=45)
	plt.yticks(tick_marks, classes)
	if normalize:
		cm = cm.astype('float')/cm.sum(axis=1)[:,np.newaxis]
	thresh = cm.max()/2.0
	for i,j in itertools.product(range(cm.shape[0]), range(cm.shape[1])):
		plt.text(j,i,cm[i,j], horizontalalignment='center',color='white' if cm[i,j] > thresh else 'black')
	#plt.tight_layout()
	plt.ylabel('True label')
	plt.xlabel('Predict label')
	
	## 保存
	plt.savefig(filename) 

#
from sklearn.metrics import confusion_matrix	 # 混淆矩阵
import numpy as np

def confusion_matrix_plot(pred_y, val_y, label_name, filename="../model/model_confusion_matrix.jpg"):
	pred_label = np.argmax(pred_y, axis=1)
	true_label = np.argmax(val_y, axis=1)
	confusion_mat = confusion_matrix(true_label, pred_label)
	# 首先可以保存在csv文件中，便于excel直接打开查看
	np.savetxt(filename+".csv", confusion_mat, fmt="%d", delimiter=",")
	plot_sonfusion_matrix(confusion_mat, classes = range(val_y.shape[1]), filename=filename)