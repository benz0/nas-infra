#!/usr/bin/env bash
# Build, sign and publish a self-built Terraform provider to the HCP Terraform
# private registry.
#
# Usage (from anywhere):
#   PROVIDER_SRC=~/code/terraform-provider-synology \
#   VERSION=0.6.12-shed.1 \
#   ./scripts/publish-provider.sh
#
# Optional overrides:
#   ORG          HCP Terraform organization        (default: derpwagon-lab)
#   NAME         provider name in the registry     (default: synology)
#   GPG_KEY_ID   signing key (RSA)                 (default: 8E19321706C6AEDF)
#   PLATFORMS    space-separated os_arch list      (default: "linux_amd64 darwin_arm64")
#   TFE_TOKEN    API token; defaults to the one saved by `terraform login`
#
# Requires: go, gpg, jq, curl, zip, shasum.
# Safe to re-run for a NEW version. Versions are immutable once uploaded; to
# change a published version, delete it in the registry UI first.

set -euo pipefail

: "${PROVIDER_SRC:?set PROVIDER_SRC to the provider source directory}"
: "${VERSION:?set VERSION, e.g. 0.6.12-shed.1}"
ORG="${ORG:-derpwagon-lab}"
NAME="${NAME:-synology}"
GPG_KEY_ID="${GPG_KEY_ID:-8E19321706C6AEDF}"
PLATFORMS="${PLATFORMS:-linux_amd64 darwin_arm64}"
API="https://app.terraform.io/api"

for bin in go gpg jq curl zip shasum; do
  command -v "$bin" >/dev/null || { echo "missing required tool: $bin" >&2; exit 1; }
done

if [[ -z "${TFE_TOKEN:-}" ]]; then
  TFE_TOKEN="$(jq -r '.credentials["app.terraform.io"].token // empty' "$HOME/.terraform.d/credentials.tfrc.json")"
fi
[[ -n "$TFE_TOKEN" ]] || { echo "no HCP Terraform token; run 'terraform login' or set TFE_TOKEN" >&2; exit 1; }

api() { # api METHOD PATH [JSON_BODY]
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json")
  [[ -n "$body" ]] && args+=(--data "$body")
  curl "${args[@]}" -w '\n%{http_code}' "$API$path"
}
status() { tail -n1 <<<"$1"; }
body()   { sed '$d' <<<"$1"; }

DIST="$(mktemp -d)"
trap 'rm -rf "$DIST"' EXIT
BASE="terraform-provider-${NAME}_${VERSION}"

echo "==> Building ${NAME} ${VERSION} from ${PROVIDER_SRC}"
( cd "$PROVIDER_SRC"
  echo "    source commit: $(git rev-parse HEAD)"
  for p in $PLATFORMS; do
    os="${p%_*}"; arch="${p#*_}"
    mkdir -p "$DIST/$p"
    CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" go build -trimpath \
      -o "$DIST/$p/terraform-provider-${NAME}_v${VERSION}" .
    ( cd "$DIST/$p" && zip -q "$DIST/${BASE}_${p}.zip" "terraform-provider-${NAME}_v${VERSION}" )
    echo "    built $p"
  done
)

echo "==> Checksums and signature"
( cd "$DIST" && shasum -a 256 ${BASE}_*.zip > "${BASE}_SHA256SUMS" )
gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign \
  --output "$DIST/${BASE}_SHA256SUMS.sig" "$DIST/${BASE}_SHA256SUMS"
gpg --verify "$DIST/${BASE}_SHA256SUMS.sig" "$DIST/${BASE}_SHA256SUMS" 2>/dev/null \
  && echo "    signature verifies"

echo "==> Provider ${ORG}/${NAME}"
r="$(api POST "/v2/organizations/$ORG/registry-providers" "$(jq -n --arg o "$ORG" --arg n "$NAME" \
  '{data:{type:"registry-providers",attributes:{name:$n,namespace:$o,"registry-name":"private"}}}')")"
case "$(status "$r")" in
  201) echo "    created" ;;
  422) echo "    already exists" ;;
  *)   body "$r" >&2; exit 1 ;;
esac

echo "==> GPG key ${GPG_KEY_ID}"
r="$(api GET "/registry/private/v2/gpg-keys?filter%5Bnamespace%5D=$ORG")"
if body "$r" | jq -e --arg k "$GPG_KEY_ID" '.data[] | select(.attributes["key-id"]==$k)' >/dev/null; then
  echo "    already registered"
else
  armor="$(gpg --armor --export "$GPG_KEY_ID")"
  r="$(api POST "/registry/private/v2/gpg-keys" "$(jq -n --arg o "$ORG" --arg a "$armor" \
    '{data:{type:"gpg-keys",attributes:{namespace:$o,"ascii-armor":$a}}}')")"
  [[ "$(status "$r")" == 201 ]] || { body "$r" >&2; exit 1; }
  echo "    registered"
fi

echo "==> Version ${VERSION}"
PV="/v2/organizations/$ORG/registry-providers/private/$ORG/$NAME/versions"
r="$(api POST "$PV" "$(jq -n --arg v "$VERSION" --arg k "$GPG_KEY_ID" \
  '{data:{type:"registry-provider-versions",attributes:{version:$v,"key-id":$k,protocols:["6.0"]}}}')")"
[[ "$(status "$r")" == 201 ]] || { body "$r" >&2; echo "(versions are immutable; delete it in the UI to re-publish)" >&2; exit 1; }
sums_url="$(body "$r" | jq -r '.data.links["shasums-upload"]')"
sig_url="$(body "$r" | jq -r '.data.links["shasums-sig-upload"]')"
curl -sSf -T "$DIST/${BASE}_SHA256SUMS" "$sums_url" >/dev/null
curl -sSf -T "$DIST/${BASE}_SHA256SUMS.sig" "$sig_url" >/dev/null
echo "    checksums and signature uploaded"

for p in $PLATFORMS; do
  os="${p%_*}"; arch="${p#*_}"; zipf="${BASE}_${p}.zip"
  sum="$(shasum -a 256 "$DIST/$zipf" | cut -d' ' -f1)"
  r="$(api POST "$PV/$VERSION/platforms" "$(jq -n --arg os "$os" --arg a "$arch" --arg s "$sum" --arg f "$zipf" \
    '{data:{type:"registry-provider-platforms",attributes:{os:$os,arch:$a,shasum:$s,filename:$f}}}')")"
  [[ "$(status "$r")" == 201 ]] || { body "$r" >&2; exit 1; }
  curl -sSf -T "$DIST/$zipf" "$(body "$r" | jq -r '.data.links["provider-binary-upload"]')" >/dev/null
  echo "    uploaded $p"
done

echo
echo "Published app.terraform.io/${ORG}/${NAME} ${VERSION}"
echo "Use it with:  source = \"app.terraform.io/${ORG}/${NAME}\"   version = \"${VERSION}\""
