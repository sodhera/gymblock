# GymBlock legal documents

Markdown sources for the GymBlock legal documents. The published copies live in the company website repository (`orecci`, folder `gymblock/`) and are served from www.orecci.com. Effective and last updated: October 8, 2026.

| Document | Source in this repo | Public URL |
|---|---|---|
| Legal home | — | https://www.orecci.com/gymblock/ |
| Privacy Policy | `docs/legal/privacy-policy.md` | https://www.orecci.com/gymblock/privacy-policy.html |
| Terms of Service | `docs/legal/terms-of-service.md` | https://www.orecci.com/gymblock/terms-of-service.html |
| User Data Deletion | `docs/legal/user-data-deletion.md` | https://www.orecci.com/gymblock/user-data-deletion.html |
| Support | — | https://www.orecci.com/gymblock/support.html |

Apple's standard EULA, which these terms supplement: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Use the Privacy Policy and Terms URLs above for `GymBlockPrivacyURL` and `GymBlockTermsURL`, the App Store Connect privacy policy and EULA fields, and the subscription offer screen.

## Keeping them in sync

The markdown here is the canonical text. When it changes:

1. Update the "Last Updated" date in every affected file.
2. Regenerate the HTML in `orecci/gymblock/` (same text inside the site's legal-document page frame) and copy the `.md` files alongside it.
3. Keep the facts honest: app blocking is simulated, analytics are first-party only, subscriptions are billed by Apple, no HealthKit, camera, microphone, location, contacts or advertising identifier.
