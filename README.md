# Broker MQTT local — Framework LoRa MQTT (Cobertura)

Broker **Eclipse Mosquitto 2** em container, na sua máquina, na porta **1883**,
para o `Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey`
(disciplina FEE247 — WissTek-IoT).

O framework inteiro — N3 (Python), simulador, N5/N6 e o Gateway ESP32 — fala
**um único broker**. Até aqui esse broker era um público (`test.mosquitto.org`,
`broker.hivemq.com`, `www.tpm.dev.br`); este repositório coloca o broker na LAN:

| Com broker público | Com este repositório |
|---|---|
| depende da internet da bancada estar de pé | funciona sem internet, na rede local |
| taxa/limite e indisponibilidade do serviço alheio | o broker é seu; se cair, você reinicia |
| as mensagens `mot_mqtt_194104/...` convivem com as de outros grupos | só existe quem você conectar |
| latência variável (ida e volta até a internet) | ida e volta dentro da LAN |

O que **não** muda: o formato dos pacotes, os tópicos, o QoS 1, o `MQTT.txt` de
8 linhas e os scripts do framework. Muda **um valor** em cada lado (o broker),
descrito em [§4](#4-apontar-o-framework-para-ele) e
[§5](#5-gateway-esp32-o-outro-lado).

---

## Início rápido

### Linux (ou WSL2), com podman ou Docker

```bash
git clone https://github.com/actiago/Broker_MQTT_Local.git
cd Broker_MQTT_Local

./broker.sh up      # sobe (o primeiro "up" baixa a imagem eclipse-mosquitto:2)
./broker.sh teste   # publica e recebe por QoS 1 dentro do container
./broker.sh ip      # o IP da LAN — use no framework e no sketch do ESP32
```

Saída esperada (a primeira execução demora mais, baixando a imagem):

```
[broker.sh] engine: podman-compose
[broker.sh] porta 1883 respondendo em 127.0.0.1.
[SELFTEST] broker respondendo em 1883 (QoS 1) — ok
[broker.sh] broker no ar: mqtt://192.168.0.10:1883 (anônimo — rede de laboratório)
```

(No exemplo acima, `192.168.0.10` é só ilustração — o seu IP é o que o
`./broker.sh ip` mostrar.)

### Windows

```bat
git clone https://github.com/actiago/Broker_MQTT_Local.git
cd Broker_MQTT_Local

windows\broker.bat up
windows\broker.bat teste
windows\broker.bat ip
```

Funciona com **Docker Desktop (backend WSL2)** — ou, sem Docker nenhum, com o
**Mosquitto nativo do Windows**. Instalação, firewall, IP, WSL e problemas
comuns: [`windows/README_WINDOWS.md`](windows/README_WINDOWS.md).

---

## 1. O que tem aqui

| Caminho | Para que serve |
|---|---|
| `docker-compose.yml` | definição do container (imagem, porta 1883, volume de dados, healthcheck) |
| `mosquitto/mosquitto.conf` | configuração do broker (listener `0.0.0.0:1883`, anônimo, logs, persistência) |
| `broker.sh` | o dia a dia no Linux/WSL: `up`, `down`, `status`, `teste`, `ip`, `logs`, `shell`, `config` |
| `apontar_framework.sh` | grava broker/porta no `MQTT.txt` do framework (**dry-run** por padrão) |
| `windows/` | a mesma coisa no Windows: `broker.bat`, `broker.ps1`, `README_WINDOWS.md` e a alternativa com Mosquitto nativo |
| `CHANGELOG.md` | histórico do repositório |
| `.editorconfig` · `.gitattributes` | fim de linha e indentação iguais para todo mundo (LF nos `.sh`, CRLF nos `.bat`/`.ps1`) |
| `.pre-commit-config.yaml` · `ferramentas/` | hooks de qualidade para quem mexe no projeto (shellcheck, fim de arquivo, BOM do `.ps1`) |

Os volumes são gerenciados pelo engine: `broker-mqtt-local-dados` guarda o
`/mosquitto/data` para que a persistência do Mosquitto funcione.

> **Para quem usa o broker:** nada de `.pre-commit-config.yaml` / `ferramentas/` é
> necessário — são ferramentas de manutenção do repositório. Se um dia você
> contribuir: `pipx install pre-commit && pre-commit install`, depois
> `pre-commit run --all-files`.

---

## 2. Pré-requisitos

**Linux (ou WSL2 no Windows):**

```bash
podman --version          # testado com podman 4.9.3
podman-compose --version  # testado com podman-compose 1.0.6
```

Se faltar:

```bash
sudo apt install podman podman-compose
# ou Docker: docker-ce + plugin compose — os mesmos comandos do broker.sh funcionam
```

**Windows:** Docker Desktop (WSL2) ou Mosquitto nativo — veja
[`windows/README_WINDOWS.md`](windows/README_WINDOWS.md) §1.

O `./broker.sh` escolhe o engine sozinho (`docker compose`, `docker-compose`,
`podman compose` ou `podman-compose`). Para forçar:

```bash
COMPOSE="podman-compose" ./broker.sh up
```

Não é preciso instalar o Mosquitto no sistema, nem usar `sudo`, nem abrir um
serviço `systemd`: o broker vive dentro do container.

### Porta diferente de 1883

Se a 1883 já estiver ocupada (Mosquitto do `apt`, outro container, um serviço no
Windows), troque a porta publicada:

```bash
PORTA_MQTT=1884 ./broker.sh up     # Linux
```

```bat
set PORTA_MQTT=1884
windows\broker.bat up
```

Aí o `MQTT.txt` do framework e o `MQTT_PORT` do sketch também passam a ser
`1884`. O self-test e o `status` seguem a variável automaticamente.

---

## 3. Saída esperada e autoteste

O `up` faz três coisas: sobe o container, espera a porta abrir e roda um
**self-test QoS 1** (publica e recebe dentro do container, com os clientes
`mosquitto_pub`/`mosquitto_sub` que já vêm na imagem — nada é instalado na sua
máquina).

- `[SELFTEST] ... — ok` → o broker está atendendo.
- `[SELFTEST] FALHOU` → a porta abriu mas o broker não responde: `./broker.sh logs`.

Equivalente "na mão", se preferir os comandos do Compose direto:

```bash
podman compose up -d
podman compose ps
podman compose logs
podman compose down
```

Depois do `up`, **dois** lugares precisam do IP desta máquina: o `MQTT.txt` do
framework (§4) e o sketch do ESP32 (§5).

### Já verificado neste repositório

| O que | Resultado |
|---|---|
| Engine de desenvolvimento | Zorin OS 18.1 · podman 4.9.3 · podman-compose 1.0.6 |
| Imagem | `eclipse-mosquitto:2` → **mosquitto 2.1.2**, container `Up (healthy)` |
| `./broker.sh up`, `status`, `teste` | porta 1883 aberta, `$SYS/broker/version` respondendo, self-test QoS 1 ok |
| Framework contra o broker | o `simulador_gateway.py` (ESP32 falso) assinou o DL, respondeu o UL e o pacote de **20 bytes** voltou pelo broker local em **QoS 1** |

O que **não** foi testado aqui: o sketch e a placa ESP32 (sem hardware) — isso é o
ensaio de campo, com o `MQTT_BROKER` do sketch apontando para o IP da máquina.
A versão Windows (`windows/`) também não foi rodada com Docker Desktop no
momento em que este texto foi escrito: comece pelo `windows\broker.bat status`,
que confere container, porta e self-test.

---

## 4. Apontar o framework para ele

O framework lê o broker do arquivo
`4_N4_Armazenamento/Parametros/MQTT.txt` (8 linhas, gravadas pelo
`Setup_Parametros_MQTT.py`, uma por vez):

| Linha | Campo | Valor para o broker local |
|---|---|---|
| 1 | comando (0 parar / 1 iniciar / 2 pausar) | o que já estiver |
| 2 | número de medidas | o que já estiver |
| 3 | tempo entre pacotes [s] | o que já estiver |
| 4 | **broker** | **o IP da LAN desta máquina** (`./broker.sh ip`) |
| 5 | **porta** | **1883** |
| 6 | tópico DL | `mot_mqtt_194104/gateway/downlink` (mantenha) |
| 7 | tópico UL | `mot_mqtt_194104/gateway/uplink` (mantenha) |
| 8 | QoS | `1` |

Duas formas de trocar — a segunda é a que preserva tudo:

**a) pela tela** — `./rodar.sh setup` → campo **URL do Broker** (é um Combobox,
aceita digitar) → `192.168.0.10` → porta `1883` → **CONFIGURA MQTT** →
**INICIAR**. O campo de tópicos já vem com `mot_mqtt_194104/...`.

**b) por script** — mostra o antes/depois e só grava com `--gravar`:

