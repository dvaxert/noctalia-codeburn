<p align="center"><strong>Today's Claude, Codex, and Cursor spend, in the Noctalia panel.</strong></p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-F97316.svg" alt="MIT license" /></a>
  <a href="https://github.com/noctalia-dev/noctalia-shell"><img src="https://img.shields.io/badge/noctalia-plugin%20api%2029-F97316.svg" alt="Noctalia plugin API 29" /></a>
  <a href="https://github.com/dvaxert/codeburn-rs"><img src="https://img.shields.io/badge/needs-codeburn--rs-F97316.svg" alt="Needs codeburn-rs" /></a>
</p>

<p align="center"><code>dvaxert/codeburn:bar</code></p>

<p align="center"><sub>Needs <a href="https://github.com/dvaxert/codeburn-rs">codeburn-rs</a> on <code>PATH</code> or in <code>~/.cargo/bin</code>, and Noctalia 5.3.</sub></p>

The bar shows a flame and the cost of the selected period. The panel puts that spend on the left — the total, a token chart, the models, the projects, and the tools — and the remaining limits on the right. A full bar means the window is almost untouched. The percent beside it is what is left.

## Sixty seconds

Point a path source at this repo and enable the plugin. In `~/.local/state/noctalia/settings.toml`:

```toml
[plugins]
enabled = ["dvaxert/codeburn"]

[[plugins.source]]
kind = "path"
location = "/path/to/noctalia-codeburn"
name = "codeburn"
```

Add the widget to a bar:

```toml
"dvaxert/codeburn:bar"
```

Then reload:

```bash
noctalia msg config-reload
```

Click the flame. The service runs:

```bash
codeburn-rs status --format menubar-json --period <period>
```

and publishes the JSON on the `view` state key. The run times out after 60 seconds. While the first scan is still going, the bar shows `—`.

`panel.luau` reloads on save. Changes to `plugin.toml` and `translations/` show up after the plugin is cycled:

```bash
noctalia msg plugins disable dvaxert/codeburn
noctalia msg plugins enable dvaxert/codeburn
```

Check the manifest offline with `noctalia plugins lint codeburn`.

## What you see

The period buttons send `today`, `week`, `30days`, `month`, or `all`. The left column follows that period. The right column does not: `limits` is always the live windows, labeled by provider and by kind, with a reset line under each bar.

If a provider does not answer, its bars are absent. If none answer, the card says the limits could not be read. The spend on the left still renders.

## Settings

| Key | Default | What it does |
|---|---|---|
| `binary` | empty | Path to `codeburn-rs`. Empty tries `PATH`, then `~/.cargo/bin/codeburn-rs` |
| `period` | `today` | Window requested when the service starts. The panel can switch it until settings change |
| `refresh_sec` | `60` | How often the service runs the binary, from 15 to 3600 |

## License

[MIT](LICENSE).

The numbers come from [codeburn-rs](https://github.com/dvaxert/codeburn-rs).
