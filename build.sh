#!/usr/bin/env bash

set -euo pipefail

readonly repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly upstream_repo="https://github.com/dotnet/diagnostics.git"
readonly upstream_commit="36ad68a92912f539ebe33661725448c33922e440"
readonly rid="${1:-linux-x64}"
readonly work_root="$(mktemp -d "${TMPDIR:-/tmp}/dotnet-gcdump-tools.XXXXXXXX")"
readonly source_dir="${work_root}/diagnostics"
readonly publish_dir="${work_root}/publish"
readonly dist_dir="${repo_root}/dist"

cleanup() {
    rm -rf "${work_root}"
}
trap cleanup EXIT

mkdir -p "${source_dir}" "${publish_dir}" "${dist_dir}"

if [[ -n "${DIAGNOSTICS_SOURCE:-}" ]]; then
    git -C "${DIAGNOSTICS_SOURCE}" archive "${upstream_commit}" | tar -x -C "${source_dir}"
else
    git -C "${source_dir}" init -q
    git -C "${source_dir}" remote add origin "${upstream_repo}"
    git -C "${source_dir}" fetch -q --depth 1 origin "${upstream_commit}"
    git -C "${source_dir}" checkout -q --detach FETCH_HEAD
fi

git -C "${source_dir}" apply --check "${repo_root}/patches/configurable-max-nodes.patch"
git -C "${source_dir}" apply "${repo_root}/patches/configurable-max-nodes.patch"

dotnet build "${source_dir}/src/Tools/dotnet-gcdump/dotnet-gcdump.csproj" -c Release --nologo

assemblies=("${source_dir}/artifacts/bin/dotnet-gcdump/Release/"*/dotnet-gcdump.dll)
if [[ ! -f "${assemblies[0]}" ]]; then
    echo "Built dotnet-gcdump assembly was not found." >&2
    exit 1
fi

dotnet run --project "${repo_root}/verify/VerifyMaxNodes.csproj" -c Release -- "${assemblies[0]}"

dotnet publish "${source_dir}/src/Tools/dotnet-gcdump/dotnet-gcdump.csproj" \
    -c Release \
    -r "${rid}" \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=false \
    -o "${publish_dir}" \
    --nologo

install -m 755 "${publish_dir}/dotnet-gcdump" "${dist_dir}/dotnet-gcdump-${rid}"
install -m 644 "${source_dir}/LICENSE.TXT" "${dist_dir}/DOTNET-DIAGNOSTICS-LICENSE.txt"
printf '%s\n' "${upstream_commit}" > "${dist_dir}/UPSTREAM-COMMIT.txt"
(
    cd "${dist_dir}"
    sha256sum "dotnet-gcdump-${rid}" "DOTNET-DIAGNOSTICS-LICENSE.txt" "UPSTREAM-COMMIT.txt" > SHA256SUMS
)

printf 'Built %s\n' "${dist_dir}/dotnet-gcdump-${rid}"
