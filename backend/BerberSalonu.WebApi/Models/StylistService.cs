using System;
using System.ComponentModel.DataAnnotations.Schema;

namespace BerberSalonu.WebApi.Models
{
    public class StylistService
    {
        public Guid StylistId { get; set; }

        [ForeignKey("StylistId")]
        public Stylist? Stylist { get; set; }

        public Guid ServiceId { get; set; }

        [ForeignKey("ServiceId")]
        public Service? Service { get; set; }
    }
}
