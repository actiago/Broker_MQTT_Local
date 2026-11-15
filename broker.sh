#!/usr/bin/env bash
# Broker MQTT local — Framework LoRa MQTT (Cobertura) / FEE247-WissTek-IoT
#
# Sobe o broker Mosquitto em container e faz o resto do ciclo (testar, ver
# logs, descobrir o IP da LAN para o framework e para o ESP32).
#
# Uso:
#   ./broker.sh up        sobe o broker (cria/atualiza o container) e valida
#   ./broker.sh down      para e remove o container (o volume de dados fica)
#   ./broker.sh limpar    remove o container E apaga o volume de dados
#   ./broker.sh restart   reinicia o container
#   ./broker.sh status    container, porta 1883, self-test QoS 1, versão, IP
#   ./broker.sh teste     autoteste: publica e recebe por QoS 1 dentro do container
#   ./broker.sh ip        IP da LAN + as linhas prontas para MQTT.txt e o sketch
#   ./broker.sh logs      acompanha os logs (Ctrl+C para sair)
#   ./broker.sh shell     abre um shell dentro do container
#   ./broker.sh config    mostra a configuração em uso (/mosquitto/config/...)
#
# Sem argumento o comando é "up".
#
# O engine é escolhido sozinho (docker compose, docker-compose, podman compose
# ou podman-compose). Para forçar: COMPOSE="podman-compose" ./broker.sh up

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$DIR/docker-compose.yml"
CONTAINER="broker-mqtt-local"
PORTA="${PORTA_MQTT:-1883}"

# ---------------------------------------------------------------------------
# engine: Compose para subir/derrubar, engine puro (docker|podman) para ps/logs/
# exec. Os dois são resolvidos uma vez, no início.
# ---------------------------------------------------------------------------
escolhe_compose() {
    if [ -n "${COMPOSE:-}" ]; then
        printf '%s' "$COMPOSE"
        return 0
    fi
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        printf 'docker compose'
    elif command -v docker-compose >/dev/null 2>&1; then
        printf 'docker-compose'
    elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
        printf 'podman compose'
    elif command -v podman-compose >/dev/null 2>&1; then
        printf 'podman-compose'
    else
        printf 'erro: nenhum Compose encontrado (instale docker-ce + compose, ou podman + podman-compose)' >&2
        return 1
    fi
}

if ! COMPOSE_TXT="$(escolhe_compose)"; then
    exit 1
fi
read -r -a COMPOSE_CMD <<< "$COMPOSE_TXT"

if [ "${COMPOSE_CMD[0]}" = "docker" ] || [ "${COMPOSE_CMD[0]}" = "docker-compose" ]; then
    ENGINE="docker"
    if ! command -v docker >/dev/null 2>&1; then
        echo "[broker.sh] aviso: compose disse docker, mas o binário docker não está no PATH." >&2
        exit 1
    fi
else
    ENGINE="podman"
    if ! command -v podman >/dev/null 2>&1; then
        echo "[broker.sh] aviso: compose disse podman, mas o binário podman não está no PATH." >&2
        exit 1
    fi
fi

compose() { "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" "$@"; }

# ---------------------------------------------------------------------------
# utilidades
# ---------------------------------------------------------------------------
tcp_ok() {
    timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/$PORTA" >/dev/null 2>&1
}

espera_porta() {
    local tentativas=60 i=1
    while [ "$i" -le "$tentativas" ]; do
        if tcp_ok; then
            echo "[broker.sh] porta $PORTA respondendo em 127.0.0.1."
            return 0
        fi
        [ "$i" -eq 10 ] && echo "[broker.sh] ainda não... (primeira execução baixa a imagem eclipse-mosquitto:2)" >&2
        sleep 0.5
        i=$((i + 1))
    done
    echo "[broker.sh] erro: a porta $PORTA não abriu em 30 s." >&2
    echo "[broker.sh] veja o que o container disse:  ./broker.sh logs" >&2
    return 1
}

# Autoteste dentro do container (os clientes mosquitto_sub/pub já vêm na imagem,
# então não é preciso instalar nada no host): assina e publica no mesmo tópico e
# exige que a mensagem volte pelo caminho do broker.
teste_qos() {
    local topico="broker_mqtt_local/selftest/$$" msg="ping-$$" saida=""
    saida=$("$ENGINE" exec "$CONTAINER" sh -c \
        "mosquitto_sub -h 127.0.0.1 -p $PORTA -t '$topico' -C 1 -W 5 -q 1 > /tmp/selftest.out 2>&1 & sleep 1; mosquitto_pub -h 127.0.0.1 -p $PORTA -t '$topico' -m '$msg' -q 1; wait; cat /tmp/selftest.out" \
        2>&1) || true
    if [ "$saida" = "$msg" ]; then
        echo "[SELFTEST] broker respondendo em $PORTA (QoS 1) — ok"
        return 0
    fi
    echo "[SELFTEST] FALHOU: a mensagem não voltou do broker em $PORTA" >&2
    [ -n "$saida" ] && printf '[SELFTEST] saída: %s\n' "$saida" >&2
    return 1
}

