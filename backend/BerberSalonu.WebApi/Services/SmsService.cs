using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BerberSalonu.WebApi.Services
{
    public interface ISmsService
    {
        Task<bool> SendSmsAsync(string toPhoneNumber, string message);
    }

    public class TwilioSmsService : ISmsService
    {
        private readonly IConfiguration _config;
        private readonly ILogger<TwilioSmsService> _logger;

        public TwilioSmsService(IConfiguration config, ILogger<TwilioSmsService> logger)
        {
            _config = config;
            _logger = logger;
        }

        public async Task<bool> SendSmsAsync(string toPhoneNumber, string message)
        {
            var twilioSection = _config.GetSection("Twilio");
            var accountSid = Environment.GetEnvironmentVariable("TWILIO_ACCOUNT_SID") ?? twilioSection["AccountSid"];
            var authToken = Environment.GetEnvironmentVariable("TWILIO_AUTH_TOKEN") ?? twilioSection["AuthToken"];
            var fromNumber = Environment.GetEnvironmentVariable("TWILIO_FROM_PHONE_NUMBER") ?? twilioSection["FromPhoneNumber"];

            var useMockStr = Environment.GetEnvironmentVariable("TWILIO_USE_MOCK_SMS");
            var useMock = !string.IsNullOrEmpty(useMockStr) 
                ? bool.Parse(useMockStr) 
                : twilioSection.GetValue<bool>("UseMockSms");

            // If not configured or mock is requested, fallback to console simulation
            if (useMock ||
                string.IsNullOrWhiteSpace(accountSid) ||
                string.IsNullOrWhiteSpace(authToken) ||
                string.IsNullOrWhiteSpace(fromNumber) ||
                accountSid.Contains("YOUR_TWILIO_ACCOUNT_SID_HERE"))
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"\n[SMS SIMULATOR - MOCK SMS] To: {toPhoneNumber} | Message: {message} | Sent at: {DateTime.UtcNow.AddHours(3)}\n");
                Console.ResetColor();
                return true;
            }

            try
            {
                using var client = new HttpClient();
                var url = $"https://api.twilio.com/2010-04-01/Accounts/{accountSid}/Messages.json";

                var requestMessage = new HttpRequestMessage(HttpMethod.Post, url);
                
                // Add Basic Authentication header
                var authBytes = Encoding.ASCII.GetBytes($"{accountSid}:{authToken}");
                requestMessage.Headers.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(authBytes));

                var formData = new Dictionary<string, string>
                {
                    { "To", toPhoneNumber },
                    { "From", fromNumber },
                    { "Body", message }
                };

                requestMessage.Content = new FormUrlEncodedContent(formData);

                var response = await client.SendAsync(requestMessage);
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation($"[REAL SMS SENT] Successfully sent SMS to {toPhoneNumber} via Twilio.");
                    return true;
                }
                else
                {
                    var responseBody = await response.Content.ReadAsStringAsync();
                    _logger.LogError($"[REAL SMS FAILED] Twilio response: {response.StatusCode} - {responseBody}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"[REAL SMS ERROR] Failed to send SMS to {toPhoneNumber}");
                return false;
            }
        }
    }
}
