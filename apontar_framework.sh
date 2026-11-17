#!/usr/bin/env bash
# Aponta o Framework_LoRa_MQTT_Cobertura_v2 para este broker local.
#
# Por padrão NÃO grava nada: mostra o que mudaria no MQTT.txt do framework
# (dry-run). Só grava com --gravar.
#
# Uso:
#   ./apontar_framework.sh                     # dry-run com o IP da LAN e porta 1883
#   ./apontar_framework.sh --gravar            # grava broker=IP da LAN, porta=1883
#   ./apontar_framework.sh --broker 10.0.0.7 --gravar
#   ./apontar_framework.sh --porta 1884 --gravar
#   ./apontar_framework.sh --topico-dl mot_mqtt_194104/gateway/downlink --gravar
#
# O que é preservado: comando (INICIAR/PAUSAR/PARAR), nº de medidas, tempo entre
# pacotes, tópicos e QoS continuam iguais, a menos que sejam passados aqui.
#
# Arquivo tocado (8 linhas, na ordem): MQTT.txt §4_N4_Armazenamento/Parametros
#   1) comando  2) nº de medidas  3) tempo entre pacotes  4) broker
#   5) porta    6) tópico DL      7) tópico UL            8) QoS

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK="${FRAMEWORK:-$DIR/../Framework_LoRa_MQTT_Cobertura_v2/Framework_LoRa_MQTT_Survey}"

BROKER=""
PORTA="1883"
TOPICO_DL=""
TOPICO_UL=""
QOS=""
COMANDO=""
MEDIDAS=""
TEMPO=""
GRAVAR=0

erro() {
    echo "[apontar_framework.sh] erro: $*" >&2
    exit 1
}

uso() {
    cat <<'FIM'
Uso: ./apontar_framework.sh [opções]

Por padrão NÃO grava nada (dry-run): mostra o que mudaria no MQTT.txt do
framework. Só grava com --gravar.

  ./apontar_framework.sh                      # dry-run com o IP da LAN e porta 1883
  ./apontar_framework.sh --gravar             # grava broker=IP da LAN, porta=1883
  ./apontar_framework.sh --broker 10.0.0.7 --gravar
  ./apontar_framework.sh --porta 1884 --gravar
  ./apontar_framework.sh --topico-dl mot_mqtt_194104/gateway/downlink --gravar
  ./apontar_framework.sh --framework /caminho/do/Framework_LoRa_MQTT_Survey --gravar

Opções:
  --broker IP · --porta N · --topico-dl T · --topico-ul T · --qos 0|1
  --comando N · --medidas N · --tempo S · --framework DIR · --gravar

O que é preservado: comando, nº de medidas, tempo entre pacotes, tópicos e QoS
continuam iguais, a menos que sejam passados aqui.

Arquivo tocado (8 linhas): 4_N4_Armazenamento/Parametros/MQTT.txt do framework.
Este script é bash: no Windows, use a tela do framework (rodar.sh setup no
WSL/Git Bash) ou edite broker/porta por lá.
FIM
}

while [ $# -gt 0 ]; do
    case "$1" in
        --broker)     BROKER="${2:-}"; shift 2 ;;
        --porta)      PORTA="${2:-}"; shift 2 ;;
        --topico-dl)  TOPICO_DL="${2:-}"; shift 2 ;;
        --topico-ul)  TOPICO_UL="${2:-}"; shift 2 ;;
        --qos)        QOS="${2:-}"; shift 2 ;;
        --comando)    COMANDO="${2:-}"; shift 2 ;;
        --medidas)    MEDIDAS="${2:-}"; shift 2 ;;
        --tempo)      TEMPO="${2:-}"; shift 2 ;;
        --framework)  FRAMEWORK="${2:-}"; shift 2 ;;
        --gravar)     GRAVAR=1; shift ;;
        -h|--ajuda|--help) uso; exit 0 ;;
        *) erro "argumento desconhecido: $1 (veja --ajuda)" ;;
    esac
done

ARQUIVO="$FRAMEWORK/4_N4_Armazenamento/Parametros/MQTT.txt"
[ -f "$ARQUIVO" ] || erro "não achei $ARQUIVO (use --framework /caminho/do/Framework_LoRa_MQTT_Survey)"

case "$PORTA" in
    ''|*[!0-9]*) erro "a porta deve ser um número inteiro (recebi '$PORTA')" ;;
