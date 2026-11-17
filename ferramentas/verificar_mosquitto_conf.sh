#!/usr/bin/env bash
# Guarda a invariante do broker anônimo.
#
# Por quê: o framework não tem campo de usuário/senha — nem no N3 (Python) nem no
# sketch do ESP32. Se alguém ativar `password_file` no mosquitto.conf, o laço
# para em silêncio: o Python do N3 aparece "conectado", o gateway nunca entra e o
# PSR fica em 0 %. O comentário do próprio mosquitto.conf explica como fazer
# isso *de propósito*; este hook só impede que mude sem querer.
#
# Chamado pelo pre-commit, ou na mão:
#   ferramentas/verificar_mosquitto_conf.sh mosquitto/mosquitto.conf

set -euo pipefail

status=0
for arquivo in "$@"; do
    [ -f "$arquivo" ] || continue
    # tira os comentários (do primeiro '#' para o fim da linha) antes de conferir
    efetivo="$(sed -e 's/#.*$//' "$arquivo")"

    if ! printf '%s\n' "$efetivo" | grep -qE '^[[:space:]]*allow_anonymous[[:space:]]+true'; then
        printf '%s: falta "allow_anonymous true" (o framework não envia credenciais).\n' "$arquivo" >&2
        status=1
    fi

    if printf '%s\n' "$efetivo" | grep -qE '^[[:space:]]*(password_file|per_listener_settings)[[:space:]]'; then
        printf '%s: autenticação ativa (password_file/per_listener_settings).\n' "$arquivo" >&2
        printf '  O N3 e o sketch do ESP32 não enviam usuário/senha: o laço vai parar.\n' >&2
        printf '  Se for intencional, ajuste o N3 e o sketch antes (README §10).\n' >&2
        status=1
    fi
done

exit "$status"
