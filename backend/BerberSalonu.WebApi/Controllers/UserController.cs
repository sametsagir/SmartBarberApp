using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;

namespace BerberSalonu.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class UserController : ControllerBase
    {
        private readonly AppDbContext _context;

        public UserController(AppDbContext context)
        {
            _context = context;
        }

        private Guid GetUserId()
        {
            var claimVal = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(claimVal))
                throw new UnauthorizedAccessException("Unauthorized access.");
            return Guid.Parse(claimVal);
        }

        [HttpGet("settings")]
        public async Task<IActionResult> GetUserSettings()
        {
            var userId = GetUserId();
            var user = await _context.Users.FindAsync(userId);
            if (user == null) return NotFound(new { Message = "User not found." });

            return Ok(new
            {
                user.Id,
                user.FullName,
                user.PhoneNumber,
                user.Role,
                user.ReminderMinutesBefore
            });
        }

        [HttpPut("settings")]
        public async Task<IActionResult> UpdateUserSettings([FromBody] UpdateSettingsRequest request)
        {
            var userId = GetUserId();
            var user = await _context.Users.FindAsync(userId);
            if (user == null) return NotFound(new { Message = "User not found." });

            user.ReminderMinutesBefore = request.ReminderMinutesBefore;
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Settings successfully updated." });
        }

        [HttpPost("favorites/salon/toggle/{salonId}")]
        public async Task<IActionResult> ToggleFavoriteSalon(Guid salonId)
        {
            var userId = GetUserId();
            var fav = await _context.FavoriteSalons
                .FirstOrDefaultAsync(f => f.UserId == userId && f.SalonId == salonId);

            if (fav == null)
            {
                var newFav = new FavoriteSalon { UserId = userId, SalonId = salonId };
                _context.FavoriteSalons.Add(newFav);
                await _context.SaveChangesAsync();
                return Ok(new { Message = "Salon added to favorites.", IsFavorite = true });
            }
            else
            {
                _context.FavoriteSalons.Remove(fav);
                await _context.SaveChangesAsync();
                return Ok(new { Message = "Salon removed from favorites.", IsFavorite = false });
            }
        }

        [HttpPost("favorites/stylist/toggle/{stylistId}")]
        public async Task<IActionResult> ToggleFavoriteStylist(Guid stylistId)
        {
            var userId = GetUserId();
            var fav = await _context.FavoriteStylists
                .FirstOrDefaultAsync(f => f.UserId == userId && f.StylistId == stylistId);

            if (fav == null)
            {
                var newFav = new FavoriteStylist { UserId = userId, StylistId = stylistId };
                _context.FavoriteStylists.Add(newFav);
                await _context.SaveChangesAsync();
                return Ok(new { Message = "Stylist added to favorites.", IsFavorite = true });
            }
            else
            {
                _context.FavoriteStylists.Remove(fav);
                await _context.SaveChangesAsync();
                return Ok(new { Message = "Stylist removed from favorites.", IsFavorite = false });
            }
        }

        [HttpGet("favorites/salons")]
        public async Task<IActionResult> GetFavoriteSalons()
        {
            var userId = GetUserId();
            var salons = await _context.FavoriteSalons
                .Where(f => f.UserId == userId)
                .Include(f => f.Salon)
                .Select(f => f.Salon)
                .ToListAsync();
            return Ok(salons);
        }

        [HttpGet("favorites/stylists")]
        public async Task<IActionResult> GetFavoriteStylists()
        {
            var userId = GetUserId();
            var stylists = await _context.FavoriteStylists
                .Where(f => f.UserId == userId)
                .Include(f => f.Stylist)
                    .ThenInclude(s => s!.User)
                .Include(f => f.Stylist)
                    .ThenInclude(s => s!.Salon)
                .Select(f => new
                {
                    f.Stylist!.Id,
                    f.Stylist.Title,
                    f.Stylist.Rating,
                    FullName = f.Stylist.User!.FullName ?? "Unknown Stylist",
                    SalonName = f.Stylist.Salon!.Name ?? "Unknown Salon"
                })
                .ToListAsync();
            return Ok(stylists);
        }
    }

    public class UpdateSettingsRequest
    {
        public int ReminderMinutesBefore { get; set; }
    }
}
