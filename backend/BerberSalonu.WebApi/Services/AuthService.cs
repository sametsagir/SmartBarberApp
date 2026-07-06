using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using BerberSalonu.WebApi.Data;
using BerberSalonu.WebApi.Models;

namespace BerberSalonu.WebApi.Services
{
    public interface IAuthService
    {
        Task<string> GenerateOtpAsync(string phoneNumber);
        Task<bool> VerifyOtpAsync(string phoneNumber, string code);
        string GenerateJwtToken(User user);
    }

    public class AuthService : IAuthService
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly ISmsService _smsService;

        public AuthService(AppDbContext context, IConfiguration configuration, ISmsService smsService)
        {
            _context = context;
            _configuration = configuration;
            _smsService = smsService;
        }

        public async Task<string> GenerateOtpAsync(string phoneNumber)
        {
            var random = new Random();
            var code = random.Next(100000, 999999).ToString();

            var useMock = _configuration.GetValue<bool>("Twilio:UseMockSms");
            if (useMock)
            {
                try
                {
                    // Write to local project directory for easy developer retrieval
                    var filePath = Path.Combine(Directory.GetCurrentDirectory(), "otp_code.txt");
                    File.WriteAllText(filePath, $"Telefon: {phoneNumber}\nDogrulama Kodu: {code}\nTarih: {DateTime.Now}");
                }
                catch (Exception) { }
            }

            var hashedCode = HashOtp(code);

            // Set expiry to 5 minutes from now
            var otpCode = new OtpCode
            {
                PhoneNumber = phoneNumber,
                Code = hashedCode,
                ExpiryTime = DateTime.UtcNow.AddMinutes(5),
                CreatedAt = DateTime.UtcNow
            };

            _context.OtpCodes.Add(otpCode);
            await _context.SaveChangesAsync();

            // Send real SMS (falls back to simulator internally if config is missing)
            await _smsService.SendSmsAsync(phoneNumber, $"Berberim verification code: {code}. This code is valid for 5 minutes.");

            return code;
        }

        public async Task<bool> VerifyOtpAsync(string phoneNumber, string code)
        {
            var hashedCode = HashOtp(code);
            var useMock = _configuration.GetValue<bool>("Twilio:UseMockSms");

            var otpRecord = await _context.OtpCodes
                .FirstOrDefaultAsync(o => o.PhoneNumber == phoneNumber && o.Code == hashedCode && (useMock || !o.IsUsed));

            if (otpRecord == null)
            {
                return false;
            }

            if (otpRecord.ExpiryTime < DateTime.UtcNow)
            {
                return false;
            }

            // Mark code as used so it cannot be used again
            otpRecord.IsUsed = true;
            await _context.SaveChangesAsync();

            return true;
        }

        private string HashOtp(string code)
        {
            using var sha256 = System.Security.Cryptography.SHA256.Create();
            var bytes = Encoding.UTF8.GetBytes(code);
            var hashBytes = sha256.ComputeHash(bytes);
            return Convert.ToHexString(hashBytes);
        }

        public string GenerateJwtToken(User user)
        {
            var jwtSettings = _configuration.GetSection("JwtSettings");
            var secretKey = jwtSettings["Secret"] ?? throw new InvalidOperationException("JWT Secret not configured.");
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.MobilePhone, user.PhoneNumber),
                new Claim(ClaimTypes.Role, user.Role),
                new Claim(ClaimTypes.Name, user.FullName ?? string.Empty)
            };

            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: jwtSettings["Issuer"],
                audience: jwtSettings["Audience"],
                claims: claims,
                expires: DateTime.UtcNow.AddDays(double.Parse(jwtSettings["ExpiryInDays"] ?? "30")),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}
