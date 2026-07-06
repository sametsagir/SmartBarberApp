using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BerberSalonu.WebApi.Models
{
    public class Appointment
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid? CustomerId { get; set; }

        [ForeignKey("CustomerId")]
        public User? Customer { get; set; }

        [Required]
        public Guid StylistId { get; set; }

        [ForeignKey("StylistId")]
        public Stylist? Stylist { get; set; }

        [Required]
        public Guid ServiceId { get; set; }

        [ForeignKey("ServiceId")]
        public Service? Service { get; set; }

        [Required]
        public DateTime StartTime { get; set; } // UTC date and time

        [Required]
        public DateTime EndTime { get; set; } // UTC date and time

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "Pending"; // Pending, Confirmed, Cancelled

        [MaxLength(100)]
        public string? GuestName { get; set; }

        [MaxLength(50)]
        public string? GuestPhone { get; set; }

        public bool ReminderSent { get; set; } = false;
    }
}
