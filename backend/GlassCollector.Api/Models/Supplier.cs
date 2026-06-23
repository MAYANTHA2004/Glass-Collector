namespace GlassCollector.Api.Models;

/// <summary>
/// A supplier location the collector visits on a trip.
/// SupplierCode is the human/barcode-facing unique ID (encoded in the Code128 barcode).
/// </summary>
public class Supplier
{
    public int Id { get; set; }

    /// <summary>Unique ID encoded into the supplier's barcode (e.g. "SUP-1001").</summary>
    public string SupplierCode { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;

    public double Latitude { get; set; }
    public double Longitude { get; set; }

    /// <summary>Expected clear glass to be collected, in kg.</summary>
    public double ExpectedClearKg { get; set; }

    /// <summary>Expected coloured glass to be collected, in kg.</summary>
    public double ExpectedColouredKg { get; set; }

    public bool IsActive { get; set; } = true;
}
