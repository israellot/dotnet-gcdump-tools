# dotnet-gcdump-tools

Reproducible `dotnet-gcdump` builds with a configurable graph node limit.

This project applies a small patch to the public [`dotnet/diagnostics`](https://github.com/dotnet/diagnostics) source. The stock collector stops at 10 million graph nodes. This build keeps that default and accepts a larger positive limit through `DOTNET_GCDUMP_MAX_NODES`.

## Download

```bash
version=v1.0.0
base=https://github.com/israellot/dotnet-gcdump-tools/releases/download/$version
curl -fLO "$base/dotnet-gcdump-linux-x64"
curl -fLO "$base/SHA256SUMS"
sha256sum -c SHA256SUMS
chmod 700 dotnet-gcdump-linux-x64
```

## Use

Keep the stock limit:

```bash
./dotnet-gcdump-linux-x64 collect -p <pid> -o dump
```

Set a measured larger limit:

```bash
DOTNET_GCDUMP_MAX_NODES=20000000 \
  ./dotnet-gcdump-linux-x64 collect -p <pid> -o dump -v
```

Malformed, zero, negative, and overflowing values fail closed.

## Safety

Microsoft restored the 10-million-node cap after larger graphs exposed edge-count inconsistencies. Raising the limit can increase collector memory and can still produce no dump when the source graph is inconsistent.

Use measured steps. Check cgroup headroom first. A 20-million setting completed one production capture below the cap, but that does not make 20 million safe for every service.

## Build

The build is pinned to `dotnet/diagnostics` commit `36ad68a92912f539ebe33661725448c33922e440`.

```bash
./build.sh linux-x64
```

Set `DIAGNOSTICS_SOURCE` to an existing clone to avoid fetching another copy:

```bash
DIAGNOSTICS_SOURCE=/path/to/diagnostics ./build.sh linux-x64
```

Release tags run the same build in GitHub Actions.

## Changes from upstream

- Keep 10 million as the default.
- Read a positive 32-bit integer from `DOTNET_GCDUMP_MAX_NODES`.
- Log the active limit in verbose output.
- Use the configured limit in the truncation check and warning.

## License

The patch and build files in this repository use the MIT license. The produced executable derives from `dotnet/diagnostics` and includes its MIT license and notices.
