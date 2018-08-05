# -*- coding: utf-8 -*-
"""
Created on Sun Jun 10 09:04:03 2018

@author: xdche
"""

import numpy as np
import matplotlib.pyplot as plt
#%% 测试CORDIC的运算结果
D = np.loadtxt("../../05_modelsim/cordic_ln.txt", delimiter=",", skiprows=1)
X = np.absolute(D[:, 0])
Y = D[:, 1]
T = np.log(X/65536)*65536
#
ER = np.absolute((Y-T)/T)
plt.plot(ER)