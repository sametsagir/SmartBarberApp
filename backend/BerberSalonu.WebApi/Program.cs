using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;
using BerberSalonu.WebApi.Services;
using Scalar.AspNetCore;

// Load environment variables from .env file if it exists at the project root
var envPath = Path.Combine(Directory.GetCurrentDirectory(), ".env");
if (File.Exists(envPath))
{
    foreach (var line in File.ReadAllLines(envPath))
    {
        if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith("#")) continue;
        var parts = line.Split('=', 2);
        if (parts.Length == 2)
        {
            var key = parts[0].Trim();
            var val = parts[1].Trim();
            Environment.SetEnvironmentVariable(key, val);
        }
    }
}

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();

// Configure EF Core with SQL Server using environment override if present
var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING") 
    ?? builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));

// Configure Dependency Injection for AuthService
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ISmsService, TwilioSmsService>();
builder.Services.AddHostedService<ReminderBackgroundService>();

// Configure JWT Authentication
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = Environment.GetEnvironmentVariable("JWT_SECRET") 
    ?? jwtSettings["Secret"] 
    ?? "SuperSecretSecurityKeyThatIsLongEnoughToMeetRequirements12345!";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey))
    };
});

// Configure OpenAPI (Swagger replacement in .NET 9/10)
builder.Services.AddOpenApi();

var app = builder.Build();