ip_lan() {
    local ip=""
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    [ -n "$ip" ] || ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    printf '%s' "$ip"
}

# ---------------------------------------------------------------------------
# comandos
# ---------------------------------------------------------------------------
mostra_ip() {
    local ip
    ip="$(ip_lan)"
    if [ -z "$ip" ]; then
        echo "[broker.sh] não consegui descobrir o IP da LAN (sem rede ativa?)" >&2
        return 1
    fi
    cat <<EOF
IP da LAN desta máquina: $ip

Use exatamente esse valor nos DOIS lados (sem "localhost"!):

1) Framework — 4_N4_Armazenamento/Parametros/MQTT.txt, linhas 4 e 5:
     $ip
     1883
   (ou pelo Setup: ./rodar.sh setup → campo "URL do Broker" → $ip)

2) Sketch do Gateway — 2_Gateway_LoRa_MQTT_N2_QoS1.ino:
     const char* MQTT_BROKER = "$ip";
     const int   MQTT_PORT   = 1883;
   A placa precisa estar na mesma rede Wi-Fi (2.4 GHz) da máquina.
EOF
}

sobe() {
    echo "[broker.sh] engine: $COMPOSE_TXT"
    if ! compose up -d; then
        echo "[broker.sh] erro: o compose não subiu o broker." >&2
        echo "[broker.sh] dica: se a porta $PORTA estiver ocupada, veja 'ss -ltnp | grep $PORTA'." >&2
        exit 1
    fi
    espera_porta
    echo
    "$ENGINE" ps -a --filter "name=$CONTAINER" || true
    echo
    teste_qos
    echo
    deixa_claro_ip
}

deixa_claro_ip() {
    echo "[broker.sh] broker no ar: mqtt://$(ip_lan):$PORTA (anônimo — rede de laboratório)"
    echo "[broker.sh] framework: ./broker.sh ip | para apontar: ./apontar_framework.sh --gravar"
}

para() {
    if "$ENGINE" inspect "$CONTAINER" >/dev/null 2>&1; then
        compose down
        echo "[broker.sh] container removido. O volume de dados foi mantido"
        echo "[broker.sh] (para apagar também os dados: ./broker.sh limpar)."
    else
        echo "[broker.sh] não há container deste compose em execução."
        compose down >/dev/null 2>&1 || true
    fi
}

limpa() {
    compose down -v
    echo "[broker.sh] container E volume de dados removidos."
}

reinicia() {
    "$ENGINE" restart "$CONTAINER" >/dev/null
    espera_porta
    teste_qos
}

status() {
    echo "[broker.sh] engine: $COMPOSE_TXT"
    echo
    echo "--- container ---"
    "$ENGINE" ps -a --filter "name=$CONTAINER" || true
    echo
    echo "--- porta $PORTA (127.0.0.1) ---"
    if tcp_ok; then
        echo "aberta"
    else
        echo "FECHADA — o broker não está atendendo (./broker.sh logs)"
    fi
    echo
    echo '--- $SYS/broker/version ---'
    "$ENGINE" exec "$CONTAINER" \
        mosquitto_sub -h 127.0.0.1 -p "$PORTA" -t '$SYS/broker/version' -C 1 -W 8 2>/dev/null \
        || echo "(sem resposta)"
    echo
    echo "--- self-test QoS 1 ---"
    teste_qos || true
    echo
    echo "--- rede ---"
    echo "IP da LAN: $(ip_lan)  (porta $PORTA)"
}

ajuda() {
    sed -n '7,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "${1:-up}" in
    up)        sobe ;;
    down)      para ;;
    limpar)    limpa ;;
    restart)   reinicia ;;
    status)    status ;;
    teste)     teste_qos ;;
    ip)        mostra_ip ;;
    logs)      "$ENGINE" logs -f --tail 50 "$CONTAINER" ;;
    shell)     "$ENGINE" exec -it "$CONTAINER" sh ;;
    config)    "$ENGINE" exec "$CONTAINER" cat /mosquitto/config/mosquitto.conf ;;
    ajuda|-h|--help)
               ajuda ;;
    *)
        echo "[broker.sh] comando desconhecido: $1" >&2
        echo >&2
        ajuda >&2
        exit 1
        ;;
esac
