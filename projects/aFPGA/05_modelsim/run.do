###########################################################
set QUARTUS_INSTALL_DIR "E:/intelFPGA/16.1/quartus"
# 定义顶层模块
########### 测试cordic函数
#set TOP_LEVEL_NAME "tb_cordic" 
########### 测试fft函数
#set TOP_LEVEL_NAME "tb_fft"
########### 测试dct函数
#set TOP_LEVEL_NAME "tb_dct"
########### 测试除法器函数
#set TOP_LEVEL_NAME "tb_sdiv" 
########### 测试NPU 函数
set TOP_LEVEL_NAME "tb_npu2" 
########### 测试cmd_parser命令解析器
#set TOP_LEVEL_NAME "tb_cmd_parser" 
########### 测试CNN的运算过程（仅仅验证NPU计算精度）
#set TOP_LEVEL_NAME "tb_cnn" 
########### 测试CNN的运算过程（同步验证MFCC特征搬运的正确性）
#set TOP_LEVEL_NAME "tb_cnn2" 
########### 测试整体系统VAD
#set TOP_LEVEL_NAME "tb_top" 
########### 测试VAD
#set TOP_LEVEL_NAME "tb_vad" 
########### 测试MFCC
#set TOP_LEVEL_NAME "tb_mfcc" 

# 包含qsys仿真目录
set QSYS_SIMDIR "../"
# 然后source 一下自己的仿真 模块
source ./msim_setup.tcl
file_copy
dev_com
###########################################################
# 下面的是要一直【更新】-->【运行】的！
user_com
# the "elab_debug" macro avoids optimizations which preserves signals so that they may be # added to the wave viewer
elab_debug

# 添加波形

####### 调试isa-npu模块
if {$TOP_LEVEL_NAME=="tb_npu2"} {
	add wave "$TOP_LEVEL_NAME/top_inst/*MODE*"
	add wave "$TOP_LEVEL_NAME/top_inst/local*"
#	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst*"
	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/GPC*"
	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/cstate*"
	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/substate*"
#	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/ddr_*"
#	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/*usedw"
#	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/npu_scfifo_Dollar1/*"
#	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/npu_scfifo_Dollar3/*"
	add wave "$TOP_LEVEL_NAME/top_inst/npu_inst_fsm_inst/npu_inst_excutor_inst/u0_npu_conv_rtl/*"
#	add wave "$TOP_LEVEL_NAME/top_inst/afi_phy_clk"
#	add wave "$TOP_LEVEL_NAME/top_inst/mux_ddr_access_local_inst/*_fifo_wrusedw"
#	add wave "$TOP_LEVEL_NAME/top_inst/mux_ddr_access_local_inst/rport_ready_*"
#	add wave "$TOP_LEVEL_NAME/top_inst/mux_ddr_access_attach_inst/*_fifo_wrusedw"
#	add wave "$TOP_LEVEL_NAME/top_inst/mux_ddr_access_attach_inst/rport_ready_*"
}

