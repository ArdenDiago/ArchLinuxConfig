# Jupyter notebooks in nvim

Opening a `.ipynb` in nvim shows raw JSON by default. Two plugins fix this:
[jupytext.nvim](https://github.com/GCBallesteros/jupytext.nvim) converts the
file to editable markdown on open/save, and
[molten-nvim](https://github.com/benlubas/molten-nvim) runs the code cells
against a real Jupyter kernel and shows the output inline.

Config: `~/.config/nvim/lua/plugins/jupytext.lua`,
`~/.config/nvim/lua/plugins/molten.lua`,
`~/.config/nvim/lua/config/options.lua` (`g:python3_host_prog`).

## Dependencies

- `jupytext` CLI, installed via `pipx install jupytext` (needs `python-pipx`
  from pacman — not in the official repos as its own package)
- A dedicated venv at `~/.local/share/nvim/venv`, built from **pyenv's**
  Python (`~/.pyenv/versions/3.13.7/bin/python3`), not linuxbrew's — the
  linuxbrew build's `sitecustomize.py` crashes any subprocess it launches
  (kernel included) with a `KeyboardInterrupt` during stdlib import. Recreate
  it with:
  ```bash
  ~/.pyenv/versions/3.13.7/bin/python3 -m venv ~/.local/share/nvim/venv
  ~/.local/share/nvim/venv/bin/pip install pynvim jupyter_client ipykernel nbformat
  ~/.local/share/nvim/venv/bin/python -m ipykernel install --user --name python3 --display-name "Python 3 (nvim)"
  ```
- `~/.local/share/jupyter/runtime/` must exist. molten writes a connection
  file to `{jupyter data dir}/runtime/...json` (not the XDG runtime dir
  `jupyter_client` itself uses) and doesn't create the directory — if it's
  missing, `:MoltenInit` fails with a `FileNotFoundError` that looks like a
  kernel-launch failure but isn't. `mkdir -p` it once.
- After changing `python3_host_prog` or installing molten, run
  `:UpdateRemotePlugins` inside nvim and restart it.

## Usage

Open a notebook, move into a code cell, then:

| Key | Action |
|---|---|
| `<localleader>rl` | run current line |
| `<localleader>e` + motion | run operator range |
| `<localleader>rv` (visual) | run selection |
| `<localleader>rr` | re-run current cell |
| `<localleader>os` / `oh` | show / hide output |

`<localleader>` is `\` unless remapped — see [`KEYBINDINGS.md`](../KEYBINDINGS.md).

A kernel auto-starts and existing outputs auto-import when the notebook is
opened; `:w` re-exports outputs back into the `.ipynb`. That export step is
the janky part of this stack (acknowledged in molten's own docs) — if it
silently doesn't update the file, run `:MoltenExportOutput!` by hand.

## Skipped

- **image.nvim** — plot/image output. Currently `molten_image_provider =
  "none"`, so only text/table output renders. Add if notebooks with plots
  come up.
- **quarto-nvim / otter.nvim** — LSP (autocomplete, go-to-def) inside the
  markdown code cells. Add if editing without LSP gets painful.
