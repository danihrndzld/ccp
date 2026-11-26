#!/usr/bin/env bash
# ccp — corre Claude Code con login aislado por perfil y la misma config que ~/.claude.
#   ccp ls                    lista perfiles y su cuenta (0 = default = ~/.claude)
#   ccp add [--share]         crea el siguiente número; --share además enlaza tu CLAUDE.md
#   ccp mv <origen> <destino> mueve la sesión (login + historial) entre perfiles
#   ccp <n> [args]            abre claude con ese perfil
# Cada perfil vive en ~/.claude-profiles/<n> (el HUD muestra ese nombre). El login está en el
# Keychain como "Claude Code-credentials-<sha256(ruta)[:8]>": renombrar la carpeta pierde la sesión.
set -euo pipefail
shopt -s nullglob
base="$HOME/.claude-profiles"
# Compartido con ~/.claude por symlink (cambios en uno se ven en todos); login e historial nunca.
shared=(settings.json plugins hooks hud skills agents commands .omc-config.json)
mkdir -p "$base"

# Carpetas "<n>" o "<n>-algo" (formato viejo, se normaliza en 'ccp mv').
profiles() { for d in "$base"/[0-9]*/; do basename "$d"; done | sort -n; }
dir_of() {
  local m; m=$(profiles | awk -v s="$1" '$0 == s || index($0, s "-") == 1' | head -1)
  [[ -n $m ]] || { echo "ccp: no existe el perfil '$1' (corre 'ccp ls' o 'ccp add')" >&2; exit 1; }
  echo "$base/$m"
}
svc_of() { echo "Claude Code-credentials-$(printf '%s' "$1" | shasum -a 256 | cut -c1-8)"; }
email_of() { jq -r '.oauthAccount.emailAddress // ""' "$1/.claude.json" 2>/dev/null || true; }
running() {
  local p
  for p in $(pgrep -x claude); do
    if ps -wwE -o command= -p "$p" | grep -q "CLAUDE_CONFIG_DIR=$1\( \|$\)"; then return 0; fi
  done
  return 1
}
copy_cred() {  # copy_cred <dir origen> <dir destino>
  local s_svc acct; s_svc=$(svc_of "$1")
  acct=$(security find-generic-password -s "$s_svc" 2>/dev/null | sed -n 's/.*"acct"<blob>="\(.*\)"$/\1/p')
  [[ -n $acct ]] || { echo "ccp: ${1##*/} no tiene sesión en el Keychain" >&2; exit 1; }
  local d_svc hex; d_svc=$(svc_of "$2")
  hex=$(printf '%s' "$(security find-generic-password -s "$s_svc" -w)" | xxd -p | tr -d '\n')  # sin el \n final
  # El token entra por stdin a `security -i` (no en argv, no se ve en `ps`). `-w` sin valor
  # tampoco sirve: lee de stdin con getpass y corta a 128 caracteres.
  printf 'add-generic-password -U -a "%s" -s "%s" -X %s\n' "$acct" "$d_svc" "$hex" | security -i
  [[ $(security find-generic-password -s "$d_svc" -w) == "$(security find-generic-password -s "$s_svc" -w)" ]] \
    || { echo "ccp: la copia del login no coincide con el original; no toco nada más" >&2; exit 1; }
}
link_shared() {
  local f cj="$1/.claude.json"
  for f in "${shared[@]}"; do
    if [[ -e $HOME/.claude/$f && ! -e $1/$f && ! -L $1/$f ]]; then ln -s "$HOME/.claude/$f" "$1/$f"; fi
  done
  # Los MCP de usuario viven en ~/.claude.json junto al login: se copia solo .mcpServers.
  if [[ -f $HOME/.claude.json ]]; then
    [[ -f $cj ]] || echo '{}' > "$cj"
    jq --argjson m "$(jq '.mcpServers // {}' "$HOME/.claude.json")" '.mcpServers = $m' "$cj" > "$cj.tmp"
    chmod 600 "$cj.tmp" && mv "$cj.tmp" "$cj"
  fi
}

case "${1:-}" in
  "" | -h | --help | ls)
    echo "uso: ccp <n> [args]  |  ccp add [--share]  |  ccp mv <origen> <destino>  |  ccp ls"
    echo "  0  default"
    for n in $(profiles); do printf '  %s  %s\n' "${n%%-*}" "$(email_of "$base/$n")"; done
    exit 0 ;;
  add)
    last=$(profiles | tail -1); n=$(( ${last%%-*} + 1 ))
    mkdir "$base/$n"
    link_shared "$base/$n"
    if [[ ${2:-} == --share ]]; then ln -s "$HOME/.claude/CLAUDE.md" "$base/$n/CLAUDE.md"; fi
    echo "ccp: creado perfil $n. Ábrelo con 'ccp $n' y corre /login la primera vez."
    exit 0 ;;
  mv)
    src=$(dir_of "${2:-}"); dst=$(dir_of "${3:-}")
    [[ $src != "$dst" ]] || { echo "ccp: origen y destino son el mismo perfil" >&2; exit 1; }
    se=$(email_of "$src"); de=$(email_of "$dst")
    [[ -z $de || $de == "$se" ]] || { echo "ccp: el perfil $3 ya tiene la sesión de $de; no la piso" >&2; exit 1; }
    copy_cred "$src" "$dst"
    excl=(--exclude=/CLAUDE.md); for f in "${shared[@]}"; do excl+=("--exclude=/$f"); done
    rsync -a --no-links "${excl[@]}" "$src/" "$dst/"
    link_shared "$dst"
    if running "$src"; then
      echo "ccp: copié la sesión ($se) del perfil $2 al $3. El $2 sigue abierto y no lo toqué;"
      echo "     ciérralo y vuelve a correr 'ccp mv $2 $3' para copiar el token más reciente y vaciar el $2."
    else
      security delete-generic-password -s "$(svc_of "$src")" >/dev/null
      rm -rf "$src"
      mkdir "$base/$2" && link_shared "$base/$2"
      echo "ccp: sesión de $se movida del perfil $2 al $3; el $2 quedó vacío y sin login."
    fi
    exit 0 ;;
esac

if [[ $1 == 0 || $1 == default ]]; then
  shift; unset CLAUDE_CONFIG_DIR; export CLAUDE_PROFILE=0
  exec claude "$@"
fi
d=$(dir_of "$1"); shift
link_shared "$d"
export CLAUDE_CONFIG_DIR=$d CLAUDE_PROFILE=${d##*/}
exec claude "$@"
