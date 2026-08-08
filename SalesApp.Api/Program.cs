using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SalesApp.Api.Services;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.Persistence;
using SalesApp.Infrastructure.SapServiceLayer;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// --- Database ---
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// --- Data Protection (encrypts Parameters.Value; keys persisted in DB, not local disk) ---
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<AppDbContext>()
    .SetApplicationName("SalesApp");

// --- SAP Service Layer integration ---
builder.Services.AddSingleton<SapSessionManager>();
builder.Services.AddHttpClient("SapServiceLayer")
    .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
    {
        // Uncomment only if the client's Service Layer uses a self-signed certificate:
        ServerCertificateCustomValidationCallback = (msg, cert, chain, errors) => true
    });
builder.Services.AddHttpClient<ISapServiceLayerClient, SapClient>("SapServiceLayer");

// --- App services ---
builder.Services.AddScoped<TokenService>();

// --- JWT authentication ---
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();