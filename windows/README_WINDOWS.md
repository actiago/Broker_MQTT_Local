# Broker MQTT local no Windows

Este diretório é a versão Windows do repositório. No Linux/WSL o dia a dia é o
`./broker.sh`; aqui os mesmos comandos são `windows\broker.bat <comando>` (o
`.bat` só chama o `broker.ps1` com `-ExecutionPolicy Bypass`, então você **não**
precisa mexer na política de execução da sua máquina).

| Linux / WSL (`./broker.sh`) | Windows (`windows\broker.bat`) |
|---|---|
| `up` — sobe e valida | `up` |
| `down` / `limpar` | `down` / `limpar` |
| `restart` | `restart` |
| `status` — container, porta, versão, self-test, IP | `status` |
| `teste` — autoteste QoS 1 | `teste` |
| `ip` — IP da LAN + linhas do `MQTT.txt` e do sketch | `ip` |
| `logs` / `shell` / `config` | `logs` / `shell` / `config` |

O que **não** existe no Windows: o `apontar_framework.sh` (é bash). Para trocar o
broker no `MQTT.txt`, use a tela do framework (`./rodar.sh setup`, dentro do
WSL) ou edite as linhas 4 e 5 do arquivo.

---

## 1. Dois caminhos possíveis

### Caminho A — Docker Desktop (recomendado)

1. Instalar o **Docker Desktop** com backend **WSL2**:
   <https://www.docker.com/products/docker-desktop/>.
   Requisitos: Windows 10 21H2+ / Windows 11 (64 bits), virtualização ligada na
   BIOS/UEFI e o WSL2 (`wsl --install` no PowerShell de administrador, seguido
   de reinício).
2. Abrir o Docker Desktop e esperar o estado **"Engine running"** no canto
   inferior esquerdo. Ele precisa estar aberto sempre que você usar o broker.
3. Clonar e subir:

   ```bat
   git clone https://github.com/actiago/Broker_MQTT_Local.git
   cd Broker_MQTT_Local
   windows\broker.bat up
   ```

   Saída esperada na primeira vez (baixa a imagem `eclipse-mosquitto:2`):

   ```
   [broker] engine: docker compose
   [broker] porta 1883 respondendo em 127.0.0.1.
   [SELFTEST] broker respondendo em 1883 (QoS 1) — ok
   [broker] broker no ar: mqtt://192.168.0.105:1883 (anônimo — rede de laboratório)
   ```

4. `windows\broker.bat status` para conferir (`aberta`, versão do Mosquitto e
   self-test) e `windows\broker.bat ip` para o IP que vai no framework e no
   sketch.

O container publica a porta em **todas as interfaces** do Windows, então o
ESP32 na mesma rede Wi-Fi alcança `IP-do-PC:1883` — desde que o **firewall**
liberei a porta (§2). O `restart: unless-stopped` do compose + o Docker Desktop
iniciando com o Windows fazem o broker voltar sozinho depois de um reboot
(confira a opção *"Start Docker Desktop when you sign in to your computer"*).

**Porta 1883 ocupada** (Mosquitto nativo, outro container ou um serviço): troque
a porta do host:

```bat
set PORTA_MQTT=1884
windows\broker.bat up
```

Aí o `MQTT.txt` e o `MQTT_PORT` do sketch também passam a ser `1884`.

### Caminho B — Mosquitto nativo (sem Docker)

Serve para quem não pode instalar o Docker Desktop. O binário fica no Windows e
roda em primeiro plano (uma janela de terminal).

1. Instalar pelo instalador oficial (`mosquitto-2.x.x-install-windows-x64.exe`)
   de <https://mosquitto.org/download/>. Ele também traz
   `mosquitto_pub.exe` / `mosquitto_sub.exe` em `C:\Program Files\mosquitto\`.
2. Se o instalador registrou e iniciou o **serviço** `mosquitto`, ele já ocupa a
   porta 1883 com a configuração padrão. Pare-o antes:

   ```bat
   net stop mosquitto
   ```

3. Subir com a configuração deste repositório (anonimato, `0.0.0.0:1883`, logs na
   tela):

   ```bat
   windows\mosquitto-nativo.bat
   ```

   O script cria `windows\dados\` (persistência), avisa se a 1883 já estiver em
   uso e mostra o IPv4 da máquina. Deixe essa janela aberta: fechou, o broker
   caiu.

4. Testar sem o framework, em outro terminal:

   ```bat
   "%ProgramFiles%\mosquitto\mosquitto_sub.exe" -h 127.0.0.1 -p 1883 -t "mot_mqtt_194104/gateway/uplink" -v
   ```

   e, em um terceiro:

   ```bat
   "%ProgramFiles%\mosquitto\mosquitto_pub.exe" -h 127.0.0.1 -p 1883 -t "mot_mqtt_194104/gateway/uplink" -m teste -q 1
   ```

Neste caminho não há `broker.bat teste`/`status` (o self-test usa o container):
o teste é o par `mosquitto_sub`/`mosquitto_pub` acima. A configuração é a de
[`mosquitto-windows.conf`](mosquitto-windows.conf), comentada linha por linha.

> Como no Linux, a placa ESP32 **não** fala com `localhost`: use o IP da LAN.

---

## 2. Firewall: liberar a 1883 para a LAN

Sem isso o broker responde para o próprio PC (`127.0.0.1`), o Python do N3
conecta, e o **ESP32 nunca aparece** — o mesmo sintoma descrito no README §9.

No **PowerShell como administrador**:

```powershell
New-NetFirewallRule -DisplayName "Mosquitto MQTT 1883 (LAN)" `
  -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow -Profile Private
```

