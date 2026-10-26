namespace ScacchiASD.Api.Models;

public class Socio
{
  public const int NomeMaxLength = 200;

  public int Id { get; set; }
  public string Nome { get; set; } = string.Empty;
}
