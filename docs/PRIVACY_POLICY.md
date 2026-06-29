# Privacy Policy — BazaarChecklist

**Status:** Draft for publication. Replace all bracketed placeholders before you host this at a public URL and link it from Google Play.

**Last updated:** [DATE, e.g. April 3, 2026]

---

## Important notice

This document describes how **BazaarChecklist** (“the app,” “we,” “us”) handles information. It is not legal advice. If you need advice for your jurisdiction, consult a qualified attorney.

---

## Who we are

- **App name:** BazaarChecklist  
- **Operator:** [YOUR NAME OR LEGAL ENTITY]  
- **Contact (privacy & data requests):** [YOUR EMAIL ADDRESS]  
- **This policy applies to:** the BazaarChecklist mobile app (and any web version we may offer using the same account system).

BazaarChecklist is an **unofficial** companion for the game **The Bazaar**. It is **not affiliated with, endorsed by, or sponsored by** the makers of The Bazaar.

---

## Summary

- **Guest mode:** Your run history and preferences can be stored **only on your device**. We do not receive that data unless you sign in and sync.  
- **Signed-in users:** We use **Google Firebase** (Authentication and Cloud Firestore) to store your account and synced run data.  
- **Screenshots:** We **do not upload or store your run screenshots on our servers today.** We plan to offer **optional** cloud storage of a single screenshot per run for signed-in users via **Firebase Storage**; when that ships, this policy will be updated and the app will only upload screenshots if you choose to attach one.  
- **Catalog:** Item catalog data is served from Firebase and is not your personal account data.  
- We **do not sell** your personal information.

---

## Information we collect

### 1. Information you provide

- **Run records** you create (for example: selected items, game mode, hero, win counts, optional notes, timestamps).  
- **Account credentials** when you create an account or sign in:
  - **Email and password** (if you use email sign-in).  
  - **Google account** profile identifiers required for Google Sign-In (handled by Google and Firebase according to their policies).  
  - **Apple Sign-In** (if/when enabled): identifiers required for Sign in with Apple, per Apple’s and Firebase’s processes.

### 2. Information collected automatically

When you use online features, **Firebase and related Google services** may process technical data needed to operate the service (for example: app instance identifiers, IP address, device/OS type, crash or diagnostic data if enabled). That processing is governed by [Google’s Privacy Policy](https://policies.google.com/privacy) and Firebase terms.

### 3. Guest mode (local-only)

If you use the app **without signing in**, run data may be stored **locally on your device** (for example via the device’s local storage mechanisms). That data is **not transmitted to us** unless and until you sign in and use sync or similar features that upload data.

### 4. Screenshots — current and planned

- **Today:** The app **does not upload run screenshots to our Firebase project** for storage or backup. Any screenshot-related data that exists only on your device stays on your device under your OS permissions.  
- **Planned feature:** We intend to allow **optional** attachment of **one screenshot per run** for **signed-in** users, stored in **Google Firebase Storage**, with a reference stored alongside your run in **Firestore**. Until that feature is released and you choose to use it, **no screenshot content** is stored on our Firebase backend for that purpose.

When screenshot upload launches, we will update this policy and the **Google Play Data safety** section to match (including **Photos and videos** / **Files and docs** declarations if required).

---

## How we use information

We use the information above to:

- Provide the app’s core features (tracking runs, catalog, challenges, sync across devices for signed-in users).  
- Authenticate you and protect your account.  
- Maintain, secure, and improve the app (including troubleshooting and abuse prevention where applicable).

We **do not** sell your personal information. We **do not** use your data to build advertising profiles for third parties.

---

## Legal bases (EEA, UK, and similar regions)

Where GDPR or similar laws apply, we rely on:

- **Performance of a contract** — providing the service you asked for (account, sync, run storage).  
- **Legitimate interests** — operating, securing, and improving the app, and communicating about the service, where not overridden by your rights.  
- **Consent** — where we ask for it (for example, for optional features such as future screenshot upload, or optional analytics if we add them later).

---

## Sharing and processors

We use **Google Firebase** (Firebase Authentication, Cloud Firestore, and in the future possibly **Firebase Storage** for optional screenshots). Google processes data on our behalf as a **service provider / processor** under our configuration. Google’s practices are described in Google’s privacy documentation.

We may disclose information if required by law or to protect rights, safety, and integrity of users and the service.

---

## Data retention and deletion

- **Signed-in data:** We retain your synced run data and account-related records until you **delete your account** or ask us to delete your data, subject to reasonable backup and legal retention needs.  
- **Guest/local data:** Removed when you uninstall the app or clear app data, unless the OS keeps backups outside our control.  
- **Future screenshot storage:** When enabled, screenshots in Firebase Storage will be deleted when you delete the associated run or your account, consistent with how we implement deletion.

To request deletion of data tied to your account, contact **[YOUR EMAIL ADDRESS]** from the email associated with your account. We may need to verify your identity.

---

## Security

We use industry-standard practices appropriate to the size of the project (including Firebase security rules and authentication). No method of transmission or storage is 100% secure.

---

## Children’s privacy

The app is **not directed at children under 13** (or the minimum age required in your country). We do not knowingly collect personal information from children. If you believe a child has provided us personal information, contact **[YOUR EMAIL ADDRESS]** and we will take appropriate steps.

---

## International transfers

If you are outside the country where we operate servers, your information may be processed in countries where Google/Firebase operates data centers, including the United States. Google provides appropriate safeguards as described in their documentation (for example, standard contractual clauses where applicable).

---

## Your rights

Depending on where you live, you may have rights to **access, correct, delete, restrict, or object** to certain processing, or to **data portability**. Contact **[YOUR EMAIL ADDRESS]** to exercise these rights. You may also lodge a complaint with your local supervisory authority.

---

## Third-party services and links

The app may reference or display content related to **The Bazaar**; that game and its services have their own policies. Our use of **Google Sign-In**, **Apple Sign-In** (if enabled), and **Firebase** is subject to those providers’ terms and privacy policies.

---

## Changes to this policy

We may update this policy when we add features (for example **optional screenshot upload**), change providers, or for legal reasons. We will post the new version at the same URL and update the **Last updated** date. For material changes, we may also notify you in the app or by email where appropriate.

---

## Contact

**Privacy questions and requests:** [YOUR EMAIL ADDRESS]

---

## Checklist before you publish on Google Play

1. Replace every `[…]` placeholder and set **Last updated**.  
2. Host this text at a **stable HTTPS URL** and enter that URL in Play Console.  
3. Complete **Data safety** so it matches this policy (Auth, Firestore; add **Photos/videos** when screenshot upload ships).  
4. When screenshot upload goes live, add a sentence in-app (e.g. Settings / About) that attaching a screenshot uploads it to your Firebase project, and bump this policy + Data safety.
