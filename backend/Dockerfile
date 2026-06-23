# ---- Build stage ----
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY GlassCollector.Api/*.csproj ./GlassCollector.Api/
RUN dotnet restore ./GlassCollector.Api/GlassCollector.Api.csproj

COPY GlassCollector.Api/. ./GlassCollector.Api/
RUN dotnet publish ./GlassCollector.Api/GlassCollector.Api.csproj -c Release -o /app

# ---- Runtime stage ----
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app .

# Persistent path for the SQLite file. On Railway/Render, mount a volume
# at /data (or set DB_PATH to wherever your volume is mounted) so the
# database survives restarts/redeploys.
ENV DB_PATH=/data/glasscollector.db
RUN mkdir -p /data

EXPOSE 8080
ENTRYPOINT ["dotnet", "GlassCollector.Api.dll"]
