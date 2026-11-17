<#
.SYNOPSIS
    Broker MQTT local — Framework LoRa MQTT (Cobertura) — versão Windows.

.DESCRIPTION
    Equivalente Windows do ./broker.sh do repositório: sobe o Eclipse Mosquitto 2
    em container (Docker Desktop com backend WSL2, Docker + Compose, ou Podman) e
    faz o resto do ciclo — testar em QoS 1, ver logs e descobrir o IP da LAN.

    Chame sempre pelo windows\broker.bat: ele usa "-ExecutionPolicy Bypass" só
    neste processo, sem mudar a política de execução da sua máquina.

.EXAMPLE
    windows\broker.bat up
    windows\broker.bat teste
    windows\broker.bat ip
#>

Set-StrictMode -Version Latest

# 'Continue' (e não 'Stop') de propósito: o script dirige docker/podman, e saída
# de erro desses programas na stderr não deve derrubar o script — o que importa é
# o $LASTEXITCODE, conferido em cada chamada.
$ErrorActionPreference = 'Continue'

$Aqui        = Split-Path -Parent $MyInvocation.MyCommand.Path
$Raiz        = Split-Path -Parent $Aqui
$ComposeFile = Join-Path $Raiz 'docker-compose.yml'
$Container   = 'broker-mqtt-local'

$Porta = 1883
if (Test-Path Env:PORTA_MQTT) { $Porta = [int]$env:PORTA_MQTT }

$Comando = 'up'
if ($args.Count -ge 1 -and $args[0]) { $Comando = [string]$args[0] }

# ---------------------------------------------------------------------------
# utilidades
# ---------------------------------------------------------------------------
function Escreve { param([string]$Texto) Write-Host $Texto }
function Aviso   { param([string]$Texto) Write-Warning $Texto }

# engine: Compose para subir/derrubar, engine puro (docker|podman) para ps/logs/exec
function Get-Compose {
    if ((Test-Path Env:COMPOSE) -and $env:COMPOSE) { return @($env:COMPOSE -split '\s+') }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        & docker compose version *> $null
        if ($LASTEXITCODE -eq 0) { return @('docker', 'compose') }
    }
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) { return @('docker-compose') }
    if (Get-Command podman -ErrorAction SilentlyContinue) {
        & podman compose version *> $null
        if ($LASTEXITCODE -eq 0) { return @('podman', 'compose') }
    }
    if (Get-Command podman-compose -ErrorAction SilentlyContinue) { return @('podman-compose') }
    return @()
}

$ComposeCmd = @(Get-Compose)
if ($ComposeCmd.Count -eq 0) {
    Aviso 'nenhum Compose encontrado: instale/abra o Docker Desktop (ou Podman).'
    Aviso 'Sem Docker? Use o Mosquitto nativo: windows\mosquitto-nativo.bat'
    exit 1
}

$Engine = if ($ComposeCmd[0] -like 'docker*') { 'docker' } else { 'podman' }

$ComposeExtra = @()
if ($ComposeCmd.Count -gt 1) { $ComposeExtra = $ComposeCmd[1..($ComposeCmd.Count - 1)] }

function Executa-Compose {
    param([string[]]$Argumentos)
    $lista = $ComposeExtra + @('-f', $ComposeFile) + $Argumentos
    & $ComposeCmd[0] @lista
    if ($LASTEXITCODE -ne 0) { throw "compose falhou (código $LASTEXITCODE)" }
}

# "A porta está atendendo?" — TCP em 127.0.0.1, sem depender de Test-NetConnection
function Testa-Porta {
    param([int]$PortaAlvo, [int]$TimeoutMs = 1500)
    $cliente = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $cliente.BeginConnect('127.0.0.1', $PortaAlvo, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $cliente.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $cliente.Close()
    }
}

function Espera-Porta {
    for ($i = 1; $i -le 60; $i++) {
        if (Testa-Porta -PortaAlvo $Porta) {
            Escreve "[broker] porta $Porta respondendo em 127.0.0.1."
            return
        }
        if ($i -eq 10) { Aviso 'ainda não... (a primeira execução baixa a imagem eclipse-mosquitto:2)' }
        Start-Sleep -Milliseconds 500
    }
    throw "a porta $Porta não abriu em 30 s — veja: windows\broker.bat logs"
}

# Autoteste dentro do container: assina e publica no mesmo tópico (QoS 1) e exige
# que a mensagem volte pelo caminho do broker. Os clientes já vêm na imagem.
function Teste-Qos {
    $topico = "broker_mqtt_local/selftest/$PID"
    $msg    = "ping-$PID"
    $remoto = "mosquitto_sub -h 127.0.0.1 -p $Porta -t '$topico' -C 1 -W 5 -q 1 > /tmp/selftest.out 2>&1 & sleep 1; mosquitto_pub -h 127.0.0.1 -p $Porta -t '$topico' -m '$msg' -q 1; wait; cat /tmp/selftest.out"
    $saida = (& $Engine exec $Container sh -c $remoto 2>&1 | Out-String).Trim()
    if ($saida -eq $msg) {
        Escreve "[SELFTEST] broker respondendo em $Porta (QoS 1) — ok"
        return
    }
    Aviso "[SELFTEST] FALHOU: a mensagem não voltou do broker em $Porta"
    if ($saida) { Aviso "[SELFTEST] saída: $saida" }
}

