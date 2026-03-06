@echo off
REM Run CDB to trace SensorLib.dll function calls via breakpoints
REM Usage: cdb_trace.cmd

set CDB="C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\cdb.exe"
set PYTHON=C:\Users\Derek\.pyenv\pyenv-win\versions\3.11.9-win32\python.exe
set SCRIPT=%~dp0cdb_trace_target.py
set SENSOR_DAT=%~dp0Sensors.dat

REM Clean up previous data
if exist "%SENSOR_DAT%" del "%SENSOR_DAT%"

REM Run CDB with deferred breakpoints on SensorLib exports
REM -o: debug child processes
REM -G: don't break on process exit
REM -g: don't break on initial breakpoint (we use sxe ld instead)
REM Using sxe ld:SensorLib to break when DLL loads, then set breakpoints
%CDB% -G -o -c "sxe ld:SensorLib; g; .echo CDB: SensorLib loaded; bu SensorLib!SSOpen \".echo ENTER SSOpen; gu; .echo EXIT SSOpen eax=; r eax; gc\"; bu SensorLib!SSAddReading \".echo ENTER SSAddReading args=; dd esp+4 L3; gu; .echo EXIT SSAddReading eax=; r eax; gc\"; bu SensorLib!SSCalculateWeightedAverage \".echo ENTER SSCalculateWeightedAverage; gu; .echo EXIT SSCalculateWeightedAverage eax=; r eax; gc\"; bu SensorLib!SSCleanupLowReadings \".echo ENTER SSCleanupLowReadings threshold=; dd esp+4 L1; gu; .echo EXIT SSCleanupLowReadings eax=; r eax; gc\"; bu SensorLib!SSClose \".echo ENTER SSClose; gu; .echo EXIT SSClose eax=; r eax; gc\"; g" "%PYTHON%" "%SCRIPT%"
