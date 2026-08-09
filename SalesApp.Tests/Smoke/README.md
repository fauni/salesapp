# Smoke test (manual)

`smoke-test.ps1` es un script de prueba **end-to-end manual** que ejercita todos
los endpoints de la API contra un SAP real. No es un test xUnit y **no** corre con
`dotnet test`; se ejecuta a mano cuando querés validar la API completa.

## Requisitos

- La API corriendo (`dotnet run --project SalesApp.Api --launch-profile https`).
- Conectividad al SAP Service Layer del cliente (crea/duplica pedidos reales).
- Datos reales de SAP para el flujo completo (cliente, ítem, lista de precios, serie).

## Uso

```powershell
cd SalesApp.Tests/Smoke

# Solo lectura (no crea pedidos en SAP):
./smoke-test.ps1 -Password "TU_PASS" -SkipWrites

# Flujo completo (crea y duplica un pedido real en SAP):
./smoke-test.ps1 -Password "TU_PASS" -CustomerCode "C0001" -ItemCode "A0001" -PriceList 1 -Series 3 -Warehouse "01"
```

## Parámetros

| Param                | Default        | Nota                                             |
|----------------------|----------------|--------------------------------------------------|
| `-BaseUrl`           | `https://localhost:7047` | URL de la API                          |
| `-Username`          | `faruni`       | usuario de login (nuestra DB, no SAP)            |
| `-Password`          | —              | **obligatorio**                                  |
| `-CustomerCode`      | `CHANGE_ME`    | CardCode real; habilita contacts/create/duplicate|
| `-ItemCode`          | `CHANGE_ME`    | ItemCode real; habilita items/create/duplicate   |
| `-Category`          | `0`            | ItemsGroupCode; `0` = sin filtro                 |
| `-PriceList`         | `1`            | lista de precios del cliente                     |
| `-Series`            | `0`            | serie SAP; `0` = default de SAP                  |
| `-SalesEmployeeCode` | (del token)    | para el caso de salespersons                     |
| `-Warehouse`         | `01`           | almacén de la línea                              |
| `-SkipWrites`        | off            | corre todo sin crear/duplicar pedidos            |

Los parámetros en `CHANGE_ME`/`0` marcan los casos dependientes como **SKIP** en
vez de fallar. Devuelve `exit 1` si algún caso falla (apto para CI).

## Notas

- Hace bypass del certificado self-signed en `https` (Windows PowerShell 5.1 no
  tiene `-SkipCertificateCheck`).
- Los casos `status=pending` / `status=rejected` validan solo el HTTP 200, no la
  discriminación pending-vs-rejected (pendiente de confirmar la config de
  Approval Procedure del SAP del cliente).
