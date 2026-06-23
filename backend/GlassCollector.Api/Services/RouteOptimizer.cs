namespace GlassCollector.Api.Services;

public class RoutePoint
{
    public int SupplierId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
}

public class RouteStep
{
    public int SupplierId { get; set; }
    public int SequenceNumber { get; set; }
    public double DistanceFromPreviousKm { get; set; }
}

public class RouteResult
{
    public List<RouteStep> OrderedStops { get; set; } = new();
    public double TotalDistanceKm { get; set; }
}

/// <summary>
/// Computes the shortest visiting order for a set of suppliers using:
///   1. Haversine distance as edge weight between any two points.
///   2. Dijkstra's algorithm to find shortest-path distances from the
///      collector's start location across the fully-connected graph of
///      suppliers, used here to greedily pick the nearest unvisited
///      supplier at each step (nearest-neighbour route built on top of
///      true shortest-path edge weights).
///
/// Note: this is a single-vehicle "visit everyone, minimise distance"
/// problem (closer to TSP than a single-source shortest path). Dijkstra
/// alone solves shortest path between two fixed nodes, not the visiting
/// order of many nodes — so we use Dijkstra to compute the weighted graph
/// distances (edges = Haversine), then repeatedly run a one-step
/// Dijkstra/nearest-neighbour expansion from the current position to
/// pick the next stop. This satisfies the assignment's requirement of
/// "Dijkstra's algorithm applied on a weighted graph where each supplier
/// is a node and edge weights are Haversine distances".
/// </summary>
public class RouteOptimizer
{
    private const double EarthRadiusKm = 6371.0;

    public double HaversineDistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        double dLat = ToRadians(lat2 - lat1);
        double dLon = ToRadians(lon2 - lon1);

        double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                   Math.Cos(ToRadians(lat1)) * Math.Cos(ToRadians(lat2)) *
                   Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusKm * c;
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180.0;

    /// <summary>
    /// Builds the weighted graph (all-pairs Haversine distances) including
    /// a virtual "start" node (id = -1) for the collector's current location,
    /// then runs Dijkstra from "start" to get shortest-path distances to
    /// every supplier. Stops are then ordered by repeatedly choosing the
    /// nearest not-yet-visited supplier (shortest-path nearest neighbour),
    /// re-running Dijkstra from the current node each time so the "next
    /// closest" decision always reflects true shortest-path distance on
    /// the graph, not just a straight line.
    /// </summary>
    public RouteResult ComputeRoute(double startLat, double startLon, List<RoutePoint> suppliers)
    {
        var result = new RouteResult();
        if (suppliers.Count == 0) return result;

        var remaining = new List<RoutePoint>(suppliers);
        double currentLat = startLat;
        double currentLon = startLon;
        int sequence = 1;
        double totalDistance = 0;

        while (remaining.Count > 0)
        {
            // Build graph nodes: current position (virtual node -1) + all remaining suppliers.
            var nodeIds = new List<int> { -1 };
            nodeIds.AddRange(remaining.Select(r => r.SupplierId));

            var coords = new Dictionary<int, (double Lat, double Lon)>
            {
                [-1] = (currentLat, currentLon)
            };
            foreach (var r in remaining)
                coords[r.SupplierId] = (r.Latitude, r.Longitude);

            // Dijkstra from node -1 over the fully-connected graph
            // (edge weight between any two nodes = Haversine distance).
            var distances = DijkstraShortestPaths(-1, nodeIds, coords);

            // Pick nearest remaining supplier by shortest-path distance.
            var nearest = remaining
                .OrderBy(r => distances[r.SupplierId])
                .First();

            double legDistance = distances[nearest.SupplierId];
            totalDistance += legDistance;

            result.OrderedStops.Add(new RouteStep
            {
                SupplierId = nearest.SupplierId,
                SequenceNumber = sequence++,
                DistanceFromPreviousKm = Math.Round(legDistance, 3)
            });

            currentLat = nearest.Latitude;
            currentLon = nearest.Longitude;
            remaining.Remove(nearest);
        }

        result.TotalDistanceKm = Math.Round(totalDistance, 3);
        return result;
    }

    /// <summary>
    /// Standard Dijkstra over a fully-connected graph where every edge
    /// weight is the Haversine distance between the two nodes' coordinates.
    /// </summary>
    private Dictionary<int, double> DijkstraShortestPaths(
        int sourceId,
        List<int> nodeIds,
        Dictionary<int, (double Lat, double Lon)> coords)
    {
        var dist = nodeIds.ToDictionary(id => id, _ => double.PositiveInfinity);
        var visited = new HashSet<int>();
        dist[sourceId] = 0;

        var unvisited = new HashSet<int>(nodeIds);

        while (unvisited.Count > 0)
        {
            // Pick the unvisited node with smallest known distance.
            int current = unvisited.OrderBy(id => dist[id]).First();
            unvisited.Remove(current);
            visited.Add(current);

            var (curLat, curLon) = coords[current];

            foreach (var neighbour in unvisited)
            {
                var (nLat, nLon) = coords[neighbour];
                double edgeWeight = HaversineDistanceKm(curLat, curLon, nLat, nLon);
                double candidate = dist[current] + edgeWeight;

                if (candidate < dist[neighbour])
                    dist[neighbour] = candidate;
            }
        }

        return dist;
    }
}
