:;#!/bin/sh
:;SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
:;HOOK_NAME="$1"
:;shift
:;exec bash "${SCRIPT_DIR}/${HOOK_NAME}" "$@"
@echo off
:: run-hook.cmd - cross-platform hook runner (Windows batch + Unix shell polyglot)
:: On Unix: sh runs the ":;" lines above (":" is a no-op, so the rest of each
:: line executes as a normal command) and execs into bash before reaching here.
:: On Windows: cmd treats every ":"-prefixed line above as a label and skips
:: it, falling through to the batch logic below.
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
