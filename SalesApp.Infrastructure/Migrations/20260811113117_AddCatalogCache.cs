using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SalesApp.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCatalogCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CatalogCache",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CatalogType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Code = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CachedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CatalogCache", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Parameters",
                columns: new[] { "Id", "Description", "Group", "IsEncrypted", "Key", "UpdatedAt", "UpdatedById", "Value" },
                values: new object[] { 7, "Hours before a cached SAP catalog name (price list / payment terms) is refreshed", "Catalog", false, "Catalog:CacheTtlHours", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), null, "6" });

            migrationBuilder.CreateIndex(
                name: "IX_CatalogCache_CatalogType_Code",
                table: "CatalogCache",
                columns: new[] { "CatalogType", "Code" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CatalogCache");

            migrationBuilder.DeleteData(
                table: "Parameters",
                keyColumn: "Id",
                keyValue: 7);
        }
    }
}
