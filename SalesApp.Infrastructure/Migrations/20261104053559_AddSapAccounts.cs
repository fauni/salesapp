using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SalesApp.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddSapAccounts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "SapAccountId",
                table: "Users",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "SapAccounts",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Username = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Password = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SapAccounts", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_SapAccountId",
                table: "Users",
                column: "SapAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_SapAccounts_Name",
                table: "SapAccounts",
                column: "Name",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Users_SapAccounts_SapAccountId",
                table: "Users",
                column: "SapAccountId",
                principalTable: "SapAccounts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Users_SapAccounts_SapAccountId",
                table: "Users");

            migrationBuilder.DropTable(
                name: "SapAccounts");

            migrationBuilder.DropIndex(
                name: "IX_Users_SapAccountId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SapAccountId",
                table: "Users");
        }
    }
}
