# 语音识别项目
在FPGA上面实现一个基于 MFCC+CNN 的语音识别系统。  
选用DE2-115开发板，FPGA外接音频编解码芯片wm8731，存储芯片SRAM 2MB  

## 00\_user\_logic
里面存放了各个模块的verilog逻辑代码

### · arith
> fixed_sdiv.v  
> 这是定点除法器模块，流水线型运算  
> 能够在24个clock里面完成32-bit/16-bit【Q16.16】定点除法  
> 时钟频率为100 MHz

### · audio
> audio\_codec.v / audio\_macro.inc / audio_save.v  
>音频编解码芯片的调度模块，  
>audio\_save.v模块支持avalon接口协议，直接生成DDR的写入请求

### · cordic
> cordic\_ln.v / cordic\_rot.v / cordic\_exp\_rtl.v / cordic\_tanh\_sigm\_rtl.v  
> 考虑到之后的运算里面要大量使用 log(x) / exp(x) / sigmoid(x) 等超越函数，  
> 所以写了一个基于CORDIC的流水线型 ln(x) 函数求解器 cordic\_ln.v  
> 基于CORDIC计算的向量求模、求夹角的函数求解器 cordic\_rot.v  
> 基于CORDIC算法的 exp() 运算函数  cordic\_exp\_rtl.v  
> 也是基于 exp() 函数，再实现了 sigmoid() / tanh() 这两个函数 cordic\_tanh\_sigm\_rtl.v  
> 另外，fixed_sdiv.v 这个模块就是实现了 signed 定点数的除法运算

### · dcfifo
> dc\_fifo.v / gray\_dec\_1p.v / gray\_enc\_1p.v / sync\_dual\_clock.v  
> 这里是DCFIFO的rtl代码，使用gray码实现跨时钟域的同步


### · dsp
> fft\_fft\_rtl\_ip.v / fft\_fft\_rtl.v / fft\_butterfly\_rtl.v  
> 之后要有MFCC特征提取过程，所以需要有一个FFT计算模块、以及后续的复数求模  
> 对于N点的FFT运算，能够在 N*log2(N) 个clock周期内完成，而且工作频率达100 MHz  

### · framing
> framing.v / window.v
> 分别是分帧和加窗函数的模块

### · i2c
> i2c\_macro.inc 和 i2c\_user\_fsm.v  
>提供了I2C接口的verilog模块代码
###· mux\_ddr\_access.v
>提供了DDR/SDRAM等存储器读写调度器，遵循avalon接口协议；  
>对于SSRAM/SRAM有将近100%的效率；  
>但是SDRAM则不行，一定要用burst才可以，建议在外部再增加一个类似cache的机制
> wm8731\_config.v  
>调用I2C接口模块，对wm8731芯片进行配置


### · matrix
> mat\_mult\_unit.v / mat\_mac\_elem.v  
> 矩阵乘法模块，因为用了onchip memory，所以数据读写的时钟周期固定  
> 不过这样容易占用不多的 OCM，比较消耗资源  
> 使用矩阵乘法，可以实现PCA，对提取到的特征进行降维

### · mfcc
> mfcc\_extract.v
> 这是MFCC特征提取的模块，输入：FFT给出的频谱，输出：当前帧的MFCC特征  
> 能够同步计算功率谱

> mfcc\_exchanger.v
> 这是将最新的TimeRange帧的MFCC特征搬运到CNN输入数据存放的内存地址  
> 然后启动NPU运算，并且等待NPU运算完成后，将CNN分类结果输出到LED灯  

### · multiport
> mux\_ddr\_access.v  
> 这是多端口调度器

### · npu
> npu\_paras\_config.v  
> 将ROM中存放的CNN的参数配置到DDR当中去  
> npu\_inst\_join.v / npu\_inst\_excutor.v / npu\_inst\_fsm.v
> 模块 npu\_inst\_join.v 实现了将 32-bit 的短命令，拼接成 128-bit 长命令，使用超时等待机制  
> npu\_inst_excutor.v 模块则是一个 tiny版本的 ISA-NPU，缺少分支跳转的指令，但是基本的矩阵/图像运算都有  
> npu\_inst\_fsm.v 模块则是一个wrap了 ISA-NPU的模块，能够接受、缓存外部指令，并控制ISA-NPU的运算  
> npu\_conv\_rtl.v 模块，实现了**任意尺寸**的 convolution / max-pooling / mean-pooling，但是例化的时候，必须指定(Km, Kn, ATlayer)参数：Km x Kn表示最大可能的卷积/池化尺寸；ATlayer = ceil( log2( Km * Kn ) ) + 1 需要使用者提前自己计算好

