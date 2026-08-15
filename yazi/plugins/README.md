# yazi plugins

`ya pkg install` restores everything listed in `../package.toml`. Two directories
here are tracked by hand instead:

## dirsize.yazi

Local plugin, not published anywhere. A fetcher that computes recursive
directory sizes so the `size` linemode shows total bytes instead of a child
count. Requires the `Linemode:size` override in `../init.lua`, which drops
yazi's child-count fallback, and the `prepend_fetchers` rule in `../yazi.toml`.

## office.yazi

Vendored **patched** copy of [macydnah/office.yazi](https://github.com/macydnah/office.yazi)
(MIT, see `office.yazi/LICENSE`). Upstream is pinned at `41ebef8` / `@since
25.2.7` and unmaintained against yazi 26. Two fixes:

1. `ya.preview_widgets` -> `ya.preview_widget` and `ya.manager_emit` ->
   `ya.mgr_emit`. Both old names were removed in yazi 26 and the plugin threw at
   preview time.
2. `doc2pdf` runs LibreOffice with a dedicated `-env:UserInstallation` profile
   and retries once. Only one LibreOffice process may use a profile at a time,
   and yazi runs the preloader and previewer concurrently, so the loser silently
   converted nothing while still exiting 0.

Needs `libreoffice` and `pdftoppm` on `PATH`. The Homebrew cask provides
`soffice`, not `libreoffice`, so a symlink is required:

```sh
ln -s /Applications/LibreOffice.app/Contents/MacOS/soffice ~/.local/bin/libreoffice
```

> **`ya pkg upgrade` overwrites `office.yazi/main.lua`** and reinstates both bugs.
> Re-copy this file afterwards.
