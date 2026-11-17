@echo off
rem ==========================================================================
rem Broker MQTT local — Framework LoRa MQTT (Cobertura) — Windows
rem
rem Atalho para o broker.ps1. Chame sempre por este .bat: ele usa
rem "-ExecutionPolicy Bypass" apenas neste processo, sem mexer na politica de
rem execucao da sua maquina.
rem
rem   windows\broker.bat up       sobe e valida (baixa a imagem na 1a vez)
rem   windows\broker.bat status   container, porta, versao, self-test e IP
rem   windows\broker.bat ip       o IP da LAN para o MQTT.txt e o sketch
rem   windows\broker.bat ajuda    lista todos os comandos
rem
rem Precisa de Docker Desktop (WSL2) ou Podman. Sem Docker, veja
rem windows\mosquitto-nativo.bat e windows\README_WINDOWS.md
rem ==========================================================================
setlocal

rem Console em UTF-8 para os acentos saírem certo.
chcp 65001 >nul

set "AQUI=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AQUI%broker.ps1" %*
set "CODIGO=%ERRORLEVEL%"

endlocal & exit /b %CODIGO%
