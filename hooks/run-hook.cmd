@echo off
:: run-hook.cmd — cross-platform hook runner (Windows batch + Unix shell polyglot)
:: On Unix: the shell skips the batch header and runs the shell section.
:: On Windows: locates bash and executes the named hook script.
goto :Windows
: << 'BATCH_END'
#!/usr/bin/env sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_NAME="$1"
shift
exec bash "${SCRIPT_DIR}/${HOOK_NAME}" "$@"
BATCH_END

:Windows
setlocal
set HOOK_NAME=%1
if "%HOOK_NAME%"=="" (
  echo Usage: run-hook.cmd ^<hook-name^> [args...]
  exit /b 1
)
set SCRIPT_DIR=%~dp0

set BASH=
for %%B in (
  "C:\Program Files\Git\bin\bash.exe"
  "C:\Program Files (x86)\Git\bin\bash.exe"
) do (
  if exist %%B set BASH=%%B
)
if "%BASH%"=="" where bash >nul 2>&1 && set BASH=bash

if "%BASH%"=="" (
  echo Warning: bash not found. Hook skipped.
  exit /b 0
)

%BASH% "%SCRIPT_DIR%%HOOK_NAME%" %*
