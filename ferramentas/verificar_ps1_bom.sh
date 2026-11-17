#!/usr/bin/env bash
# Garante o BOM UTF-8 nos scripts .ps1.
#
# Por quê: sem BOM, o Windows PowerShell 5.1 (o que vem no Windows 10/11) lê o
# arquivo como ANSI/cp1252 — o script até roda, mas as mensagens com acento saem
# quebradas no terminal. O PowerShell 7 não tem esse problema, mas o aluno usa o
# 5.1.
#
# Chamado pelo pre-commit (.pre-commit-config.yaml), ou na mão:
#   ferramentas/verificar_ps1_bom.sh windows/broker.ps1   # só confere
#   ferramentas/verificar_ps1_bom.sh --fix windows/*.ps1  # corrige

set -euo pipefail

corrigir=0
if [ "${1:-}" = "--fix" ]; then
    corrigir=1
    shift
fi

status=0
for arquivo in "$@"; do
    [ -f "$arquivo" ] || continue
    atual="$(head -c 3 "$arquivo" | od -An -tx1 | tr -d ' \n')"
    if [ "$atual" = "efbbbf" ]; then
        continue
    fi
    if [ "$corrigir" -eq 1 ]; then
        { printf '\xef\xbb\xbf'; cat "$arquivo"; } > "$arquivo.bom"
        mv "$arquivo.bom" "$arquivo"
        printf '%s: BOM UTF-8 adicionado.\n' "$arquivo" >&2
    else
        printf '%s: falta o BOM UTF-8 (EF BB BF) no início — o Windows PowerShell 5.1 leria como ANSI.\n' "$arquivo" >&2
        printf '  corrigir: ferramentas/verificar_ps1_bom.sh --fix %s\n' "$arquivo" >&2
        status=1
    fi
done

exit "$status"
