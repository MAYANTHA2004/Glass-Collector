namespace GlassCollector.Api.Models;

public enum StopStatus
{
    Pending = 0,
    Next = 1,
    Collected = 2
}

/// <summary>
/// A single day's collection run. Created when the app calls /api/trips/today
/// for the first time on a given day (or reused if one is already open).
/// </summary>
public class Trip
{
    public int Id { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAtUtc { get; set; }

    /// <summary>Collector's starting latitude for route calculation.</summary>
    public double StartLatitude { get; set; }
    public double StartLongitude { get; set; }

    /// <summary>Total route distance in km, computed once the route is built.</summary>
    public double TotalDistanceKm { get; set; }

    public List<TripStop> Stops { get; set; } = new();
}

/// <summary>
/// A supplier's position and status within a specific trip.
/// Holds the per-trip status (Pending/Next/Collected) and the actual
/// collected quantities once a scan + submission happens.
/// </summary>
public class TripStop
{
    public int Id { get; set; }

    public int TripId { get; set; }
    public Trip? Trip { get; set; }

    public int SupplierId { get; set; }
    public Supplier? Supplier { get; set; }

    /// <summary>1-based order in the optimised route (from Dijkstra).</summary>
    public int SequenceNumber { get; set; }

    public StopStatus Status { get; set; } = StopStatus.Pending;

    /// <summary>Distance in km from the previous stop (or start point for stop 1).</summary>
    public double DistanceFromPreviousKm { get; set; }

    public double? CollectedClearKg { get; set; }
    public double? CollectedColouredKg { get; set; }
    public string? Condition { get; set; }

    public DateTime? CollectedAtUtc { get; set; }
}
