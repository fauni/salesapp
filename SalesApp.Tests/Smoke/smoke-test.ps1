<#
    SalesApp API — smoke test
    Corre todos los endpoints creados y reporta OK / FAIL / SKIP por caso.

    Uso (desde PowerShell, con la API ya corriendo):
        ./smoke-test.ps1 -Password "TU_PASS" -CustomerCode "C0001" -ItemCode "A0001" -PriceList 1

    Parametros con "CHANGE_ME" o 0 se consideran "no provistos": los casos que
    dependen de ese dato se marcan SKIP en vez de fallar.
#>

param(
    [string]$BaseUrl           = "https://localhost:7047",
    [string]$Username          = "faruni",
    [string]$Password          = "CHANGE_ME",
    [string]$CustomerCode      = "CHANGE_ME",
    [string]$ItemCode          = "CHANGE_ME",
    [int]   $Category          = 0,           # ItemsGroupCode; 0 = sin filtro de categoria
    [int]   $PriceList         = 1,
    [int]   $Series            = 0,           # 0 = dejar que SAP use la serie default
    [string]$SalesEmployeeCode = "",          # vacio = se toma del token
    [string]$Warehouse         = "01",
    [switch]$SkipWrites                        # no crear/duplicar pedidos
)

$ProgressPreference = 'SilentlyContinue'

# --- Bypass del certificado self-signed en https (PS 5.1 no tiene -SkipCertificateCheck) ---
if ($BaseUrl -like "https:*") {
    if (-not ("TrustAllCertsPolicy" -as [type])) {
        Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12
}

$script:results = New-Object System.Collections.Generic.List[object]

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers = @{},
        $Body = $null
    )
    $uri = "$BaseUrl$Path"
    try {
        $p = @{ Method = $Method; Uri = $uri; Headers = $Headers; UseBasicParsing = $true; ErrorAction = 'Stop' }
        if ($null -ne $Body) { $p.ContentType = 'application/json'; $p.Body = $Body }
        $resp = Invoke-WebRequest @p
        return [pscustomobject]@{ Code = [int]$resp.StatusCode; Content = $resp.Content }
    } catch {
        if ($null -ne $_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            $sr   = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            return [pscustomobject]@{ Code = $code; Content = $sr.ReadToEnd() }
        }
        return [pscustomobject]@{ Code = -1; Content = $_.Exception.Message }
    }
}

function Record {
    param([string]$Name, [int]$Actual, [int[]]$Expect, [string]$Detail = "")
    $ok = $Expect -contains $Actual
    $status = if ($ok) { "OK  " } else { "FAIL" }
    $color  = if ($ok) { "Green" } else { "Red" }
    $expTxt = ($Expect -join "/")
    Write-Host ("[{0}] {1,-45} esperado {2,-9} -> {3} {4}" -f $status, $Name, $expTxt, $Actual, $Detail) -ForegroundColor $color
    $script:results.Add([pscustomobject]@{ Name = $Name; Status = $status.Trim() })
}

function Skip {
    param([string]$Name, [string]$Why)
    Write-Host ("[SKIP] {0,-45} {1}" -f $Name, $Why) -ForegroundColor DarkYellow
    $script:results.Add([pscustomobject]@{ Name = $Name; Status = "SKIP" })
}

function Has([string]$v) { return ($v -and $v -ne "CHANGE_ME") }

Write-Host "`n=== SalesApp smoke test contra $BaseUrl ===`n" -ForegroundColor Cyan

# ------------------------------------------------------------------ Fase 1: Auth
Write-Host "-- Fase 1: Auth --" -ForegroundColor Cyan

if (-not (Has $Password)) {
    Write-Host "Falta -Password. Abortando (sin token no se puede seguir)." -ForegroundColor Red
    return
}

