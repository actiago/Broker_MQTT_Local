# Broker MQTT local — Framework LoRa MQTT (Cobertura)

Broker **Eclipse Mosquitto 2** em container, na própria máquina, na porta
**1883**, para o `Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey`
do projeto (FEE247 / WissTek-IoT).

O framework inteiro — N3 (Python), simulador, N5/N6 e o Gateway ESP32 — fala
**um único broker**. Até aqui esse broker era um público (`test.mosquitto.org`,
`broker.hivemq.com`, `www.tpm.dev.br`); este repositório coloca o broker na LAN:

| Com broker público | Com este repositório |
|---|---|
| depende da internet da bancada estar de pé | funciona sem internet, na rede local |
| taxa/limite e indisponibilidade do serviço alheio | o broker é seu; se cair, você reinicia |
| as mensagens `mot_mqtt_194104/...` convivem com as de outros grupos | só existe quem você conectar |
| latência variável (ida e volta até a internet) | ida e volta dentro da LAN |

O que **não** muda: o formato dos pacotes, os tópicos, o QoS 1, o
`MQTT.txt` de 8 linhas e os scripts do framework. Muda **um valor** em cada
lado (o broker), descritos em §4 e §5.

---

## 1. O que tem aqui

| Caminho | Para que serve |
|---|---|
| `docker-compose.yml` | definição do container (imagem, porta 1883, volume de dados, healthcheck) |
| `mosquitto/mosquitto.conf` | configuração do broker (listener `0.0.0.0:1883`, anônimo, logs, persistência) |
| `broker.sh` | o dia a dia: `up`, `down`, `status`, `teste`, `ip`, `logs`, `shell`, `config` |
| `apontar_framework.sh` | grava broker/porta no `MQTT.txt` do framework (**dry-run** por padrão) |
| `CHANGELOG.md` | histórico do repositório |

Os volumes são gerenciados pelo engine: `broker-mqtt-local-dados` guarda o
`/mosquitto/data` para que a persistência do Mosquitto funcione.

---

## 2. Pré-requisitos

Nesta máquina já está tudo instalado (verificado):

```bash
podman --version          # podman 4.9.3
podman-compose --version  # podman-compose 1.0.6
```

Se em outra máquina faltar:

```bash
sudo apt install podman podman-compose
# (ou Docker: docker-ce + plugin compose — os mesmos comandos do broker.sh funcionam)
```

O `./broker.sh` escolhe o engine sozinho (`docker compose`, `docker-compose`,
`podman compose` ou `podman-compose`). Para forçar:

```bash
COMPOSE="podman-compose" ./broker.sh up
```

Não é preciso instalar o Mosquitto no sistema, nem usar `sudo`, nem abrir um
serviço `systemd`: o broker vive dentro do container.

---

## 3. Início rápido

```bash
cd /home/tiago/projetos/github/LoRa/Broker_MQTT_Local

./broker.sh up      # sobe (o primeiro "up" baixa a imagem eclipse-mosquitto:2)
./broker.sh teste   # publica e recebe por QoS 1 dentro do container
./broker.sh ip      # o IP da LAN que você vai usar no framework e no ESP32
```

Saída esperada (a primeira execução demora mais, baixando a imagem):

```
[broker.sh] engine: podman-compose
[broker.sh] porta 1883 respondendo em 127.0.0.1.
[SELFTEST] broker respondendo em 1883 (QoS 1) — ok
[broker.sh] broker no ar: mqtt://192.168.0.105:1883 (anônimo — rede de laboratório)
```

Equivalente "na mão", se preferir os comandos do Compose direto:

```bash
podman compose up -d
podman compose ps
podman compose logs
podman compose down
```

### Já verificado nesta máquina (2026-11-15)

| O que | Resultado |
|---|---|
| Engine | Zorin OS 18.1 · podman 4.9.3 · podman-compose 1.0.6 |
| Imagem | `eclipse-mosquitto:2` → **mosquitto 2.1.2**, container `Up (healthy)` |
| `./broker.sh up`, `status`, `teste` | porta 1883 aberta, `$SYS/broker/version` respondendo, self-test QoS 1 ok |
| Framework contra o broker | o `simulador_gateway.py` (ESP32 falso) assinou o DL, respondeu o UL e o pacote de **20 bytes** voltou pelo broker local em **QoS 1** |

