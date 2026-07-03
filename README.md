# MacMTR

MacMTR is a native macOS version of WinMTR: a visual network diagnostic app that
combines route discovery with repeated ping measurements.

This fork is based on [WinMTR/WinMTR-Official](https://github.com/WinMTR/WinMTR-Official)
and keeps the project under GPL v2.

## Features

- Native SwiftUI macOS app.
- Route discovery through macOS `/usr/sbin/traceroute`.
- Continuous per-hop ping sampling through `/sbin/ping`.
- WinMTR-style table: hop, host, address, loss, sent/received, last, average,
  best, and worst latency.
- Copy text report and export text or HTML reports.
- original macOS app icon authored in Icon Composer.
- Codex Run button support through `script/build_and_run.sh`.

## Requirements

- macOS 14 or later.
- Xcode / Swift toolchain with Swift 6 support.

## Build, Test, Run

```bash
swift test
swift build --product MacMTR
./script/build_and_run.sh
```

The run script builds a SwiftPM GUI binary, stages `dist/MacMTR.app`, and opens
it as a foreground macOS app bundle.

Useful script modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## Notes

MacMTR intentionally uses Apple-provided command line tools instead of raw ICMP
sockets in this first macOS version. That keeps the app simple to build and run
without special entitlements. Firewall, DNS, or ICMP filtering can still affect
results, just as with `traceroute` and `ping` in Terminal.

## License

GPL v2. See `LICENSE`.
