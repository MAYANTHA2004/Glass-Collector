using GlassCollector.Api.Models;

namespace GlassCollector.Api.Data;

/// <summary>
/// Seeds a handful of test suppliers so the app has something to load,
/// route, and scan against on first run. Coordinates are real points
/// around Colombo, Sri Lanka, spaced a few km apart so the route
/// calculation and map distances look sensible during a demo.
/// </summary>
public static class DbSeeder
{
    public static void Seed(GlassCollectorDbContext db)
    {
        db.Database.EnsureCreated();

        if (db.Suppliers.Any())
            return; // already seeded

        var suppliers = new List<Supplier>
        {
            new() {
                SupplierCode = "SUP-1001",
                Name = "Galle Face Hotel - Kitchen Store",
                Address = "Galle Rd, Colombo 03",
                Latitude = 6.9271, Longitude = 79.8425,
                ExpectedClearKg = 40, ExpectedColouredKg = 15
            },
            new() {
                SupplierCode = "SUP-1002",
                Name = "Liberty Plaza Food Court",
                Address = "R A De Mel Mawatha, Colombo 03",
                Latitude = 6.9147, Longitude = 79.8483,
                ExpectedClearKg = 25, ExpectedColouredKg = 10
            },
            new() {
                SupplierCode = "SUP-1003",
                Name = "Majestic City Beverages",
                Address = "Station Rd, Colombo 04",
                Latitude = 6.8862, Longitude = 79.8587,
                ExpectedClearKg = 30, ExpectedColouredKg = 20
            },
            new() {
                SupplierCode = "SUP-1004",
                Name = "Mount Lavinia Hotel Bar",
                Address = "Hotel Rd, Mount Lavinia",
                Latitude = 6.8389, Longitude = 79.8653,
                ExpectedClearKg = 50, ExpectedColouredKg = 35
            },
            new() {
                SupplierCode = "SUP-1005",
                Name = "Dehiwala Junction Wine Store",
                Address = "Galle Rd, Dehiwala",
                Latitude = 6.8513, Longitude = 79.8634,
                ExpectedClearKg = 20, ExpectedColouredKg = 8
            },
        };

        db.Suppliers.AddRange(suppliers);
        db.SaveChanges();
    }
}
