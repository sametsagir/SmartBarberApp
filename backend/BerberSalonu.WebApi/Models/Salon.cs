using System;
using System.ComponentModel.DataAnnotations;

namespace BerberSalonu.WebApi.Models
{
    public class Salon
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(500)]
        public string Address { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Phone { get; set; } = string.Empty;

        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public double Rating { get; set; }

        [MaxLength(500)]
        public string? ImageUrl { get; set; }
    }
}