function Get-IpLan {
    $rota = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric | Select-Object -First 1
    if ($rota) {
        $ip = Get-NetIPAddress -InterfaceIndex $rota.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1
        if ($ip) { return $ip.IPAddress }
    }
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
          Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
          Select-Object -First 1
    if ($ip) { return $ip.IPAddress }
    return ''
}

# ---------------------------------------------------------------------------
# comandos
# ---------------------------------------------------------------------------
function Mostra-Ip {
    $ip = Get-IpLan
    if (-not $ip) {
        Aviso 'não consegui descobrir o IP da LAN (o Wi-Fi/cabo está conectado?)'
        exit 1
    }
    Escreve @"
IP da LAN desta máquina: $ip

Use exatamente esse valor nos DOIS lados (sem "localhost"!):

1) Framework — 4_N4_Armazenamento/Parametros/MQTT.txt, linhas 4 e 5:
     $ip
     $Porta
   (ou pela tela do Setup: ./rodar.sh setup -> campo "URL do Broker")

2) Sketch do Gateway — 2_Gateway_LoRa_MQTT_N2_QoS1.ino:
     const char* MQTT_BROKER = "$ip";
     const int   MQTT_PORT   = $Porta;
   A placa precisa estar na mesma rede Wi-Fi (2,4 GHz) da máquina.

Confira tambem o firewall: windows\README_WINDOWS.md secao 2
"@
}

function Sobe {
    Escreve "[broker] engine: $($ComposeCmd -join ' ')"
    try {
        Executa-Compose -Argumentos @('up', '-d')
    } catch {
        Aviso "erro: o compose não subiu o broker ($($_.Exception.Message))."
        Aviso "dica: se a porta $Porta estiver ocupada: netstat -ano | findstr :$Porta"
        exit 1
    }
    Espera-Porta
    Escreve ''
    & $Engine ps -a --filter "name=$Container"
    Escreve ''
    Teste-Qos
    Escreve ''
    Escreve "[broker] broker no ar: mqtt://$(Get-IpLan):$Porta (anônimo — rede de laboratório)"
    Escreve "[broker] framework: windows\broker.bat ip | depois aponte o MQTT.txt para esse IP"
}

function Para {
    & $Engine inspect $Container *> $null
    if ($LASTEXITCODE -eq 0) {
        Executa-Compose -Argumentos @('down')
        Escreve '[broker] container removido. O volume de dados foi mantido'
        Escreve '[broker] (para apagar também os dados: windows\broker.bat limpar).'
    } else {
        Escreve '[broker] não há container deste compose em execução.'
    }
}

function Limpa {
    Executa-Compose -Argumentos @('down', '-v')
    Escreve '[broker] container E volume de dados removidos.'
}

function Reinicia {
    & $Engine restart $Container *> $null
    Espera-Porta
    Teste-Qos
}

function Status {
    Escreve "[broker] engine: $($ComposeCmd -join ' ')"
    Escreve ''
    Escreve '--- container ---'
    & $Engine ps -a --filter "name=$Container"
    Escreve ''
    Escreve "--- porta $Porta (127.0.0.1) ---"
    if (Testa-Porta -PortaAlvo $Porta) {
        Escreve 'aberta'
    } else {
        Escreve 'FECHADA — o broker não está atendendo (windows\broker.bat logs)'
    }
    Escreve ''
    Escreve '--- $SYS/broker/version ---'
    & $Engine exec $Container mosquitto_sub -h 127.0.0.1 -p $Porta -t '$SYS/broker/version' -C 1 -W 8 2>$null
    if ($LASTEXITCODE -ne 0) { Escreve '(sem resposta)' }
    Escreve ''
    Escreve '--- self-test QoS 1 ---'
    Teste-Qos
    Escreve ''
    Escreve '--- rede ---'
    Escreve "IP da LAN: $(Get-IpLan)  (porta $Porta)"
}

function Ajuda {
    Escreve @'
Uso: windows\broker.bat [comando]        (sem argumento o comando é "up")

  up        sobe o broker (cria/atualiza o container) e valida
  down      para e remove o container (o volume de dados fica)
  limpar    remove o container E apaga o volume de dados
  restart   reinicia o container
  status    container, porta, versão, self-test QoS 1 e IP
  teste     autoteste: publica e recebe por QoS 1 dentro do container
  ip        IP da LAN + as linhas prontas para MQTT.txt e o sketch
  logs      acompanha os logs (Ctrl+C para sair)
  shell     abre um shell dentro do container
  config    mostra a configuração em uso (/mosquitto/config/...)
  ajuda     esta mensagem

Precisa de Docker Desktop (WSL2) ou Podman. Sem Docker, existe a alternativa
nativa: windows\mosquitto-nativo.bat (veja windows\README_WINDOWS.md).

Porta diferente de 1883:  set PORTA_MQTT=1884  &  windows\broker.bat up
No Linux/WSL o equivalente deste script é ./broker.sh
'@
}

switch ($Comando.ToLower()) {
    'up'      { Sobe }
    'down'    { Para }
    'limpar'  { Limpa }
    'restart' { Reinicia }
    'status'  { Status }
    'teste'   { Teste-Qos }
    'ip'      { Mostra-Ip }
    'logs'    { & $Engine logs -f --tail 50 $Container }
    'shell'   { & $Engine exec -it $Container sh }
    'config'  { & $Engine exec $Container cat /mosquitto/config/mosquitto.conf }
    'ajuda'   { Ajuda }
    '-h'      { Ajuda }
    '--help'  { Ajuda }
    default {
        Aviso "comando desconhecido: $Comando"
        Escreve ''
        Ajuda
        exit 1
    }
}
