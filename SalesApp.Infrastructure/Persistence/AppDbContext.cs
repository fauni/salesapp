using Microsoft.AspNetCore.DataProtection.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SalesApp.Core.Entities;

namespace SalesApp.Infrastructure.Persistence;

// Implements IDataProtectionKeyContext so ASP.NET Core's Data Protection keys
// (used to encrypt Parameters.Value) persist here instead of the local file
// system - important on-premise if the app ever moves to another machine.
public class AppDbContext : DbContext, IDataProtectionKeyContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<UserRole> UserRoles => Set<UserRole>();
    public DbSet<UserSalesSeries> UserSalesSeries => Set<UserSalesSeries>();
    public DbSet<Parameter> Parameters => Set<Parameter>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<Microsoft.AspNetCore.DataProtection.EntityFrameworkCore.DataProtectionKey> DataProtectionKeys => Set<Microsoft.AspNetCore.DataProtection.EntityFrameworkCore.DataProtectionKey>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(u => u.Username).IsUnique();
            entity.Property(u => u.Username).HasMaxLength(100).IsRequired();
            entity.Property(u => u.PasswordHash).IsRequired();
            entity.Property(u => u.SalesEmployeeCode).HasMaxLength(20);
        });

        modelBuilder.Entity<Role>(entity =>
        {
            entity.HasIndex(r => r.Name).IsUnique();
            entity.Property(r => r.Name).HasMaxLength(50).IsRequired();
        });

        modelBuilder.Entity<UserRole>(entity =>
        {
            entity.HasKey(ur => new { ur.UserId, ur.RoleId });

            entity.HasOne(ur => ur.User)
                  .WithMany(u => u.UserRoles)
                  .HasForeignKey(ur => ur.UserId);

            entity.HasOne(ur => ur.Role)
                  .WithMany(r => r.UserRoles)
                  .HasForeignKey(ur => ur.RoleId);
        });

        modelBuilder.Entity<UserSalesSeries>(entity =>
        {
            entity.HasOne(s => s.User)
                  .WithMany(u => u.SalesSeries)
                  .HasForeignKey(s => s.UserId);

            entity.HasIndex(s => new { s.UserId, s.SapSeriesId }).IsUnique();
            entity.Property(s => s.SapSeriesName).HasMaxLength(100);
        });

        modelBuilder.Entity<Parameter>(entity =>
        {
            entity.HasIndex(p => p.Key).IsUnique();
            entity.Property(p => p.Key).HasMaxLength(150).IsRequired();
            entity.Property(p => p.Value).IsRequired();
            entity.Property(p => p.Group).HasMaxLength(50);
            entity.Property(p => p.Description).HasMaxLength(300);

            entity.HasOne(p => p.UpdatedBy)
                  .WithMany()
                  .HasForeignKey(p => p.UpdatedById)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.HasOne(a => a.User)
                  .WithMany(u => u.AuditLogs)
                  .HasForeignKey(a => a.UserId);

            entity.Property(a => a.Action).HasMaxLength(100).IsRequired();
        });

        // Seed default roles
        modelBuilder.Entity<Role>().HasData(
            new Role { Id = 1, Name = "Salesperson" },
            new Role { Id = 2, Name = "Supervisor" },
            new Role { Id = 3, Name = "Administrator" }
        );

        // Seed initial SAP Service Layer connection parameters (values to be set post-deploy)
        modelBuilder.Entity<Parameter>().HasData(
            new Parameter { Id = 1, Key = "Sap:ServiceLayer:BaseUrl", Value = "", IsEncrypted = false, Group = "Sap", Description = "Service Layer base URL", UpdatedAt = new DateTime(2026, 1, 1) },
            new Parameter { Id = 2, Key = "Sap:ServiceLayer:CompanyDb", Value = "", IsEncrypted = false, Group = "Sap", Description = "SAP company database name", UpdatedAt = new DateTime(2026, 1, 1) },
            new Parameter { Id = 3, Key = "Sap:ServiceLayer:Username", Value = "", IsEncrypted = true, Group = "Sap", Description = "Integration user for Service Layer", UpdatedAt = new DateTime(2026, 1, 1) },
            new Parameter { Id = 4, Key = "Sap:ServiceLayer:Password", Value = "", IsEncrypted = true, Group = "Sap", Description = "Integration user password", UpdatedAt = new DateTime(2026, 1, 1) },
            new Parameter { Id = 5, Key = "Sap:ServiceLayer:SessionTimeoutMinutes", Value = "30", IsEncrypted = false, Group = "Sap", Description = "Minutes before B1SESSION expires", UpdatedAt = new DateTime(2026, 1, 1) },
            new Parameter { Id = 6, Key = "Sap:ServiceLayer:MaxPoolSessions", Value = "10", IsEncrypted = false, Group = "Sap", Description = "Max concurrent Service Layer sessions", UpdatedAt = new DateTime(2026, 1, 1) }
        );
    }
}