
# ----------------------------------------
# Auto-generated simulation script

# ----------------------------------------
# Initialize variables
if ![info exists SYSTEM_INSTANCE_NAME] { 
  set SYSTEM_INSTANCE_NAME ""
} elseif { ![ string match "" $SYSTEM_INSTANCE_NAME ] } { 
  set SYSTEM_INSTANCE_NAME "/$SYSTEM_INSTANCE_NAME"
}

if ![info exists TOP_LEVEL_NAME] { 
  set TOP_LEVEL_NAME "test_cordic"
}

if ![info exists QSYS_SIMDIR] { 
  set QSYS_SIMDIR "./../"
}

if ![info exists QUARTUS_INSTALL_DIR] { 
  set QUARTUS_INSTALL_DIR "F:/intelFPGA/16.1/quartus/"
}

# ----------------------------------------
# Initialize simulation properties - DO NOT MODIFY!
set ELAB_OPTIONS ""
set SIM_OPTIONS ""
if ![ string match "*-64 vsim*" [ vsim -version ] ] {
} else {
}

# Copy ROM/RAM files to simulation directory
alias file_copy {
  echo "\[exec\] file_copy"
  file copy -force $QSYS_SIMDIR/00_user_logic/uart/uart_conf.inc ./
}
# ----------------------------------------
# Create compilation libraries
proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }
ensure_lib          ./libraries/     
ensure_lib          ./libraries/work/
vmap       work     ./libraries/work/
vmap       work_lib ./libraries/work/
if ![ string match "*ModelSim ALTERA*" [ vsim -version ] ] {
  ensure_lib                       ./libraries/altera_ver/           
  vmap       altera_ver            ./libraries/altera_ver/           
  ensure_lib                       ./libraries/lpm_ver/              
  vmap       lpm_ver               ./libraries/lpm_ver/              
  ensure_lib                       ./libraries/sgate_ver/            
  vmap       sgate_ver             ./libraries/sgate_ver/            
  ensure_lib                       ./libraries/altera_mf_ver/        
  vmap       altera_mf_ver         ./libraries/altera_mf_ver/        
  ensure_lib                       ./libraries/altera_lnsim_ver/     
  vmap       altera_lnsim_ver      ./libraries/altera_lnsim_ver/           
}
# ----------------------------------------
# Compile device library files
alias dev_com {
  echo "\[exec\] dev_com"
  if ![ string match "*ModelSim ALTERA*" [ vsim -version ] ] {
    vlog -incr      "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_primitives.v"                     -work altera_ver           
    vlog -incr      "$QUARTUS_INSTALL_DIR/eda/sim_lib/220model.v"                              -work lpm_ver              
    vlog -incr      "$QUARTUS_INSTALL_DIR/eda/sim_lib/sgate.v"                                 -work sgate_ver            
    vlog -incr      "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_mf.v"                             -work altera_mf_ver        
    vlog -incr  -sv "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_lnsim.sv"                         -work altera_lnsim_ver          
  }
}

# --------------------------
# user files compile
alias user_com {      
vlog -incr  	   "../01_altera_ip/cordic_factor_exp_rom_ip/cordic_factor_exp_rom_ip.v"    
vlog -incr  	   "../01_altera_ip/cordic_factor_Kn_rom_ip/cordic_factor_Kn_rom_ip.v" 
vlog -incr  	   "../01_altera_ip/cordic_int_part_exp_rom_ip/cordic_int_part_exp_rom_ip.v" 
# FFT   
vlog -incr  	   "../01_altera_ip/npu_inst_ram/npu_inst_ram.v"    
vlog -incr  	   "../01_altera_ip/npu_inst_ram_bak/npu_inst_ram_bak.v"    
vlog -incr  	   "../01_altera_ip/npu_paras_rom/npu_paras_rom.v"   


vlog -incr  	   "../01_altera_ip/alt_pll_ip_core/alt_pll_ip_core.v"    


vlog -incr  	   "../00_user_logic/ram/dpram_2p.v"    

vlog -incr  	   "../00_user_logic/scfifo/sc_fifo.v"    

vlog -incr  	   "../00_user_logic/dcfifo/dc_fifo.v"    
vlog -incr  	   "../00_user_logic/dcfifo/gray_dec_1p.v"    
vlog -incr  	   "../00_user_logic/dcfifo/gray_enc_1p.v"    
vlog -incr  	   "../00_user_logic/dcfifo/sync_dual_clock.v"    

	                    
vlog -incr		   "../00_user_logic/cordic/cordic_ln.v"		                    
vlog -incr		   "../00_user_logic/cordic/cordic_rot.v"		                    
vlog -incr		   "../00_user_logic/cordic/cordic_exp_rtl.v"		                    
vlog -incr		   "../00_user_logic/cordic/cordic_tanh_sigm_rtl.v"		    
                
vlog -incr		   "../00_user_logic/arith/fixed_sdiv.v"		    
                

vlog -incr		   "../00_user_logic/npu/npu_inst_join.v"	
vlog -incr		   "../00_user_logic/npu/npu_inst_excutor.v"	
vlog -incr		   "../00_user_logic/npu/npu_inst_fsm.v"	
vlog -incr		   "../00_user_logic/npu/npu_paras_config.v"	
vlog -incr		   "../00_user_logic/npu/npu_conv_rtl.v"	

vlog -incr		   "../00_user_logic/uart/uart_rtl.v"	
vlog -incr		   "../00_user_logic/uart/uart_wr.v"	

vlog -incr		   "../00_user_logic/multiport/mux_ddr_access.v"	

vlog -incr		   "../00_user_logic/sram/sram_controller.v"	

vlog -incr		   "../00_user_logic/parser/cmd_parser.v"	

vlog -incr		   "../00_user_logic/top.v"	+define+SIMULATE

vlog -incr  	   "../02_testbench/sram_sim.v"    
                                                  
vlog -incr  	   "../02_testbench/tb_sdiv.v"                      
vlog -incr  	   "../02_testbench/tb_npu2.v"                    
vlog -incr  	   "../02_testbench/tb_cmd_parser.v"                               
vlog -incr  	   "../02_testbench/tb_cnn.v" 
vlog -incr  	   "../02_testbench/tb_cordic.v" 
}
# --------------------

# ----------------------------------------
# Elaborate top level design
alias elab {
  echo "\[exec\] elab"
  eval vsim -t ps $ELAB_OPTIONS -L work -L work_lib -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver $TOP_LEVEL_NAME
}

# ----------------------------------------
# Elaborate the top level design with novopt option
alias elab_debug {
  echo "\[exec\] elab_debug"
  eval vsim -novopt -t ps $ELAB_OPTIONS -L work -L work_lib -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver $TOP_LEVEL_NAME
}

# ----------------------------------------
# Compile all the design files and elaborate the top level design
alias ld "
  dev_com
  com
  elab
"

# ----------------------------------------
# Compile all the design files and elaborate the top level design with -novopt
alias ld_debug "
  dev_com
  com
  elab_debug
"

