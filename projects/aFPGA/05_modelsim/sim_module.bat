:: 请根据实际情况，配置altera仿真库的路径
set ALTERA_SIM_DIR=E:\modeltech64_10.4\altera16.1
:: 请根据实际情况，配置modelsim的安装路径
set MTI_HOME=E:\modeltech64_10.4
:: 运行
copy /y %ALTERA_SIM_DIR%\modelsim.ini .\modelsim.ini
%MTI_HOME%\win64\vsim -do run.do 