@echo off
REM ============================================================================
REM Terraform Azure CI/CD Pipeline Setup - Windows Batch Launcher
REM ============================================================================

echo.
echo ============================================================
echo Terraform Azure CI/CD Pipeline Setup
echo ============================================================
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not installed or not in PATH
    echo Please install PowerShell and try again
    pause
    exit /b 1
)

REM Run the PowerShell setup script
echo Starting setup script...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pipeline.ps1"

echo.
echo Setup script completed. Check PIPELINE_SETUP_SUMMARY.md for details.
pause