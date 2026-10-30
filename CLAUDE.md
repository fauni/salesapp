# SalesApp — Project Context

Mobile sales-order app integrating with SAP Business One HANA via Service
Layer. Field reps create sales orders from their phones; SAP owns approval.

## Stack

- **Mobile:** Flutter — lives in `SalesApp.Mobile/sales_app_mobile/` (its own
  `CLAUDE.md` holds the mobile context + API contracts). Uses `flutter_bloc`.
  Project scaffolded (`flutter create`); the auth/network milestone is not
  implemented yet.
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
- **Allowed warehouses are a global list** (`AllowedWarehouses` table, same
  for every user, admin-managed via `/api/warehouses`). The item catalog only
  returns stock for allowed warehouses and `POST /api/orders` rejects lines
  using any other. **An empty list allows NONE** (client decision 2026-10-30).
  The catalog's "in stock only" filter still counts stock in all warehouses
  (SAP OData limitation) — accepted for now.
- Order lines carry **only the sales unit of measure** (`SalesUnitOfMeasure`
  → SAP line `UoMCode`). The TFE (electronic invoicing) UoM was **dropped**
  from order lines on 2026-08-08 (client decision, supersedes the earlier
  "two separate UoMs" rule). If TFE UoM is ever reintroduced, add it back as
  a **separate** line field — never collapsed into the sales UoM.

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
  parameter rows), plus `DataProtectionKeys` (implements `IDataProtectionKeyContext`)
- Migrations applied to a real SQL Server instance: `InitialCreate` and
  `AddDataProtectionKeys` (the second one was needed because
  `DataProtectionKeys` was added to `AppDbContext` after the first migration
  — remember: **any change to `AppDbContext` needs a new migration**, EF
  doesn't detect schema drift at runtime)
- `SapSessionManager` + `SapClient` implemented **and confirmed working
  end-to-end against the client's real on-premise SAP B1 HANA** via
  `GET /api/sap-test/ping`
- JWT auth working end-to-end (`AuthController`, `TokenService`, `PasswordHasher`)
- First admin user created via temporary `SeedController`
- `ConfigController` (temporary) loads real SAP connection params, encrypting
  sensitive ones with `IDataProtector`
- `SapTestController` has two working endpoints: `Ping()` (real SAP call) and
  `ConfigCheck()` (diagnostic — shows masked loaded config without exposing
  the real password, useful if SAP connectivity breaks again later)

Not started yet:
- Customers, Items, Orders controllers (see endpoint table below)
- Flutter app (mobile) — project context defined in
  `SalesApp.Mobile/sales_app_mobile/CLAUDE.md` (stack, layers, full API
  contracts, business rules); project scaffolded, feature code not built yet
- Web admin panel (separate frontend, manages Users/Roles/UserSalesSeries)

## Hard-won gotchas (do not reintroduce these bugs)

- **`HttpClient.BaseAddress` must end with `/`, and `resourcePath` passed to
  `SapClient` must NOT start with `/`.** If either rule breaks, URI
  combination silently drops the last path segment of the base
  (`.../b1s/v1` + `Login` → `.../b1s/Login`, a 404) instead of erroring
  clearly. `SapSessionManager.LoginAsync` and `SapClient.ExecuteAsync`
  already normalize this with `.TrimEnd('/') + "/"` — don't remove that, and
  when calling `_sapClient.GetAsync/PostAsync/PatchAsync` elsewhere, always
  use resource paths without a leading slash (`"Orders"`, not `"/Orders"`).
- **JWT signing key must be 32+ characters (256 bits).** HMAC-SHA256 throws
  at runtime (not at startup) if the key is under 128 bits — this fails
  silently until the first login attempt. `Jwt:Key` in `appsettings.json`
  needs a real random value before production, not committed to source
  control (env var / server secret instead).
- **SAP Service Layer error bodies are worth surfacing, not swallowing.**
  `LoginAsync` reads and throws the actual SAP JSON error
  (`{"error":{"code":206,"message":{"value":"..."}}}`) instead of calling
  bare `EnsureSuccessStatusCode()` — keep this pattern when adding new
  SAP-facing methods, SAP's error codes are genuinely informative (206 =
  invalid credentials, etc.).
- **Client's Service Layer uses a self-signed certificate.**
  `ServerCertificateCustomValidationCallback` is enabled (not commented out)
  in `Program.cs` for the `"SapServiceLayer"` named `HttpClient`. This is
  acceptable because backend and SAP are on the same internal network — do
  not copy this pattern for any HttpClient that talks to the public internet.

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
