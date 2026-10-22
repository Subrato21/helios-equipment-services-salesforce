| Decision | Use this value or rule |
| --- | --- |
| Regions | `Benelux`, `DACH`, `Nordics` |
| Country mapping | Benelux: BE/NL/LU; DACH: DE/AT/CH; Nordics: DK/FI/IS/NO/SE |
| Unknown country or unmatched email | Send to a **Needs Triage** queue; never guess a region |
| Case function | Standard Case **Type**: `Technical` or `Billing`; record types and layouts follow on Day 4 |
| Deal health | Open Opportunity aged **30 days or more** = `At Risk`; otherwise `Healthy` |
| Effort report buckets | Short: up to 4 hours; Standard: over 4 through 16; Long: over 16 |
| Coverage | A unit may have multiple plans **over time**, but only one selected active plan at once. Do not activate overlapping coverage for that unit. |
| Plan activation | A person reviews and activates a Draft plan. Activation is allowed only within its start/end dates and updates each linked unit’s current-plan lookup. |
| Expiry | The Case formula uses `TODAY()`, so its displayed position changes when the date passes without a scheduling job. The current-plan lookup stays on the expired plan until a replacement is activated. |
| Junk | Start with a narrow, documented test rule, such as the subject prefix `TEST-JUNK:`; expand only after proving that real cases are unaffected. |