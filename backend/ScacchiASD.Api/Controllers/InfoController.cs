using System.Reflection;
using Microsoft.AspNetCore.Mvc;
using ScacchiASD.Api.Dtos;

namespace ScacchiASD.Api.Controllers;

// Dice al frontend in che ambiente gira e che versione e'. Non usa il database.
// Serve perche' staging e prod ricevono lo stesso identico pacchetto: e' il backend
// a sapere dove si trova (ASPNETCORE_ENVIRONMENT impostato su Azure).
[ApiController]
[Route("api/[controller]")]
public class InfoController(IWebHostEnvironment ambiente) : ControllerBase
{
  // La versione la imposta il workflow di rilascio (es. 2026.11.13-42).
  private static readonly string Versione =
    typeof(InfoController).Assembly
      .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "";

  [HttpGet]
  public InfoDto Get() =>
    new(ambiente.EnvironmentName, ambiente.IsDevelopment() ? "locale" : Versione);
}
