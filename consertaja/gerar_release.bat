@echo off
REM ==================================================================
REM  Gera a versao de producao do ConsertaJa.
REM
REM  - App Bundle (.aab) para a Play Store: a loja entrega para cada
REM    celular so o codigo da arquitetura dele (APK bem menor).
REM  - APKs separados por arquitetura, para instalar direto em testes.
REM  - --obfuscate: embaralha os nomes do codigo Dart (dificulta engenharia
REM    reversa). Os simbolos ficam em build\simbolos (NAO subir para o Git;
REM    guarde-os para ler relatorios de erro da Play Store).
REM
REM  Antes: crie android\key.properties com a chave de assinatura
REM  (veja docs\SEGURANCA.md).
REM ==================================================================
cd /d "%~dp0"

call flutter clean
call flutter pub get

call flutter build appbundle --release --obfuscate --split-debug-info=build\simbolos
if errorlevel 1 goto erro

call flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build\simbolos
if errorlevel 1 goto erro

echo.
echo Pronto:
echo   Play Store: build\app\outputs\bundle\release\app-release.aab
echo   APKs:       build\app\outputs\flutter-apk\
pause
exit /b 0

:erro
echo.
echo Falhou. Veja a mensagem acima.
pause
exit /b 1
