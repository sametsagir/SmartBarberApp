using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;

namespace BerberSalonu.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SalonsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _config;

        public SalonsController(AppDbContext context, IConfiguration config)
        {
            _context = context;
            _config = config;
        }

        // GET: api/salons
        [HttpGet]
        public async Task<IActionResult> GetSalons(
            [FromQuery] string? search,
            [FromQuery] string? serviceName,
            [FromQuery] double? minRating,
            [FromQuery] decimal? maxPrice,
            [FromQuery] double? latitude,
            [FromQuery] double? longitude,
            [FromQuery] double? maxDistanceKm,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            // Set bounds for safety
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 100) pageSize = 100;

            var query = _context.Salons
                .Where(s => _context.Services.Any(ser => ser.SalonId == s.Id))
                .AsQueryable();

            var nowTurkey = DateTime.UtcNow.AddHours(3);
            var todayDayOfWeek = (int)nowTurkey.DayOfWeek;
            var nowTime = nowTurkey.TimeOfDay;

            var activeStylistHours = await _context.WorkingHours
                .Where(w => w.DayOfWeek == todayDayOfWeek && w.IsActive && w.Stylist!.IsActive)
                .Select(w => new { w.StylistId, w.StartTime, w.EndTime })
                .ToListAsync();

            var stylistSalonMapping = await _context.Stylists
                .Where(s => s.IsActive)
                .Select(s => new { s.Id, s.SalonId })
                .ToListAsync();

            // Filter by name/address search term
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.ToLower();
                query = query.Where(s => s.Name.ToLower().Contains(term) || s.Address.ToLower().Contains(term));
            }

            // Filter by minimum rating
            if (minRating.HasValue)
            {
                query = query.Where(s => s.Rating >= minRating.Value);
            }

            // Filter by services in the salon
            if (!string.IsNullOrWhiteSpace(serviceName))
            {
                var term = serviceName.ToLower();
                var salonIdsWithService = await _context.Services
                    .Where(ser => ser.Name.ToLower().Contains(term))
                    .Select(ser => ser.SalonId)
                    .Distinct()
                    .ToListAsync();

                query = query.Where(s => salonIdsWithService.Contains(s.Id));
            }

            // Filter by maximum price of any service in the salon
            if (maxPrice.HasValue)
            {
                var salonIdsWithCheaperServices = await _context.Services
                    .Where(ser => ser.Price <= maxPrice.Value)
                    .Select(ser => ser.SalonId)
                    .Distinct()
                    .ToListAsync();

                query = query.Where(s => salonIdsWithCheaperServices.Contains(s.Id));
            }

            if (latitude.HasValue && longitude.HasValue)
            {
                double lat = latitude.Value;
                double lng = longitude.Value;

                const double degToRad = Math.PI / 180.0;
                double latRad = lat * degToRad;
                double lngRad = lng * degToRad;

                var queryWithDistance = query.Select(s => new
                {
                    Salon = s,
                    DistanceKm = Math.Acos(
                        (Math.Sin(latRad) * Math.Sin(s.Latitude * degToRad) +
                         Math.Cos(latRad) * Math.Cos(s.Latitude * degToRad) *
                         Math.Cos((s.Longitude * degToRad) - lngRad)) > 1.0 ? 1.0 :
                        ((Math.Sin(latRad) * Math.Sin(s.Latitude * degToRad) +
                          Math.Cos(latRad) * Math.Cos(s.Latitude * degToRad) *
                          Math.Cos((s.Longitude * degToRad) - lngRad)) < -1.0 ? -1.0 :
                         (Math.Sin(latRad) * Math.Sin(s.Latitude * degToRad) +
                          Math.Cos(latRad) * Math.Cos(s.Latitude * degToRad) *
                          Math.Cos((s.Longitude * degToRad) - lngRad)))
                    ) * 6371.0
                });

                // Filter by max distance if provided
                if (maxDistanceKm.HasValue)
                {
                    queryWithDistance = queryWithDistance.Where(x => x.DistanceKm <= maxDistanceKm.Value);
                }

                // Order by distance and apply pagination at DB query level
                var pagedQuery = queryWithDistance
                    .OrderBy(x => x.DistanceKm)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize);

                var pagedList = await pagedQuery.ToListAsync();

                var result = pagedList.Select(x => {
                    var salonStylistIds = stylistSalonMapping
                        .Where(s => s.SalonId == x.Salon.Id)
                        .Select(s => s.Id)
                        .ToList();

                    bool isOpen = activeStylistHours.Any(w => 
                        salonStylistIds.Contains(w.StylistId) && 
                        w.StartTime <= nowTime && 
                        nowTime <= w.EndTime);

                    return new
                    {
                        x.Salon.Id,
                        x.Salon.Name,
                        x.Salon.Address,
                        x.Salon.Phone,
                        x.Salon.Latitude,
                        x.Salon.Longitude,
                        x.Salon.Rating,
                        x.Salon.ImageUrl,
                        DistanceKm = Math.Round(x.DistanceKm, 1),
                        IsOpen = isOpen
                    };
                }).ToList();

                return Ok(result);
            }
            else
            {
                // No coordinates provided, order by rating (fallback) and paginate
                var pagedList = await query
                    .OrderByDescending(s => s.Rating)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                var result = pagedList.Select(s => {
                    var salonStylistIds = stylistSalonMapping
                        .Where(st => st.SalonId == s.Id)
                        .Select(st => st.Id)
                        .ToList();

                    bool isOpen = activeStylistHours.Any(w => 
                        salonStylistIds.Contains(w.StylistId) && 
                        w.StartTime <= nowTime && 
                        nowTime <= w.EndTime);

                    return new
                    {
                        s.Id,
                        s.Name,
                        s.Address,
                        s.Phone,
                        s.Latitude,
                        s.Longitude,
                        s.Rating,
                        s.ImageUrl,
                        DistanceKm = (double?)null,
                        IsOpen = isOpen
                    };
                }).ToList();

                return Ok(result);
            }
        }

        // GET: api/salons/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetSalonDetails(Guid id)
        {
            var salon = await _context.Salons.FindAsync(id);
            if (salon == null)
            {
                return NotFound(new { Message = "Salon not found." });
            }

            var services = await _context.Services
                .Where(s => s.SalonId == id)
                .ToListAsync();

            var stylistsData = await _context.Stylists
                .Where(s => s.SalonId == id && s.IsActive && _context.StylistServices.Any(ss => ss.StylistId == s.Id))
                .Include(s => s.User)
                .ToListAsync();

            var stylistIds = stylistsData.Select(s => s.Id).ToList();
            var now = DateTime.UtcNow.AddHours(3);

            // Get IDs of stylists who currently have an active appointment running
            var busyStylistIds = await _context.Appointments
                .Where(a => stylistIds.Contains(a.StylistId) &&
                            a.Status != "Cancelled" &&
                            a.StartTime <= now &&
                            a.EndTime > now)
                .Select(a => a.StylistId)
                .Distinct()
                .ToListAsync();

            var stylistServicesMap = await _context.StylistServices
                .Where(ss => stylistIds.Contains(ss.StylistId))
                .ToListAsync();

            var stylists = stylistsData.Select(s => new
            {
                s.Id,
                s.Title,
                s.Rating,
                FullName = s.User?.FullName ?? "Unknown Stylist",
                IsBusy = busyStylistIds.Contains(s.Id),
                ServiceIds = stylistServicesMap
                    .Where(ss => ss.StylistId == s.Id)
                    .Select(ss => ss.ServiceId)
                    .ToList()
            }).ToList();

            var reviews = await _context.Reviews
                .Include(r => r.Customer)
                .Include(r => r.Appointment)
                    .ThenInclude(a => a!.Service)
                .Include(r => r.Appointment)
                    .ThenInclude(a => a!.Stylist)
                        .ThenInclude(s => s!.User)
                .Where(r => r.Appointment!.Stylist!.SalonId == id)
                .OrderByDescending(r => r.CreatedAt)
                .Select(r => new
                {
                    r.Id,
                    r.Rating,
                    r.Comment,
                    CreatedAt = r.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                    CustomerName = r.Customer != null ? r.Customer.FullName : "Anonymous Customer",
                    ServiceName = r.Appointment != null && r.Appointment.Service != null ? r.Appointment.Service.Name : "Unknown Service",
                    StylistName = r.Appointment != null && r.Appointment.Stylist != null && r.Appointment.Stylist.User != null ? r.Appointment.Stylist.User.FullName : "Unknown Barber"
                })
                .ToListAsync();

            return Ok(new
            {
                Salon = salon,
                Services = services,
                Stylists = stylists,
                Reviews = reviews
            });
        }
    }
}
