using GlassCollector.Api.Data;
using GlassCollector.Api.Dtos;
using GlassCollector.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GlassCollector.Api.Controllers;

[ApiController]
[Route("api/collections")]
public class CollectionsController : ControllerBase
{
    private readonly GlassCollectorDbContext _db;

    public CollectionsController(GlassCollectorDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Screen 2 check-in gate: verifies the scanned barcode (decoded to a
    /// supplier code by the app) matches the CURRENT expected stop for
    /// this trip. Wrong supplier ID -> blocked. Correct match -> caller
    /// may unlock the quantity form for that stop.
    /// </summary>
    [HttpPost("verify")]
    public async Task<ActionResult<VerifyBarcodeResponse>> Verify([FromBody] VerifyBarcodeRequest request)
    {
        var trip = await _db.Trips
            .Include(t => t.Stops).ThenInclude(s => s.Supplier)
            .FirstOrDefaultAsync(t => t.Id == request.TripId);

        if (trip == null)
            return NotFound(new VerifyBarcodeResponse { IsMatch = false, Message = "Trip not found." });

        var expectedStop = trip.Stops
            .Where(s => s.Status != StopStatus.Collected)
            .OrderBy(s => s.SequenceNumber)
            .FirstOrDefault();

        if (expectedStop == null)
            return Ok(new VerifyBarcodeResponse { IsMatch = false, Message = "All stops already collected." });

        bool isMatch = string.Equals(
            expectedStop.Supplier!.SupplierCode,
            request.ScannedSupplierCode,
            StringComparison.OrdinalIgnoreCase);

        if (!isMatch)
        {
            return Ok(new VerifyBarcodeResponse
            {
                IsMatch = false,
                Message = $"Wrong supplier. Expected '{expectedStop.Supplier.SupplierCode}' " +
                          $"but scanned '{request.ScannedSupplierCode}'."
            });
        }

        return Ok(new VerifyBarcodeResponse
        {
            IsMatch = true,
            Message = "Match confirmed. Quantity form unlocked.",
            TripStopId = expectedStop.Id,
            SupplierId = expectedStop.SupplierId
        });
    }

    /// <summary>
    /// Screen 2 confirmation: accepts a collection submission by supplier
    /// ID (decoded from the barcode), updates that supplier's collected
    /// quantities, and sets status to Collected. Also advances the trip's
    /// next "Next" stop pointer.
    /// </summary>
    [HttpPost("submit")]
    public async Task<ActionResult<CollectionSubmissionResponse>> Submit([FromBody] CollectionSubmissionRequest request)
    {
        var stop = await _db.TripStops
            .Include(s => s.Supplier)
            .Include(s => s.Trip)
            .FirstOrDefaultAsync(s => s.Id == request.TripStopId && s.TripId == request.TripId);

        if (stop == null)
        {
            return NotFound(new CollectionSubmissionResponse
            {
                Success = false,
                Message = "Trip stop not found."
            });
        }

        // Re-verify supplier code server-side — barcode is the only way to
        // identify/update a record, no manual override.
        if (!string.Equals(stop.Supplier!.SupplierCode, request.SupplierCode, StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new CollectionSubmissionResponse
            {
                Success = false,
                Message = "Supplier code does not match this stop. Submission rejected."
            });
        }

        stop.CollectedClearKg = request.ClearKg;
        stop.CollectedColouredKg = request.ColouredKg;
        stop.Condition = request.Condition;
        stop.CollectedAtUtc = request.CollectedAtUtc == default ? DateTime.UtcNow : request.CollectedAtUtc;
        stop.Status = StopStatus.Collected;

        // Promote the next pending stop (by sequence) to "Next".
        var nextStop = await _db.TripStops
            .Where(s => s.TripId == stop.TripId && s.Status == StopStatus.Pending)
            .OrderBy(s => s.SequenceNumber)
            .FirstOrDefaultAsync();

        if (nextStop != null)
        {
            nextStop.Status = StopStatus.Next;
        }
        else
        {
            // No more pending stops — mark trip complete if nothing else is outstanding.
            var anyRemaining = await _db.TripStops
                .AnyAsync(s => s.TripId == stop.TripId && s.Status != StopStatus.Collected);

            if (!anyRemaining && stop.Trip != null && stop.Trip.CompletedAtUtc == null)
            {
                stop.Trip.CompletedAtUtc = DateTime.UtcNow;
            }
        }

        await _db.SaveChangesAsync();

        return Ok(new CollectionSubmissionResponse
        {
            Success = true,
            Message = $"Collection recorded for {stop.Supplier.Name}.",
            NewStatus = stop.Status.ToString(),
            NextTripStopId = nextStop?.Id
        });
    }

    /// <summary>
    /// Screen 3 "Sync to server": final confirmation push of all locally
    /// stored (offline-first) records. Idempotent — re-submitting an
    /// already-collected stop with the same data simply re-confirms it,
    /// so a retried sync after a partial failure is safe.
    /// </summary>
    [HttpPost("sync")]
    public async Task<ActionResult<SyncResponse>> Sync([FromBody] SyncRequest request)
    {
        var response = new SyncResponse();

        foreach (var record in request.Records)
        {
            var stop = await _db.TripStops
                .Include(s => s.Supplier)
                .FirstOrDefaultAsync(s => s.Id == record.TripStopId && s.TripId == request.TripId);

            if (stop == null || stop.Supplier == null)
            {
                response.Errors.Add($"Stop {record.TripStopId}: not found.");
                continue;
            }

            if (!string.Equals(stop.Supplier.SupplierCode, record.SupplierCode, StringComparison.OrdinalIgnoreCase))
            {
                response.Errors.Add($"Stop {record.TripStopId}: supplier code mismatch, skipped.");
                continue;
            }

            stop.CollectedClearKg = record.ClearKg;
            stop.CollectedColouredKg = record.ColouredKg;
            stop.Condition = record.Condition;
            stop.CollectedAtUtc = record.CollectedAtUtc;
            stop.Status = StopStatus.Collected;

            response.RecordsAccepted++;
        }

        await _db.SaveChangesAsync();
        response.Success = response.Errors.Count == 0;

        return Ok(response);
    }
}
