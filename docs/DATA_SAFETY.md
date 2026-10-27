# Google Play Data Safety inventory (draft)

Source of truth for the Play Console form. Built from the **merged manifest of the shipped build** (`scripts/check_apk.sh`, `aab_report.txt`) and the SDKs actually packaged. Google's SDK rows come from Google's published Play data-disclosure guidance for the Mobile Ads SDK and UMP SDK. **The owner must re-verify them against Google's current pages for the pinned versions before submitting**; they change over time.

## Packaged SDKs and versions
| Component | Version | Network use |
|---|---|---|
| Godot Engine runtime | 4.7.2-stable | none |
| Google Mobile Ads SDK (`play-services-ads`) | 24.4.0 | yes, only after consent check, only for opt-in rewarded hints |
| Google User Messaging Platform (`user-messaging-platform`) | 3.2.0 | yes, consent status at launch |
| LegendAds plugin (own code) | in repo | bridges the two SDKs above, no own network calls |

## Permissions in the release manifest
`INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE`, plus `WAKE_LOCK` / `FOREGROUND_SERVICE`-type entries merged by WorkManager inside the ads SDK (no identifiers). **Removed on purpose:** `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS`. Enforced by `check_apk.sh` on every CI build.

## Data collected by the app's own code
None leaves the device. Progress, settings, hint counts and random ad receipts are stored locally (`user://save.json`). Event counters are local only (`EventLog`, no upload).

## Data collected or shared through SDKs (to declare)
| Play category → type | Collected by | Purpose (Play wording) | Notes |
|---|---|---|---|
| Location → Approximate location | Google Mobile Ads (IP address) | Advertising or marketing; Fraud prevention, security, and compliance | No precise location permission |
| App activity → App interactions | Google Mobile Ads (ad views/taps, app launches) | Advertising or marketing; Analytics | |
| App info and performance → Crash logs, Diagnostics | Google Mobile Ads | Analytics; Fraud prevention, security, and compliance | |
| Device or other IDs → Device or other IDs | Google Mobile Ads (app set ID; the advertising ID is not available because `AD_ID` is removed), UMP (consent state identifiers) | Advertising or marketing; Fraud prevention, security, and compliance | Re-check whether Google still lists the advertising ID when the permission is absent |

Answers to the form's general questions (draft):
- Is all user data encrypted in transit? **Yes** (Google SDKs use TLS).
- Can users request deletion? The game holds no server-side user data; SDK data is handled by Google. Users can delete local data by clearing app storage.
- Data shared with third parties? Data processed by Google SDKs as a service provider for ads; follow Google's current guidance on whether this counts as "shared".
- Account creation: **none**.

## Families / target audience (Play Console)
Target audience includes children → Families policy applies: use only Families-certified ad SDK configuration (child-directed treatment is set on every request, `MAX_AD_CONTENT_RATING_G`, under-age-of-consent tag), no interstitials for this audience (disabled in code), privacy policy URL required, teacher-approved programme optional.
