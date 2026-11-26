# ccp

`ccp` abre Claude Code con una cuenta distinta en cada terminal. Puedes tener la cuenta del trabajo en una ventana y la personal en otra, al mismo tiempo, sin cerrar sesión.

```bash
ccp 0    # tu cuenta de siempre (~/.claude)
ccp 1    # otra cuenta
ccp 2    # otra más
```

Cada número es un perfil. Cada perfil tiene su propio login y su propio historial. Los settings, plugins, hooks, skills, agents y servidores MCP salen de tu `~/.claude`, así que configuras todo una sola vez.

## Requisitos

- macOS (el login se guarda en el Keychain)
- [Claude Code](https://docs.claude.com/en/docs/claude-code) instalado
- `jq` y `rsync`: `brew install jq rsync`

## Instalación

```bash
git clone https://github.com/danihrndzld/ccp.git ~/ccp
mkdir -p ~/.local/bin
ln -s ~/ccp/ccp ~/.local/bin/ccp
```

Si `~/.local/bin` no está en tu `PATH`, agrégalo a `~/.zshrc` y abre una terminal nueva:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

Para actualizar: `git -C ~/ccp pull`.

## Uso

Crea un perfil nuevo y entra con otra cuenta:

```bash
ccp add          # crea el perfil 1 (luego el 2, el 3...)
ccp 1            # abre Claude Code con ese perfil
/login           # dentro de Claude Code, la primera vez
```

| Comando | Qué hace |
|---|---|
| `ccp ls` | Lista los perfiles y la cuenta de cada uno |
| `ccp add` | Crea el siguiente perfil |
| `ccp add --share` | Igual, y además usa tu `~/.claude/CLAUDE.md` |
| `ccp <n>` | Abre Claude Code con el perfil `n` |
| `ccp <n> --resume` | Cualquier argumento extra pasa directo a `claude` |
| `ccp mv <origen> <destino>` | Mueve una sesión de un perfil a otro sin perder el login |

Ejemplo de `ccp ls`:

```
  0  default
  1  yo@personal.com
  2  yo@trabajo.com
```

## Qué se comparte y qué no

| Compartido con `~/.claude` | Propio de cada perfil |
|---|---|
| `settings.json`, `plugins/`, `hooks/`, `hud/` | Login (en el Keychain) |
| `skills/`, `agents/`, `commands/` | Historial y sesiones |
| Servidores MCP de `~/.claude.json` | `CLAUDE.md` (salvo con `--share`) |

Lo compartido son enlaces simbólicos: si cambias un setting en el perfil 0, cambia en todos. Los servidores MCP se copian cada vez que abres un perfil.

## Cómo funciona

Cada perfil es una carpeta en `~/.claude-profiles/<n>`. `ccp` pone `CLAUDE_CONFIG_DIR` apuntando a esa carpeta y abre `claude`. Claude Code guarda el login en el Keychain con un nombre que sale de esa ruta, por eso cada perfil tiene su propia sesión.

## Cuidado

- **No renombres ni muevas las carpetas a mano.** El login depende de la ruta y se pierde. Usa `ccp mv`.
- **Para borrar un perfil:** ciérralo y corre `rm -rf ~/.claude-profiles/<n>`. Si quieres, borra también su login con `security delete-generic-password -s "Claude Code-credentials-<hash>"` (`security dump-keychain | grep Claude` te muestra el nombre).
- **Un perfil no es un usuario aparte.** Claude corre con tu usuario de macOS y puede leer tus archivos. Si otra persona usa tu Mac, un perfil separa su cuenta, no sus permisos.