$loginBody = @{ username = $Username; password = $Password } | ConvertTo-Json
$r = Invoke-Api POST "/api/auth/login" @{} $loginBody
Record "1.1 login OK" $r.Code @(200)
if ($r.Code -ne 200) {
    Write-Host "Login fallo, no hay token. Abortando." -ForegroundColor Red
    return
}
$login = $r.Content | ConvertFrom-Json
$token = $login.token
$auth  = @{ Authorization = "Bearer $token" }
if (-not (Has $SalesEmployeeCode)) { $SalesEmployeeCode = [string]$login.salesEmployeeCode }
$isAdmin = @($login.roles) -contains "Administrator"
Write-Host ("     usuario={0}  roles={1}  salesEmployeeCode={2}" -f $login.username, ($login.roles -join ','), $SalesEmployeeCode) -ForegroundColor Gray

$r = Invoke-Api POST "/api/auth/login" @{} (@{ username = $Username; password = "definitivamente-mal" } | ConvertTo-Json)
Record "1.2 login password incorrecto" $r.Code @(401)

$r = Invoke-Api POST "/api/auth/refresh" $auth
Record "1.3 refresh con token valido" $r.Code @(200)
if ($r.Code -eq 200) { $token = ($r.Content | ConvertFrom-Json).token; $auth = @{ Authorization = "Bearer $token" } }

$r = Invoke-Api POST "/api/auth/refresh" @{}
Record "1.4 refresh sin token" $r.Code @(401)

# ------------------------------------------------------------- Fase 2: Customers
Write-Host "`n-- Fase 2: Customers --" -ForegroundColor Cyan

$r = Invoke-Api GET "/api/customers" $auth
Record "2.1 listado sin filtro" $r.Code @(200)

$q = if (Has $CustomerCode) { $CustomerCode } else { "a" }
$r = Invoke-Api GET "/api/customers?search=$q" $auth
Record "2.2 busqueda ?search=" $r.Code @(200)

if (Has $CustomerCode) {
    $r = Invoke-Api GET "/api/customers/$CustomerCode/contacts" $auth
    Record "2.3 contactos codigo valido" $r.Code @(200)
} else { Skip "2.3 contactos codigo valido" "falta -CustomerCode" }

$r = Invoke-Api GET "/api/customers/ZZZ_NOEXISTE_999/contacts" $auth
Record "2.4 contactos codigo inexistente" $r.Code @(404)   # gracias al SapExceptionFilter

$r = Invoke-Api GET "/api/customers" @{}
Record "2.5 sin token -> 401" $r.Code @(401)

# ---------------------------------------------------------- Fase 3: Salespersons
Write-Host "`n-- Fase 3: Salespersons --" -ForegroundColor Cyan

if (Has $SalesEmployeeCode) {
    $r = Invoke-Api GET "/api/salespersons/$SalesEmployeeCode/series" $auth
    Record "3.1 series (code == JWT)" $r.Code @(200)
} else { Skip "3.1 series (code == JWT)" "usuario sin salesEmployeeCode" }

$otherCode = if (Has $SalesEmployeeCode) { "$SalesEmployeeCode-X" } else { "999999" }
$r = Invoke-Api GET "/api/salespersons/$otherCode/series" $auth
Record "3.2 series (code != JWT) -> 403" $r.Code @(403)

# ----------------------------------------------------------------- Fase 4: Items
Write-Host "`n-- Fase 4: Items --" -ForegroundColor Cyan

