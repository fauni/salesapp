-- ============================================================================
-- Crea el usuario Administrator inicial en PRODUCCION.
--
-- Ejecutar UNA sola vez, DESPUES de aplicar migrations.sql (necesita las tablas
-- Users / Roles / UserRoles y el seed de roles ya presentes).
--
-- Credenciales de este script:
--     Username : admin
--     Password : Admin123!
--
-- El PasswordHash de abajo es PBKDF2 (Rfc2898DeriveBytes, SHA256, 100k iter),
-- formato {iterations}.{saltBase64}.{hashBase64}, VERIFICADO contra el
-- PasswordHasher.Verify real de SalesApp.Core.
--
-- >>> CAMBIA LA CONTRASENA tras el primer login. Si quieres otra contrasena
--     ANTES de correr esto, pideme regenerar el hash: NO se puede editar a mano.
--
-- El rol 'Administrator' tiene Id = 3 (seed fijo de InitialCreate).
-- ============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- Idempotencia: si ya existe un usuario 'admin', no hacer nada.
IF EXISTS (SELECT 1 FROM [Users] WHERE [Username] = N'admin')
BEGIN
    PRINT 'El usuario admin ya existe. No se realizaron cambios.';
    ROLLBACK TRANSACTION;
    RETURN;
END;

-- Verifica que el rol Administrator exista (por si migrations.sql no corrio).
IF NOT EXISTS (SELECT 1 FROM [Roles] WHERE [Name] = N'Administrator')
BEGIN
    RAISERROR('Rol Administrator no encontrado. Ejecuta primero migrations.sql.', 16, 1);
    ROLLBACK TRANSACTION;
    RETURN;
END;

DECLARE @AdminRoleId INT = (SELECT [Id] FROM [Roles] WHERE [Name] = N'Administrator');

INSERT INTO [Users] ([Username], [PasswordHash], [SalesEmployeeCode], [IsActive], [CreatedAt])
VALUES (
    N'admin',
    N'100000.isHSt/Xw+FRata/yoJQXbg==.m3HlsYasBwntPtRhDC+gFAuDW7eEKnE4/OSJtLQ2CIs=',
    NULL,                 -- SalesEmployeeCode: el admin no necesita mapeo a SAP.
    1,                    -- IsActive
    SYSUTCDATETIME()      -- CreatedAt (UTC, igual que DateTime.UtcNow del backend)
);

DECLARE @NewUserId INT = SCOPE_IDENTITY();

INSERT INTO [UserRoles] ([UserId], [RoleId])
VALUES (@NewUserId, @AdminRoleId);

COMMIT TRANSACTION;

PRINT 'Usuario admin creado con rol Administrator. Login: admin / Admin123!  (CAMBIAR TRAS PRIMER LOGIN)';
