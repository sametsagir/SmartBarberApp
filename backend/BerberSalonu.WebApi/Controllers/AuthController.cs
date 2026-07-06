using System;
using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;
using BerberSalonu.WebApi.Services;

namespace BerberSalonu.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IAuthService _authService;
        private readonly IConfiguration _configuration;

        public AuthController(AppDbContext context, IAuthService authService, IConfiguration configuration)
        {
            _context = context;
            _authService = authService;
            _configuration = configuration;
        }

        [HttpPost("send-otp")]
        public async Task<IActionResult> SendOtp([FromBody] SendOtpRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var existingUser = await _context.Users.AnyAsync(u => u.PhoneNumber == request.PhoneNumber);

            if (request.IsRegister)
            {
                if (existingUser)
                {
                    return BadRequest(new { Message = "This phone number is already registered. Please log in." });
                }
            }
            else
            {
                if (!existingUser)
                {
                    return BadRequest(new { Message = "No account found with this phone number. Please register first." });
                }
            }

            // Rate limit check: max 15 SMS codes per day per phone number
            var today = DateTime.UtcNow.AddHours(3).Date;
            var tomorrow = today.AddDays(1);
            var dailyOtpCount = await _context.OtpCodes
                .CountAsync(o => o.PhoneNumber == request.PhoneNumber && o.CreatedAt >= today && o.CreatedAt < tomorrow);

            if (dailyOtpCount >= 15)
            {
                return BadRequest(new { Message = "You have reached the daily maximum SMS verification limit (15). Please try again tomorrow." });
            }

            var code = await _authService.GenerateOtpAsync(request.PhoneNumber);

            // Check if Twilio settings are configured
            var twilioSection = _configuration.GetSection("Twilio");
            var accountSid = twilioSection["AccountSid"];
            var isConfigured = !string.IsNullOrWhiteSpace(accountSid) && !accountSid.Contains("YOUR_TWILIO_ACCOUNT_SID_HERE");
            var useMock = twilioSection.GetValue<bool>("UseMockSms");

            if (useMock || !isConfigured)
            {
                return Ok(new { 
                    Message = "Verification code sent (Simulated).", 
                    DebugCode = code 
                });
            }

            return Ok(new { Message = "Verification code sent." });
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var isValid = await _authService.VerifyOtpAsync(request.PhoneNumber, request.Code);
            if (!isValid)
            {
                return BadRequest(new { Message = "Invalid or expired code." });
            }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == request.PhoneNumber);
            if (user == null)
            {
                return BadRequest(new { Message = "No account found with this phone number. Please register first." });
            }

            var token = _authService.GenerateJwtToken(user);
            return Ok(new 
            { 
                Token = token, 
                User = new { user.Id, user.PhoneNumber, user.FullName, user.Role } 
            });
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var isValid = await _authService.VerifyOtpAsync(request.PhoneNumber, request.Code);
            if (!isValid)
            {
                return BadRequest(new { Message = "Invalid or expired verification code." });
            }

            var existingUser = await _context.Users.AnyAsync(u => u.PhoneNumber == request.PhoneNumber);
            if (existingUser)
            {
                return BadRequest(new { Message = "This phone number is already registered." });
            }

            var role = request.Role;
            if (role != "Customer" && role != "Barber" && role != "Admin")
            {
                role = "Customer";
            }

            var newUser = new User
            {
                PhoneNumber = request.PhoneNumber,
                FullName = request.FullName,
                Role = role,
                CreatedAt = DateTime.UtcNow,
                IsActive = true
            };

            _context.Users.Add(newUser);
            await _context.SaveChangesAsync();

            var token = _authService.GenerateJwtToken(newUser);
            return Ok(new 
            { 
                Token = token, 
                User = new { newUser.Id, newUser.PhoneNumber, newUser.FullName, newUser.Role } 
            });
        }
    }

    public class SendOtpRequest
    {
        [Required]
        [Phone]
        public string PhoneNumber { get; set; } = string.Empty;

        public bool IsRegister { get; set; } = false;
    }

    public class VerifyOtpRequest
    {
        [Required]
        [Phone]
        public string PhoneNumber { get; set; } = string.Empty;

        [Required]
        [StringLength(6, MinimumLength = 6)]
        public string Code { get; set; } = string.Empty;
    }

    public class RegisterRequest
    {
        [Required]
        [Phone]
        public string PhoneNumber { get; set; } = string.Empty;

        [Required]
        [StringLength(6, MinimumLength = 6)]
        public string Code { get; set; } = string.Empty;

        [Required]
        [StringLength(100, MinimumLength = 2)]
        public string FullName { get; set; } = string.Empty;

        [Required]
        [RegularExpression("^(Customer|Barber)$", ErrorMessage = "Invalid role. Role must be Customer or Barber.")]
        public string Role { get; set; } = "Customer";
    }
}
