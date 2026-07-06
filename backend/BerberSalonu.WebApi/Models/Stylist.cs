using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BerberSalonu.WebApi.Models
{
    public class Stylist
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid UserId { get; set; }

        [ForeignKey("UserId")]
        public User? User { get; set; }

        [Required]
        public Guid SalonId { get; set; }

        [ForeignKey("SalonId")]
        public Salon? Salon { get; set; }

        [Required]
        [MaxLength(100)]
        public string Title { get; set; } = string.Empty;

        public double Rating { get; set; }

        public bool IsOwner { get; set; } = false;
        
        public bool IsActive { get; set; } = true;
    }
}
