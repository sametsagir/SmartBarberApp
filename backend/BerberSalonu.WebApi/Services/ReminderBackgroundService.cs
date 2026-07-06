using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using BerberSalonu.WebApi.Data;

namespace BerberSalonu.WebApi.Services
{
    public class ReminderBackgroundService : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<ReminderBackgroundService> _logger;

        public ReminderBackgroundService(IServiceScopeFactory scopeFactory, ILogger<ReminderBackgroundService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("ReminderBackgroundService baslatildi.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CheckUpcomingAppointmentsAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "ReminderBackgroundService calisirken hata olustu.");
                }

                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            }
        }

        private async Task CheckUpcomingAppointmentsAsync()
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var now = DateTime.UtcNow.AddHours(3);
            var targetMaxTime = now.AddDays(1);

            var upcomingAppointments = await context.Appointments
                .Where(a => a.Status != "Cancelled" && !a.ReminderSent && a.StartTime >= now && a.StartTime <= targetMaxTime)
                .Include(a => a.Customer)
                .Include(a => a.Stylist)
                    .ThenInclude(s => s!.User)
                .Include(a => a.Service)
                .ToListAsync();

            foreach (var app in upcomingAppointments)
            {
                if (app.Customer == null) continue;

                var reminderMinutes = app.Customer.ReminderMinutesBefore;
                var reminderTime = app.StartTime.AddMinutes(-reminderMinutes);

                // Trigger if current time has crossed reminder target time and is within a 15-minute tolerance window
                if (now >= reminderTime && now <= reminderTime.AddMinutes(15) && !app.ReminderSent)
                {
                    app.ReminderSent = true;
                    context.Appointments.Update(app);
                    await context.SaveChangesAsync();

                    var customerName = app.Customer.FullName ?? "Müşteri";
                    var customerPhone = app.Customer.PhoneNumber;
                    var stylistName = app.Stylist?.User?.FullName ?? "Usta";
                    var serviceName = app.Service?.Name ?? "Hizmet";
                    var startTimeStr = app.StartTime.ToString("HH:mm");

                    var hoursLabel = reminderMinutes >= 60 
                        ? (reminderMinutes >= 1440 ? "1 gün" : (reminderMinutes / 60) + " saat") 
                        : reminderMinutes + " dakika";

                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("\n========================================= SIMULATED NOTIFICATION =========================================");
                    Console.WriteLine($"[SMS REMINDER] ⏰ RANDEVUYA {hoursLabel.ToUpper(new System.Globalization.CultureInfo("tr-TR"))} KALDI! (Kullanıcı Ayarı: {hoursLabel})");
                    Console.WriteLine($"Kullanıcıya Gönderilen (SMS) -> Alıcı: {customerPhone} ({customerName})");
                    Console.WriteLine($"  İçerik: Sayın {customerName}, {serviceName} randevunuza {hoursLabel} kalmıştır. Saat: {startTimeStr}.");
                    Console.WriteLine($"Ustaya Gönderilen (Push Notification) -> Alıcı: {stylistName}");
                    Console.WriteLine($"  İçerik: Sayın {stylistName}, {customerName} ile olan {serviceName} randevunuza {hoursLabel} kalmıştır. Saat: {startTimeStr}.");
                    Console.WriteLine("========================================================================================================\n");
                    Console.ResetColor();
                }
            }
        }
    }
}
