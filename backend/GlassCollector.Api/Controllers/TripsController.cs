using GlassCollector.Api.Data;
using GlassCollector.Api.Dtos;
using GlassCollector.Api.Models;
using GlassCollector.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GlassCollector.Api.Controllers;

[ApiController]
[Route("api/trips")]
public class TripsController : ControllerBase
{
    private readonly GlassCollectorDbContext _db;
    private readonly RouteOptimizer _routeOptimizer;

    // Default collector starting point (depot). In a real app this would
    // come from the device's GPS or a configured depot location.
    private const double DefaultStartLat = 6.9344; // Colombo Fort area
    private const double DefaultStartLon = 79.8428;

    public TripsController(GlassCollectorDbContext db, RouteOptimizer routeOptimizer)
    {
        _db = db;
        _routeOptimizer = routeOptimizer;
    }

    /// <summary>
    /// Screen 1: Fetch (or create) today's trip with the optimised stop
    /// sequence. If an open trip already exists for today, its live
    /// status is returned instead of recalculating the route, so that
    /// scans recorded earlier in the day are reflected.
    /// </summary>
    [HttpGet("today")]
    public async Task<ActionResult<TripResponseDto>> GetToday(
        [FromQuery] double? startLat, [FromQuery] double? startLon)
    {
        var todayUtc = DateTime.UtcNow.Date;

        var existingTrip = await _db.Trips
            .Include(t => t.Stops).ThenInclude(s => s.Supplier)
            .Where(t => t.CreatedAtUtc.Date == todayUtc)
            .OrderByDescending(t => t.Id)
            .FirstOrDefaultAsync();

        Trip trip;

        if (existingTrip != null)
        {
            trip = existingTrip;
        }
        else
        {
            trip = await CreateTripWithRoute(startLat ?? DefaultStartLat, startLon ?? DefaultStartLon);
        }

        return Ok(BuildTripResponse(trip));
    }

    /// <summary>
    /// Forces creation of a brand-new trip (new route calculation),
    /// useful for demos/testing without waiting for the next calendar day.
    /// </summary>
    [HttpPost("new")]
    public async Task<ActionResult<TripResponseDto>> CreateNew(
        [FromQuery] double? startLat, [FromQuery] double? startLon)
    {
        var trip = await CreateTripWithRoute(startLat ?? DefaultStartLat, startLon ?? DefaultStartLon);
        return Ok(BuildTripResponse(trip));
    }

    private async Task<Trip> CreateTripWithRoute(double startLat, double startLon)
    {
        var activeSuppliers = await _db.Suppliers.Where(s => s.IsActive).ToListAsync();

        var routePoints = activeSuppliers.Select(s => new RoutePoint
        {
            SupplierId = s.Id,
            Latitude = s.Latitude,
            Longitude = s.Longitude
        }).ToList();

        var route = _routeOptimizer.ComputeRoute(startLat, startLon, routePoints);

        var trip = new Trip
        {
            StartLatitude = startLat,
            StartLongitude = startLon,
            TotalDistanceKm = route.TotalDistanceKm,
            CreatedAtUtc = DateTime.UtcNow
        };

        foreach (var step in route.OrderedStops)
        {
            trip.Stops.Add(new TripStop
            {
                SupplierId = step.SupplierId,
                SequenceNumber = step.SequenceNumber,
                DistanceFromPreviousKm = step.DistanceFromPreviousKm,
                Status = step.SequenceNumber == 1 ? StopStatus.Next : StopStatus.Pending
            });
        }

        _db.Trips.Add(trip);
        await _db.SaveChangesAsync();

        // Reload with Supplier navigation populated.
        return await _db.Trips
            .Include(t => t.Stops).ThenInclude(s => s.Supplier)
            .FirstAsync(t => t.Id == trip.Id);
    }

    private TripResponseDto BuildTripResponse(Trip trip)
    {
        var orderedStops = trip.Stops.OrderBy(s => s.SequenceNumber).ToList();

        return new TripResponseDto
        {
            TripId = trip.Id,
            TotalDistanceKm = trip.TotalDistanceKm,
            RemainingStops = orderedStops.Count(s => s.Status != StopStatus.Collected),
            Stops = orderedStops.Select(s => new TripStopDto
            {
                TripStopId = s.Id,
                SupplierId = s.SupplierId,
                SupplierCode = s.Supplier!.SupplierCode,
                SupplierName = s.Supplier.Name,
                Address = s.Supplier.Address,
                Latitude = s.Supplier.Latitude,
                Longitude = s.Supplier.Longitude,
                SequenceNumber = s.SequenceNumber,
                DistanceFromPreviousKm = s.DistanceFromPreviousKm,
                ExpectedClearKg = s.Supplier.ExpectedClearKg,
                ExpectedColouredKg = s.Supplier.ExpectedColouredKg,
                Status = s.Status.ToString()
            }).ToList()
        };
    }

    /// <summary>
    /// Screen 3: Trip report — per-supplier summary, totals, duration,
    /// and shortfall flags.
    /// </summary>
    [HttpGet("{tripId}/report")]
    public async Task<ActionResult<TripReportDto>> GetReport(int tripId)
    {
        var trip = await _db.Trips
            .Include(t => t.Stops).ThenInclude(s => s.Supplier)
            .FirstOrDefaultAsync(t => t.Id == tripId);

        if (trip == null) return NotFound(new { message = "Trip not found." });

        var stops = trip.Stops.OrderBy(s => s.SequenceNumber).ToList();

        var report = new TripReportDto
        {
            TripId = trip.Id,
            TotalDistanceKm = trip.TotalDistanceKm,
            TotalKgCollected = stops.Sum(s => (s.CollectedClearKg ?? 0) + (s.CollectedColouredKg ?? 0)),
            TripDurationSeconds = ((trip.CompletedAtUtc ?? DateTime.UtcNow) - trip.CreatedAtUtc).TotalSeconds,
            Suppliers = stops.Select(s =>
            {
                double collectedClear = s.CollectedClearKg ?? 0;
                double collectedColoured = s.CollectedColouredKg ?? 0;
                double expectedTotal = s.Supplier!.ExpectedClearKg + s.Supplier.ExpectedColouredKg;
                double collectedTotal = collectedClear + collectedColoured;

                return new TripReportSupplierDto
                {
                    SupplierName = s.Supplier.Name,
                    SupplierCode = s.Supplier.SupplierCode,
                    ExpectedClearKg = s.Supplier.ExpectedClearKg,
                    ExpectedColouredKg = s.Supplier.ExpectedColouredKg,
                    CollectedClearKg = collectedClear,
                    CollectedColouredKg = collectedColoured,
                    IsShortfall = s.Status == StopStatus.Collected && collectedTotal < expectedTotal,
                    Condition = s.Condition ?? ""
                };
            }).ToList()
        };

        return Ok(report);
    }
}
