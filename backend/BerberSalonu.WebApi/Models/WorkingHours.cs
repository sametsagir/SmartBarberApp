using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BerberSalonu.WebApi.Models
{
    public class WorkingHours
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid StylistId { get; set; }

        [ForeignKey("StylistId")]
        public Stylist? Stylist { get; set; }

        [Required]
        public int DayOfWeek { get; set; } // 0 = Sunday, 1 = Monday, ..., 6 = Saturday

        [Required]
        public TimeSpan StartTime { get; set; } // E.g., 09:00:00

        [Required]
        public TimeSpan EndTime { get; set; } // E.g., 18:00:00

        public TimeSpan? LunchStartTime { get; set; } // E.g., 12:00:00

        public TimeSpan? LunchEndTime { get; set; } // E.g., 13:00:00

        public bool IsActive { get; set; } = true; // False if off-day
    }
}
