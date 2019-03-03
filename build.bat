@echo off

set PATH=%PATH%;C:\Program Files (x86)\MSBuild\12.0\Bin\

rem current version requires vs2013 for the moment
premake\windows\premake5 vs2013
if %errorlevel% neq 0 exit /b %errorlevel%

msbuild build\windows\vs2013\otp_pony_node.sln /t:Build /p:Configuration=Release
if %errorlevel% neq 0 exit /b %errorlevel%

ponyc
if %errorlevel% neq 0 exit /b %errorlevel%
