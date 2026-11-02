# noctalia-codeburn

Noctalia panel for [codeburn-rs](https://github.com/dvaxert/codeburn-rs). The service runs `codeburn-rs status --format menubar-json`. The bar shows the period cost. The panel shows that cost, a token chart, and the models, projects, and tools behind it.

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