// Auto-create database and tables at startup (Convenient for local development)
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        bool needsRecreate = false;
        try
        {
            if (dbContext.Database.CanConnect())
            {
                // Check if schema is up to date (by querying the new column)
                _ = dbContext.Appointments.Select(a => a.ReminderSent).FirstOrDefault();
            }
        }
        catch (Exception)
        {
            Console.WriteLine("[SCHEMA UPDATE] Database schema is outdated (missing ReminderSent column). Recreating database...");
            needsRecreate = true;
        }

        dbContext.Database.EnsureCreated();

        // Seed Salons, Services, Stylists, and WorkingHours
        if (!dbContext.Salons.Any())
        {
            Console.WriteLine("[SEEDING] Seeding dummy salons, services, and stylists...");
            var rand = new Random();
            var mockSalons = new List<(string Name, string Address, double Lat, double Lng, string ImageUrl)>
            {
                ("Adalar Makas", "Büyükada İskele Meydanı No: 5, Adalar, İstanbul", 40.8742, 29.1292, "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=500"),
                ("Arnavutköy Stil", "Fatih Caddesi No: 44, Arnavutköy, İstanbul", 41.1852, 28.7408, "https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500"),
                ("Ataşehir Klas", "Atatürk Bulvarı No: 12, Ataşehir, İstanbul", 40.9847, 29.1067, "https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=500"),
                ("Avcılar Efsane", "Marmara Caddesi No: 88, Avcılar, İstanbul", 40.9801, 28.7175, "https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=500"),
                ("Bağcılar Prestij", "Mimar Sinan Caddesi No: 23, Bağcılar, İstanbul", 41.0344, 28.8333, "https://images.unsplash.com/photo-1605497746444-17dbd80a997a?w=500"),
                ("Bahçelievler Trend", "Çalışlar Caddesi No: 67, Bahçelievler, İstanbul", 40.9961, 28.8614, "https://images.unsplash.com/photo-1512864084360-7c0c4d0a0845?w=500"),
                ("Bakırköy Karizma", "Ebubekir Caddesi No: 9, Bakırköy, İstanbul", 40.9785, 28.8745, "https://images.unsplash.com/photo-1517832606589-7a598b647192?w=500"),
                ("Başakşehir Elite", "Olimpiyat Bulvarı No: 102, Başakşehir, İstanbul", 41.1077, 28.7944, "https://images.unsplash.com/photo-1521454307-3cf7efc98813?w=500"),
                ("Bayrampaşa Vizyon", "Abdi İpekçi Caddesi No: 54, Bayrampaşa, İstanbul", 41.0347, 28.8967, "https://images.unsplash.com/photo-1634480256802-7cb5b451f99a?w=500"),
                ("Beşiktaş Makas", "Ihlamurdere Caddesi No: 33, Beşiktaş, İstanbul", 41.0428, 29.0075, "https://images.unsplash.com/photo-1501719183311-155fe0d848b5?w=500"),
                ("Beykoz Stil", "Fevzi Paşa Caddesi No: 15, Beykoz, İstanbul", 41.1322, 29.1026, "https://images.unsplash.com/photo-1593702295094-aec22df2652f?w=500"),
                ("Beylikdüzü Karizma", "Cumhuriyet Caddesi No: 77, Beylikdüzü, İstanbul", 40.9897, 28.6431, "https://images.unsplash.com/photo-1527799851257-6592a8865e52?w=500"),
                ("Beyoğlu Klas", "İstiklal Caddesi No: 144, Beyoğlu, İstanbul", 41.0370, 28.9760, "https://images.unsplash.com/photo-1532710093739-9470acff878f?w=500"),
                ("Büyükçekmece Asil", "Kordonboyu Caddesi No: 8, Büyükçekmece, İstanbul", 41.0218, 28.5902, "https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=500"),
                ("Çatalca Efsane", "Atatürk Caddesi No: 50, Çatalca, İstanbul", 41.1436, 28.4614, "https://images.unsplash.com/photo-1622287198396-0976014a66f1?w=500"),
                ("Çekmeköy Prime", "Şahinbey Caddesi No: 99, Çekmeköy, İstanbul", 41.0401, 29.2045, "https://images.unsplash.com/photo-1507081329514-61f2f98e74b9?w=500"),
                ("Esenler Vizyon", "Atışalanı Caddesi No: 12, Esenler, İstanbul", 41.0326, 28.8703, "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=500"),
                ("Esenyurt Trend", "Doğan Araslı Bulvarı No: 210, Esenyurt, İstanbul", 41.0343, 28.6801, "https://images.unsplash.com/photo-1516975080664-ed2fc6a32937?w=500"),
                ("Eyüpsultan Asil", "Feshane Caddesi No: 40, Eyüpsultan, İstanbul", 41.0478, 28.9329, "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=500"),
                ("Fatih Klas", "Fevzipaşa Caddesi No: 110, Fatih, İstanbul", 41.0180, 28.9480, "https://images.unsplash.com/photo-1620331311520-246422fd82f9?w=500"),
                ("Gaziosmanpaşa Stil", "Bağlarbaşı Caddesi No: 85, Gaziosmanpaşa, İstanbul", 41.0573, 28.9144, "https://images.unsplash.com/photo-1592647429448-423719985434?w=500"),
                ("Güngören Elite", "Menderes Caddesi No: 3, Güngören, İstanbul", 41.0211, 28.8722, "https://images.unsplash.com/photo-1560066984-138dadb4c035?w=500"),
                ("Kadıköy Moda", "Moda Caddesi No: 42, Kadıköy, İstanbul", 40.9901, 29.0270, "https://images.unsplash.com/photo-1562322140-8baeececf3df?w=500"),
                ("Kağıthane Trend", "Cendere Caddesi No: 18, Kağıthane, İstanbul", 41.0811, 28.9733, "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500"),
                ("Kartal Prestij", "Ankara Caddesi No: 66, Kartal, İstanbul", 40.8886, 29.1862, "https://images.unsplash.com/photo-1598252573306-2224455024e0?w=500"),
                ("Küçükçekmece Efsane", "Halkalı Caddesi No: 120, Küçükçekmece, İstanbul", 41.0022, 28.7818, "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=500"),
                ("Maltepe Klas", "Bağdat Caddesi No: 340, Maltepe, İstanbul", 40.9248, 29.1311, "https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500"),
                ("Pendik Asil", "19 Mayıs Caddesi No: 45, Pendik, İstanbul", 40.8795, 29.2581, "https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=500"),
                ("Sancaktepe Vizyon", "Demokrasi Caddesi No: 8, Sancaktepe, İstanbul", 40.9904, 29.2319, "https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=500"),
                ("Sarıyer Elite", "Dereboyu Caddesi No: 14, Sarıyer, İstanbul", 41.1668, 29.0501, "https://images.unsplash.com/photo-1605497746444-17dbd80a997a?w=500"),
                ("Silivri Karizma", "Şerif Sokak No: 2, Silivri, İstanbul", 41.0742, 28.2481, "https://images.unsplash.com/photo-1512864084360-7c0c4d0a0845?w=500"),
                ("Sultanbeyli Efsane", "Fatih Bulvarı No: 180, Sultanbeyli, İstanbul", 40.9664, 29.2667, "https://images.unsplash.com/photo-1517832606589-7a598b647192?w=500"),
                ("Sultangazi Trend", "Lütfi Aykaç Bulvarı No: 55, Sultangazi, İstanbul", 41.1072, 28.8767, "https://images.unsplash.com/photo-1521454307-3cf7efc98813?w=500"),
                ("Şile Klas", "Üsküdar Caddesi No: 10, Şile, İstanbul", 41.1744, 29.6125, "https://images.unsplash.com/photo-1634480256802-7cb5b451f99a?w=500"),
                ("Şişli Nişantaşı", "Abdi İpekçi Caddesi No: 22, Şişli, İstanbul", 41.0520, 28.9900, "https://images.unsplash.com/photo-1501719183311-155fe0d848b5?w=500"),
                ("Tuzla Prestij", "Postane Mahallesi No: 5, Tuzla, İstanbul", 40.8164, 29.3032, "https://images.unsplash.com/photo-1593702295094-aec22df2652f?w=500"),
                ("Ümraniye Trend", "Alemdağ Caddesi No: 150, Ümraniye, İstanbul", 41.0247, 29.1244, "https://images.unsplash.com/photo-1527799851257-6592a8865e52?w=500"),
                ("Üsküdar Çarşı", "Mimar Sinan Caddesi No: 19, Üsküdar, İstanbul", 41.0260, 29.0160, "https://images.unsplash.com/photo-1532710093739-9470acff878f?w=500"),
                ("Zeytinburnu Stil", "58. Bulvar No: 44, Zeytinburnu, İstanbul", 40.9882, 28.9036, "https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=500")
            };

            var stylistNames = new[] { "Mustafa Yılmaz", "Kerem Şahin", "Okan Demir", "Serkan Kaya", "Burak Çelik" };
            var stylistTitles = new[] { "Haircut Specialist", "Beard Styling Expert", "Senior Barber" };

            Guid kadikoyModaSalonId = Guid.Empty;
            var kadikoyModaStylists = new List<Stylist>();
            var kadikoyModaServices = new List<Service>();

            foreach (var mock in mockSalons)
            {
                for (int k = 1; k <= 3; k++)
                {
                    var salonId = Guid.NewGuid();
                    string name = k == 1 ? mock.Name : $"{mock.Name} - {k}";
                    string address = k == 1 ? mock.Address : mock.Address.Replace("No: ", $"No: {k}0, Blok {k}, ");
                    
                    double latOffset = (k - 1) * 0.005 * (rand.NextDouble() > 0.5 ? 1 : -1);
                    double lngOffset = (k - 1) * 0.007 * (rand.NextDouble() > 0.5 ? 1 : -1);
                    double lat = mock.Lat + latOffset;
                    double lng = mock.Lng + lngOffset;

                    var salon = new Salon
                    {
                        Id = salonId,
                        Name = name,
                        Address = address,
                        Phone = $"+905{rand.Next(100, 999)} {rand.Next(10, 99)} {rand.Next(10, 99)}",
                        Latitude = lat,
                        Longitude = lng,
                        Rating = Math.Round(4.0 + rand.NextDouble() * 1.0, 1),
                        ImageUrl = mock.ImageUrl
                    };
                    dbContext.Salons.Add(salon);

                    var services = new List<Service>
                    {
                        new Service { Id = Guid.NewGuid(), SalonId = salonId, Name = "Haircut", DurationInMinutes = 30, Price = 400 },
                        new Service { Id = Guid.NewGuid(), SalonId = salonId, Name = "Beard Trim & Design", DurationInMinutes = 20, Price = 200 },
                        new Service { Id = Guid.NewGuid(), SalonId = salonId, Name = "Hair & Beard Trim", DurationInMinutes = 45, Price = 550 },
                        new Service { Id = Guid.NewGuid(), SalonId = salonId, Name = "Skin Care & Black Mask", DurationInMinutes = 30, Price = 300 }
                    };
                    dbContext.Services.AddRange(services);

                    if (mock.Name == "Kadıköy Moda" && k == 1)
                    {
                        kadikoyModaSalonId = salonId;
                        kadikoyModaServices.AddRange(services);
                    }

                    for (int i = 0; i < 2; i++)
                    {
                        var uid = Guid.NewGuid();
                        string stylistName;
                        string phone;
                        bool isOwner = i == 0;

                        if (mock.Name == "Kadıköy Moda" && k == 1)
                        {
                            if (i == 0)
                            {
                                stylistName = "Hakan Yılmaz";
                                phone = "+905321112233"; // TEST BARBER OWNER
                            }
                            else
                            {
                                stylistName = "Kerem Şahin";
                                phone = "+905322223344"; // TEST BARBER EMPLOYEE
                            }
                        }
                        else
                        {
                            stylistName = stylistNames[rand.Next(stylistNames.Length)];
                            phone = $"+90555{rand.Next(1000000, 9999999)}";
                        }

                        dbContext.Users.Add(new User 
                        { 
                            Id = uid, 
                            PhoneNumber = phone, 
                            FullName = stylistName, 
                            Role = "Barber", 
                            IsActive = true, 
                            CreatedAt = DateTime.UtcNow 
                        });
                        
                        var sid = Guid.NewGuid();
                        var stylist = new Stylist 
                        { 
                            Id = sid, 
                            UserId = uid, 
                            SalonId = salonId, 
                            Title = stylistTitles[rand.Next(stylistTitles.Length)], 
                            Rating = 4.7,
                            IsOwner = isOwner
                        };
                        dbContext.Stylists.Add(stylist);

                        if (mock.Name == "Kadıköy Moda" && k == 1)
                        {
                            kadikoyModaStylists.Add(stylist);
                        }

                        // Assign all services to the seeded stylists
                        foreach (var s in services)
                        {
                            dbContext.StylistServices.Add(new StylistService
                            {
                                StylistId = sid,
                                ServiceId = s.Id
                            });
                        }

                        for (int day = 1; day <= 6; day++) 
                        {
                            dbContext.WorkingHours.Add(new WorkingHours 
                            { 
                                Id = Guid.NewGuid(), 
                                StylistId = sid, 
                                DayOfWeek = day, 
                                StartTime = new TimeSpan(9, 0, 0), 
                                EndTime = new TimeSpan(19, 0, 0), 
                                LunchStartTime = new TimeSpan(12, 0, 0), 
                                LunchEndTime = new TimeSpan(13, 0, 0), 
                                IsActive = true 
                            });
                        }
                    }
                }
            }
            dbContext.SaveChanges();
            Console.WriteLine("[SEEDING] 117 mock salons, services and stylists seeded.");

            // 2. Seed Dummy Customers
            Console.WriteLine("[SEEDING] Seeding dummy customer accounts...");
            var dummyCustomers = new List<User>
            {
                new User { Id = Guid.NewGuid(), PhoneNumber = "+905551112233", FullName = "Ahmet Kaya", Role = "Customer", IsActive = true, CreatedAt = DateTime.UtcNow },
                new User { Id = Guid.NewGuid(), PhoneNumber = "+905552223344", FullName = "Mehmet Can", Role = "Customer", IsActive = true, CreatedAt = DateTime.UtcNow },
                new User { Id = Guid.NewGuid(), PhoneNumber = "+905553334455", FullName = "Can Demir", Role = "Customer", IsActive = true, CreatedAt = DateTime.UtcNow },
                new User { Id = Guid.NewGuid(), PhoneNumber = "+905554445566", FullName = "Emre Aslan", Role = "Customer", IsActive = true, CreatedAt = DateTime.UtcNow },
                new User { Id = Guid.NewGuid(), PhoneNumber = "+905555556677", FullName = "Ali Öztürk", Role = "Customer", IsActive = true, CreatedAt = DateTime.UtcNow }
            };
            dbContext.Users.AddRange(dummyCustomers);
            dbContext.SaveChanges();

            // 3. Seed Appointments for Kadıköy Moda Salon (Hakan Yılmaz & Kerem Şahin)
            if (kadikoyModaSalonId != Guid.Empty && kadikoyModaStylists.Count >= 2 && kadikoyModaServices.Count >= 4)
            {
                Console.WriteLine("[SEEDING] Seeding dummy appointments and reviews for Kadıköy Moda...");
                var hakan = kadikoyModaStylists[0]; // Owner
                var kerem = kadikoyModaStylists[1]; // Stylist

                var today = DateTime.Today;

                // Dynamically generate past completed appointments over the last 30 days to reach exactly ~270,000 TL for Hakan and ~130,000 TL for Kerem
                var randAppt = new Random();
                for (int dayOffset = -30; dayOffset < 0; dayOffset++)
                {
                    var date = today.AddDays(dayOffset);
                    
                    // Hakan: 25 appointments per day * 362.5 avg price ~ 9,000 TL per day. Over 30 days = 270,000 TL!
                    for (int apptIndex = 0; apptIndex < 25; apptIndex++)
                    {
                        var customer = dummyCustomers[randAppt.Next(dummyCustomers.Count)];
                        var service = kadikoyModaServices[randAppt.Next(kadikoyModaServices.Count)];
                        var hour = 9 + (apptIndex % 10);
                        var minute = (apptIndex * 15) % 60;
                        var startTime = new DateTime(date.Year, date.Month, date.Day, hour, minute, 0);

                        var apptId = Guid.NewGuid();
                        dbContext.Appointments.Add(new Appointment
                        {
                            Id = apptId,
                            CustomerId = customer.Id,
                            StylistId = hakan.Id,
                            ServiceId = service.Id,
                            StartTime = startTime,
                            EndTime = startTime.AddMinutes(service.DurationInMinutes),
                            Status = "Completed",
                            ReminderSent = false
                        });

                        // Seed a few reviews randomly
                        if (randAppt.Next(10) == 0) // 10% chance
                        {
                            var reviewComments = new[] { "Excellent service!", "Very professional.", "Highly recommended.", "Best haircut in town!", "Clean and fast." };
                            dbContext.Reviews.Add(new Review
                            {
                                Id = Guid.NewGuid(),
                                AppointmentId = apptId,
                                CustomerId = customer.Id,
                                Rating = randAppt.Next(4, 6), // 4 or 5 stars
                                Comment = reviewComments[randAppt.Next(reviewComments.Length)],
                                CreatedAt = startTime.AddHours(2)
                            });
                        }
                    }

                    // Kerem: 12 appointments per day
                    for (int apptIndex = 0; apptIndex < 12; apptIndex++)
                    {
                        var customer = dummyCustomers[randAppt.Next(dummyCustomers.Count)];
                        var service = kadikoyModaServices[randAppt.Next(kadikoyModaServices.Count)];
                        var hour = 9 + (apptIndex % 10);
                        var minute = (apptIndex * 20) % 60;
                        var startTime = new DateTime(date.Year, date.Month, date.Day, hour, minute, 0);

                        dbContext.Appointments.Add(new Appointment
                        {
                            Id = Guid.NewGuid(),
                            CustomerId = customer.Id,
                            StylistId = kerem.Id,
                            ServiceId = service.Id,
                            StartTime = startTime,
                            EndTime = startTime.AddMinutes(service.DurationInMinutes),
                            Status = "Completed",
                            ReminderSent = false
                        });
                    }
                }

                dbContext.SaveChanges();
                Console.WriteLine("[SEEDING] Kadıköy Moda appointments and reviews seeded successfully!");
            }
        }
        else
        {
            Console.WriteLine("[STARTUP] Database already seeded. Skipping seeding.");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[RESET] Failed to reset database: {ex.Message}");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options.Title = "Berber Salonu Web API Reference";
        options.Theme = ScalarTheme.Purple;
    });
}

// app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
