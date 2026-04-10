# Research Notes: SaaS Migration

## Technical Context & Technology Choices

**1. Reliable Time Sync (NTP)**
- **Decision**: Use `ntp` package (or simply trust Firebase `FieldValue.serverTimestamp()` where possible, and NTP for client-side evaluation).
- **Rationale**: The specification requires local checking of timestamps (expiration, 14-day trial, 48-hour grace period) to not be circumventable by changing the device clock. Firebase rules can't dynamically block reads based on future dates without client cooperation in some cases, but relying on server time for writes is standard. For offline reading/evaluating gates, an NTP check on startup cached locally is ideal.
- **Alternatives**: Relying solely on `DateTime.now()` (rejected: easily bypassed). Relying solely on server checks on every action (rejected: high latency, violates Zero-Latency principle).

**2. Device Fingerprinting**
- **Decision**: Use `device_info_plus` and `shared_preferences` (or `flutter_secure_storage`).
- **Rationale**: Required for device registry to prevent Trial abuse (e.g., uninstall/reinstall). A UUID will be generated and stored securely on the device, accompanied by hardware info (model, manufacturer).
- **Alternatives**: Firebase Auth tied (rejected: spec says store-level device tracking).

**3. Stitch MCP Integration (UI)**
- **Decision**: Fetch RTL UI structures via Stitch MCP (Project ID: 3771784857992882396).
- **Rationale**: Follows the strict Bottom-Up and MCP-driven UI requirements.
- **Alternatives**: Hand-coding UI from scratch (rejected: violates project guidelines).

**4. Migration of Legacy Users**
- **Decision**: Client-side parsing migration default (FR-17).
- **Rationale**: When a legacy store is read, if `subscription` is null, the client injects a "Lifetime" model in-memory and immediately writes it back to Firestore to permanently migrate them.

## Resolved Clarifications
1. **Trial duration**: 14 days.
2. **Feature limits**: Free (3 wallets, 1 emp, no SMS), Trial/Pro/Lifetime (999 wallets, 999 emps, SMS).
3. **Admin suspension**: Shows a full-screen block message, halting all access.
4. **Existing stores**: Grandfathered as Lifetime subscribers.