```bash
./apontar_framework.sh                         # dry-run: o que mudaria
./apontar_framework.sh --gravar                # broker = IP da LAN, porta 1883
./apontar_framework.sh --broker 10.0.0.7 --gravar
```

Depois, **dentro do framework**:

```bash
cd ../Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey
./rodar.sh broker     # mostra o MQTT.txt e testa broker:porta (TCP)
```

`./rodar.sh broker` é a conferência que vale para os dois lados: se ele diz que
`broker:porta` respondem, o N3 vai conectar.

> **Se este repositório não estiver ao lado do framework:** `apontar_framework.sh`
> assume `../Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey` por padrão.
> Fora dessa vizinhança, passe o caminho explicitamente:
> `./apontar_framework.sh --framework /caminho/do/Framework_LoRa_MQTT_Survey --gravar`
> (ou exporte `FRAMEWORK=`). O `broker.sh` não depende disso — ele só sobe o container.

---

## 5. Gateway ESP32 (o outro lado)

O IP do broker está **compilado no sketch**, em
`2_Gateway_LoRa_MQTT_N2_QoS1/2_Gateway_LoRa_MQTT_N2_QoS1.ino`. Hoje ele aponta
`test.mosquitto.org`:

```c
const char* MQTT_BROKER = "test.mosquitto.org";   // <- trocar pelo IP da LAN
const int   MQTT_PORT   = 1883;
const char* TOPIC_DL    = "mot_mqtt_194104/gateway/downlink";  // igual ao MQTT.txt
const char* TOPIC_UL    = "mot_mqtt_194104/gateway/uplink";    // igual ao MQTT.txt
```