$itemsPath = "/api/items?page=1&pageSize=20&priceList=$PriceList"
if (Has $ItemCode) { $itemsPath += "&search=$ItemCode" }
if ($Category -gt 0) { $itemsPath += "&category=$Category" }
$r = Invoke-Api GET $itemsPath $auth
Record "4.1 busqueda + precio + paginacion" $r.Code @(200)
if ($r.Code -eq 200) {
    $paged = $r.Content | ConvertFrom-Json
    Write-Host ("     totalCount={0}  itemsEnPagina={1}" -f $paged.totalCount, @($paged.items).Count) -ForegroundColor Gray
    if (@($paged.items).Count -gt 0) {
        $it = $paged.items[0]
        Write-Host ("     [0] code={0} price={1} {2} (lista {3}) almacenes={4}" -f $it.code, $it.price, $it.currency, $it.priceList, @($it.warehouses).Count) -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------- Fase 5: Orders
Write-Host "`n-- Fase 5: Orders --" -ForegroundColor Cyan

$docEntry = $null
if (-not $SkipWrites -and (Has $CustomerCode) -and (Has $ItemCode)) {
    $line = @{ itemCode = $ItemCode; quantity = 2; salesUnitOfMeasure = "UN"; warehouseCode = $Warehouse }
    $ord  = @{ customerCode = $CustomerCode; comments = "Smoke test SalesApp"; lines = @($line) }
    if ($Series -gt 0) { $ord.series = $Series }
    $r = Invoke-Api POST "/api/orders" $auth ($ord | ConvertTo-Json -Depth 6)
    Record "5.1 crear pedido valido" $r.Code @(201)
    if ($r.Code -eq 201) {
        $docEntry = ($r.Content | ConvertFrom-Json).id
        Write-Host ("     DocEntry creado = {0}" -f $docEntry) -ForegroundColor Gray
    } else {
        Write-Host ("     respuesta: {0}" -f $r.Content) -ForegroundColor DarkGray
    }
} else {
    Skip "5.1 crear pedido valido" "faltan datos o -SkipWrites"
}

# validaciones locales (no dependen de datos reales)
$r = Invoke-Api POST "/api/orders" $auth (@{ customerCode = "X"; lines = @() } | ConvertTo-Json)
Record "5.2 crear sin lineas -> 400" $r.Code @(400)

$r = Invoke-Api POST "/api/orders" $auth (@{ lines = @(@{ itemCode = "X"; quantity = 1 }) } | ConvertTo-Json -Depth 6)
Record "5.3 crear sin cliente -> 400" $r.Code @(400)

$r = Invoke-Api GET "/api/orders?status=approved" $auth
Record "5.5 listar ?status=approved" $r.Code @(200)

$r = Invoke-Api GET "/api/orders?status=pending" $auth
Record "5.6 listar ?status=pending" $r.Code @(200)

$r = Invoke-Api GET "/api/orders?status=rejected" $auth
Record "5.7 listar ?status=rejected" $r.Code @(200)

$r = Invoke-Api GET "/api/orders?status=basura" $auth
Record "5.8 status invalido -> 400" $r.Code @(400)

if ($docEntry) {
    $r = Invoke-Api GET "/api/orders/$docEntry" $auth
    Record "5.9 get {id} existente" $r.Code @(200)
} else { Skip "5.9 get {id} existente" "no se creo pedido" }

$r = Invoke-Api GET "/api/orders/99999999" $auth
Record "5.10 get {id} inexistente -> 404" $r.Code @(404)

if ($docEntry) {
    $r = Invoke-Api GET "/api/orders/$docEntry/pdf" $auth
    Record "5.11 pdf -> 501 (no implementado)" $r.Code @(501)
} else { Skip "5.11 pdf -> 501" "no se creo pedido" }

if (-not $SkipWrites -and $docEntry) {
    $r = Invoke-Api POST "/api/orders/$docEntry/duplicate" $auth
    Record "5.12 duplicar pedido" $r.Code @(201)
    if ($r.Code -eq 201) {
        Write-Host ("     DocEntry duplicado = {0}" -f ($r.Content | ConvertFrom-Json).id) -ForegroundColor Gray
    }
} else { Skip "5.12 duplicar pedido" "faltan datos o -SkipWrites" }

# ----------------------------------------------------------------- Resumen
$pass = @($script:results | Where-Object Status -eq "OK").Count
$fail = @($script:results | Where-Object Status -eq "FAIL").Count
$skip = @($script:results | Where-Object Status -eq "SKIP").Count

Write-Host "`n=== Resumen: $pass OK, $fail FAIL, $skip SKIP ===" -ForegroundColor Cyan
if ($fail -gt 0) {
    Write-Host "Casos fallados:" -ForegroundColor Red
    $script:results | Where-Object Status -eq "FAIL" | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Red }
    exit 1
}
exit 0
