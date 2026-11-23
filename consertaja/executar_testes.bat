@echo off
REM Plano de Testes PT-CJ-01 - ConsertaJa
REM Executa os testes automatizados e gera coverage\lcov.info
cd /d "%~dp0"
call flutter pub get
echo.
echo ===== Testes do plano (com cobertura) =====
call flutter test test/plano_testes --coverage --reporter expanded
echo.
echo ===== Regressao (sem os testes de defeitos conhecidos) =====
call flutter test test/plano_testes --exclude-tags defeito
echo.
echo Relatorio de cobertura: coverage\lcov.info
pause