### · parser
> cmd\_parser.v  
>host主机命令解析与执行器

###· ram
> dpram\_2p.v
> 双端口RAM的rtl描述

###· scfifo
> sc\_fifo.v
> 单时钟FIFO的rtl描述  
> ！注意，在标志位的生成上可能还有bug

### · sram
> sram\_controller.v  
>SRAM控制器，时序上貌似还有问题（？）

### · uart
> uart\_wr.v / uart\_rtl.v / uart\_conf.inc  
>串口读写器，可以在inc文件中配置串口的baudrate  
>而uart_wr.v模块则是在串口调度器外部接上了两个收发fifo，遵循avalon接口

### · vad
> vad\_sp\_entropy.v / vad\_zero\_pass.v / vad\_pca.v / vad\_svm.v  
> 用来实现VAD语音端点检测的模块  
> 其中，vad\_sp\_entropy.v 实现了基于STFT的短时平均能量计算，和谱熵  
> 而 vad\_zero\_pass.v 模块则是实现了短时平均过零率求解  
> 使用连续8~16帧的3-D特征，拼接成 24~48-D的特征，使用PCA降维（用矩阵乘法模块实现），  
> 之后会输入到SVM中，vad\_svm.v 模块实现了基于rbf核函数的SVM（未流水）

## 01\_altera\_ip
调用altera提供的IP核

## 02\_testbench
测试代码
### · sram\_sim.v
> SRAM的仿真模型
### · tb\_cmd\_parser.v
> 测试cmd\_parser模块
### · tb\_cnn.v
> 测试NPU单元构建的CNN模块是否运算正确
### · tb\_cnn2.v
> 测试MFCC搬运、CNN参数配置和NPU计算的正确性
### · tb\_dct.v
> 测试DCT变换的正确性
### · tb\_fft.v
> 测试FFT变换的正确性
### · tb\_frame.v
> 测试分帧的正确性
### · tb\_ln.v
> 测试CORDIC实现的log函数、exp函数的正确性
### · tb_mfcc.v
> 测试MFCC特征提取的正确性
### · tb_vad.v
> 测试VAD语音端点检测的 正确性

## 03\_signaltap
使用Quartus自带的signaltap工具捕捉波形，对各个模块进行调试

## 04\_scripts
脚本，主要是mif文件，引脚绑定和时序约束文件

## 05\_modelsim
仿真文件夹，执行里面的 sim_module.bat 批处理文件即可。  
当然，要提前设置好环境变量 PATH，要包含 modelsim 的安装路径

## 08\_quartus
Quartus工程项目文件夹

## 09\_cpp\_files
这里主要是几个脚本的生成程序  
### · wm8731_config.h
> 这是音频芯片wm8731的配置表  
> 可以被generate\_i2c\_setting.c给include  
### · generate\_i2c\_setting.c
> 这是I2C配置的表，用来生成ROM初始化文件mif  
> 另外，每次wm8731_config.h里面的数据有所更改，都要重新编译
### · widdle_factor.c
> 这是用来生成旋转因子ROM表初始化mif文件的代码

## 10\_python
python脚本程序的文件夹
### *fft文件夹*
#### · fft\_test\_data_generator.py
> 这是生成FFT测试数据的脚本文件
### *dct文件夹*
#### · test\_dct_modelsim.py
> 这是在测试DCT能不能用FFT来实现
### *cordic文件夹*
#### · int\_cordic\_core\_generate_factor.py
> 这是生成 CORDIC_* 相关模块的ROM表初始化 mif 文件的脚本
### *mel文件夹*
#### · generate\_mel\_coefs.py
> 生成mfcc特征提取时候的测试数据（原始波形数据）  
> 加载modelsim仿真结果  
> 依次对 fft/power、mel滤波器输出、ln对数变换、dct余弦变换的结果进行误差比对
### *npu文件夹*
#### · generate\_npu\_sram\_init_file.py
> 生成NPU测试的时候，需要对SRAM内存进行初始化
#### · check\_npu\_result.py
> 测试NPU运算的正确性，计量精度误差
### *vad文件夹*
#### · generate\_vad\_test\_file.py
> 为了测试VAD语音端点检测模块的正确性设计  
> 能够加载 vad_pca 给出的PCA降维后的特征向量  
> 加载训练好的SVM进行分类判别（软件仿真）  
> 能够转化 pca / svm 的参数到 ROM 初始化的 mif 文件

### *cnn文件夹*
#### · check\_cnn.py
> 能够验证CNN运行的正确性（modelsim和python对比）、精度（浮点运算对比）
#### · generate\_npu\_inst\_paras.py
> 能够根据TF训练得到的NPU参数和NPU指令，转换成相应的mif文件，供FPGA使用