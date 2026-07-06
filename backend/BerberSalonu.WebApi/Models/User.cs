using System;
using System.ComponentModel.DataAnnotations;

namespace BerberSalonu.WebApi.Models
{
    public class User
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(20)]
        public string PhoneNumber { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? FullName { get; set; }

        [Required]
        [MaxLength(20)]
        public string Role { get; set; } = "Customer"; // Customer, Barber, Admin

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public bool IsActive { get; set; } = true;

        public int ReminderMinutesBefore { get; set; } = 60;
    }
}
