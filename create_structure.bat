@echo off
echo Creating Flutter lib folder structure...

REM move to project root (adjust if needed)
cd /d %~dp0

REM create directories
if not exist lib mkdir lib
if not exist lib\data mkdir lib\data
if not exist lib\screens mkdir lib\screens
if not exist lib\models mkdir lib\models
if not exist lib\utils mkdir lib\utils

echo.
echo Done.
echo Created:
echo  - lib\data
echo  - lib\screens
echo  - lib\models
echo  - lib\utils
echo.

pause
