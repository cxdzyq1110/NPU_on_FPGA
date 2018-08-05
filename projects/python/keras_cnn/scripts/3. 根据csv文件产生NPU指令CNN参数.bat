cd ..\source
python .\generate_npu_inst.py > ..\isa-npu\npu_inst.txt

cd ..
cd ..\..\aFPGA\10_python\cnn
python .\generate_npu_inst_paras.py
pause