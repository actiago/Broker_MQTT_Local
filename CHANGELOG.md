# Changelog

Todas as mudanças relevantes deste repositório são registradas neste arquivo.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e a
numeração acompanha o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não publicado]

## [1.1.0] — 2026-11-17

### Adicionado

- **Suporte a Microsoft Windows** em `windows/`:
  - `windows/broker.bat` + `windows/broker.ps1` — os mesmos comandos do
    `broker.sh` (`up`, `down`, `limpar`, `restart`, `status`, `teste`, `ip`,
    `logs`, `shell`, `config`, `ajuda`) via PowerShell, com detecção automática
    do Compose (`docker compose`, `docker-compose`, `podman`, `podman-compose`),
    porta alternativa por `PORTA_MQTT`, IP da LAN por `Get-NetRoute`/
    `Get-NetIPAddress` e self-test QoS 1 dentro do container.
  - `windows/README_WINDOWS.md` — dois caminhos (Docker Desktop/WSL2 e
    Mosquitto nativo), firewall do Windows, apontamento do framework/sketch,
    integração com framework rodando no WSL2 e tabela de problemas comuns.
  - `windows/mosquitto-windows.conf` + `windows/mosquitto-nativo.bat` —
    alternativa sem Docker: Mosquitto instalado no Windows, com caminhos
    nativos (`.\dados\`) e a mesma política do container.
- `.gitattributes` — `.sh`/`.yml`/`.conf`/`.md` em LF e `.bat`/`.ps1` em CRLF,
  para o clone no Windows não quebrar os scripts com `bad interpreter`.
- `.github/workflows/validar.yml` — CI que roda `bash -n`, `shellcheck -S error`,
  `docker compose config` (porta padrão e `PORTA_MQTT=1884`) e o parser do
  PowerShell em `windows/broker.ps1`.
- `README.md`: **Início rápido** no topo (Linux e Windows), `git clone` com a URL
  real do repositório, tabela de equivalência `broker.sh` ↔ `broker.bat`,
  §"Porta diferente de 1883", firewall do Windows, linha sobre WPA2-Enterprise
  (eduroam) e diagnóstico com os casos de Windows/WSL.
- `.gitignore`: `mosquitto/passwd` (lista de usuários de exemplo) fora do
  versionamento.

### Corrigido

- `PORTA_MQTT` agora chega ao `docker-compose.yml` (`${PORTA_MQTT:-1883}:1883`):
  antes, `PORTA_MQTT=1884 ./broker.sh up` fazia o script testar/esperar a 1884
  enquanto o container publicava 1883 — o `up` falhava depois de 30 s esperando
  uma porta que nunca abriria.
- `ajuda` (broker.sh) e `uso` (apontar_framework.sh) deixaram de extrair o texto
  por número de linha (`sed -n '7,22p'`) e passaram a usar `heredoc`: editar o
  cabeçalho do script não estraga mais a mensagem de ajuda.

## [1.0.0] — 2026-11-15

### Adicionado

- Broker **Eclipse Mosquitto 2** em container (`docker-compose.yml`) para o
  `Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey`: listener
  `0.0.0.0:1883`, anônimo (o framework não tem campo de credenciais),
  `max_connections -1`, persistência em volume nomeado, logs em `stdout` e
  healthcheck que publica por QoS 0.
- `mosquitto/mosquitto.conf` comentado diretiva por diretiva, com a razão de
  cada escolha (0.0.0.0 por causa do ESP32; anônimo por causa dos 8 campos do
  `MQTT.txt`; `sys_interval 5` para o self-test de versão) e um bloco comentado
  de autenticação para o dia em que N3 e sketch enviarem usuário/senha.
- `broker.sh` — ciclo de vida com detecção automática de engine
  (`docker compose`, `docker-compose`, `podman compose`, `podman-compose`) e
  subcomandos `up`, `down`, `limpar`, `restart`, `status`, `teste`, `ip`,
  `logs`, `shell`, `config`. O self-test (`teste`) publica e recebe por QoS 1
  **dentro** do container, usando os clientes que já vêm na imagem — não é
  preciso instalar pacote no host.
- `apontar_framework.sh` — grava `broker`/`porta` no
  `4_N4_Armazenamento/Parametros/MQTT.txt` preservando comando, nº de medidas,
  tempo, tópicos e QoS; **dry-run por padrão**, grava só com `--gravar`.
- `README.md` — como subir, como apontar o framework (tela e script), como
  trocar o IP no sketch do ESP32, o laço completo com o simulador, diagnóstico
  e os limites de segurança do modo anônimo na LAN.

### Verificado

- Subida real nesta máquina (Zorin OS 18.1, podman 4.9.3, podman-compose 1.0.6):
  imagem `eclipse-mosquitto:2` → **mosquitto 2.1.2**, container `Up (healthy)`,
  porta 1883 abrindo e self-test QoS 1 passando; e o `simulador_gateway.py` do
  próprio framework trocando o pacote de **20 bytes** (DL→UL) pelo broker local
  em **QoS 1**. O sketch e a placa ESP32 não foram testados (sem hardware).
