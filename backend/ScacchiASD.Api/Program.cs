using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.EntityFrameworkCore;
using ScacchiASD.Api.Data;

// "--migra": applica le migration e termina, senza avviare il sito.
// Lo usa il lavoro delle migration su Azure Container Apps, a ogni rilascio.
var soloMigration = args.Contains("--migra");

var builder = WebApplication.CreateBuilder(args.Where(a => a != "--migra").ToArray());

builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Application Insights nei container: su App Service lo collega Azure da solo (agente),
// in un container va collegato dal codice. Azure Container Apps imposta da sola le variabili
// CONTAINER_APP_NAME (app) e CONTAINER_APP_JOB_NAME (lavoro): fuori dai container non si attiva.
var inContainerApps =
  !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CONTAINER_APP_NAME")) ||
  !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CONTAINER_APP_JOB_NAME"));
if (inContainerApps && !string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
{
  builder.Services.AddOpenTelemetry().UseAzureMonitor();
}

// Stringa di connessione: appsettings.<Ambiente>.json (Development, Staging, Production).
// Su Azure non c'e' nessuna password: l'app entra nel database con la sua identita' gestita di Azure.
builder.Services.AddDbContext<ScacchiASDContext>(options =>
  options.UseSqlServer(
    builder.Configuration.GetConnectionString("ScacchiASD"),
    // Il database gratuito di Azure va in pausa dopo 60 minuti senza uso e ci mette
    // fino a circa un minuto a ripartire: intanto riprovo invece di dare errore.
    sql => sql.EnableRetryOnFailure(
      maxRetryCount: 10,
      maxRetryDelay: TimeSpan.FromSeconds(30),
      errorNumbersToAdd: null)));

var app = builder.Build();

if (soloMigration)
{
  ApplicaMigration(app);
  // Chiude i servizi in modo ordinato (anche l'invio dei log ad Application Insights).
  await app.DisposeAsync();
  return;
}

// Migration all'avvio fuori dal dev (in dev si lanciano a mano, vedi README).
// Su App Service avviene ancora qui. Nei container e' spento (Database__MigraAllAvvio=false):
// lo fa il lavoro delle migration prima di aggiornare l'app, cosi' l'avvio non aspetta il database.
if (!app.Environment.IsDevelopment() && app.Configuration.GetValue("Database:MigraAllAvvio", true))
{
  ApplicaMigration(app);
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

static void ApplicaMigration(WebApplication app)
{
  using var scope = app.Services.CreateScope();
  scope.ServiceProvider.GetRequiredService<ScacchiASDContext>().Database.Migrate();
}
