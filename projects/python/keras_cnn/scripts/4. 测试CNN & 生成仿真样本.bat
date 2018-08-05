cd ..\isa-npu
rd /s /q sim_source
mkdir sim_source
rd /s /q sim_source_fpga
mkdir sim_source_fpga
rd /s /q ver_compare
mkdir ver_compare
cd ..\source
python .\test_npu_inst.py
pause