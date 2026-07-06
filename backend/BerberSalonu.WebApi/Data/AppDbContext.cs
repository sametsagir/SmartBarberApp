using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using BerberSalonu.WebApi.Models;

namespace BerberSalonu.WebApi.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<OtpCode> OtpCodes { get; set; }
        public DbSet<Salon> Salons { get; set; }
        public DbSet<Stylist> Stylists { get; set; }
        public DbSet<Service> Services { get; set; }
        public DbSet<WorkingHours> WorkingHours { get; set; }
        public DbSet<Appointment> Appointments { get; set; }
        public DbSet<Review> Reviews { get; set; }
        public DbSet<FavoriteSalon> FavoriteSalons { get; set; }
        public DbSet<FavoriteStylist> FavoriteStylists { get; set; }
        public DbSet<StylistService> StylistServices { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure Indexes
            modelBuilder.Entity<User>()
                .HasIndex(u => u.PhoneNumber)
                .IsUnique();

            modelBuilder.Entity<OtpCode>()
                .HasIndex(o => o.PhoneNumber);

            modelBuilder.Entity<Appointment>()
                .HasIndex(a => new { a.StylistId, a.StartTime });

            // Disable cascade delete on Appointments to prevent multiple cascade paths in SQL Server
            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.Customer)
                .WithMany()
                .HasForeignKey(a => a.CustomerId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.Stylist)
                .WithMany()
                .HasForeignKey(a => a.StylistId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.Service)
                .WithMany()
                .HasForeignKey(a => a.ServiceId)
                .OnDelete(DeleteBehavior.Restrict);

            // Configure Review Constraints
            modelBuilder.Entity<Review>()
                .HasIndex(r => r.AppointmentId)
                .IsUnique();

            modelBuilder.Entity<Review>()
                .HasOne(r => r.Appointment)
                .WithOne()
                .HasForeignKey<Review>(r => r.AppointmentId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Review>()
                .HasOne(r => r.Customer)
                .WithMany()
                .HasForeignKey(r => r.CustomerId)
                .OnDelete(DeleteBehavior.Restrict);

            // Configure FavoriteSalon & FavoriteStylist relationships to prevent multiple cascade paths in SQL Server
            modelBuilder.Entity<FavoriteSalon>()
                .HasOne(f => f.User)
                .WithMany()
                .HasForeignKey(f => f.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<FavoriteSalon>()
                .HasOne(f => f.Salon)
                .WithMany()
                .HasForeignKey(f => f.SalonId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<FavoriteStylist>()
                .HasOne(f => f.User)
                .WithMany()
                .HasForeignKey(f => f.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<FavoriteStylist>()
                .HasOne(f => f.Stylist)
                .WithMany()
                .HasForeignKey(f => f.StylistId)
                .OnDelete(DeleteBehavior.Restrict);

            // Configure many-to-many StylistService keys and cascades
            modelBuilder.Entity<StylistService>()
                .HasKey(ss => new { ss.StylistId, ss.ServiceId });

            modelBuilder.Entity<StylistService>()
                .HasOne(ss => ss.Stylist)
                .WithMany()
                .HasForeignKey(ss => ss.StylistId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<StylistService>()
                .HasOne(ss => ss.Service)
                .WithMany()
                .HasForeignKey(ss => ss.ServiceId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Service>()
                .Property(s => s.Price)
                .HasPrecision(18, 2);
        }
    }
}
