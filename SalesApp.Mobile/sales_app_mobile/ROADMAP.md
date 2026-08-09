# SalesApp Mobile — Roadmap por etapas

Plan de construcción del cliente Flutter, alineado con `DESIGN.md` (fuente de
verdad visual) y `CLAUDE.md` (stack, reglas de negocio, contratos de API).

**Patrón por feature (todas las etapas):** modelo (`json_serializable`) →
`Repository` → `Bloc` (siempre Bloc, nunca Cubit) → UI, con tests unitarios de
repos/blocs usando `dio` mockeado.

**Modelo de navegación (de `DESIGN.md`, NO negociable sin confirmar):** side
drawer + FAB + segmented control. **No** bottom tab bar.

**Estado:** Etapas 0–4 completas (… + catálogo de ítems con scroll infinito,
bottom sheet de línea, carrito y cart pill). Próximo: Etapa 5 (resumen + envío).

---

## Etapa 0 — Fundaciones de diseño + shell (drawer) ✅ COMPLETA

- `google_fonts`: Plus Jakarta Sans + Inter en `ThemeData.textTheme`.
- Tokens exactos de `DESIGN.md`: `AppColors`, `AppRadius`, sombras (soft shadow,
  no bordes duros), gradientes (shell / primary / avatar / login).
- Primitivas de interacción: `PressableScale` (0.96, 140ms) + transición de
  pantalla (fade + slide-up 6px, 260ms).
- Shell con **side drawer** (gradient shell; secciones: Mis pedidos, Nuevo
  pedido, Clientes, Perfil, Cerrar sesión) + slot top-left hamburguesa/atrás +
  patrón FAB.
- Re-estilar **Login** a `DESIGN.md` (fondo claro, brand mark, campos, botón).
  La "geo-captured pill" queda diferida (ver Gap #5).

**Entregable:** theme + tokens + drawer navegable + login con el diseño aprobado.

## Etapa 1 — Home / Mis pedidos ⭐ ✅ COMPLETA

- Modelos: `Order`, `OrderLine`, estado.
- `OrderRepository` (list por status) + `OrdersBloc` con segmented control
  Pendientes / Autorizados / Rechazados → `pending / approved / rejected`.
- UI: **order card** de `DESIGN.md` (acento izq. 3px `sapBlue`, badge de estado
  con mapping amber/verde/rojo, fila meta Total/Fecha/Ítems) + **FAB**.
- Caveat: el backend aún no discrimina fino pending vs rejected (mismo origen de
  drafts); no apoyar lógica crítica en esa distinción todavía.

**Entregable:** pantalla principal con pedidos por estado.

## Etapa 2 — Detalle de pedido ✅ COMPLETA

- `OrderRepository.getById` + `duplicate`.
- UI: badge de estado, card "Datos del pedido", card cliente, lista de ítems,
  desglose de totales, fila de geolocalización, acciones de reporte
  (PDF/compartir), acción contextual (Duplicar / "usar como base" si rechazado).
- **PDF → 501**: acción deshabilitada / "no disponible". Duplicar sí funciona.

**Entregable:** detalle completo + duplicar.

## Etapa 3 — Nuevo pedido: selección de cliente + sección Clientes ✅ COMPLETA

- Modelos: `Customer`, `CustomerContact`; `CustomerRepository` + `CustomersBloc`.
- UI: search grande + tira de "clientes recientes" (ver Gap #6) + resultados
  filtrados en vivo (debounce).

**Entregable:** buscar/seleccionar cliente + ver contactos.

## Etapa 4 — Nuevo pedido: catálogo de ítems + bottom sheet de línea ✅ COMPLETA

- Modelos: `Item`, `ItemWarehouseStock`, `PagedResult<T>`; `ItemRepository` +
  `ItemsBloc` (scroll infinito, `pageSize` máx 20).
- UI: search con scan (ver Gap #6), category chips, cart pill flotante; bottom
  sheet de línea (stepper de cantidad, select de **UM de venta**, subtotal).
- **Sin lista de precios por ahora (Gap #3):** el catálogo muestra stock; el
  precio no se resuelve por lista. El precio de línea, si se usa, va como
  `unitPrice` manual o lo resuelve SAP al crear el pedido.

**Entregable:** catálogo con stock + configurar líneas.

## Etapa 5 — Resumen/confirmación + envío (RF-06..RF-10)

- `OrderBuilderBloc` (Bloc "rico": cliente + serie + líneas + submit); modelo
  `CreateOrderRequest`.
- UI: card cliente, selects de serie, lista editable, total sticky + guardar.
  Series desde `/salespersons/{code}/series`. Errores SAP `{ message, sap }`.
- Reglas: sin validación de crédito; el estado de aprobación solo se muestra.

**Entregable:** crear un pedido real en SAP desde el celular.

## Etapa 6 — Perfil + pulido

- Pantalla Perfil (info + logout).
- Estados "sin conexión" claros (100% online), pull-to-refresh, skeletons,
  ícono/nombre de app, tests faltantes.

---

## Gaps / conflictos mockup ↔ backend (resolver antes de las etapas indicadas)

El `DESIGN.md` viene de un mockup que quedó desactualizado respecto de decisiones
posteriores del backend. Estado de cada punto:

| # | Tema | Situación | Recomendación | Bloquea |
|---|------|-----------|---------------|---------|
| 1 | **UM de facturación (TFE)** | ✅ **RESUELTO (2026-08-09):** solo UM de venta. `DESIGN.md` actualizado (sin campo TFE) | Hecho | — |
| 2 | **Descuento % y fecha por línea** | Mockup los pide; backend line solo soporta `itemCode, quantity, salesUnitOfMeasure, unitPrice, warehouseCode` | Dropear de UI **o** agregar al backend | Et. 4/5 |
| 3 | **Lista de precios del cliente** | ✅ **RESUELTO (2026-08-09):** no se usa por ahora. La app no envía `priceList` ni muestra precio derivado de lista. El código de precio en el backend Items queda intacto (sin usar) para retomarlo luego | Hecho | — |
| 4 | **Payment terms** | Detalle/resumen lo muestran/seleccionan; backend no expone el campo | Agregar al backend o dropear de UI | Et. 2/5 |
| 5 | **Geolocalización** | Login (geo pill) y detalle (fila geo) la muestran; backend no tiene campos ni el pedido los recibe | Definir: ¿capturar GPS y enviarlo (backend + permisos) o solo visual/futuro? | Et. 0/2/5 |
| 6 | **Clientes recientes / scan barras** | "Recientes" choca con 100% online; scan suma dependencia de cámara | Diferibles; "recientes" podría derivar de últimos pedidos | Et. 3/4 |

**Decisiones abiertas restantes:** #2, #4, #5, #6 — ninguna bloquea las Etapas 0/1.
Conviene cerrar #2/#4 antes de la Etapa 5 (envío de pedido).

---

## Orden de trabajo sugerido

1. Etapa 0 + Etapa 1 (fundaciones + Home/Mis pedidos).
2. Etapa 2 → 3 → 4 → 5 → 6.
3. Antes de la Etapa 5: cerrar Gaps #2 (descuento/fecha por línea) y #4 (payment terms).
