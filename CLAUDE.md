# SalesApp — Project Context

Mobile sales-order app integrating with SAP Business One HANA via Service
Layer. Field reps create sales orders from their phones; SAP owns approval.

## Stack

- **Mobile:** Flutter (not started yet)
- **Backend:** ASP.NET Core 8, C#
- **Database:** SQL Server (own DB for users/roles/config — NOT SAP's DB)
- **SAP integration:** SAP B1 Service Layer REST API (cookie-session based)
- **EF Core:** 8.0.26 exactly — do not let NuGet pull 9.x/10.x, they target
  .NET 9/10 and will break the build. Pin every `Microsoft.EntityFrameworkCore.*`
  package to `8.0.26`.
- **Hosting:** on-premise, client's Windows Server, IIS + Kestrel. No cloud.
- **Auth:** JWT (own login, NOT SAP users). SAP Service Layer session is
  separate and fully transparent to the mobile app.

## Architecture — deliberately simple, not Clean Architecture

Three projects, straight dependency chain, no repository-interface ceremony
except where it earns its keep:

```
SalesApp.Api             → Controllers, DTOs, Program.cs, JWT setup
SalesApp.Core             → Entities, ISapServiceLayerClient interface, PasswordHasher
SalesApp.Infrastructure   → AppDbContext, SapSessionManager, SapClient
SalesApp.Tests            → xUnit
```

Dependency flow: `Api → Core, Infrastructure` / `Infrastructure → Core`.
`Core` has **zero external NuGet dependencies** — pure C#/BCL only
(this is why password hashing uses `Rfc2898DeriveBytes`, not BCrypt).

The one interface we do keep: `ISapServiceLayerClient` (in Core, implemented
by `SapClient` in Infrastructure) — SAP integration is the most fragile part
and the one place worth decoupling for testing.

## Naming conventions

- All code (classes, methods, tables, columns, endpoints, project names) in
  **English**. Chat explanations to the human are in Spanish — irrelevant to
  you, just don't translate identifiers.
- C# classes/properties: PascalCase. JSON over the wire: camelCase (default
  System.Text.Json behavior, don't fight it).
- SQL tables: PascalCase plural (`Users`, `Roles`).

## Key business rules (do not re-litigate these, they were decided with the client)

- **100% online.** No offline mode, no local caching of orders/catalogs across
  sessions. If connectivity questions come up, the answer is "requires active
  connection," full stop.
- **SAP owns order approval.** The app only *displays* SAP's Approval
  Procedure status (Pending/Approved/Rejected). Never build an in-app
  approve/reject flow.
- **No credit limit validation.** Explicitly out of scope, confirmed with client.
- **No multi-branch (SAP Branches).** Confirmed not used by this client.
- **Users/roles live in our own SQL Server DB**, independent of SAP users.
  A `User` links to SAP only via `SalesEmployeeCode` (a string, not an FK).
- **Numbering series are SAP's**, we only store which SAP series a user is
  allowed to use (`UserSalesSeries.SapSeriesId`) — never replicate SAP's
  series catalog locally.
- Order line items need **two separate units of measure**: sales UoM and
  TFE (electronic invoicing) UoM. Don't collapse these into one field.

## Parameters table — generic config, not just SAP

`Parameters` (Key, Value, IsEncrypted, Group, Description, UpdatedAt,
UpdatedById) is a generic key/value config store, seeded initially with SAP
Service Layer connection settings (`Sap:ServiceLayer:BaseUrl`, `CompanyDb`,
`Username`, `Password`, `SessionTimeoutMinutes`, `MaxPoolSessions`). It will
grow to hold other config later — don't assume it's SAP-only when extending it.

Sensitive values (`IsEncrypted = true`) are encrypted with
`IDataProtector` using purpose string **`"SalesApp.SapCredentials"`**.
This exact string must never change once real credentials are saved with
it, or they become permanently undecryptable. Data Protection keys are
persisted to the DB (`AppDbContext` implements `IDataProtectionKeyContext`),
not the local filesystem — required for on-premise portability.

## SapSessionManager (Infrastructure/SapServiceLayer/)

Singleton. Holds the `B1SESSION` (+`ROUTEID` if present) cookie in memory,
tracks expiry with a 1-minute safety margin, thread-safe renewal via
`SemaphoreSlim`. `SapClient` retries once on 401 by calling
`ForceRenewAsync()`. Config is lazy-loaded from `Parameters` on first use and
cached — call `InvalidateConfig()` after changing SAP parameters at runtime.

## Current state (as of this file's creation)

Done:
- Solution scaffolded, 4 projects wired with correct references
- `AppDbContext` with all entities, Fluent API config, seed data (roles + SAP
  parameter rows)
- `InitialCreate` migration applied to a real SQL Server instance
- `SapSessionManager` + `SapClient` implemented
- JWT auth working end-to-end (`AuthController`, `TokenService`, `PasswordHasher`)
- First admin user created via temporary `SeedController` (**must be deleted
  before production deploy** — it's gated to `Development` env but shouldn't
  ship at all)
- `ConfigController` (temporary, same deletion caveat) to load real SAP
  connection params from the API instead of hand-editing the DB
- `SapTestController.Ping()` — diagnostic endpoint hitting real
  `BusinessPartners?$top=1`, gated `[Authorize(Roles = "Administrator")]`,
  this one is fine to keep permanently

Not started yet:
- Customers, Items, Orders controllers (see endpoint table below)
- Flutter app
- Web admin panel (separate frontend, manages Users/Roles/UserSalesSeries)

## Planned endpoints (English, REST)

```
POST   /api/auth/login
POST   /api/auth/refresh
GET    /api/customers?search=
GET    /api/customers/{code}/contacts
GET    /api/items?search=&category=
POST   /api/orders
GET    /api/orders?status=pending|approved|rejected
GET    /api/orders/{id}
GET    /api/orders/{id}/pdf
POST   /api/orders/{id}/duplicate
GET    /api/salespersons/{code}/series
```

## Things to remember before production

- Delete `SeedController` and `ConfigController` (or at minimum verify
  `ASPNETCORE_ENVIRONMENT` is never `Development` on the client's server —
  both are gated on that, but don't rely on it alone).
- Generate a real random `Jwt:Key` (32+ chars), never commit it — env var or
  server-level secret on the client's machine.
- If SAP's Service Layer uses a self-signed cert (common on-premise), the
  `ServerCertificateCustomValidationCallback` bypass in `Program.cs` is
  commented out by default — only enable it if actually needed, and know
  it's a real trust downgrade.
