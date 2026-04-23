# Drift Log

## Metadata
- Last audit: 2026-04-23
- Runs since audit: 3

## Unresolved Observations
- [2026-04-23 | "architect audit"] | Item | Justification | |---|---| | Drift log Obs 4 / Obs-6a — `get_stage_policy` subshell overhead | Carried forward by prior audit decision. No demonstrated performance problem; eliminating the subshell requires a nameref or global side-channel. Architectural tradeoff does not favor the change. | | Drift log Obs 4 / Obs-6b — `_INIT_FILES_WRITTEN` scatter risk | Carried forward by prior audit decision. No scatter has materialized; speculative indirection not warranted. | | Further `common.sh` reduction beyond box-drawer extraction | S-2 brings common.sh to ~355 lines. Remaining content is tightly coupled output infrastructure; further splitting risks circular sourcing. Defer to a dedicated cleanup milestone if the ceiling breach remains a concern. |

## Resolved
