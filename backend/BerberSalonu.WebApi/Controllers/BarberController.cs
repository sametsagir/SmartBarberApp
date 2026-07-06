using System.IO;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;

namespace BerberSalonu.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class BarberController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _config;

        public BarberController(AppDbContext context, IConfiguration config)
        {
            _context = context;
            _config = config;
        }

        private Guid GetUserId()
        {
            var claimVal = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(claimVal))
                throw new UnauthorizedAccessException("Yetkisiz erişim.");
            return Guid.Parse(claimVal);
        }

        private async Task<Stylist> GetOrCreateStylistAsync(Guid userId)
        {
            var stylist = await _context.Stylists
                .Include(s => s.Salon)
                .FirstOrDefaultAsync(s => s.UserId == userId);

            if (stylist != null)
            {
                var hasOwner = await _context.Stylists.AnyAsync(s => s.SalonId == stylist.SalonId && s.IsOwner);
                if (!hasOwner)
                {
                    stylist.IsOwner = true;
                    _context.Entry(stylist).State = EntityState.Modified;
                    await _context.SaveChangesAsync();
                }
                return stylist;
            }

            var user = await _context.Users.FindAsync(userId);
            var salonName = user != null ? $"{user.FullName} Berber Salonu" : "Yeni Berber Salonu";
            
            var newSalon = new Salon
            {
                Name = salonName,
                Address = "Adres girilmemiş. Lütfen güncelleyin.",
                Phone = user?.PhoneNumber ?? "+905555555555",
                Latitude = 41.0082, // Varsayılan İstanbul koordinatları
                Longitude = 28.9784,
                Rating = 5.0,
                ImageUrl = "https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500"
            };
            _context.Salons.Add(newSalon);
            await _context.SaveChangesAsync();

            stylist = new Stylist
            {
                UserId = userId,
                SalonId = newSalon.Id,
                Title = "Usta Berber",
                Rating = 5.0,
                IsOwner = true // Salon sahibi ilk berberdir
            };
            _context.Stylists.Add(stylist);
            await _context.SaveChangesAsync();


                var whList = new List<WorkingHours>();
                for (int day = 1; day <= 6; day++)
                {
                    whList.Add(new WorkingHours
                    {
                        StylistId = stylist.Id,
                        DayOfWeek = day,
                        StartTime = new TimeSpan(9, 0, 0),
                        EndTime = new TimeSpan(19, 0, 0),
                        LunchStartTime = new TimeSpan(12, 0, 0),
                        LunchEndTime = new TimeSpan(13, 0, 0),
                        IsActive = true
                    });
                }
                whList.Add(new WorkingHours
                {
                    StylistId = stylist.Id,
                    DayOfWeek = 0,
                    StartTime = new TimeSpan(9, 0, 0),
                    EndTime = new TimeSpan(19, 0, 0),
                    IsActive = false
                });

                _context.WorkingHours.AddRange(whList);
                await _context.SaveChangesAsync();

            return stylist;
        }

        [HttpGet("profile")]
        public async Task<IActionResult> GetProfile()
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var workingHours = await _context.WorkingHours
                    .Where(w => w.StylistId == stylist.Id)
                    .OrderBy(w => w.DayOfWeek)
                    .Select(w => new
                    {
                        w.Id,
                        w.DayOfWeek,
                        StartTime = w.StartTime.ToString(@"hh\:mm"),
                        EndTime = w.EndTime.ToString(@"hh\:mm"),
                        LunchStartTime = w.LunchStartTime.HasValue ? w.LunchStartTime.Value.ToString(@"hh\:mm") : null,
                        LunchEndTime = w.LunchEndTime.HasValue ? w.LunchEndTime.Value.ToString(@"hh\:mm") : null,
                        w.IsActive
                    })
                    .ToListAsync();

                var user = await _context.Users.FindAsync(userId);

                return Ok(new
                {
                    StylistId = stylist.Id,
                    FullName = user?.FullName ?? "Bilinmeyen Berber",
                    Title = stylist.Title,
                    Rating = stylist.Rating,
                    IsOwner = stylist.IsOwner,
                    SalonId = stylist.SalonId,
                    SalonName = stylist.Salon?.Name ?? "Bilinmeyen Salon",
                    WorkingHours = workingHours
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPut("working-hours")]
        public async Task<IActionResult> UpdateWorkingHours([FromBody] List<WorkingHoursUpdateModel> request)
        {
            if (request == null || !request.Any())
                return BadRequest(new { Message = "Request cannot be empty." });

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                foreach (var item in request)
                {
                    var wh = await _context.WorkingHours
                        .FirstOrDefaultAsync(w => w.StylistId == stylist.Id && w.DayOfWeek == item.DayOfWeek);

                    if (wh != null)
                    {
                        wh.StartTime = TimeSpan.Parse(item.StartTime);
                        wh.EndTime = TimeSpan.Parse(item.EndTime);
                        wh.LunchStartTime = !string.IsNullOrEmpty(item.LunchStartTime) ? TimeSpan.Parse(item.LunchStartTime) : null;
                        wh.LunchEndTime = !string.IsNullOrEmpty(item.LunchEndTime) ? TimeSpan.Parse(item.LunchEndTime) : null;
                        wh.IsActive = item.IsActive;
                    }
                }

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Working hours successfully updated." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = $"Update failed: {ex.Message}" });
            }
        }

        [HttpGet("services")]
        public async Task<IActionResult> GetServices()
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                var services = await _context.Services
                    .Where(s => s.SalonId == stylist.SalonId)
                    .Select(s => new
                    {
                        s.Id,
                        s.Name,
                        s.DurationInMinutes,
                        s.Price
                    })
                    .ToListAsync();

                return Ok(services);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPost("services")]
        public async Task<IActionResult> AddService([FromBody] ServiceCreateModel request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                var newService = new Service
                {
                    SalonId = stylist.SalonId,
                    Name = request.Name,
                    DurationInMinutes = request.DurationInMinutes,
                    Price = request.Price
                };

                _context.Services.Add(newService);
                await _context.SaveChangesAsync();

                return Ok(new { Message = "Service successfully added.", Service = newService });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPut("services/{id}")]
        public async Task<IActionResult> UpdateService(Guid id, [FromBody] ServiceCreateModel request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                var service = await _context.Services
                    .FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);

                if (service == null)
                    return NotFound(new { Message = "Service not found." });

                service.Name = request.Name;
                service.DurationInMinutes = request.DurationInMinutes;
                service.Price = request.Price;

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Service successfully updated." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpDelete("services/{id}")]
        public async Task<IActionResult> DeleteService(Guid id)
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                var service = await _context.Services
                    .FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);

                if (service == null)
                    return NotFound(new { Message = "Service not found." });

                var totalServicesCount = await _context.Services.CountAsync(s => s.SalonId == stylist.SalonId);
                if (totalServicesCount <= 1)
                {
                    return BadRequest(new { Message = "The last service in the salon cannot be deleted. At least one service is required for customers to book appointments." });
                }

                var hasAppointments = await _context.Appointments.AnyAsync(a => a.ServiceId == id && a.Status != "Cancelled");
                if (hasAppointments)
                {
                    return BadRequest(new { Message = "This service cannot be deleted because there are active appointments booked for it." });
                }

                var stylistServices = await _context.StylistServices.Where(ss => ss.ServiceId == id).ToListAsync();
                _context.StylistServices.RemoveRange(stylistServices);

                _context.Services.Remove(service);
                await _context.SaveChangesAsync();
                return Ok(new { Message = "Service successfully deleted." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("analytics")]
        public async Task<IActionResult> GetAnalytics()
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                // Get all active (non-cancelled) appointments for the stylist's salon
                var salonAppointmentsQuery = _context.Appointments
                    .Where(a => a.Stylist!.SalonId == stylist.SalonId && a.Status != "Cancelled")
                    .Include(a => a.Service)
                    .Include(a => a.Stylist)
                        .ThenInclude(s => s!.User)
                    .AsQueryable();

                if (!stylist.IsOwner)
                {
                    salonAppointmentsQuery = salonAppointmentsQuery.Where(a => a.StylistId == stylist.Id);
                }

                var appointments = await salonAppointmentsQuery.ToListAsync();


                var today = DateTime.UtcNow.AddHours(3).Date;
                var enCulture = new System.Globalization.CultureInfo("en-US");

                // Calculate Totals
                decimal totalSalonRevenue = appointments.Sum(a => a.Service?.Price ?? 0);
                int totalSalonBookings = appointments.Count;
                decimal personalRevenue = appointments.Where(a => a.StylistId == stylist.Id).Sum(a => a.Service?.Price ?? 0);
                int personalBookings = appointments.Count(a => a.StylistId == stylist.Id);

                // Daily Earnings (Last 7 Days)
                var dailyEarnings = new List<object>();
                for (int i = 6; i >= 0; i--)
                {
                    var targetDate = today.AddDays(-i);
                    var sum = appointments
                        .Where(a => a.StartTime.Date == targetDate)
                        .Sum(a => a.Service?.Price ?? 0);

                    string dayLabel = targetDate.ToString("dddd", enCulture);
                    // Abbreviate if possible (Monday -> Mon)
                    if (dayLabel.Length > 3) dayLabel = dayLabel.Substring(0, 3);

                    dailyEarnings.Add(new
                    {
                        Date = targetDate.ToString("yyyy-MM-dd"),
                        DayName = dayLabel,
                        DayMonth = targetDate.ToString("dd.MM"),
                        Revenue = sum
                    });
                }

                // Monthly Earnings (Last 6 Months)
                var monthlyEarnings = new List<object>();
                for (int i = 5; i >= 0; i--)
                {
                    var targetMonth = today.AddMonths(-i);
                    var sum = appointments
                        .Where(a => a.StartTime.Year == targetMonth.Year && a.StartTime.Month == targetMonth.Month)
                        .Sum(a => a.Service?.Price ?? 0);

                    monthlyEarnings.Add(new
                    {
                        Month = targetMonth.ToString("yyyy-MM"),
                        MonthName = targetMonth.ToString("MMMM", enCulture),
                        Revenue = sum
                    });
                }

                // Stylist Stats (Leaderboard of bookings)
                var stylistStats = appointments
                    .GroupBy(a => a.StylistId)
                    .Select(g => {
                        var st = g.First().Stylist;
                        return new
                        {
                            StylistId = g.Key,
                            FullName = st?.User?.FullName ?? "Bilinmeyen Usta",
                            Title = st?.Title ?? "Usta Berber",
                            BookingCount = g.Count(),
                            Revenue = g.Sum(a => a.Service?.Price ?? 0)
                        };
                    })
                    .OrderByDescending(s => s.BookingCount)
                    .ToList();

                // Service Stats
                var serviceStats = appointments
                    .GroupBy(a => a.ServiceId)
                    .Select(g => {
                        var svc = g.First().Service;
                        return new
                        {
                            ServiceId = g.Key,
                            Name = svc?.Name ?? "Bilinmeyen Hizmet",
                            BookingCount = g.Count(),
                            Revenue = g.Sum(a => a.Service?.Price ?? 0)
                        };
                    })
                    .OrderByDescending(s => s.BookingCount)
                    .ToList();

                return Ok(new
                {
                    SalonId = stylist.SalonId,
                    SalonName = stylist.Salon?.Name ?? "Bilinmeyen Salon",
                    TotalSalonRevenue = totalSalonRevenue,
                    TotalSalonBookings = totalSalonBookings,
                    PersonalRevenue = personalRevenue,
                    PersonalBookings = personalBookings,
                    PersonalRating = stylist.Rating,
                    DailyEarnings = dailyEarnings,
                    MonthlyEarnings = monthlyEarnings,
                    StylistStats = stylistStats,
                    ServiceStats = serviceStats
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("appointments")]
        public async Task<IActionResult> GetAppointments([FromQuery] string? startDate, [FromQuery] string? endDate)
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);

                var query = _context.Appointments
                    .Where(a => a.StylistId == stylist.Id)
                    .Include(a => a.Service)
                    .Include(a => a.Customer)
                    .AsQueryable();

                if (!string.IsNullOrEmpty(startDate) && DateTime.TryParse(startDate, out var parsedStart))
                {
                    query = query.Where(a => a.StartTime >= parsedStart);
                }

                if (!string.IsNullOrEmpty(endDate) && DateTime.TryParse(endDate, out var parsedEnd))
                {
                    query = query.Where(a => a.StartTime < parsedEnd);
                }

                var appointments = await query
                    .OrderBy(a => a.StartTime)
                    .Select(a => new
                    {
                        a.Id,
                        CustomerName = a.Customer != null ? a.Customer.FullName : "Bilinmeyen Müşteri",
                        CustomerPhone = a.Customer != null ? a.Customer.PhoneNumber : "",
                        ServiceName = a.Service != null ? a.Service.Name : "Bilinmeyen Hizmet",
                        ServiceDuration = a.Service != null ? a.Service.DurationInMinutes : 30,
                        ServicePrice = a.Service != null ? a.Service.Price : 0,
                        StartTime = a.StartTime.ToString("yyyy-MM-dd HH:mm"),
                        EndTime = a.EndTime.ToString("yyyy-MM-dd HH:mm"),
                        a.Status
                    })
                    .ToListAsync();

                return Ok(appointments);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("salon")]
        public async Task<IActionResult> GetSalon()
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var salon = await _context.Salons.FindAsync(stylist.SalonId);
                if (salon == null)
                    return NotFound(new { Message = "Salon not found." });

                // If the salon phone number is the default dummy placeholder, automatically correct it to the user's real phone number
                if (salon.Phone == "+905555555555" || string.IsNullOrWhiteSpace(salon.Phone))
                {
                    var user = await _context.Users.FindAsync(userId);
                    if (user != null && !string.IsNullOrWhiteSpace(user.PhoneNumber))
                    {
                        salon.Phone = user.PhoneNumber;
                        await _context.SaveChangesAsync();
                    }
                }

                return Ok(salon);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("employees")]
        public async Task<IActionResult> GetEmployees()
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                if (!stylist.IsOwner)
                {
                    return Forbid();
                }

                var employees = await _context.Stylists
                    .Where(s => s.SalonId == stylist.SalonId && s.IsActive)
                    .Include(s => s.User)
                    .Select(s => new
                    {
                        s.Id,
                        s.Title,
                        s.Rating,
                        s.IsOwner,
                        FullName = s.User != null ? s.User.FullName : "Unknown Barber",
                        PhoneNumber = s.User != null ? s.User.PhoneNumber : ""
                    })
                    .ToListAsync();

                return Ok(employees);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPost("employees")]
        public async Task<IActionResult> AddEmployee([FromBody] EmployeeCreateModel request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                if (!stylist.IsOwner)
                {
                    return Forbid();
                }

                var user = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == request.PhoneNumber);
                if (user == null)
                {
                    user = new User
                    {
                        PhoneNumber = request.PhoneNumber,
                        FullName = request.FullName,
                        Role = "Barber",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    };
                    _context.Users.Add(user);
                    await _context.SaveChangesAsync();
                }
                else
                {
                    var alreadyStylist = await _context.Stylists.AnyAsync(s => s.UserId == user.Id);
                    if (alreadyStylist)
                    {
                        return BadRequest(new { Message = "This phone number is already registered as an employee in a salon." });
                    }
                    user.Role = "Barber";
                    user.FullName = request.FullName;
                    _context.Entry(user).State = EntityState.Modified;
                }

                var newStylist = new Stylist
                {
                    UserId = user.Id,
                    SalonId = stylist.SalonId,
                    Title = request.Title,
                    Rating = 5.0,
                    IsOwner = false
                };
                _context.Stylists.Add(newStylist);
                await _context.SaveChangesAsync();

                var whList = new List<WorkingHours>();
                for (int day = 1; day <= 6; day++)
                {
                    whList.Add(new WorkingHours
                    {
                        StylistId = newStylist.Id,
                        DayOfWeek = day,
                        StartTime = new TimeSpan(9, 0, 0),
                        EndTime = new TimeSpan(19, 0, 0),
                        LunchStartTime = new TimeSpan(12, 0, 0),
                        LunchEndTime = new TimeSpan(13, 0, 0),
                        IsActive = true
                    });
                }
                whList.Add(new WorkingHours
                {
                    StylistId = newStylist.Id,
                    DayOfWeek = 0,
                    StartTime = new TimeSpan(9, 0, 0),
                    EndTime = new TimeSpan(19, 0, 0),
                    IsActive = false
                });
                _context.WorkingHours.AddRange(whList);

                var salonServices = await _context.Services.Where(s => s.SalonId == stylist.SalonId).ToListAsync();
                foreach (var s in salonServices)
                {
                    _context.StylistServices.Add(new StylistService
                    {
                        StylistId = newStylist.Id,
                        ServiceId = s.Id
                    });
                }

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Employee successfully added.", EmployeeId = newStylist.Id });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpDelete("employees/{id}")]
        public async Task<IActionResult> DeleteEmployee(Guid id)
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                if (!stylist.IsOwner)
                {
                    return Forbid();
                }

                var targetStylist = await _context.Stylists.FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);
                if (targetStylist == null)
                {
                    return NotFound(new { Message = "Employee not found." });
                }

                if (targetStylist.IsOwner)
                {
                    return BadRequest(new { Message = "The salon owner cannot be deleted from the staff." });
                }

                var hasBookings = await _context.Appointments.AnyAsync(a => a.StylistId == id && a.Status != "Cancelled" && a.StartTime >= DateTime.UtcNow.AddHours(3));
                if (hasBookings)
                {
                    return BadRequest(new { Message = "This employee cannot be deleted because they have active future appointments." });
                }

                var hasAnyAppointments = await _context.Appointments.AnyAsync(a => a.StylistId == id);
                if (hasAnyAppointments)
                {
                    // Soft delete: Keep the record for historical reporting, just mark inactive
                    targetStylist.IsActive = false;
                    _context.Entry(targetStylist).State = EntityState.Modified;
                }
                else
                {
                    // Hard delete: Clean up dependent records and remove Stylist entity
                    var whs = await _context.WorkingHours.Where(w => w.StylistId == id).ToListAsync();
                    _context.WorkingHours.RemoveRange(whs);

                    var svcs = await _context.StylistServices.Where(ss => ss.StylistId == id).ToListAsync();
                    _context.StylistServices.RemoveRange(svcs);

                    _context.Stylists.Remove(targetStylist);
                }

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Employee successfully removed from the staff." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("employees/{id}/working-hours")]
        public async Task<IActionResult> GetEmployeeWorkingHours(Guid id)
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var targetStylist = await _context.Stylists.FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);
                if (targetStylist == null)
                {
                    return NotFound(new { Message = "Employee not found." });
                }

                var workingHours = await _context.WorkingHours
                    .Where(w => w.StylistId == id)
                    .OrderBy(w => w.DayOfWeek)
                    .Select(w => new
                    {
                        w.Id,
                        w.DayOfWeek,
                        StartTime = w.StartTime.ToString(@"hh\:mm"),
                        EndTime = w.EndTime.ToString(@"hh\:mm"),
                        LunchStartTime = w.LunchStartTime.HasValue ? w.LunchStartTime.Value.ToString(@"hh\:mm") : null,
                        LunchEndTime = w.LunchEndTime.HasValue ? w.LunchEndTime.Value.ToString(@"hh\:mm") : null,
                        w.IsActive
                    })
                    .ToListAsync();

                return Ok(workingHours);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPut("employees/{id}/working-hours")]
        public async Task<IActionResult> UpdateEmployeeWorkingHours(Guid id, [FromBody] List<WorkingHoursUpdateModel> request)
        {
            if (request == null || !request.Any())
                return BadRequest(new { Message = "Request cannot be empty." });

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                if (!stylist.IsOwner && stylist.Id != id)
                {
                    return Forbid();
                }

                var targetStylist = await _context.Stylists.FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);
                if (targetStylist == null)
                {
                    return NotFound(new { Message = "Employee not found." });
                }

                foreach (var item in request)
                {
                    var wh = await _context.WorkingHours
                        .FirstOrDefaultAsync(w => w.StylistId == id && w.DayOfWeek == item.DayOfWeek);

                    if (wh != null)
                    {
                        wh.StartTime = TimeSpan.Parse(item.StartTime);
                        wh.EndTime = TimeSpan.Parse(item.EndTime);
                        wh.LunchStartTime = !string.IsNullOrEmpty(item.LunchStartTime) ? TimeSpan.Parse(item.LunchStartTime) : null;
                        wh.LunchEndTime = !string.IsNullOrEmpty(item.LunchEndTime) ? TimeSpan.Parse(item.LunchEndTime) : null;
                        wh.IsActive = item.IsActive;
                    }
                }

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Working hours successfully updated." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = $"Update failed: {ex.Message}" });
            }
        }

        [HttpGet("employees/{id}/services")]
        public async Task<IActionResult> GetEmployeeServices(Guid id)
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var targetStylist = await _context.Stylists.FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);
                if (targetStylist == null)
                {
                    return NotFound(new { Message = "Employee not found." });
                }

                var assignedServiceIds = await _context.StylistServices
                    .Where(ss => ss.StylistId == id)
                    .Select(ss => ss.ServiceId)
                    .ToListAsync();

                return Ok(assignedServiceIds);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPut("employees/{id}/services")]
        public async Task<IActionResult> UpdateEmployeeServices(Guid id, [FromBody] List<Guid> serviceIds)
        {
            if (serviceIds == null || serviceIds.Count == 0)
            {
                return BadRequest(new { Message = "At least one service must be selected for the barber." });
            }

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                if (!stylist.IsOwner)
                {
                    return Forbid();
                }

                var targetStylist = await _context.Stylists.FirstOrDefaultAsync(s => s.Id == id && s.SalonId == stylist.SalonId);
                if (targetStylist == null)
                {
                    return NotFound(new { Message = "Employee not found." });
                }

                var existing = await _context.StylistServices.Where(ss => ss.StylistId == id).ToListAsync();
                _context.StylistServices.RemoveRange(existing);

                foreach (var svcId in serviceIds)
                {
                    var serviceExists = await _context.Services.AnyAsync(s => s.Id == svcId && s.SalonId == stylist.SalonId);
                    if (serviceExists)
                    {
                        _context.StylistServices.Add(new StylistService
                        {
                            StylistId = id,
                            ServiceId = svcId
                        });
                    }
                }

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Service authorizations successfully updated." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("salon-appointments")]
        public async Task<IActionResult> GetSalonAppointments([FromQuery] string date)
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                if (!DateTime.TryParse(date, out var parsedDate))
                {
                    return BadRequest(new { Message = "Invalid date format." });
                }

                var startOfDay = parsedDate.Date;
                var endOfDay = startOfDay.AddDays(1);

                var appointments = await _context.Appointments
                    .Where(a => a.Stylist!.SalonId == stylist.SalonId &&
                                a.StartTime >= startOfDay &&
                                a.StartTime < endOfDay &&
                                a.Status != "Cancelled")
                    .Include(a => a.Service)
                    .Include(a => a.Customer)
                    .Include(a => a.Stylist)
                        .ThenInclude(s => s!.User)
                    .OrderBy(a => a.StartTime)
                    .Select(a => new
                    {
                        a.Id,
                        a.StylistId,
                        StylistName = a.Stylist!.User != null ? a.Stylist.User.FullName : "Unknown Barber",
                        CustomerName = a.Customer != null ? a.Customer.FullName : (a.GuestName ?? "Walk-in Booking"),
                        CustomerPhone = a.Customer != null ? a.Customer.PhoneNumber : (a.GuestPhone ?? ""),
                        ServiceName = a.Service != null ? a.Service.Name : "Unknown Service",
                        ServiceDuration = a.Service != null ? a.Service.DurationInMinutes : 30,
                        ServicePrice = a.Service != null ? a.Service.Price : 0,
                        StartTime = a.StartTime.ToString("yyyy-MM-dd HH:mm"),
                        EndTime = a.EndTime.ToString("yyyy-MM-dd HH:mm"),
                        a.Status
                    })
                    .ToListAsync();

                return Ok(appointments);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPost("walk-in")]
        public async Task<IActionResult> CreateWalkIn([FromBody] WalkInCreateModel request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var targetStylist = await _context.Stylists.FindAsync(request.StylistId);
                if (targetStylist == null || targetStylist.SalonId != stylist.SalonId)
                {
                    return BadRequest(new { Message = "Invalid employee." });
                }

                var service = await _context.Services.FindAsync(request.ServiceId);
                if (service == null || service.SalonId != stylist.SalonId)
                {
                    return BadRequest(new { Message = "Invalid service." });
                }

                if (!DateTime.TryParse(request.StartTime, out var parsedStartTime))
                {
                    return BadRequest(new { Message = "Invalid start time." });
                }

                var endTime = parsedStartTime.AddMinutes(service.DurationInMinutes);

                var hasConflict = await _context.Appointments.AnyAsync(a =>
                    a.StylistId == request.StylistId &&
                    a.Status != "Cancelled" &&
                    a.StartTime < endTime &&
                    a.EndTime > parsedStartTime);

                if (hasConflict)
                {
                    return BadRequest(new { Message = "The employee already has another booking in this time slot." });
                }

                var newApp = new Appointment
                {
                    CustomerId = null,
                    StylistId = request.StylistId,
                    ServiceId = request.ServiceId,
                    StartTime = parsedStartTime,
                    EndTime = endTime,
                    Status = "Confirmed",
                    GuestName = request.GuestName,
                    GuestPhone = request.GuestPhone
                };

                _context.Appointments.Add(newApp);
                await _context.SaveChangesAsync();

                return Ok(new { Message = "Walk-in appointment successfully added.", Appointment = newApp });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpGet("reviews")]
        public async Task<IActionResult> GetReviews()
        {
            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var reviews = await _context.Reviews
                    .Include(r => r.Customer)
                    .Include(r => r.Appointment)
                        .ThenInclude(a => a!.Service)
                    .Include(r => r.Appointment)
                        .ThenInclude(a => a!.Stylist)
                            .ThenInclude(s => s!.User)
                    .Where(r => r.Appointment!.Stylist!.SalonId == stylist.SalonId)
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

                return Ok(reviews);
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPost("upload")]
        public async Task<IActionResult> UploadImage(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { Message = "Invalid file." });

            try
            {
                var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
                if (!Directory.Exists(uploadsFolder))
                {
                    Directory.CreateDirectory(uploadsFolder);
                }

                var fileName = Guid.NewGuid().ToString() + Path.GetExtension(file.FileName);
                var filePath = Path.Combine(uploadsFolder, fileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                var fileUrl = $"/uploads/{fileName}";
                return Ok(new { Url = fileUrl });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = $"Upload error: {ex.Message}" });
            }
        }

        [HttpGet("reverse-geocode")]
        public async Task<IActionResult> ReverseGeocode([FromQuery] double latitude, [FromQuery] double longitude)
        {
            try
            {
                string address = await ReverseGeocodeAsync(latitude, longitude);
                return Ok(new { Address = address });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        [HttpPut("salon")]
        public async Task<IActionResult> UpdateSalon([FromBody] SalonUpdateModel request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var userId = GetUserId();
                var stylist = await GetOrCreateStylistAsync(userId);
                
                var salon = await _context.Salons.FindAsync(stylist.SalonId);
                if (salon == null)
                    return NotFound(new { Message = "Salon not found." });

                if (!stylist.IsOwner)
                {
                    return Forbid();
                }

                // Use the client-provided address, or fallback to reverse geocoding if empty
                string? address = request.Address;
                if (string.IsNullOrEmpty(address))
                {
                    address = await ReverseGeocodeAsync(request.Latitude, request.Longitude);
                }

                salon.Name = request.Name;
                salon.Address = address;
                salon.Phone = request.Phone;
                salon.Latitude = request.Latitude;
                salon.Longitude = request.Longitude;
                if (!string.IsNullOrEmpty(request.ImageUrl))
                {
                    salon.ImageUrl = request.ImageUrl;
                }

                await _context.SaveChangesAsync();
                return Ok(new { Message = "Salon information successfully updated.", Salon = salon });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        private async Task<string> ReverseGeocodeAsync(double lat, double lng)
        {
            string? googleApiKey = _config["GooglePlaces:ApiKey"];
            if (!string.IsNullOrEmpty(googleApiKey) && !googleApiKey.Contains("YOUR_GOOGLE_MAPS_API_KEY_HERE"))
            {
                try
                {
                    using var client = new HttpClient();
                    var url = $"https://maps.googleapis.com/maps/api/geocode/json?latlng={lat},{lng}&key={googleApiKey}";
                    var response = await client.GetAsync(url);
                    if (response.IsSuccessStatusCode)
                    {
                        var jsonString = await response.Content.ReadAsStringAsync();
                        using var doc = JsonDocument.Parse(jsonString);
                        if (doc.RootElement.TryGetProperty("results", out var results) && results.ValueKind == JsonValueKind.Array && results.GetArrayLength() > 0)
                        {
                            return results[0].GetProperty("formatted_address").GetString() ?? "Bilinmeyen Adres";
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[REVERSE GEOCODING ERROR] Google Reverse Geocoding failed: {ex.Message}");
                }
            }

            // Fallback to OpenStreetMap Nominatim
            try
            {
                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("User-Agent", "BerberSalonuApp/1.0 (contact@berbersalonuapp.com)");
                
                var url = $"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lng}&format=json";
                var response = await client.GetAsync(url);
                if (response.IsSuccessStatusCode)
                {
                    var jsonString = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(jsonString);
                    if (doc.RootElement.TryGetProperty("display_name", out var displayNameProp))
                    {
                        return displayNameProp.GetString() ?? "Bilinmeyen Adres";
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[REVERSE GEOCODING ERROR] Nominatim failed: {ex.Message}");
            }

            return $"İstanbul (Koordinat: {lat:F4}, {lng:F4})";
        }

        private async Task<(double Lat, double Lng)> GeocodeAddressAsync(string address)
        {
            string? googleApiKey = _config["GooglePlaces:ApiKey"];
            if (!string.IsNullOrEmpty(googleApiKey) && !googleApiKey.Contains("YOUR_GOOGLE_MAPS_API_KEY_HERE"))
            {
                try
                {
                    using var client = new HttpClient();
                    var url = $"https://maps.googleapis.com/maps/api/geocode/json?address={Uri.EscapeDataString(address)}&key={googleApiKey}";
                    var response = await client.GetAsync(url);
                    if (response.IsSuccessStatusCode)
                    {
                        var jsonString = await response.Content.ReadAsStringAsync();
                        using var doc = JsonDocument.Parse(jsonString);
                        if (doc.RootElement.TryGetProperty("results", out var results) && results.ValueKind == JsonValueKind.Array && results.GetArrayLength() > 0)
                        {
                            var location = results[0].GetProperty("geometry").GetProperty("location");
                            double lat = location.GetProperty("lat").GetDouble();
                            double lng = location.GetProperty("lng").GetDouble();
                            return (lat, lng);
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[GEOCODING ERROR] Google Geocoding failed: {ex.Message}");
                }
            }

            // Fallback to OpenStreetMap Nominatim
            try
            {
                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("User-Agent", "BerberSalonuApp/1.0 (contact@berbersalonuapp.com)");
                
                var url = $"https://nominatim.openstreetmap.org/search?q={Uri.EscapeDataString(address)}&format=json&limit=1";
                var response = await client.GetAsync(url);
                if (response.IsSuccessStatusCode)
                {
                    var jsonString = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(jsonString);
                    if (doc.RootElement.ValueKind == JsonValueKind.Array && doc.RootElement.GetArrayLength() > 0)
                    {
                        var first = doc.RootElement[0];
                        if (first.TryGetProperty("lat", out var latProp) && first.TryGetProperty("lon", out var lonProp))
                        {
                            double lat = double.Parse(latProp.GetString() ?? "0", System.Globalization.CultureInfo.InvariantCulture);
                            double lng = double.Parse(lonProp.GetString() ?? "0", System.Globalization.CultureInfo.InvariantCulture);
                            return (lat, lng);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GEOCODING ERROR] Nominatim failed: {ex.Message}");
            }

            // Fallback to central Istanbul coordinates if geocoding fails completely
            return (41.0082, 28.9784);
        }
    }

    public class SalonUpdateModel
    {
        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Required]
        public double Latitude { get; set; }

        [Required]
        public double Longitude { get; set; }

        [Required]
        [MaxLength(50)]
        public string Phone { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? ImageUrl { get; set; }

        [MaxLength(500)]
        public string? Address { get; set; }
    }

    public class WorkingHoursUpdateModel
    {
        [Required]
        public int DayOfWeek { get; set; }
        [Required]
        public string StartTime { get; set; } = "09:00";
        [Required]
        public string EndTime { get; set; } = "19:00";
        public string? LunchStartTime { get; set; } = "12:00";
        public string? LunchEndTime { get; set; } = "13:00";
        [Required]
        public bool IsActive { get; set; } = true;
    }

    public class ServiceCreateModel
    {
        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [Range(5, 480, ErrorMessage = "Duration must be between 5 and 480 minutes.")]
        public int DurationInMinutes { get; set; }

        [Required]
        [Range(0, 100000, ErrorMessage = "Price must be between 0 and 100000.")]
        public decimal Price { get; set; }
    }

    public class EmployeeCreateModel
    {
        [Required]
        [MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        [Required]
        [Phone]
        public string PhoneNumber { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string Title { get; set; } = string.Empty;
    }

    public class WalkInCreateModel
    {
        [Required]
        public Guid StylistId { get; set; }
        [Required]
        public Guid ServiceId { get; set; }
        [Required]
        public string StartTime { get; set; } = string.Empty;
        [Required]
        [MaxLength(100)]
        public string GuestName { get; set; } = string.Empty;
        [MaxLength(50)]
        public string? GuestPhone { get; set; }
    }
}