Troque o `MQTT_BROKER` pelo IP que o `./broker.sh ip` mostrou, **regrave a
placa** (`/dev/ttyUSB0` ou `/dev/ttyACM0` na Arduino IDE) e mantenha a placa na
**mesma rede Wi-Fi** da máquina. Conferindo os três pontos: IP certo, porta
1883, tópicos idênticos aos do `MQTT.txt`.

A rede Wi-Fi não pode ter **isolamento de clientes** (*AP isolation*): é o
motivo mais comum de o ESP32 conectar à internet e ainda assim não alcançar o
broker da LAN. Em rede de celular/eduroam/hotspot compartilhado, acontece.

> A placa ESP32 não fala WPA2-Enterprise: em rede de instituição (eduroam, por
> exemplo) prefira um roteador/AP próprio — e um celular em modo roteador serve,
> desde que sem isolamento de clientes.

---

## 6. Testar o laço completo sem hardware

Com o broker local e o ESP32 falso (o `simulador_gateway.py` faz o papel da
placa, inclusive montando o pacote de 20 bytes como o firmware):

```bash
# terminal 1 — framework
./rodar.sh setup        # broker = IP da LAN, 1883, tópicos do RA -> INICIAR
# terminal 2 — "ESP32" falso, lê broker/tópicos do próprio MQTT.txt
./rodar.sh simular
# terminal 3..6
./rodar.sh n5-gerencia
./rodar.sh n5-cliente
./rodar.sh n6-gerencia
./rodar.sh n3
```

Se o PSR ficar em 0 %, o simulador e o `MQTT.txt` estão em brokers/tópicos
diferentes — `./rodar.sh broker` (framework) e `./broker.sh ip` resolvem a
dúvida. É a mesma conferência do ensaio com as placas.

---

## 7. Comandos

### `broker.sh` (Linux/WSL) e o equivalente no Windows

| Comando | O que faz | Windows |
|---|---|---|
| `./broker.sh up` | sobe o container, espera a porta 1883 e roda o self-test | `windows\broker.bat up` |
| `./broker.sh down` | para e remove o container (o volume de dados fica) | `windows\broker.bat down` |
| `./broker.sh limpar` | remove o container **e** apaga o volume de dados | `windows\broker.bat limpar` |
| `./broker.sh restart` | reinicia (use depois de editar o `mosquitto.conf`) | `windows\broker.bat restart` |
| `./broker.sh status` | container, porta, `$SYS/broker/version`, self-test e IP | `windows\broker.bat status` |
| `./broker.sh teste` | autoteste QoS 1 dentro do container | `windows\broker.bat teste` |
| `./broker.sh ip` | IP da LAN + as linhas prontas para o `MQTT.txt` e para o sketch | `windows\broker.bat ip` |
| `./broker.sh logs` | acompanha os logs (aparecem as conexões do N3 e do ESP32) | `windows\broker.bat logs` |
| `./broker.sh shell` | shell dentro do container | `windows\broker.bat shell` |
| `./broker.sh config` | mostra o `mosquitto.conf` em uso | `windows\broker.bat config` |
| `./broker.sh ajuda` | lista os comandos | `windows\broker.bat ajuda` |