####### 调试CNN运算（参数&MFCC搬运已经提前完成的版本，对应于实际运行中的【串口配置指令&参数&输入图像】）
if {$TOP_LEVEL_NAME=="tb_cnn"} {
	add wave "$TOP_LEVEL_NAME/top_inst/*MODE*"
	add wave "$TOP_LEVEL_NAME/top_inst/CNN*"
	add wave "$TOP_LEVEL_NAME/top_inst/cnn*"
	add wave "$TOP_LEVEL_NAME/top_inst/npu_paras_config_inst/*"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/*"
}

####### 调试CNN参数配置 & 调试MFCC搬运模块
if {$TOP_LEVEL_NAME=="tb_cnn2"} {
	add wave "$TOP_LEVEL_NAME/top_inst/*MODE*"
	add wave "$TOP_LEVEL_NAME/top_inst/CNN*"
	add wave "$TOP_LEVEL_NAME/top_inst/cnn*"
	add wave "$TOP_LEVEL_NAME/top_inst/npu_paras_config_inst/*"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/*"
}

####### 调试cmd_parser模块
if {$TOP_LEVEL_NAME=="tb_cmd_parser"} {
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/sys_ddr*"
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/sys_uart*"
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/*_cmd"
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/*_time"
}

####### 调试VAD/top模块
if {$TOP_LEVEL_NAME=="tb_top"} {
	# 首先是SRAM的信号
	add wave "$TOP_LEVEL_NAME/SRAM*"
	add wave "$TOP_LEVEL_NAME/top_inst/*MODE"
	# 然后是VAD的信号
	add wave "$TOP_LEVEL_NAME/top_inst/CLOCK50"
	add wave "$TOP_LEVEL_NAME/top_inst/audio_rdata_left"
	add wave "$TOP_LEVEL_NAME/top_inst/window_data"
	add wave "$TOP_LEVEL_NAME/top_inst/vad_svm_inst/N_SV"
	# 测SP谱熵的运算时间
	add wave "$TOP_LEVEL_NAME/top_inst/fft_sink_sop"
	add wave "$TOP_LEVEL_NAME/top_inst/fft_rho"
	add wave "$TOP_LEVEL_NAME/top_inst/fft_rho_phase_en"
	add wave "$TOP_LEVEL_NAME/top_inst/energy"
	add wave "$TOP_LEVEL_NAME/top_inst/sp_entropy"
	add wave "$TOP_LEVEL_NAME/top_inst/zero_pass"
	add wave "$TOP_LEVEL_NAME/top_inst/energy_entropy_en"
	# 测PCA时间
	add wave "$TOP_LEVEL_NAME/top_inst/vad_pca_inst/energy_entropy_en"
	add wave "$TOP_LEVEL_NAME/top_inst/vad_pca_inst/feature_dr"
	add wave "$TOP_LEVEL_NAME/top_inst/vad_pca_inst/feature_dr_en"
	# 测SVM运算时间
	add wave "$TOP_LEVEL_NAME/top_inst/vad_svm_inst/classification"
	add wave "$TOP_LEVEL_NAME/top_inst/vad_svm_inst/classification_en"
	add wave "$TOP_LEVEL_NAME/top_inst/vad_result*"
	# MFCC计算测时间
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_extract_inst/fft_sop"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_extract_inst/fft_mag"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_extract_inst/fft_mag_en"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_extract_inst/mfcc"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_extract_inst/mfcc_en"
	# 然后要有CNN运算的信号
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/cstate"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/speech_vad"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/vad_down"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/cnn_comp_en"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/cnn_comp_ready"
	add wave "$TOP_LEVEL_NAME/top_inst/mfcc_exchanger_inst/cnn_classification"
}

####### 调试VAD单个模块
if {$TOP_LEVEL_NAME=="tb_vad"} {
	add wave "$TOP_LEVEL_NAME/data"
	add wave "$TOP_LEVEL_NAME/window_data"
	add wave "$TOP_LEVEL_NAME/fft_rho"
	add wave "$TOP_LEVEL_NAME/energy"
	add wave "$TOP_LEVEL_NAME/sp_entropy"
	add wave "$TOP_LEVEL_NAME/zero_pass"
	add wave "$TOP_LEVEL_NAME/vad_svm_inst/class*"
}

######## 调试除法器
if {$TOP_LEVEL_NAME=="tb_sdiv"} {
	add wave "$TOP_LEVEL_NAME/fixed_sdiv_inst/*"
}

######## 调试cordic
if {$TOP_LEVEL_NAME=="tb_cordic"} {
	add wave "$TOP_LEVEL_NAME/r_in_shifter10"
	add wave "$TOP_LEVEL_NAME/ln_r_out_"
	add wave "$TOP_LEVEL_NAME/rho_exp"
	add wave "$TOP_LEVEL_NAME/rho_tanh_sigmoid"
}

######## 调试fft
if {$TOP_LEVEL_NAME=="tb_fft"} {
	add wave "$TOP_LEVEL_NAME/fft_mdl/fix_fft_rtl_inst/*"
}

######## 调试dct
if {$TOP_LEVEL_NAME=="tb_dct"} {
	add wave "$TOP_LEVEL_NAME/dct_mdl/*"
}

# 十进制显示
radix decimal

#run 1000ms
run -all