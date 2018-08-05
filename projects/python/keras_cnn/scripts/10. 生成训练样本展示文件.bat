cd ..\samples
rd /s /q .\agwn-noise
rd /s /q .\bg-music
rd /s /q .\no-noise
cd ..\source
python .\show_training_samples.py
pause