def generate_cnn(filename = "../scripts/网络描述文件.txt"):
	H = []
	fp = open(filename, "r")
	for lines in fp:
		layer = []
		elements = lines.split("\n")[0].split(":")
		if elements[0]=="I":
			hwc = elements[1].split(",")
			layer.append("I")
			layer.append(int(hwc[0]))
			layer.append(int(hwc[1]))
			layer.append(int(hwc[2]))
			H.append(layer)
		else:
			layer_info = elements[1].replace(" ","").split(",")
			if layer_info[0]=="C":
				layer.append("C")
				layer.append(int(layer_info[1]))
				layer.append(int(layer_info[2]))
				layer.append(int(layer_info[3]))
				layer.append((layer_info[4]))
				# 查看是不是有dropout
				if layer_info[-1]=="dropout":
					layer.append("dropout")
				else:
					layer.append("")
				H.append(layer)
			elif layer_info[0]=="S":
				layer.append("S")
				layer.append(int(layer_info[1]))
				layer.append(int(layer_info[2]))
				# 查看是不是有dropout
				if layer_info[-1]=="dropout":
					layer.append("dropout")
				else:
					layer.append("")
				H.append(layer)
			elif layer_info[0]=="STRIP":
				layer.append("STRIP")
				layer.append(int(layer_info[1]))
				# 查看是不是有dropout
				if layer_info[-1]=="dropout":
					layer.append("dropout")
				else:
					layer.append("")
				H.append(layer)
			elif layer_info[0]=="FC":
				layer.append("FC")
				layer.append(int(layer_info[1]))
				layer.append(int(layer_info[2]))
				layer.append((layer_info[3]))
				# 查看是不是有dropout
				if layer_info[-1]=="dropout":
					layer.append("dropout")
				else:
					layer.append("")
				H.append(layer)
	
	fp.close()
	print(H)
	return H
	
if __name__ == '__main__':
	generate_cnn()