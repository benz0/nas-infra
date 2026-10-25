# Patches for terraform-provider-synology

Applied on top of upstream main at `6219694919bad2be5b0cd3f8b3c5ea02c11452ce`, then built and published with `scripts/publish-provider.sh`.

| Patch | Fixes | Version |
|---|---|---|
| `0001-api-resource-json-results.patch` | `synology_api` panics ("Missing Object Attribute Value") when a DSM response contains a nested object, a null, or an empty array. Replaces the reflection-based conversion with a JSON-aware one. | `0.6.12-shed.2` |

Apply from the provider checkout:

    git apply /path/to/nas-infra/patches/terraform-provider-synology/0001-api-resource-json-results.patch