esac
[ "$PORTA" -ge 1 ] && [ "$PORTA" -le 65535 ] || erro "porta fora da faixa 1..65535: $PORTA"

# ---------------------------------------------------------------------------
# lê o que está lá hoje (o arquivo pode ter CRLF: foi gravado no Windows)
# ---------------------------------------------------------------------------
mapfile -t LINHAS < <(sed -e 's/\r$//' "$ARQUIVO")
[ "${#LINHAS[@]}" -ge 8 ] || erro "MQTT.txt com ${#LINHAS[@]} linha(s); esperava 8. Abra ./rodar.sh setup e salve de novo."

atual_comando="${LINHAS[0]}"
atual_medidas="${LINHAS[1]}"
atual_tempo="${LINHAS[2]}"
atual_broker="${LINHAS[3]}"
atual_porta="${LINHAS[4]}"
atual_dl="${LINHAS[5]}"
atual_ul="${LINHAS[6]}"
atual_qos="${LINHAS[7]}"

# ---------------------------------------------------------------------------
# valores novos (o que não foi passado continua como está)
# ---------------------------------------------------------------------------
if [ -z "$BROKER" ]; then
    BROKER="$(ip -4 route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
fi
[ -n "$BROKER" ] || erro "não consegui descobrir o IP da LAN; passe --broker <IP>"

novo_comando="${COMANDO:-$atual_comando}"
novo_medidas="${MEDIDAS:-$atual_medidas}"
novo_tempo="${TEMPO:-$atual_tempo}"
novo_porta="$PORTA"
novo_dl="${TOPICO_DL:-$atual_dl}"
novo_ul="${TOPICO_UL:-$atual_ul}"
novo_qos="${QOS:-$atual_qos}"

case "$novo_qos" in
    0|1) ;;
    *) erro "QoS deve ser 0 ou 1 (recebi '$novo_qos')" ;;
esac

case "$BROKER" in
    localhost|127.0.0.1|::1)
        echo "[apontar_framework.sh] aviso: '$BROKER' só funciona para o Python no" >&2
        echo "  mesmo computador — o ESP32 não alcança o localhost da máquina." >&2
        echo "  Para o laço completo, use o IP da LAN (./broker.sh ip)." >&2
        ;;
esac

# ---------------------------------------------------------------------------
# mostra o antes/depois
# ---------------------------------------------------------------------------
linha_diff() { # $1=rótulo $2=atual $3=novo
    if [ "$2" != "$3" ]; then
        printf '  %-24s %-30s -> %s\n' "$1" "$2" "$3"
    else
        printf '  %-24s %-30s    (igual)\n' "$1" "$2"
    fi
}

echo "Arquivo: $ARQUIVO"
echo
linha_diff "1 comando"          "$atual_comando" "$novo_comando"
linha_diff "2 nº de medidas"    "$atual_medidas" "$novo_medidas"
linha_diff "3 tempo [s]"        "$atual_tempo"   "$novo_tempo"
linha_diff "4 broker"           "$atual_broker"  "$BROKER"
linha_diff "5 porta"            "$atual_porta"   "$novo_porta"
linha_diff "6 tópico DL"        "$atual_dl"      "$novo_dl"
linha_diff "7 tópico UL"        "$atual_ul"      "$novo_ul"
linha_diff "8 QoS"              "$atual_qos"     "$novo_qos"
echo

if [ "$GRAVAR" -eq 0 ]; then
    echo "dry-run: nada foi gravado. Para aplicar:  $0 --gravar"
    echo "(depois: ./rodar.sh broker  — mostra e testa broker:porta com o framework)"
    exit 0
fi

# Grava preservando 1-3, 6-7 e trocando broker/porta. LF fixo (o mesmo formato
# que o Setup_Parametros_MQTT.py produz no Linux).
if ! printf '%s\n' "$novo_comando" "$novo_medidas" "$novo_tempo" "$BROKER" \
        "$novo_porta" "$novo_dl" "$novo_ul" "$novo_qos" > "$ARQUIVO"; then
    erro "não consegui gravar em $ARQUIVO (permissão?)"
fi

echo "gravado."
echo
echo "próximos passos:"
echo "  1) cd $FRAMEWORK && ./rodar.sh broker     # confere broker:porta com o framework"
echo "  2) ./rodar.sh setup                       # confira na tela (opcional) e clique INICIAR"
echo "  3) sketch do Gateway: MQTT_BROKER = \"$BROKER\"  (e regrave o ESP32)"
