using System.ComponentModel.DataAnnotations;
using ScacchiASD.Api.Models;

namespace ScacchiASD.Api.Dtos;

public record CreaSocioRequest(
  [Required(AllowEmptyStrings = false)]
  [StringLength(Socio.NomeMaxLength, MinimumLength = 1)]
  string Nome);