Os clientes de teste (`mosquitto_sub`/`mosquitto_pub`) rodam **dentro** do
container: não é preciso instalar pacote nenhum no host.

---

## 8. Como o broker está configurado (e por quê)

Resumo do `mosquitto/mosquitto.conf`, com a razão de cada escolha:

| Diretiva | Valor | Por quê |
|---|---|---|
| `listener` | `1883 0.0.0.0` | o ESP32 chega pela LAN; `127.0.0.1` deixaria a placa de fora |
| `allow_anonymous` | `true` | o framework não tem campo de usuário/senha (nem no N3, nem no sketch) |
| `max_connections` | `-1` | N3 + simulador + N5/N6 + ESP32 ao mesmo tempo |
| `persistence` | `true` em volume | mensagens/estado sobrevivem a `restart` do container |
| `log_dest` | `stdout` | `./broker.sh logs` vê tudo; nada de arquivo dentro do container |
| `sys_interval` | `5` | `$SYS/broker/version` responde rápido no `./broker.sh status` |

O broker é **anônimo e sem TLS de propósito**: é rede de laboratório. Qualquer
aparelho na LAN pode publicar/assinar, inclusive nos tópicos do seu RA. O
namespace `mot_mqtt_194104/` evita colisão entre grupos, não evita gente
mal-intencionada. Não publique a porta 1883 na internet.

---

## 9. Firewall: libere a porta para a LAN (senão só o próprio PC acessa)

O container roda em **podman rootless**: a porta publicada é atendida por um
processo do `rootlessport` no espaço de rede do host. Consequência prática: as
conexões que vêm **de fora** (o ESP32) passam pela cadeia `input` do firewall do
PC, e um `policy drop` derruba tudo em silêncio — o ESP32 só vê timeout, enquanto
o Python no mesmo PC continua funcionando por *loopback*.

Sintoma típico: `./broker.sh status` diz "porta 1883 respondendo", o
`./rodar.sh broker` (Python) testa OK, mas o gateway nunca aparece no broker.

### Linux — nftables (exemplo com `policy drop` na entrada)

```
chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iifname "lo" accept
    ip protocol icmp accept
    ip saddr 192.168.0.0/24 tcp dport 1883 accept   # Mosquitto para a LAN
}
```

Aplicar sem reiniciar:

```bash
sudo nft add rule inet filter input ip saddr 192.168.0.0/24 tcp dport 1883 accept
```

Persistir: incluir a linha em `/etc/nftables.conf` e recarregar com
`sudo nft -f /etc/nftables.conf` (o arquivo já começa com `flush ruleset`, então
é idempotente — e é ele que roda no boot, pois o serviço está `enabled`).

Para provar que os pacotes chegam, use um contador: `sudo nft add rule inet
filter input ip saddr 192.168.0.0/24 tcp dport 1883 counter accept` e depois
`sudo nft list ruleset` — o contador tem que subir quando a placa tentar conectar.

### Linux — ufw

```bash
sudo ufw allow from 192.168.0.0/24 to any port 1883 proto tcp
sudo ufw status
```

### Windows

Docker Desktop e Mosquitto nativo esbarram na mesma regra de entrada. No
PowerShell **como administrador**:

```powershell
New-NetFirewallRule -DisplayName "Mosquitto MQTT 1883 (LAN)" -Direction Inbound `
  -Protocol TCP -LocalPort 1883 -Action Allow -Profile Private
