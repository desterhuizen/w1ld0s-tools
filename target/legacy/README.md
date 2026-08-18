# Frozen bash `target`

`target.bash` is the original bash implementation of `target`, kept verbatim as a rollback path after the Python port (`target/target.py`).

It is **not** maintained. Bug fixes and new features go into `target/target.py`.

## Why mode 0644 matters

`setup_links:13` enumerates symlink candidates with `find . -type f -executable`, and `setup_links:30` strips the file extension when naming the link. An **executable** `target.bash` would therefore strip to `target` and race `target/target.py` for `~/.local/bin/target`, with `find` order deciding the winner — nondeterministically.

Mode `0644` fails the `-executable` test, so this file is never enumerated. **Do not `chmod +x` it.** Run it explicitly instead:

```bash
bash target/legacy/target.bash -i
```

The same reasoning is why this lives here rather than beside `target.py`: mode `0644` keeps it out of `setup_links` without needing an exclude rule.

It is also excluded from CI via `FILTER_REGEX_EXCLUDE` in `.github/workflows/super-linter.yml`. Super-Linter runs with `VALIDATE_ALL_CODEBASE: false`, so moving the file makes it a *changed* file and would otherwise trigger shellcheck on 529 lines of never-linted bash that we are not maintaining.

## Rollback

Both implementations read the same five state files in the same `export X="..."` format, so they are hot-swappable — **but you must put the config where the bash version looks for it**, which is not `target/config/`.

`target.bash:9` resolves its own directory with `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`. That does **not** follow symlinks, so the config directory it uses is `<directory the script was invoked from>/config`:

| Invoked as | Reads/writes |
|---|---|
| `bash target/legacy/target.bash` | `target/legacy/config/` |
| `~/.local/bin/target` (symlink) | `~/.local/bin/config/` |

This path-resolution bug is why the Python port needed a config adoption step at all. Always confirm with:

```bash
bash target/legacy/target.bash -i | grep 'Config Dir'
```

### One-off: run the bash version for a single command

```bash
mkdir -p target/legacy/config
cp target/config/*.sh target/legacy/config/
cp target/config/config.legacy.sh target/legacy/config/config.sh
bash target/legacy/target.bash -i
```

`target/legacy/config/` is gitignored. Note that state written here does **not** flow back to `target/config/`, so anything you set during a one-off is invisible to the Python version.

### Full rollback

```bash
rm ~/.local/bin/target
ln -s "$PWD/target/legacy/target.bash" ~/.local/bin/target   # bypasses setup_links
mkdir -p ~/.local/bin/config
cp target/config/*.sh ~/.local/bin/config/
cp target/config/config.legacy.sh ~/.local/bin/config/config.sh
target -i        # Config Dir must read ~/.local/bin/config
```

Then revert `aliases`, which after the port sources `target/config/*.sh` — a path the bash version no longer writes:

```bash
git checkout aliases
```

