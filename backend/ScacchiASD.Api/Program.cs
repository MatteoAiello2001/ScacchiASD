using Microsoft.EntityFrameworkCore;
using ScacchiASD.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Stringa di connessione: appsettings.Development.json in dev, appsettings.Production.json in prod.
// In prod non c'e' nessuna password: l'app entra nel database con la sua identita' gestita di Azure.
builder.Services.AddDbContext<ScacchiASDContext>(options =>
  options.UseSqlServer(
    builder.Configuration.GetConnectionString("ScacchiASD"),
    // Il database gratuito di Azure va in pausa dopo 15 minuti senza uso e ci mette
    // fino a circa un minuto a ripartire: intanto riprovo invece di dare errore.
    sql => sql.EnableRetryOnFailure(
      maxRetryCount: 10,
      maxRetryDelay: TimeSpan.FromSeconds(30),
      errorNumbersToAdd: null)));

var app = builder.Build();

// Fuori dal dev le migration le applica l'app all'avvio. In dev si lanciano a mano (vedi README).
if (!app.Environment.IsDevelopment())
{
  using var scope = app.Services.CreateScope();
  scope.ServiceProvider.GetRequiredService<ScacchiASDContext>().Database.Migrate();
}

if (app.Environment.IsDevelopment())
{
  app.MapOpenApi();

  // In sviluppo il frontend gira a parte (npm start) e chiama il backend tramite il proxy.
  app.UseHttpsRedirection();
}

// In prod il backend serve anche il frontend compilato (cartella wwwroot): un unico pacchetto da rilasciare.
app.UseDefaultFiles();
app.UseStaticFiles();

app.UseAuthorization();
app.MapControllers();

// Qualsiasi percorso che non sia /api e non sia un file (nonfile = senza estensione) restituisce index.html.
app.MapFallbackToFile("{*path:nonfile:regex(^(?!api(/|$)).*$)}", "index.html");

app.Run();