```

Confira com `Get-NetFirewallRule -DisplayName "Mosquitto MQTT 1883 (LAN)"` e
remova com `Remove-NetFirewallRule -DisplayName "Mosquitto MQTT 1883 (LAN)"`.
Detalhes e o caso do perfil de rede "Público": [`windows/README_WINDOWS.md`](windows/README_WINDOWS.md) §2.

> Laboratório: esta liberação deixa o broker **anônimo** visível para toda a
> sub-rede. Para apertar depois: reservar o IP do gateway no DHCP e liberar só
> ele (`ip saddr 192.168.0.150 tcp dport 1883 accept`) ou colocar usuário/senha no
> `mosquitto/mosquitto.conf` (aí o sketch e o Python também precisam das
> credenciais).

---

## 10. Segurança e limites

- **Anônimo**: sem usuário/senha; quem está na LAN entra. Aceitável em bancada.
- **Sem TLS**: tráfego em claro. Se um dia precisar, o caminho é `cafile`/
  `certfile`/`keyfile` no `mosquitto.conf` — e os dois clientes (N3 e sketch)
  precisam mudar para TLS, o que não é feito hoje.
- **Autenticação** (se a rede não for confiável): o `mosquitto.conf` já traz o
  bloco comentado com `password_file`. Ao ativá-lo, o laço **para** até o N3
  (`mqtt.Client(...).username_pw_set(...)`) e o sketch
  (`mqttClient.connect(clientId, usuario, senha)`) enviarem credenciais.
- **Sem `sudo`**: o container é rootless (podman). Para ele voltar junto com a
  máquina depois de um reboot:

  ```bash
  systemctl --user enable --now podman-restart.service
  ```

  (o `restart: unless-stopped` do compose é respeitado por esse serviço; sem
  ele, o broker só sobe quando você roda `./broker.sh up`). No Docker Desktop
  do Windows isso é automático, desde que "Start Docker Desktop when you sign
  in to your computer" esteja marcado.

---

## 11. Diagnóstico

| Sintoma | Causa provável | Como confirmar / resolver |
|---|---|---|
| `./broker.sh up` falha e a porta não abre | porta 1883 já em uso (Mosquitto do `apt`, outro container) | `ss -ltnp \| grep 1883`; pare o outro serviço ou use `PORTA_MQTT` (§2) |
| `podman` reclama de `cannot clone: Operation not permitted` | ambiente sem *user namespaces* (sandbox, container dentro de container, CI) | rode no terminal normal da sessão gráfica |
| container sobe, N3 conecta, mas o ESP32 não recebe DL | IP errado, sketch não regravado, placa em outra rede ou *AP isolation* | `./broker.sh logs` mostra as conexões; `./broker.sh ip` confere o IP |
| N3 "conectado" e PSR em 0 % | tópicos diferentes entre `MQTT.txt` e o sketch | compare as linhas 6 e 7 do `MQTT.txt` com `TOPIC_DL`/`TOPIC_UL` |
| `./rodar.sh broker` (framework) não conecta | broker não está no ar, ou firewall | `./broker.sh status`; `sudo ufw status` (§9) |
| logs do container vazios | `log_dest file` sobrescrito na sua cópia do `.conf` | `./broker.sh config` mostra o arquivo realmente em uso |
| Windows: `windows\broker.bat up` diz "nenhum Compose encontrado" | Docker Desktop fechado / não instalado | abra o Docker Desktop e espere "Engine running", ou use o Mosquitto nativo ([`windows/README_WINDOWS.md`](windows/README_WINDOWS.md)) |
| Windows: `bad interpreter` ou `\r` ao rodar um `.sh` | `.sh` com CRLF (clone feito com `core.autocrlf=true`) | use `windows\broker.bat` no Windows; no WSL, `git config --global core.autocrlf input` e clone de novo |

---

## 12. Limpeza

```bash
./broker.sh down     # para o container; dados preservados
./broker.sh limpar   # remove container + volume de dados
```

No Windows: `windows\broker.bat down` e `windows\broker.bat limpar`.

Os dois são seguros: nada fora de `Broker_MQTT_Local` e do engine é tocado.

---

## 13. Referências

- Mosquitto (documentação oficial): https://mosquitto.org/documentation/
- Imagem `eclipse-mosquitto` (Docker Hub): https://hub.docker.com/_/eclipse-mosquitto
- Mosquitto para Windows (instalador): https://mosquitto.org/download/
- `podman-compose`: https://github.com/containers/podman-compose
- Framework e portabilidade Linux: `../Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey/README_Linux.md`
- Arquitetura geral do projeto: `../ARQUITETURA-E-FRAMEWORK.md`

---

Licença MIT — veja [`LICENSE`](LICENSE). Repositório de apoio à disciplina
FEE247 (WissTek-IoT); achou um problema? Abra uma *issue* com a saída de
`./broker.sh status` (ou `windows\broker.bat status`).
