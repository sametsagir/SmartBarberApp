using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BerberSalonu.WebApi.Controllers;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;
using Xunit;

namespace BerberSalonu.Tests
{
    public class BookingControllerTests
    {
        private AppDbContext GetInMemoryDbContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        [Fact]
        public async Task GetAvailableSlots_ShouldSupportOvernightShifts()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            
            var salonId = Guid.NewGuid();
            var salon = new Salon { Id = salonId, Name = "Test Salon", Address = "Istanbul" };
            context.Salons.Add(salon);

            var serviceId = Guid.NewGuid();
            var service = new Service { Id = serviceId, SalonId = salonId, Name = "Haircut", DurationInMinutes = 30, Price = 100 };
            context.Services.Add(service);

            var stylistId = Guid.NewGuid();
            var userId = Guid.NewGuid();
            context.Users.Add(new User { Id = userId, PhoneNumber = "+905555555555", FullName = "Stylist User", Role = "Barber" });
            
            var stylist = new Stylist 
            { 
                Id = stylistId, 
                UserId = userId, 
                SalonId = salonId, 
                Title = "Master"
            };
            context.Stylists.Add(stylist);

            context.WorkingHours.Add(new WorkingHours
            {
                DayOfWeek = (int)DayOfWeek.Monday,
                StylistId = stylistId,
                StartTime = new TimeSpan(9, 0, 0), // 09:00 AM
                EndTime = new TimeSpan(1, 0, 0),   // 01:00 AM (Next Day)
                IsActive = true
            });
            await context.SaveChangesAsync();
            var controller = new BookingController(context);

            // Set date to a future Monday to avoid past slot filtering
            var nextMonday = DateTime.Today;
            while (nextMonday.DayOfWeek != DayOfWeek.Monday)
            {
                nextMonday = nextMonday.AddDays(1);
            }
            var testDate = nextMonday.AddDays(7); // Guarantee it is in the future

            // Act
            var actionResult = await controller.GetAvailableSlots(stylistId, testDate, serviceId);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(actionResult);
            var slots = Assert.IsType<List<string>>(okResult.Value);

            // Verify late night slots generated correctly
            Assert.Contains("09:00", slots);
            Assert.Contains("23:30", slots);
            Assert.Contains("00:00", slots);
            Assert.Contains("00:30", slots);
            Assert.DoesNotContain("01:00", slots); // Shift ends at 01:00, so last slot is 00:30 (30 mins duration)
        }

        [Fact]
        public async Task CreateAppointment_ShouldPreventDoubleBooking()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var salonId = Guid.NewGuid();
            var serviceId = Guid.NewGuid();
            var stylistId = Guid.NewGuid();
            var customerId = Guid.NewGuid();
            var barberUserId = Guid.NewGuid();

            context.Salons.Add(new Salon { Id = salonId, Name = "Test", Address = "Test" });
            context.Services.Add(new Service { Id = serviceId, SalonId = salonId, Name = "Haircut", DurationInMinutes = 30, Price = 100 });
            context.Users.Add(new User { Id = barberUserId, PhoneNumber = "+905551", FullName = "Barber", Role = "Barber" });
            context.Users.Add(new User { Id = customerId, PhoneNumber = "+905552", FullName = "Customer", Role = "Customer" });
            context.Stylists.Add(new Stylist { Id = stylistId, UserId = barberUserId, SalonId = salonId, Title = "Master" });

            // Seed existing appointment at 10:00 - 10:30
            var existingApp = new Appointment
            {
                Id = Guid.NewGuid(),
                CustomerId = customerId,
                StylistId = stylistId,
                ServiceId = serviceId,
                StartTime = new DateTime(2026, 7, 6, 10, 0, 0),
                EndTime = new DateTime(2026, 7, 6, 10, 30, 0),
                Status = "Confirmed"
            };
            context.Appointments.Add(existingApp);
            await context.SaveChangesAsync();

            var controller = new BookingController(context);

            var request = new CreateAppointmentRequest
            {
                CustomerId = customerId,
                StylistId = stylistId,
                ServiceId = serviceId,
                AppointmentDate = new DateTime(2026, 7, 6),
                TimeSlot = "10:00"
            };

            // Act
            var actionResult = await controller.CreateAppointment(request);

            // Assert
            var badRequest = Assert.IsType<BadRequestObjectResult>(actionResult);
            dynamic response = badRequest.Value!;
            Assert.Contains("already booked", (string)response.GetType().GetProperty("Message").GetValue(response, null));
        }

        [Fact]
        public async Task CreateAppointment_ShouldResolveOvernightDayCorrectly()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var salonId = Guid.NewGuid();
            var serviceId = Guid.NewGuid();
            var stylistId = Guid.NewGuid();
            var customerId = Guid.NewGuid();
            var barberUserId = Guid.NewGuid();

            context.Salons.Add(new Salon { Id = salonId, Name = "Test", Address = "Test" });
            context.Services.Add(new Service { Id = serviceId, SalonId = salonId, Name = "Haircut", DurationInMinutes = 30, Price = 100 });
            context.Users.Add(new User { Id = barberUserId, PhoneNumber = "+905551", FullName = "Barber", Role = "Barber" });
            context.Users.Add(new User { Id = customerId, PhoneNumber = "+905552", FullName = "Customer", Role = "Customer" });
            
            var stylist = new Stylist { Id = stylistId, UserId = barberUserId, SalonId = salonId, Title = "Master" };
            context.Stylists.Add(stylist);

            context.WorkingHours.Add(new WorkingHours
            {
                DayOfWeek = (int)DayOfWeek.Monday,
                StylistId = stylistId,
                StartTime = new TimeSpan(9, 0, 0),
                EndTime = new TimeSpan(1, 0, 0), // Overnight
                IsActive = true
            });
            await context.SaveChangesAsync();

            var controller = new BookingController(context);

            // Request for a future Monday, but picking 00:30 slot (which is overnight/Tuesday morning)
            var nextMonday = DateTime.Today;
            while (nextMonday.DayOfWeek != DayOfWeek.Monday)
            {
                nextMonday = nextMonday.AddDays(1);
            }
            var testMonday = nextMonday.AddDays(7);

            var request = new CreateAppointmentRequest
            {
                CustomerId = customerId,
                StylistId = stylistId,
                ServiceId = serviceId,
                AppointmentDate = testMonday,
                TimeSlot = "00:30"
            };

            // Act
            var actionResult = await controller.CreateAppointment(request);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(actionResult);
            
            // Retrieve created appointment from Db
            var createdApp = await context.Appointments.SingleOrDefaultAsync(a => a.CustomerId == customerId && a.Status == "Pending");
            Assert.NotNull(createdApp);
            
            // Expect date to be Tuesday (testMonday + 1 day) at 00:30
            var expectedStart = testMonday.AddDays(1).Add(new TimeSpan(0, 30, 0));
            var expectedEnd = testMonday.AddDays(1).Add(new TimeSpan(1, 0, 0));
            Assert.Equal(expectedStart, createdApp.StartTime);
            Assert.Equal(expectedEnd, createdApp.EndTime);
        }
    }
}
