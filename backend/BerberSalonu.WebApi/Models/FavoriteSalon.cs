using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BerberSalonu.WebApi.Models
{
    public class FavoriteSalon
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
    }
}
