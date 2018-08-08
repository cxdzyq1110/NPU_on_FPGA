###########################################################
# 请根据Quartus的安装路径进行配置
set QUARTUS_INSTALL_DIR "E:/intelFPGA/16.1/quartus"
# 请根据仿真需要，定义顶层模块
########### 测试cordic函数
#set TOP_LEVEL_NAME "tb_cordic" 
########### 测试除法器函数
#set TOP_LEVEL_NAME "tb_sdiv" 
########### 测试NPU 函数
#set TOP_LEVEL_NAME "tb_npu2" 
########### 测试cmd_parser命令解析器
#set TOP_LEVEL_NAME "tb_cmd_parser" 
########### 测试CNN的运算过程（仅仅验证NPU计算精度）
set TOP_LEVEL_NAME "tb_cnn" 

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
}

####### 调试cmd_parser模块
if {$TOP_LEVEL_NAME=="tb_cmd_parser"} {
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/sys_ddr*"
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/sys_uart*"
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/*_cmd"
	add wave "$TOP_LEVEL_NAME/top_inst/cmd_parser_inst/*_time"
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


# 十进制显示
radix decimal

#run 1000ms
run -all