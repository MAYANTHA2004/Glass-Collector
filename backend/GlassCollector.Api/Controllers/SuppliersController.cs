using GlassCollector.Api.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GlassCollector.Api.Controllers;

[ApiController]
[Route("api/suppliers")]
public class SuppliersController : ControllerBase
{
    private readonly GlassCollectorDbContext _db;

    public SuppliersController(GlassCollectorDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Returns all seeded suppliers with their barcode-encoded SupplierCode.
    /// Use this list to know which codes to generate barcodes for when
    /// testing (see README "Barcode setup").
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var suppliers = await _db.Suppliers
            .Select(s => new
            {
                s.Id,
                s.SupplierCode,
                s.Name,
                s.Address,
                s.Latitude,
                s.Longitude,
                s.ExpectedClearKg,
                s.ExpectedColouredKg
            })
            .ToListAsync();

        return Ok(suppliers);
    }
}
