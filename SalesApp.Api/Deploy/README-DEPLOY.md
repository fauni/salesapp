# Despliegue de SalesApp.Api en IIS (on-premise)

Checklist de instalación del backend **SalesApp.Api** (ASP.NET Core 8) en el
servidor Windows del cliente, con **IIS** y **SQL Server en máquina separada**.

Topología asumida:

- Servidor IIS: Windows Server con IIS + .NET 8 Hosting Bundle.
- SQL Server: máquina separada (ej. `192.168.88.4,1433`), autenticación SQL.
- SAP Business One Service Layer: red interna, certificado self-signed (ya
  contemplado en el backend).

---

## 1. Preparar el servidor IIS (una sola vez)

- [ ] **Instalar IIS**
  Panel de control → *Activar características de Windows* → **Internet
  Information Services** (marcar "Servicios World Wide Web" + "Herramientas de
  administración web").

- [ ] **Instalar el ASP.NET Core 8 Hosting Bundle** (paso crítico)
  Descargar el **.NET 8 Hosting Bundle** desde
  <https://dotnet.microsoft.com/download/dotnet/8.0> (sección *Hosting Bundle*).
  Instalarlo **después** de IIS.

- [ ] **Reiniciar IIS** para que registre el módulo:
  ```powershell
  net stop was /y
  net start w3svc
  ```

- [ ] **Verificar instalación**
  ```powershell
  dotnet --info
  ```
  Debe listar `Microsoft.AspNetCore.App 8.0.x`. En IIS debe existir el módulo
  **AspNetCoreModuleV2**.

---

## 2. Publicar la aplicación (en la máquina de desarrollo)

- [ ] Desde la carpeta de la solución:
  ```powershell
  dotnet publish SalesApp.Api/SalesApp.Api.csproj -c Release -o C:\publish\SalesApp
  ```
- [ ] Copiar el contenido de `C:\publish\SalesApp` al servidor IIS
  (ej. `C:\inetpub\SalesApp`).

> `dotnet publish` genera su propio `web.config`. En el paso 4 se edita para
> añadir `ASPNETCORE_ENVIRONMENT=Production`.

---

## 3. Configurar el sitio en IIS

- [ ] **Application Pool**
  IIS → *Grupos de aplicaciones* → *Agregar*:
  - Nombre: `SalesAppPool`
  - Versión CLR .NET: **Sin código administrado** (importante)
  - Modo de canalización: Integrado

- [ ] **Sitio web**
  IIS → *Sitios* → *Agregar sitio web*:
  - Nombre: `SalesApp`
  - Ruta física: `C:\inetpub\SalesApp`
  - Grupo de aplicaciones: `SalesAppPool`
  - Enlace: **https**, puerto 443 (o el elegido), con certificado

- [ ] **Permisos**
  Dar lectura a `IIS AppPool\SalesAppPool` sobre `C:\inetpub\SalesApp`.

---

## 4. Configuración de Production (secretos + entorno)

- [ ] **Copiar `appsettings.Production.json`** con los valores reales a la
  carpeta publicada en el servidor. **No** se versiona en git (está en
  `.gitignore`). Contiene:
  - `ConnectionStrings:Default` → SQL remoto (host, usuario, password).
  - `Jwt:Key` → clave aleatoria de 32+ caracteres (ya generada).

- [ ] **Editar el `web.config` generado** por publish y añadir la variable de
  entorno de Production (usar `web.Production.reference.config` del proyecto
  como guía). Bloque a agregar dentro de `<aspNetCore>`:
  ```xml
  <environmentVariables>
    <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
  </environmentVariables>
  ```
  > **Crítico:** sin `Production`, quedan expuestos `SeedController`,
  > `ConfigController` y Swagger (todos gateados en `IsDevelopment()`).

---

## 5. Conectividad al SQL Server remoto

En la máquina de SQL Server:

- [ ] **TCP/IP habilitado** (SQL Server Configuration Manager → Protocolos →
  TCP/IP → *Enabled*). Reiniciar el servicio SQL tras el cambio.
- [ ] **Firewall**: abrir el puerto **1433** (o el usado) hacia el servidor IIS.
- [ ] **SQL Browser** en ejecución si se usa instancia con nombre sin puerto fijo.
- [ ] **Autenticación mixta** activada (SQL Server + Windows), ya que la cadena
  de conexión usa `User Id`/`Password`.

---

## 6. Base de datos (ejecutar ANTES del primer arranque)

> El orden importa: los Data Protection keys se persisten en la tabla
> `DataProtectionKeys`. Si no existe al arrancar, el cifrado de credenciales
> SAP falla.

- [ ] **Crear la base** (el script de esquema NO la crea):
  ```powershell
  sqlcmd -S 192.168.88.4,1433 -U sa -P <password> -Q "CREATE DATABASE SalesAppDb;"
  ```
- [ ] **Aplicar el esquema** (`migrations.sql` — idempotente, incluye seed de
  roles + parámetros SAP):
  ```powershell
  sqlcmd -S 192.168.88.4,1433 -U sa -P <password> -d SalesAppDb -i "migrations.sql"
  ```
- [ ] **Crear el usuario admin** (`create-admin.sql`):
  ```powershell
  sqlcmd -S 192.168.88.4,1433 -U sa -P <password> -d SalesAppDb -i "create-admin.sql"
  ```
  Credenciales iniciales: **`admin` / `Admin123!`** → **cambiar tras el primer
  login**. (Para otro usuario/clave desde el inicio, regenerar el hash — no es
  editable a mano.)

Alternativa a `sqlcmd`: abrir cada `.sql` en SSMS con la base `SalesAppDb`
seleccionada y ejecutar (F5).

---

## 7. Cargar la configuración de SAP

Los parámetros de conexión al Service Layer se guardan en la tabla
`Parameters` (los sensibles cifrados con Data Protection). Se cargan vía el
`ConfigController` temporal, que **solo funciona en Development**. Opciones:

- Arrancar **una vez** con `ASPNETCORE_ENVIRONMENT=Development`, cargar los
  parámetros SAP reales, y volver a `Production`; **o**
- Cargarlos en un entorno de staging antes de mover la DB.

> Verificar los parámetros: `BaseUrl`, `CompanyDb`, `Username`, `Password`,
> `SessionTimeoutMinutes`, `MaxPoolSessions`.

---

## 8. Verificación final

- [ ] `POST https://<servidor>/api/auth/login` con `admin` / `Admin123!` → 200 + token.
- [ ] `GET https://<servidor>/api/sap-test/ping` → conexión SAP OK.
- [ ] `https://<servidor>/swagger` → **NO debe cargar** (correcto en Production).
- [ ] Cambiar la contraseña del admin.

Si la app no arranca, activar logs temporalmente en `web.config`
(`stdoutLogEnabled="true"`, `stdoutLogFile=".\logs\stdout"`, crear carpeta
`logs`) y revisar la salida.

---

## Antes de dar por cerrado el despliegue

- [ ] Contraseña del admin cambiada.
- [ ] `Jwt:Key` es un valor aleatorio real y **no** el de `appsettings.example.json`.
- [ ] `ASPNETCORE_ENVIRONMENT=Production` confirmado (Swagger no carga).
- [ ] `SeedController` y `ConfigController` inaccesibles (gateados en Development,
  pero idealmente eliminarlos del build de producción).
- [ ] Binding HTTPS con certificado válido (o `app.UseHttpsRedirection()` fallará).

---

## Archivos de esta carpeta (`Deploy/`)

| Archivo | Propósito |
|---------|-----------|
| `migrations.sql` | Esquema completo + seed (idempotente). Paso 6. |
| `create-admin.sql` | Usuario Administrator inicial. Paso 6. |
| `README-DEPLOY.md` | Este checklist. |

En la raíz del proyecto `SalesApp.Api/`:

| Archivo | Propósito |
|---------|-----------|
| `appsettings.Production.json` | Secretos de Production (no versionado). Paso 4. |
| `web.Production.reference.config` | Plantilla del `web.config` de Production. Paso 4. |
