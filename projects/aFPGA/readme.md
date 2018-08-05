# NPU项目
在FPGA上面实现一个基于NPU运算单元。  
选用DE2-115开发板，存储芯片SRAM 2MB  

## 00\_user\_logic
里面存放了各个模块的verilog逻辑代码

### · arith
> fixed_sdiv.v  
> 这是定点除法器模块，流水线型运算  
> 能够在24个clock里面完成32-bit/16-bit【Q16.16】定点除法  
> 时钟频率为100 MHz

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

## 03\_signaltap
使用Quartus自带的signaltap工具捕捉波形，对各个模块进行调试

## 04\_scripts
脚本，主要是mif文件，引脚绑定和时序约束文件

## 05\_modelsim
仿真文件夹，执行里面的 sim_module.bat 批处理文件即可。  
当然，要提前设置好环境变量 PATH，要包含 modelsim 的安装路径

## 08\_quartus
Quartus工程项目文件夹

## 10\_python
python脚本程序的文件夹
### *cordic文件夹*
#### · int\_cordic\_core\_generate_factor.py
> 这是生成 CORDIC_* 相关模块的ROM表初始化 mif 文件的脚本
### *npu文件夹*
#### · generate\_npu\_sram\_init_file.py
> 生成NPU测试的时候，需要对SRAM内存进行初始化
#### · check\_npu\_result.py
> 测试NPU运算的正确性，计量精度误差

### *cnn文件夹*
#### · check\_cnn.py
> 能够验证CNN运行的正确性（modelsim和python对比）、精度（浮点运算对比）
#### · generate\_npu\_inst\_paras.py
> 能够根据TF训练得到的NPU参数和NPU指令，转换成相应的mif文件，供FPGA使用