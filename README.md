# noctalia-codeburn

Noctalia panel for [codeburn-rs](https://github.com/dvaxert/codeburn-rs). The service runs `codeburn-rs status --format menubar-json` and the bar shows today's figure once a provider reports `parsed: true`. Until then the bar shows an ellipsis and the panel lists files found on disk.

Point a path source at this repo and enable `dvaxert/codeburn`:

```toml
[[plugins.source]]
kind = "path"
location = "/home/ex/workspace/noctalia-codeburn"
name = "codeburn"

[plugins]
enabled = ["dvaxert/codeburn"]
```

Put the bar widget on a panel with type `dvaxert/codeburn:bar`. The binary setting overrides PATH; an empty value uses `codeburn-rs` on `PATH`, then `~/.cargo/bin/codeburn-rs`.
