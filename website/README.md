# KinCrypt website

Three standalone English pages: `index.html`, `terms.html`, and `privacy.html`.
Open `index.html` directly to review. No build, package installation, JavaScript,
analytics, forms, or external font requests are needed. Shared styling is in
`styles.css`; header/footer markup is intentionally repeated to keep HTML portable.

The site directly adapts `../design/DESIGN.md`: dark colors, Manrope 400/500,
flat sections, restrained dividers, 12/16px radii, and 44–48px navigation targets.
The supplied app icon is copied unchanged. No app code or APIs are modified.

## Vercel preparation

For a later deployment, select `website` as the project root, the Other framework
preset, no build command, and the root directory (`.`) as the output directory.
Keep the `.html` URLs; no SPA fallback or framework routing is needed. Do not enable
Web Analytics, Speed Insights, or third-party integrations without updating the
privacy statement. This work does not create a Vercel project or deploy anything.

## Confirmed publication information

Effective date: 1 September 2026. Last updated: 20 September 2026.
The effective date is operator-specified; it is not a claim of prior publication
or retroactive user acceptance.

- Operator: Christoph Bühler. Correspondence address: c/o Glas- und Farbdesign AG,
  Weidenhofstrasse 9c, 9323 Steinach, Switzerland. The company is listed as the
  contact address, not substituted for the individual operator.
- Hosting: Vercel Hobby. The operator reports no analytics or additional logging.
  The statement distinguishes this from Vercel's own infrastructure processing;
  it does not claim zero provider logging or a universal retention duration.
- Support: `kincrypt-support@cbue.ch`, hosted by Proton Mail. Correspondence is
  retained only as needed for the request, necessary follow-up, or legal duties
  and claims; no fixed deletion interval was supplied or invented.
- App font downloads remain enabled by the operator's choice. Google receives
  font requests when Manrope is unavailable locally; the privacy statement
  discloses this. The website's font is self-hosted. No Flutter changes were made.
- Provider transfer information is attributed to the providers' public policies.
  No Pro/Enterprise DPA is represented as covering this Hobby project.

Keep the statements aligned with future hosting, email, and app changes. These pages
create no click-through acceptance mechanism or app distribution integration.

## Content evidence and sources

Initially checked 18 September 2026; provider information refreshed 20 September 2026. Text is original drafting, not copied third-party terms.

- [Swiss official e-commerce guidance](https://www.kmu.admin.ch/en/statutory-obligations-swiss-and-european-e-commerce-laws): operator disclosures and Swiss/EU context; applicability depends on the distribution model.
- [FDPIC privacy FAQ](https://www.edoeb.admin.ch/en/faq-data-protection): transparency, controller information, recipients, and privacy rights.
- [EU consumer contract guidance](https://europa.eu/youreurope/business/selling-in-eu/consumer-contracts-guarantees/consumer-contracts/indexamp_en.htm): fairness and preservation of mandatory rights.
- [EU digital contract rules](https://commission.europa.eu/topics/business-and-industry/contract-rules/digital-contracts/digital-contract-rules_en): free digital offerings can still fall within consumer rules depending on the facts.
- [Proton authentication explanation](https://proton.me/blog/encrypted-email-authentication): SRP; persistent storage claims are separately grounded in this repository.
- [Proton terms](https://proton.me/legal/terms) and [privacy policy](https://proton.me/legal/privacy): the independent provider relationship.
- [Vercel privacy notice](https://vercel.com/legal/privacy-notice) and [DPA](https://vercel.com/legal/dpa): hosting data and plan-dependent contractual roles; they do not establish this project's configuration.
- [EU/EEA supervisory authorities](https://www.edpb.europa.eu/about-edpb/our-members_en): privacy complaints.

Repository checks: `proton_go_api_bridge/src/auth/refresh_info.go` persists access
and refresh tokens through secure storage; `storage/secure_storage_apple.go` uses
the device keychain. `auth/key_rings.go` persists key material. The login flow uses
Proton's library and holds pending passwords in memory; `auth/logout.go` removes
stored secrets and attempts remote session revocation, without clearing the contact
database. No claim of app-level contact-database encryption is made.

## Assets

- `assets/icon.png`: byte-for-byte copy of the production `../assets/icon.png`.
- `assets/fonts/manrope-variable.ttf`: unmodified Manrope variable font from the
  [Google Fonts source repository](https://github.com/google/fonts/tree/main/ofl/manrope),
  used only at weights 400/500. Its SIL Open Font License is included as
  `assets/fonts/OFL.txt`. Keep the font and license together when distributing.

## Verification

Use static HTML/CSS, link/fragment, asset, and contrast checks. No test suite or
browser/app runtime verification is added or run, following repository instructions.
Flutter analysis and Go builds are unnecessary for this isolated static addition.

Completed static checks: all three documents parse as HTML5; 65 local references
and anchors resolve; 221 CSS declarations parse and all custom properties resolve.
The copied icon matches byte for byte, and the local variable font and license are
present. All nine text/surface color combinations meet WCAG AA, with a minimum
contrast ratio of 7.25:1. Rendered layout and keyboard behavior remain manual checks.

Manual review before publication:

1. Open all three pages at 320px, 390px, 768px, and 1280px widths. Check text wrapping,
   navigation, icon proportions, and absence of horizontal overflow.
2. Use keyboard navigation: reveal the skip link, move to main content, follow the
   primary action, all contents links, back-to-top links, and header/footer links.
   Confirm visible focus and the support mail link's destination.
3. Zoom to 200%; check reading order and that all legal text and controls remain
   readable. The page should stay dark regardless of the device's theme setting.
4. With browser developer tools, verify the icon, stylesheet, and local font load;
   no script, analytics, or external font request should originate from these files.
5. After a separately authorized deployment, check the direct `.html` URLs, inspect
   any host-injected requests/cookies, and reconcile actual hosting behavior with
   the privacy statement.

Additional provider sources checked 20 September 2026:

- [Proton Mail privacy policy](https://proton.me/mail/privacy-policy): mailbox hosting locations and provider handling.
- [Google privacy policy](https://policies.google.com/privacy) and [transfer frameworks](https://policies.google.com/privacy/frameworks): font-request recipient and international processing.
- [Vercel runtime logs](https://vercel.com/docs/logs/runtime): platform logs differ from operator-enabled analytics. The Hobby runtime-log window is not a general deletion deadline for every infrastructure record.
