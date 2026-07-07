# Windows optional module: WP-CLI

Every other platform in this repo ships a `modules/wp-auto-update.sh.tpl`
that wraps WP-CLI for scheduled WordPress maintenance. This slot is
deliberately **left empty on Windows**.

## Why

Running a production WordPress site on Windows (IIS + WinCache/FastCGI, or
WAMP-style stacks) is uncommon compared to Linux, and the moving parts that
would need to be scripted differ enough from the Unix platforms that a
naive port would be misleading rather than useful:

- WP-CLI on Windows requires PHP configured for CLI use, which is often set
  up differently from the IIS FastCGI PHP handler used to actually serve
  the site.
- There's no direct Windows equivalent of `sudo -u <user>` for running WP-CLI
  as the site's app-pool identity — it typically requires `runas` with a
  stored credential or a scheduled task configured with that identity,
  which is a meaningfully different (and more fragile) setup step than the
  one-liner `sudo -u "$WP_USER" wp ...` used on the other platforms.
- IIS site/app-pool restart semantics (`appcmd recycle`) don't map cleanly
  onto the "flush cache, restart nothing" idempotent update pattern the
  other platforms' `wp-auto-update.sh.tpl` relies on.

## What to do instead

If you're running WordPress on Windows/IIS and want automated updates:

1. Install WP-CLI manually per the [official Windows guide](https://make.wordpress.org/cli/handbook/guides/installing/#windows-installation).
2. Write a small PowerShell wrapper calling `php wp-cli.phar core update` etc.
   under the identity your site actually runs as.
3. Schedule it with `Register-ScheduledTask`, following the same pattern
   `Install.ps1` uses for `Declutter.ps1` in this folder, as a reference.

This module slot is intentionally left as documentation rather than a
best-effort script that would give a false sense of "this is supported and
tested," which it is not.
