@echo off
REM Revisa la app NUNC y guarda el resultado en revision.txt
cd /d "%~dp0"
echo Revisando NUNC... (tarda 1-3 minutos)
(
  echo ===== flutter pub get =====
  call flutter pub get
  echo.
  echo ===== flutter analyze =====
  call flutter analyze
  echo.
  echo ===== flutter test =====
  call flutter test
) > revision.txt 2>&1
echo Listo. Resultado guardado en revision.txt
pause
