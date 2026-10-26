using Microsoft.EntityFrameworkCore;
using ScacchiASD.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

// In dev la stringa di connessione e' in appsettings.Development.json.
// In prod non e' nel repo: la fornisce Azure (impostazione "ConnectionStrings:ScacchiASD").
builder.Services.AddDbContext<ScacchiASDContext>(options =>
  options.UseSqlServer(builder.Configuration.GetConnectionString("ScacchiASD")));

var app = builder.Build();

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
