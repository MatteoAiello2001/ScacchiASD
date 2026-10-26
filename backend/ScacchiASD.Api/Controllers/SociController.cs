using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ScacchiASD.Api.Data;
using ScacchiASD.Api.Dtos;
using ScacchiASD.Api.Models;

namespace ScacchiASD.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SociController(ScacchiASDContext context) : ControllerBase
{
  [HttpGet]
  public async Task<ActionResult<IReadOnlyList<SocioDto>>> GetAll(CancellationToken ct)
  {
    var soci = await context.Soci
      .AsNoTracking()
      .OrderBy(s => s.Nome)
      .Select(s => new SocioDto(s.Id, s.Nome))
      .ToListAsync(ct);

    return Ok(soci);
  }

  [HttpGet("{id:int}")]
  public async Task<ActionResult<SocioDto>> GetById(int id, CancellationToken ct)
  {
    var socio = await context.Soci
      .AsNoTracking()
      .Where(s => s.Id == id)
      .Select(s => new SocioDto(s.Id, s.Nome))
      .FirstOrDefaultAsync(ct);

    return socio is null ? NotFound() : Ok(socio);
  }

  [HttpPost]
  public async Task<ActionResult<SocioDto>> Create(CreaSocioRequest request, CancellationToken ct)
  {
    var nome = request.Nome.Trim();
    if (nome.Length == 0)
    {
      ModelState.AddModelError(nameof(request.Nome), "Il nome non può essere vuoto.");
      return ValidationProblem(ModelState);
    }

    var socio = new Socio { Nome = nome };
    context.Soci.Add(socio);
    await context.SaveChangesAsync(ct);

    var dto = new SocioDto(socio.Id, socio.Nome);
    return CreatedAtAction(nameof(GetById), new { id = dto.Id }, dto);
  }
}