`-Profile Private` vale quando o Wi-Fi está marcado como rede **Privada**
(Configurações → Rede e Internet → Wi-Fi → propriedades da rede → perfil).
Em bancada com o roteador em rede marcada como **Pública**, use `-Profile Any`
(mais aberto — ok em laboratório, evite em rede compartilhada).

Conferir e remover:

```powershell
Get-NetFirewallRule -DisplayName "Mosquitto MQTT 1883 (LAN)"
Remove-NetFirewallRule -DisplayName "Mosquitto MQTT 1883 (LAN)"
```

Provar que a placa alcança a máquina: em **outro** PC/telefone da mesma rede,
`Test-NetConnection IP-do-PC -Port 1883` (PowerShell) ou um app MQTT apontando
para `IP-do-PC:1883`.

---

## 3. Apontar framework e ESP32

O IP é o que o `windows\broker.bat ip` mostra (ou o `IPv4` do adaptador Wi-Fi no
`ipconfig`). Os dois lados precisam dele:

- **Framework** — `4_N4_Armazenamento/Parametros/MQTT.txt`, linhas 4 e 5:
  o IP e `1883`. Pela tela: `./rodar.sh setup` → **URL do Broker** → IP →
  **CONFIGURA MQTT** → **INICIAR**.
- **Sketch** — `const char* MQTT_BROKER = "<IP>";` e `MQTT_PORT = 1883;`, depois
  regrave o ESP32 pela Arduino IDE (*COM4*, *COM5*... no Windows) e mantenha a
  placa na **mesma rede Wi-Fi** do PC.

> O framework (`rodar.sh`, scripts bash) roda no Linux; no Windows o caminho
> normal é rodá-lo no **WSL2** e o broker no Docker Desktop. Nesse arranjo:
> do WSL, `127.0.0.1:1883` funciona para o Python (a porta publicada pelo Docker
> Desktop aparece no WSL); a **placa** continua usando o IP do Windows. Se o
> WSL não alcançar o broker, libere a regra de firewall também para a rede
> virtual do WSL2 (`-Profile Any`) e confira `windows\broker.bat status`.

---

## 4. Problemas comuns

| Sintoma | Causa provável | Resolver |
|---|---|---|
| `nenhum Compose encontrado` | Docker Desktop fechado ou não instalado | abra o Docker Desktop até "Engine running"; ou use o Caminho B |
| `error during connect: ... docker daemon is not running` | idem, ou WSL2 desatualizado | abra o Docker Desktop; `wsl --update` e reinicie |
| `up` falha e a porta não abre | 1883 já em uso | `netstat -ano \| findstr :1883` → veja o PID em `tasklist /FI "PID eq N"`; pare o serviço (`net stop mosquitto`) ou use `PORTA_MQTT` |
| Python do N3 conecta, ESP32 não | firewall, perfil de rede "Público", AP isolation, IP errado, sketch não regravado | §2 e `windows\broker.bat logs` (as conexões aparecem lá) |
| ESP32 conecta ao Wi-Fi e não vê o broker | placa em outra rede (2,4 GHz × 5 GHz) ou AP isolation | use a mesma rede/roteador, sem isolamento de clientes |
| `bad interpreter` ou `^M` ao rodar um `.sh` no WSL | clone com CRLF | `git config --global core.autocrlf input` e clone de novo |
| Mosquitto nativo: `Address in use` | serviço `mosquitto` de fundo | `net stop mosquitto` (§1-B) |
| Docker Desktop não inicia / erro de virtualização | VT-x/AMD-V desligado na BIOS | ligue a virtualização e reinicie |

---

## 5. Limpando

```bat
windows\broker.bat down      rem para o container; o volume de dados fica
windows\broker.bat limpar    rem remove container + volume de dados
```

No Caminho B, feche a janela do `mosquitto-nativo.bat` (Ctrl+C) e, se quiser
apagar a persistência, exclua `windows\dados\`.

---

## 6. Referências

- Docker Desktop para Windows: <https://docs.docker.com/desktop/install/windows-install/>
- WSL2: <https://learn.microsoft.com/windows/wsl/install>
- Mosquitto para Windows: <https://mosquitto.org/download/>
- Firewall do Windows com PowerShell (`New-NetFirewallRule`):
  <https://learn.microsoft.com/powershell/module/netsecurity/new-netfirewallrule>
