@echo off
rem ==========================================================================
rem Broker MQTT local — alternativa SEM DOCKER no Windows
rem
rem Sobe o Mosquitto NATIVO do Windows (instalador de https://mosquitto.org/download/)
rem com a configuracao windows\mosquitto-windows.conf: listener 0.0.0.0:1883,
rem anonimo, logs na tela. Ctrl+C para parar.
rem
rem Use quando o Docker Desktop nao estiver instalado. Para o dia a dia com
rem container, use windows\broker.bat (up, status, teste, ip...).
rem
rem Nao esqueca o firewall (README_WINDOWS.md secao 2), senao so este PC acessa.
rem ==========================================================================
setlocal

set "AQUI=%~dp0"
set "MOSQUITTO=%ProgramFiles%\mosquitto\mosquitto.exe"

rem O conf usa caminho relativo (persistence_location .\dados\): rode daqui.
cd /d "%AQUI%"

if not exist "%MOSQUITTO%" (
  echo [erro] nao achei "%MOSQUITTO%"
  echo        Instale o Mosquitto para Windows: https://mosquitto.org/download/
  echo        Marque a opcao de instalar o servico; aqui ele roda na mao.
  exit /b 1
)

rem A persistencia grava .\dados\mosquitto.db — a pasta tem que existir.
if not exist "%AQUI%dados" mkdir "%AQUI%dados"

rem Se o servico do Mosquitto (instalado pelo instalador) estiver de pe, ele ja
rem ocupa a 1883 e este comando falha com "Address in use".
netstat -ano | findstr /c:":1883" | findstr /i "LISTENING" >nul 2>&1
if not errorlevel 1 (
  echo [aviso] a porta 1883 ja esta em uso.
  echo         Se for o servico do Mosquitto, pare-o antes:
  echo             net stop mosquitto
  exit /b 1
)

echo [mosquitto] iniciando com "%AQUI%mosquitto-windows.conf"
echo [mosquitto] IP desta maquina, para o MQTT.txt e o sketch:
ipconfig | findstr /i "IPv4"
echo [mosquitto] Ctrl+C para parar.
echo.

"%MOSQUITTO%" -c "%AQUI%mosquitto-windows.conf" -v
set "CODIGO=%ERRORLEVEL%"

endlocal & exit /b %CODIGO%
