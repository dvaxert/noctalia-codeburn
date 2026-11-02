# Packages the checkout this file sits in. ./install.sh also builds codeburn-rs and enables the plugin.
pkgname=noctalia-codeburn
pkgver=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$startdir/codeburn/plugin.toml" | head -n 1)
pkgrel=1
pkgdesc="Noctalia bar widget and panel for Claude, Codex, and Cursor spend"
arch=(any)
url="https://github.com/dvaxert/noctalia-codeburn"
license=(MIT)
depends=(codeburn-rs noctalia)
install=noctalia-codeburn.install

package() {
  cd "$startdir"
  # A Noctalia path source: a directory that holds plugin directories.
  install -d "$pkgdir/usr/share/noctalia-codeburn"
  cp -r --no-preserve=ownership codeburn "$pkgdir/usr/share/noctalia-codeburn/"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
