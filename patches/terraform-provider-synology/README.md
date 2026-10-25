# Patches for terraform-provider-synology

Applied on top of upstream main at `6219694919bad2be5b0cd3f8b3c5ea02c11452ce`, then built and published with `scripts/publish-provider.sh`.

| Patch | Fixes | Version |
|---|---|---|
| `0001-api-resource-json-results.patch` | `synology_api` panics ("Missing Object Attribute Value") when a DSM response contains a nested object, a null, or an empty array. Replaces the reflection-based conversion with a JSON-aware one. | `0.6.12-shed.2` |
| `0002-api-resource-own-get-request.patch` | `synology_api` writes silently did nothing. go-synology's `api.GetQuery` stores each request's query in the client's shared base URL and lets it override the next call's `api`/`method`, so every call after the first reused the first call's method (a `set_schedule` was sent as `get_schedule` and returned success). The resource now builds its own GET from a copy of the base URL, with the call's parameters taking precedence. Includes a regression test. Apply after 0001. | `0.6.12-shed.3` |

Apply in order from the provider checkout:

    git apply /path/to/nas-infra/patches/terraform-provider-synology/0001-api-resource-json-results.patch
    git apply /path/to/nas-infra/patches/terraform-provider-synology/0002-api-resource-own-get-request.patch