O que **não** foi testado aqui: o sketch e a placa ESP32 (sem hardware) — isso é o
ensaio de campo, com o `MQTT_BROKER` do sketch apontando para o IP da máquina.

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
aceita digitar) → `192.168.0.105` → porta `1883` → **CONFIGURA MQTT** →
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

## 7. Comandos do `broker.sh`

| Comando | O que faz |
|---|---|
| `./broker.sh up` | sobe o container, espera a porta 1883 e roda o self-test |
| `./broker.sh down` | para e remove o container (o volume de dados fica) |
| `./broker.sh limpar` | remove o container **e** apaga o volume de dados |
| `./broker.sh restart` | reinicia (use depois de editar o `mosquitto.conf`) |
| `./broker.sh status` | container, porta, `$SYS/broker/version`, self-test e IP |
| `./broker.sh teste` | autoteste QoS 1 dentro do container (sem instalar cliente no host) |
| `./broker.sh ip` | IP da LAN + as linhas prontas para o `MQTT.txt` e para o sketch |
| `./broker.sh logs` | acompanha os logs (aparecem as conexões do N3 e do ESP32) |
| `./broker.sh shell` | shell dentro do container |
| `./broker.sh config` | mostra o `mosquitto.conf` em uso |

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

## 9. Segurança e limites

- **Anônimo**: sem usuário/senha; quem está na LAN entra. Aceitável em bancada.
- **Sem TLS**: tráfego em claro. Se um dia precisar, o caminho é `cafile`/
  `certfile`/`keyfile` no `mosquitto.conf` — e os dois clientes (N3 e sketch)
  precisam mudar para TLS, o que não é feito hoje.
- **Autenticação** (se a rede não for confiável): o `mosquitto.conf` já traz o
  bloco comentado com `password_file`. Ao ativá-lo, o laço **para** até o N3
  (`mqtt.Client(...).username_pw_set(...)`) e o sketch
  (`mqttClient.connect(clientId, usuario, senha)`) enviarem credenciais.
- **Firewall da máquina**: se a porta estiver fechada para a LAN, libere-a:
  `sudo ufw allow 1883/tcp` (e confira `sudo ufw status`).
- **Sem `sudo`**: o container é rootless (podman). Para ele voltar junto com a
  máquina depois de um reboot:

  ```bash
  systemctl --user enable --now podman-restart.service
  ```

  (o `restart: unless-stopped` do compose é respeitado por esse serviço; sem
  ele, o broker só sobe quando você roda `./broker.sh up`).

---

## 10. Diagnóstico

| Sintoma | Causa provável | Como confirmar / resolver |
|---|---|---|
| `./broker.sh up` falha e a porta não abre | porta 1883 já em uso (Mosquitto do `apt`, outro container) | `ss -ltnp \| grep 1883`; pare o outro serviço ou use `PORTA_MQTT` |
| `podman` reclama de `cannot clone: Operation not permitted` | ambiente sem *user namespaces* (sandbox, container dentro de container, CI) | rode no terminal normal da sessão gráfica |
| container sobe, N3 conecta, mas o ESP32 não recebe DL | IP errado, sketch não regravado, placa em outra rede ou *AP isolation* | `./broker.sh logs` mostra as conexões; `./broker.sh ip` confere o IP |
| N3 "conectado" e PSR em 0 % | tópicos diferentes entre `MQTT.txt` e o sketch | compare as linhas 6 e 7 do `MQTT.txt` com `TOPIC_DL`/`TOPIC_UL` |
| `./rodar.sh broker` (framework) não conecta | broker não está no ar, ou firewall | `./broker.sh status`; `sudo ufw status` |
| logs do container vazios | `log_dest file` sobrescrito na sua cópia do `.conf` | `./broker.sh config` mostra o arquivo realmente em uso |

---

## 11. Limpeza

```bash
./broker.sh down     # para o container; dados preservados
./broker.sh limpar   # remove container + volume de dados
```

Os dois são seguros: nada fora de `Broker_MQTT_Local` e do engine é tocado.

---

## 12. Referências

- Mosquitto (documentação oficial): https://mosquitto.org/documentation/
- Imagem `eclipse-mosquitto` (Docker Hub): https://hub.docker.com/_/eclipse-mosquitto
- `podman-compose`: https://github.com/containers/podman-compose
- Framework e portabilidade Linux: `../Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey/README_Linux.md`
- Arquitetura geral do projeto: `../ARQUITETURA-E-FRAMEWORK.md`
