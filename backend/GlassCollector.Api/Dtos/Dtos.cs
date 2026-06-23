namespace GlassCollector.Api.Dtos;

// ---------- Screen 1: Trip Sequence ----------

public class TripStopDto
{
    public int TripStopId { get; set; }
    public int SupplierId { get; set; }
    public string SupplierCode { get; set; } = string.Empty;
    public string SupplierName { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int SequenceNumber { get; set; }
    public double DistanceFromPreviousKm { get; set; }
    public double ExpectedClearKg { get; set; }
    public double ExpectedColouredKg { get; set; }
    public string Status { get; set; } = "Pending"; // Pending | Next | Collected
}

public class TripResponseDto
{
    public int TripId { get; set; }
    public double TotalDistanceKm { get; set; }
    public int RemainingStops { get; set; }
    public List<TripStopDto> Stops { get; set; } = new();
}

// ---------- Screen 2: Scan & Collect ----------

public class VerifyBarcodeRequest
{
    public int TripId { get; set; }
    public string ScannedSupplierCode { get; set; } = string.Empty;
}

public class VerifyBarcodeResponse
{
    public bool IsMatch { get; set; }
    public string Message { get; set; } = string.Empty;
    public int? TripStopId { get; set; }
    public int? SupplierId { get; set; }
}

public class CollectionSubmissionRequest
{
    public int TripId { get; set; }
    public int TripStopId { get; set; }
    public string SupplierCode { get; set; } = string.Empty; // re-verified server-side
    public double ClearKg { get; set; }
    public double ColouredKg { get; set; }
    public string Condition { get; set; } = string.Empty; // e.g. Good / Contaminated / Damaged
    public DateTime CollectedAtUtc { get; set; }
}

public class CollectionSubmissionResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public string NewStatus { get; set; } = string.Empty;
    public int? NextTripStopId { get; set; }
}

// ---------- Screen 3: Trip Report ----------

public class TripReportSupplierDto
{
    public string SupplierName { get; set; } = string.Empty;
    public string SupplierCode { get; set; } = string.Empty;
    public double ExpectedClearKg { get; set; }
    public double ExpectedColouredKg { get; set; }
    public double CollectedClearKg { get; set; }
    public double CollectedColouredKg { get; set; }
    public bool IsShortfall { get; set; }
    public string Condition { get; set; } = string.Empty;
}

public class TripReportDto
{
    public int TripId { get; set; }
    public double TotalDistanceKm { get; set; }
    public double TotalKgCollected { get; set; }

    /// <summary>Trip duration in seconds (plain number, avoids TimeSpan JSON ambiguity).</summary>
    public double TripDurationSeconds { get; set; }

    public List<TripReportSupplierDto> Suppliers { get; set; } = new();
}

// ---------- Sync ----------

public class SyncRecordDto
{
    public string SupplierCode { get; set; } = string.Empty;
    public int TripStopId { get; set; }
    public double ClearKg { get; set; }
    public double ColouredKg { get; set; }
    public string Condition { get; set; } = string.Empty;
    public DateTime CollectedAtUtc { get; set; }
}

public class SyncRequest
{
    public int TripId { get; set; }
    public List<SyncRecordDto> Records { get; set; } = new();
}

public class SyncResponse
{
    public bool Success { get; set; }
    public int RecordsAccepted { get; set; }
    public List<string> Errors { get; set; } = new();
}
