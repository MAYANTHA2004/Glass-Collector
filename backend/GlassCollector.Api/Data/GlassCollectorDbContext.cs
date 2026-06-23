using GlassCollector.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GlassCollector.Api.Data;

public class GlassCollectorDbContext : DbContext
{
    public GlassCollectorDbContext(DbContextOptions<GlassCollectorDbContext> options)
        : base(options) { }

    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<Trip> Trips => Set<Trip>();
    public DbSet<TripStop> TripStops => Set<TripStop>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Supplier>()
            .HasIndex(s => s.SupplierCode)
            .IsUnique();

        modelBuilder.Entity<TripStop>()
            .HasOne(ts => ts.Trip)
            .WithMany(t => t.Stops)
            .HasForeignKey(ts => ts.TripId);

        modelBuilder.Entity<TripStop>()
            .HasOne(ts => ts.Supplier)
            .WithMany()
            .HasForeignKey(ts => ts.SupplierId);

        modelBuilder.Entity<TripStop>()
            .Property(ts => ts.Status)
            .HasConversion<string>();
    }
}
