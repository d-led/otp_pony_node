@echo off

start /B  elixir --sname demo@localhost --cookie secretcookie demo.exs

ping 127.0.0.1 -n 3 > nul

otp_pony_node.exe
if %errorlevel% neq 0 exit /b %errorlevel%
