using GlassCollector.Api.Data;
using GlassCollector.Api.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// ---- Services ----
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// SQLite connection string. On most free hosts (Railway/Render) you should
// point this at a persistent volume path via the DB_PATH env var; falls
// back to a local file for development.
var dbPath = Environment.GetEnvironmentVariable("DB_PATH") ?? "glasscollector.db";
builder.Services.AddDbContext<GlassCollectorDbContext>(options =>
    options.UseSqlite($"Data Source={dbPath}"));

builder.Services.AddSingleton<RouteOptimizer>();

// Allow the Flutter app (any origin) to call this API. Tighten this in
// production if you want to restrict to a specific app/domain.
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

// ---- Ensure DB exists + seed on startup ----
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<GlassCollectorDbContext>();
    DbSeeder.Seed(db);
}

// ---- Middleware ----
app.UseSwagger();
app.UseSwaggerUI(); // available at /swagger — handy for manually testing endpoints

app.UseCors("AllowAll");
app.UseAuthorization();
app.MapControllers();

// Simple root health check — useful to confirm the hosted URL is alive.
app.MapGet("/", () => Results.Ok(new
{
    status = "ok",
    service = "Glass Collector API",
    time = DateTime.UtcNow
}));

app.Run();
