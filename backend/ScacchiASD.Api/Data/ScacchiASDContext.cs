using Microsoft.EntityFrameworkCore;
using ScacchiASD.Api.Models;

namespace ScacchiASD.Api.Data;

public class ScacchiASDContext(DbContextOptions<ScacchiASDContext> options) : DbContext(options)
{
  public DbSet<Socio> Soci => Set<Socio>();

  protected override void OnModelCreating(ModelBuilder modelBuilder)
  {
    modelBuilder.Entity<Socio>(entity =>
    {
      entity.ToTable("Soci");

      entity.Property(s => s.Nome)
        .IsRequired()
        .HasMaxLength(Socio.NomeMaxLength);
    });
  }
}
