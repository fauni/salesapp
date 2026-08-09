# SalesApp Mobile — Project Context

Cliente móvil (Flutter) de **SalesApp**, una app de toma de pedidos de venta para
representantes de campo. El backend (ASP.NET Core, en `../../SalesApp.Api`) **ya existe
y funciona**; este proyecto es SOLO la app Flutter que lo consume. SAP Business One
(detrás del backend) es dueño de la aprobación; la app solo la muestra.

## Objetivo

App móvil **online** donde un representante: se loguea, busca clientes, arma un
pedido de venta con ítems (precio según la lista del cliente + stock por almacén)
y lo envía a SAP a través del backend.

## Stack

- **Flutter** (última estable), Dart null-safety.
- **Estado: `flutter_bloc` — usar SIEMPRE `Bloc` (con eventos), NO `Cubit`.** Todo
  feature (auth, customers, items, orders, armador de pedido) se modela como
  `Bloc` con sus eventos y estados explícitos. **No** usar `hydrated_bloc` ni
  persistir estado (regla 100% online).
- **HTTP:** `dio`. **Token:** `flutter_secure_storage`. **Navegación:** `go_router`.
- **Modelos:** `json_serializable` (JSON) + `Equatable` (igualdad por valor en
  modelos y estados/eventos de Bloc). **freezed queda fuera por ahora**: para
  Flutter 3.44 / Dart 3.12 solo resuelve a un prerelease (`4.0.0-dev.3`); volver
  a evaluarlo cuando haya un `freezed` 4.x estable.
- **Sin** persistencia local de catálogos ni pedidos. Lo único que se guarda en disco
  es el JWT en secure storage.

## Arquitectura (capas)

- `data/`: `ApiClient` (dio), modelos (freezed), y repositories por dominio
  (`AuthRepository`, `CustomerRepository`, `ItemRepository`, `OrderRepository`,
  `SalespersonRepository`).
- `blocs/`: un `Bloc` por feature (eventos + estados). No usar Cubit.
- `ui/`: pantallas y widgets.

## Convenciones

- Identificadores de código (clases, métodos, variables) en **inglés**.
- Texto de UI visible al usuario en **español** (los reps son hispanohablantes).
- JSON sobre la red en **camelCase** en ambos sentidos (default del backend).

## Backend API

- Base URL configurable por entorno (dev `https://localhost:7047`, prod = servidor
  on-premise del cliente). En on-premise la API puede usar **certificado self-signed**:
  configurar el `badCertificateCallback` de dio para ese host (red interna, mismo
  trade-off aceptado en el backend). No copiar ese bypass para hosts de internet.
- Auth: **JWT Bearer** en header `Authorization: Bearer <token>`.

### Autenticación y RF-04 (re-login transparente) — LEER CON ATENCIÓN

- `POST /api/auth/login` — body `{ "username", "password" }`
  → 200 `{ token, username, salesEmployeeCode, roles: [] }` · 401 si credenciales inválidas.
- `POST /api/auth/refresh` — requiere Bearer con token **aún válido**
  → 200 mismo shape que login (token nuevo) · 401 si el token venció o el usuario se desactivó.

**IMPORTANTE:** el backend NO usa refresh token; `/refresh` reemite a partir de un
token todavía válido. Por lo tanto el cliente DEBE renovar **proactivamente ANTES de
que expire**, no esperar al 401. Implementar en un interceptor de dio: decodificar el
`exp` del JWT y, si falta menos de ~5 min, llamar a `/refresh` antes de enviar el
request. Un `401` real → limpiar token y mandar a login.

### Customers

- `GET /api/customers?search=`
  → 200 `[ { code, name, phone, cellular, email, federalTaxId, currency } ]`
- `GET /api/customers/{code}/contacts`
  → 200 `[ { internalCode, name, position, phone, mobilePhone, email, active } ]`

### Salespersons (series de numeración permitidas)

- `GET /api/salespersons/{code}/series` — `{code}` = salesEmployeeCode del usuario logueado
  → 200 `[ { sapSeriesId, sapSeriesName } ]` · 403 si `{code}` no coincide con el del token.

### Items

- `GET /api/items?search=&category=&priceList=&page=&pageSize=`
  (`category` = ItemsGroupCode numérico; `priceList` = lista de precios del cliente
  seleccionado; `pageSize` máx 20)
  → 200 `{ items: [ { code, name, groupCode, price, currency, priceList,
       warehouses: [ { warehouseCode, inStock, committed, ordered, available } ] } ],
       page, pageSize, totalCount }`
  - `price` viene `null` si no se pasa `priceList`.
  - `available = inStock - committed` (lo vendible ahora).
  - **La app NO usa `priceList` por ahora** (decisión 2026-08-09): no se envía y el
    catálogo no muestra precio derivado de lista. El backend sigue soportando el
    parámetro para retomarlo más adelante.

### Orders

- `POST /api/orders` — body:
  `{ customerCode, salesPersonCode?, series?, dueDate?, comments?,
     lines: [ { itemCode, quantity, salesUnitOfMeasure?, unitPrice?, warehouseCode? } ] }`
  → 201 `OrderDto` · 400 si falta customerCode o no hay líneas.
- `GET /api/orders?status=pending|approved|rejected` → 200 `[ OrderDto ]`
- `GET /api/orders/{id}` → 200 `OrderDto` · 404 si no existe.
- `GET /api/orders/{id}/pdf` → **501 (no implementado aún — NO construir esa pantalla).**
- `POST /api/orders/{id}/duplicate` → 201 `OrderDto` (nuevo pedido a partir de uno existente).

