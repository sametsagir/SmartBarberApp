using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;

namespace BerberSalonu.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class BookingController : ControllerBase
    {
        private readonly AppDbContext _context;

        public BookingController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/booking/available-slots
        [HttpGet("available-slots")]
        public async Task<IActionResult> GetAvailableSlots(
            [FromQuery] Guid stylistId,
            [FromQuery] DateTime date,
            [FromQuery] Guid serviceId)
        {
            var stylist = await _context.Stylists.FindAsync(stylistId);
            if (stylist == null)
            {
                return NotFound(new { Message = "Stylist not found." });
            }

            var service = await _context.Services.FindAsync(serviceId);
            if (service == null)
            {
                return NotFound(new { Message = "Service not found." });
            }

            // Find working hours for this stylist on this day of week
            // C# DayOfWeek: 0 = Sunday, 1 = Monday, ..., 6 = Saturday
            int dayOfWeek = (int)date.DayOfWeek;
            var workingHours = await _context.WorkingHours
                .FirstOrDefaultAsync(w => w.StylistId == stylistId && w.DayOfWeek == dayOfWeek && w.IsActive);

            if (workingHours == null)
            {
                // Off-day or no shift configured
                return Ok(new List<string>());
            }

            // Get existing appointments for the stylist on this date range (excluding cancelled ones)
            var startOfDay = date.Date;
            var endOfRange = startOfDay.AddDays(2); // load 48 hours to cover shifts crossing midnight
            var appointments = await _context.Appointments
                .Where(a => a.StylistId == stylistId && a.StartTime >= startOfDay && a.StartTime < endOfRange && a.Status != "Cancelled")
                .ToListAsync();

            var availableSlots = new List<string>();
            var startShift = workingHours.StartTime;
            var endShift = workingHours.EndTime;
            var lunchStart = workingHours.LunchStartTime;
            var lunchEnd = workingHours.LunchEndTime;

            var serviceDuration = TimeSpan.FromMinutes(service.DurationInMinutes);

            var startDateTime = date.Date.Add(startShift);
            var endDateTime = date.Date.Add(endShift);
            if (endShift <= startShift)
            {
                endDateTime = endDateTime.AddDays(1);
            }

            var lunchStartDateTime = lunchStart.HasValue ? date.Date.Add(lunchStart.Value) : (DateTime?)null;
            var lunchEndDateTime = lunchEnd.HasValue ? date.Date.Add(lunchEnd.Value) : (DateTime?)null;
            if (lunchStart.HasValue && lunchEnd.HasValue && lunchStart.Value < startShift)
            {
                lunchStartDateTime = lunchStartDateTime!.Value.AddDays(1);
                lunchEndDateTime = lunchEndDateTime!.Value.AddDays(1);
            }
            
            // Generate slots every 30 minutes
            var currentSlotStart = startDateTime;
            var nowTurkey = DateTime.UtcNow.AddHours(3);

            while (currentSlotStart + serviceDuration <= endDateTime)
            {
                var currentSlotEnd = currentSlotStart + serviceDuration;

                // Check if this slot is in the past for selected date (Turkey Time)
                if (currentSlotStart <= nowTurkey)
                {
                    currentSlotStart = currentSlotStart.AddMinutes(30);
                    continue;
                }

                // 1. Check Lunch Break Overlap
                bool overlapsLunch = false;
                if (lunchStartDateTime.HasValue && lunchEndDateTime.HasValue)
                {
                    if (currentSlotStart < lunchEndDateTime.Value && currentSlotEnd > lunchStartDateTime.Value)
                    {
                        overlapsLunch = true;
                    }
                }

                // 2. Check Existing Appointments Overlap
                bool overlapsAppointment = false;
                if (!overlapsLunch)
                {
                    foreach (var app in appointments)
                    {
                        if (currentSlotStart < app.EndTime && currentSlotEnd > app.StartTime)
                        {
                            overlapsAppointment = true;
                            break;
                        }
                    }
                }

                if (!overlapsLunch && !overlapsAppointment)
                {
                    availableSlots.Add(currentSlotStart.ToString("HH:mm"));
                }

                // Step forward by 30 minutes
                currentSlotStart = currentSlotStart.AddMinutes(30);
            }

            return Ok(availableSlots);
        }

        // POST: api/booking/create
        [HttpPost("create")]
        public async Task<IActionResult> CreateAppointment([FromBody] CreateAppointmentRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var stylist = await _context.Stylists.FindAsync(request.StylistId);
            if (stylist == null)
            {
                return BadRequest(new { Message = "Stylist not found." });
            }

            var service = await _context.Services.FindAsync(request.ServiceId);
            if (service == null)
            {
                return BadRequest(new { Message = "Service not found." });
            }

            // Parse time slot and combine with appointment date
            if (!TimeSpan.TryParse(request.TimeSlot, out var parsedTime))
            {
                return BadRequest(new { Message = "Invalid time format." });
            }

            var localStartTime = request.AppointmentDate.Date.Add(parsedTime);

            // Handle shifts crossing midnight
            var dayOfWeek = (int)request.AppointmentDate.DayOfWeek;
            var workingHours = await _context.WorkingHours.FirstOrDefaultAsync(w => w.StylistId == request.StylistId && w.DayOfWeek == dayOfWeek);
            if (workingHours != null && parsedTime < workingHours.StartTime)
            {
                localStartTime = localStartTime.AddDays(1);
            }

            var localEndTime = localStartTime.AddMinutes(service.DurationInMinutes);

            // Double Booking Prevention Check
            var hasConflict = await _context.Appointments.AnyAsync(a =>
                a.StylistId == request.StylistId &&
                a.Status != "Cancelled" &&
                a.StartTime < localEndTime &&
                a.EndTime > localStartTime);

            if (hasConflict)
            {
                return BadRequest(new { Message = "The selected time slot is already booked. Please choose another slot." });
            }

            var customer = await _context.Users.FindAsync(request.CustomerId);
            if (customer == null)
            {
                return BadRequest(new { Message = "Customer not found." });
            }


            var appointment = new Appointment
            {
                CustomerId = request.CustomerId,
                StylistId = request.StylistId,
                ServiceId = request.ServiceId,
                StartTime = localStartTime,
                EndTime = localEndTime,
                Status = "Pending" // Starts as Pending, requires stylist confirmation
            };

            _context.Appointments.Add(appointment);
            await _context.SaveChangesAsync();

            // Simulate SMS & Push notification on creation
            try
            {
                var customerName = customer?.FullName ?? "Müşteri";
                var customerPhone = customer?.PhoneNumber ?? "Bilinmiyor";
                var stylistEntity = await _context.Stylists.Include(s => s.User).FirstOrDefaultAsync(s => s.Id == appointment.StylistId);
                var stylistName = stylistEntity?.User?.FullName ?? "Usta";
                var serviceName = service.Name;

                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("========================================= SIMULATED NOTIFICATION =========================================");
                Console.WriteLine($"[NOTIFICATION SIMULATOR] 📱 RANDEVU ONAYLANDI!");
                Console.WriteLine($"Müşteriye Gönderilen (SMS) -> Alıcı: {customerPhone} ({customerName})");
                Console.WriteLine($"  İçerik: Sayın {customerName}, {serviceName} randevunuz onaylandı. Tarih: {localStartTime:yyyy-MM-dd HH:mm}.");
                Console.WriteLine($"Ustaya Gönderilen (Push Notification) -> Alıcı: {stylistName}");
                Console.WriteLine($"  İçerik: Sayın {stylistName}, {customerName} ile olan {serviceName} randevunuz onaylandı. Tarih: {localStartTime:yyyy-MM-dd HH:mm}.");
                Console.WriteLine("========================================================================================================");
                Console.ResetColor();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Notification simulator error: {ex.Message}");
            }

            return Ok(new
            {
                Message = "Appointment created successfully.",
                Appointment = new
                {
                    appointment.Id,
                    appointment.CustomerId,
                    appointment.StylistId,
                    appointment.ServiceId,
                    StartTime = appointment.StartTime.ToString("yyyy-MM-dd HH:mm"),
                    EndTime = appointment.EndTime.ToString("yyyy-MM-dd HH:mm"),
                    appointment.Status
                }
            });
        }

        // GET: api/booking/customer/{customerId}
        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> GetCustomerAppointments(Guid customerId)
        {
            var appointments = await _context.Appointments
                .Where(a => a.CustomerId == customerId)
                .Include(a => a.Service)
                .Include(a => a.Stylist)
                    .ThenInclude(s => s!.User)
                .Include(a => a.Stylist)
                    .ThenInclude(s => s!.Salon)
                .OrderByDescending(a => a.StartTime)
                .ToListAsync();

            var now = DateTime.UtcNow.AddHours(3);

            var reviewedAppointmentIds = await _context.Reviews
                .Where(r => r.CustomerId == customerId)
                .Select(r => r.AppointmentId)
                .ToListAsync();

            var result = appointments.Select(a => {
                var isPast = a.EndTime < now;
                var isCancelAllowed = a.Status != "Cancelled" && !isPast && (a.StartTime - now).TotalHours >= 2;
                var isRescheduleAllowed = a.Status != "Cancelled" && !isPast && (a.StartTime - now).TotalHours >= 2;
                var isRated = reviewedAppointmentIds.Contains(a.Id);

                int? userRating = null;
                string? userComment = null;
                if (isRated)
                {
                    var reviewObj = _context.Reviews.FirstOrDefault(r => r.AppointmentId == a.Id);
                    userRating = reviewObj?.Rating;
                    userComment = reviewObj?.Comment;
                }

                return new
                {
                    a.Id,
                    a.CustomerId,
                    a.StylistId,
                    StylistName = a.Stylist?.User?.FullName ?? "Unknown Stylist",
                    StylistTitle = a.Stylist?.Title ?? "Barber",
                    SalonId = a.Stylist?.SalonId,
                    SalonName = a.Stylist?.Salon?.Name ?? "Unknown Salon",
                    a.ServiceId,
                    ServiceName = a.Service?.Name ?? "Unknown Service",
                    ServicePrice = a.Service?.Price ?? 0,
                    ServiceDurationInMinutes = a.Service?.DurationInMinutes ?? 30,
                    StartTime = a.StartTime.ToString("yyyy-MM-dd HH:mm"),
                    EndTime = a.EndTime.ToString("yyyy-MM-dd HH:mm"),
                    a.Status,
                    IsPast = isPast,
                    IsCancelAllowed = isCancelAllowed,
                    IsRescheduleAllowed = isRescheduleAllowed,
                    IsRated = isRated,
                    Rating = userRating,
                    Comment = userComment
                };
            });

            return Ok(result);
        }

        // POST: api/booking/cancel/{appointmentId}
        [HttpPost("cancel/{appointmentId}")]
        public async Task<IActionResult> CancelAppointment(Guid appointmentId)
        {
            var appointment = await _context.Appointments.FindAsync(appointmentId);
            if (appointment == null)
            {
                return NotFound(new { Message = "Appointment not found." });
            }

            if (appointment.Status == "Cancelled")
            {
                return BadRequest(new { Message = "This appointment is already cancelled." });
            }

            var now = DateTime.UtcNow.AddHours(3);
            if (appointment.StartTime < now)
            {
                return BadRequest(new { Message = "A past appointment cannot be cancelled." });
            }

            if ((appointment.StartTime - now).TotalHours < 2)
            {
                return BadRequest(new { Message = "Appointments cannot be cancelled within 2 hours of the start time." });
            }

            var customer = await _context.Users.FindAsync(appointment.CustomerId);

            appointment.Status = "Cancelled";
            await _context.SaveChangesAsync();

            // Simulate SMS & Push notification on cancellation
            try
            {
                var customerName = customer?.FullName ?? "Müşteri";
                var customerPhone = customer?.PhoneNumber ?? "Bilinmiyor";
                var stylistUser = await _context.Stylists.Include(s => s.User).FirstOrDefaultAsync(s => s.Id == appointment.StylistId);
                var stylistName = stylistUser?.User?.FullName ?? "Usta";
                var service = await _context.Services.FindAsync(appointment.ServiceId);
                var serviceName = service?.Name ?? "Hizmet";

                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("========================================= SIMULATED NOTIFICATION =========================================");
                Console.WriteLine($"[NOTIFICATION SIMULATOR] ❌ RANDEVU İPTAL EDİLDİ!");
                Console.WriteLine($"Müşteriye Gönderilen (SMS) -> Alıcı: {customerPhone} ({customerName})");
                Console.WriteLine($"  İçerik: Sayın {customerName}, {serviceName} randevunuz iptal edilmiştir.");
                Console.WriteLine($"Ustaya Gönderilen (Push Notification) -> Alıcı: {stylistName}");
                Console.WriteLine($"  İçerik: Sayın {stylistName}, {customerName} ile olan {serviceName} randevunuz iptal edilmiştir.");

                Console.WriteLine("========================================================================================================");
                Console.ResetColor();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Notification simulator error: {ex.Message}");
            }

            return Ok(new { Message = "Your appointment was successfully cancelled." });
        }

        // POST: api/booking/reschedule
        [HttpPost("reschedule")]
        public async Task<IActionResult> RescheduleAppointment([FromBody] RescheduleAppointmentRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var appointment = await _context.Appointments
                .Include(a => a.Service)
                .FirstOrDefaultAsync(a => a.Id == request.AppointmentId);

            if (appointment == null)
            {
                return NotFound(new { Message = "Appointment not found." });
            }

            if (appointment.Status == "Cancelled")
            {
                return BadRequest(new { Message = "A cancelled appointment cannot be updated." });
            }

            var now = DateTime.UtcNow.AddHours(3);
            if (appointment.StartTime < now)
            {
                return BadRequest(new { Message = "A past appointment cannot be updated." });
            }

            if ((appointment.StartTime - now).TotalHours < 2)
            {
                return BadRequest(new { Message = "Appointments cannot be updated within 2 hours of the start time." });
            }

            if (!TimeSpan.TryParse(request.NewTimeSlot, out var parsedTime))
            {
                return BadRequest(new { Message = "Invalid time format." });
            }

            var newStartTime = request.NewDate.Date.Add(parsedTime);

            // Handle shifts crossing midnight
            var dayOfWeek = (int)request.NewDate.DayOfWeek;
            var workingHours = await _context.WorkingHours.FirstOrDefaultAsync(w => w.StylistId == appointment.StylistId && w.DayOfWeek == dayOfWeek);
            if (workingHours != null && parsedTime < workingHours.StartTime)
            {
                newStartTime = newStartTime.AddDays(1);
            }

            var newEndTime = newStartTime.AddMinutes(appointment.Service!.DurationInMinutes);

            var hasConflict = await _context.Appointments.AnyAsync(a =>
                a.Id != request.AppointmentId &&
                a.StylistId == appointment.StylistId &&
                a.Status != "Cancelled" &&
                a.StartTime < newEndTime &&
                a.EndTime > newStartTime);

            if (hasConflict)
            {
                return BadRequest(new { Message = "The selected new time slot is already booked. Please choose another slot." });
            }

            appointment.StartTime = newStartTime;
            appointment.EndTime = newEndTime;
            appointment.Status = "Confirmed";

            await _context.SaveChangesAsync();

            // Simulate SMS & Push notification on rescheduling
            try
            {
                var customer = await _context.Users.FindAsync(appointment.CustomerId);
                var customerName = customer?.FullName ?? "Müşteri";
                var customerPhone = customer?.PhoneNumber ?? "Bilinmiyor";
                var stylistUser = await _context.Stylists.Include(s => s.User).FirstOrDefaultAsync(s => s.Id == appointment.StylistId);
                var stylistName = stylistUser?.User?.FullName ?? "Usta";
                var serviceName = appointment.Service?.Name ?? "Hizmet";

                Console.ForegroundColor = ConsoleColor.Magenta;
                Console.WriteLine("========================================= SIMULATED NOTIFICATION =========================================");
                Console.WriteLine($"[NOTIFICATION SIMULATOR] 🔄 RANDEVU ERTELENDİ!");
                Console.WriteLine($"Müşteriye Gönderilen (SMS) -> Alıcı: {customerPhone} ({customerName})");
                Console.WriteLine($"  İçerik: Sayın {customerName}, {serviceName} randevunuz ertelenmiştir. Yeni Tarih: {newStartTime:yyyy-MM-dd HH:mm}.");
                Console.WriteLine($"Ustaya Gönderilen (Push Notification) -> Alıcı: {stylistName}");
                Console.WriteLine($"  İçerik: Sayın {stylistName}, {customerName} ile olan {serviceName} randevunuz ertelenmiştir. Yeni Tarih: {newStartTime:yyyy-MM-dd HH:mm}.");
                Console.WriteLine("========================================================================================================");
                Console.ResetColor();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Notification simulator error: {ex.Message}");
            }

            return Ok(new { Message = "Appointment time successfully updated." });
        }

        // POST: api/booking/review
        [HttpPost("review")]
        public async Task<IActionResult> CreateReview([FromBody] CreateReviewRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var appointment = await _context.Appointments
                .Include(a => a.Stylist)
                .FirstOrDefaultAsync(a => a.Id == request.AppointmentId);

            if (appointment == null)
            {
                return NotFound(new { Message = "Appointment not found." });
            }

            if (appointment.CustomerId != request.CustomerId)
            {
                return BadRequest(new { Message = "This appointment is not registered under your name." });
            }

            if (appointment.Status == "Cancelled")
            {
                return BadRequest(new { Message = "Cancelled appointments cannot be rated." });
            }

            var now = DateTime.Now;
            if (appointment.StartTime >= now)
            {
                return BadRequest(new { Message = "Future appointments cannot be rated yet." });
            }

            var alreadyReviewed = await _context.Reviews.AnyAsync(r => r.AppointmentId == request.AppointmentId);
            if (alreadyReviewed)
            {
                return BadRequest(new { Message = "A review has already been written for this appointment." });
            }

            var review = new Review
            {
                AppointmentId = request.AppointmentId,
                CustomerId = request.CustomerId,
                Rating = request.Rating,
                Comment = request.Comment,
                CreatedAt = now
            };

            _context.Reviews.Add(review);
            await _context.SaveChangesAsync();

            var stylistReviews = await _context.Reviews
                .Where(r => r.Appointment!.StylistId == appointment.StylistId)
                .Select(r => r.Rating)
                .ToListAsync();
            double avgStylist = stylistReviews.Any() ? stylistReviews.Average() : 5.0;
            
            var stylist = await _context.Stylists.FindAsync(appointment.StylistId);
            if (stylist != null)
            {
                stylist.Rating = Math.Round(avgStylist, 1);
            }

            var salonReviews = await _context.Reviews
                .Where(r => r.Appointment!.Stylist!.SalonId == appointment.Stylist!.SalonId)
                .Select(r => r.Rating)
                .ToListAsync();
            double avgSalon = salonReviews.Any() ? salonReviews.Average() : 5.0;

            var salon = await _context.Salons.FindAsync(appointment.Stylist!.SalonId);
            if (salon != null)
            {
                salon.Rating = Math.Round(avgSalon, 1);
            }

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Your review was successfully saved." });
        }

        // POST: api/booking/confirm/{appointmentId}
        [HttpPost("confirm/{appointmentId}")]
        public async Task<IActionResult> ConfirmAppointment(Guid appointmentId)
        {
            var appointment = await _context.Appointments.FindAsync(appointmentId);
            if (appointment == null)
            {
                return NotFound(new { Message = "Appointment not found." });
            }

            if (appointment.Status != "Pending")
            {
                return BadRequest(new { Message = "Only pending appointments can be confirmed." });
            }

            appointment.Status = "Confirmed";
            await _context.SaveChangesAsync();

            // Simulate SMS & Push notification on confirmation
            try
            {
                var customer = await _context.Users.FindAsync(appointment.CustomerId);
                var customerName = customer?.FullName ?? "Müşteri";
                var customerPhone = customer?.PhoneNumber ?? "Bilinmiyor";
                var service = await _context.Services.FindAsync(appointment.ServiceId);
                var serviceName = service?.Name ?? "Hizmet";

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("========================================= SIMULATED NOTIFICATION =========================================");
                Console.WriteLine($"[NOTIFICATION SIMULATOR] ✅ RANDEVU ONAYLANDI!");
                Console.WriteLine($"Müşteriye Gönderilen (SMS) -> Alıcı: {customerPhone} ({customerName})");
                Console.WriteLine($"  İçerik: Sayın {customerName}, {serviceName} randevunuz usta tarafından onaylandı. Saat: {appointment.StartTime:yyyy-MM-dd HH:mm}.");
                Console.WriteLine("========================================================================================================");
                Console.ResetColor();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Notification simulator error: {ex.Message}");
            }

            return Ok(new { Message = "Appointment successfully confirmed." });
        }

        // POST: api/booking/reject/{appointmentId}
        [HttpPost("reject/{appointmentId}")]
        public async Task<IActionResult> RejectAppointment(Guid appointmentId)
        {
            var appointment = await _context.Appointments.FindAsync(appointmentId);
            if (appointment == null)
            {
                return NotFound(new { Message = "Appointment not found." });
            }

            if (appointment.Status != "Pending" && appointment.Status != "Confirmed")
            {
                return BadRequest(new { Message = "This appointment cannot be rejected or is already cancelled." });
            }

            var customer = await _context.Users.FindAsync(appointment.CustomerId);

            appointment.Status = "Cancelled";
            await _context.SaveChangesAsync();

            // Simulate SMS & Push notification on rejection
            try
            {
                var customerName = customer?.FullName ?? "Müşteri";
                var customerPhone = customer?.PhoneNumber ?? "Bilinmiyor";
                var service = await _context.Services.FindAsync(appointment.ServiceId);
                var serviceName = service?.Name ?? "Hizmet";

                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("========================================= SIMULATED NOTIFICATION =========================================");
                Console.WriteLine($"[NOTIFICATION SIMULATOR] ❌ RANDEVU REDDEDİLDİ!");
                Console.WriteLine($"Müşteriye Gönderilen (SMS) -> Alıcı: {customerPhone} ({customerName})");
                Console.WriteLine($"  İçerik: Sayın {customerName}, {serviceName} randevunuz usta tarafından reddedildi.");
                Console.WriteLine("========================================================================================================");
                Console.ResetColor();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Notification simulator error: {ex.Message}");
            }

            return Ok(new { Message = "Appointment successfully rejected and deposit refunded." });
        }

        // POST: api/booking/create-test-appointments
        [HttpPost("create-test-appointments")]
        public async Task<IActionResult> CreateTestAppointments([FromBody] CreateTestRequest request)
        {
            var customer = await _context.Users.FindAsync(request.CustomerId);
            if (customer == null)
            {
                return NotFound(new { Message = "Customer not found." });
            }

            var stylist = await _context.Stylists.FirstOrDefaultAsync();
            var service = await _context.Services.FirstOrDefaultAsync();
            if (stylist == null || service == null)
            {
                return BadRequest(new { Message = "No stylist or service found for test data." });
            }

            var now = DateTime.Now;

            var tomorrow = DateTime.Today.AddDays(1);
            var app1 = new Appointment
            {
                CustomerId = request.CustomerId,
                StylistId = stylist.Id,
                ServiceId = service.Id,
                StartTime = tomorrow.AddHours(14),
                EndTime = tomorrow.AddHours(14).AddMinutes(service.DurationInMinutes),
                Status = "Confirmed"
            };

            var app2 = new Appointment
            {
                CustomerId = request.CustomerId,
                StylistId = stylist.Id,
                ServiceId = service.Id,
                StartTime = now.AddHours(1),
                EndTime = now.AddHours(1).AddMinutes(service.DurationInMinutes),
                Status = "Pending"
            };

            var yesterday = DateTime.Today.AddDays(-1);
            var app3 = new Appointment
            {
                CustomerId = request.CustomerId,
                StylistId = stylist.Id,
                ServiceId = service.Id,
                StartTime = yesterday.AddHours(10),
                EndTime = yesterday.AddHours(10).AddMinutes(service.DurationInMinutes),
                Status = "Confirmed"
            };

            _context.Appointments.AddRange(app1, app2, app3);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Simulation appointments successfully assigned to your account." });
        }
    }

    public class CreateAppointmentRequest
    {
        [Required]
        public Guid CustomerId { get; set; }

        [Required]
        public Guid StylistId { get; set; }

        [Required]
        public Guid ServiceId { get; set; }

        [Required]
        public DateTime AppointmentDate { get; set; }

        [Required]
        [RegularExpression(@"^\d{2}:\d{2}$", ErrorMessage = "Time format must be HH:mm.")]
        public string TimeSlot { get; set; } = string.Empty;
    }

    public class RescheduleAppointmentRequest
    {
        [Required]
        public Guid AppointmentId { get; set; }

        [Required]
        public DateTime NewDate { get; set; }

        [Required]
        [RegularExpression(@"^\d{2}:\d{2}$", ErrorMessage = "Time format must be HH:mm.")]
        public string NewTimeSlot { get; set; } = string.Empty;
    }

    public class CreateReviewRequest
    {
        [Required]
        public Guid AppointmentId { get; set; }

        [Required]
        public Guid CustomerId { get; set; }

        [Required]
        [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5.")]
        public int Rating { get; set; }

        [MaxLength(500)]
        public string Comment { get; set; } = string.Empty;
    }

    public class CreateTestRequest
    {
        [Required]
        public Guid CustomerId { get; set; }
    }
}