`OrderDto`:
`{ id, docNum, customerCode, customerName, docDate, dueDate, salesPersonCode,
   series, comments, status, docTotal,
   lines: [ { lineNum, itemCode, description, quantity, salesUnitOfMeasure,
              unitPrice, lineTotal, warehouseCode } ] }`

`status` ∈ { "pending", "approved", "rejected" }.

### Manejo de errores (uniforme)

- Errores del lado SAP: status 400 / 404 / 502 con body `{ message, sap }` (donde `sap`
  es el mensaje real de SAP). Mostrar `sap` como detalle cuando exista.
- Errores de validación local: 400 `{ message }`.
- 401 (sin token / vencido), 403 (prohibido).
- Centralizar el mapeo en un interceptor/handler de dio.

## Reglas de negocio (decididas con el cliente, no re-litigar)

1. **100% online.** Sin modo offline ni caché local de pedidos/catálogos. Sin conexión
   = error, no se opera.
2. **Líneas de pedido: solo Unidad de Medida de VENTA** (`salesUnitOfMeasure`). NO existe
   UM de facturación en las líneas.
3. **El estado del pedido solo se MUESTRA** (pending/approved/rejected). Prohibido
   construir flujo de aprobar/rechazar en la app — eso es de SAP.
4. **Sin validación ni UI de límite de crédito** (fuera de alcance).
5. **Precios / lista de precios: fuera de alcance por ahora** (decisión 2026-08-09).
   La app no envía `priceList` ni muestra precio derivado de lista. Si se necesita
   un precio de línea, va como `unitPrice` manual o lo resuelve SAP al crear el
   pedido. Retomar cuando se decida usar listas de precios.
6. **Series de numeración**: son de SAP; el usuario elige entre las permitidas
   (`/salespersons/{code}/series`).
7. `pending` vs `rejected` en el backend aún no discrimina fino (mismo origen de drafts);
   no apoyar lógica crítica en esa distinción todavía.

## Primer milestone (empezar por acá)

Base de red + autenticación, ANTES de cualquier pantalla de negocio:

1. Proyecto Flutter + estructura de capas.
2. `ApiClient` (dio) con baseUrl configurable y el manejo de cert self-signed.
3. `AuthRepository` (login/refresh) + almacenamiento del token en secure storage.
4. Interceptor de dio: adjunta Bearer + refresh proactivo (según RF-04 de arriba).
5. `AuthBloc` (eventos: AppStarted, LoggedIn, LoggedOut; estados: Unknown /
   Unauthenticated / Authenticated).
6. Pantalla de Login conectada a `/api/auth/login` + ruteo protegido con `go_router`.

## Roadmap de features

El plan por etapas (alineado con `DESIGN.md`) vive en **`ROADMAP.md`**. Resumen:

0. Fundaciones de diseño + shell con **side drawer** (no bottom tabs) + re-estilar login.
1. **Home / Mis pedidos** (segmented control Pendientes/Autorizados/Rechazados) ⭐ arranque.
2. Detalle de pedido (+ duplicar; PDF = 501).
3. Nuevo pedido: selección de cliente + sección Clientes.
4. Nuevo pedido: catálogo de ítems + bottom sheet de línea.
5. Resumen/confirmación + envío del pedido.
6. Perfil + pulido.

Ver `ROADMAP.md` para entregables, dependencias y los **gaps mockup ↔ backend**
pendientes de decisión (TFE UoM, priceList en CustomerDto, payment terms, geo, etc.).

## Estado actual

- Proyecto Flutter scaffoldeado + **primer milestone (red + auth) implementado**:
  - `lib/config/app_config.dart` — baseUrl / cert self-signed / ventana de refresh (dart-define).
  - `lib/core/jwt.dart` — lectura de `exp` y claims del JWT (para refresh proactivo y restaurar sesión).
  - `lib/data/network/api_client.dart` — dio configurado (+ trust self-signed).
  - `lib/data/network/auth_interceptor.dart` — adjunta Bearer + refresh proactivo + logout en 401.
  - `lib/data/storage/token_storage.dart` — JWT en secure storage.
  - `lib/data/models/login_response.dart` (+ `.g.dart`) — json_serializable.
  - `lib/data/repositories/auth_repository.dart` — login/logout + mapeo de errores.
  - `lib/blocs/auth/` — `AuthBloc` (eventos/estados) con Equatable.
  - `lib/ui/{splash,login,home}/` — pantallas.
  - `lib/router.dart` — go_router con redirect según AuthBloc; `lib/app.dart`, `lib/main.dart` (DI manual).
  - Verificado: `flutter analyze` (solo infos idiomáticos) y `flutter test` en verde.
- **Próximo**: feature Clientes (búsqueda + contactos). Para nuevos modelos JSON,
  correr `dart run build_runner build` tras crearlos.

## Pendientes / notas técnicas

- `flutter_secure_storage` 11 puede requerir subir `minSdkVersion` en Android
  (`android/app/build.gradle`) — ajustar si falla el build de Android.
- **Config de entornos vía `--dart-define-from-file`** (compile-time, sin código extra):
  - `config/dev.json` y `config/prod.json` (versionados) definen `API_BASE_URL` y
    `ALLOW_SELF_SIGNED`. `config/local.json` es override personal (gitignoreado).
  - `.vscode/launch.json` tiene configs `dev` / `prod` / `local` → elegir en el
    desplegable de Run and Debug y F5 (o Ctrl+F5).
  - CLI: `flutter run --dart-define-from-file=config/dev.json`.
  - El default de `AppConfig.baseUrl` es `https://10.0.2.2:7047` (emulador Android →
    host), así que F5 sin config sirve para desarrollo con emulador.
  - Al agregar un nuevo parámetro de entorno: sumar la clave a los `config/*.json` y
    leerla en `AppConfig` con `String.fromEnvironment` / `bool.fromEnvironment`.
