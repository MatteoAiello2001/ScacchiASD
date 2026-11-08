# ScacchiASD

Web app per la gestione dell'ASD di scacchi. Frontend Angular, backend ASP.NET Core con Entity Framework Core, database SQL Server.

```
ws-scacchiasd/
├── .github/     CI (workflows/ci.yml) e aggiornamenti automatici delle dipendenze (dependabot.yml)
├── backend/     Soluzione .NET (ScacchiASD.slnx) con il progetto ScacchiASD.Api
├── frontend/    Angular
├── startup-dev.ps1   avvia il dev (backend + frontend)
└── stop-dev.ps1      ferma il dev
```

## Come si lavora

`main` è protetto: non si fa push diretto, ci si arriva solo con una pull request.

1. Parti da `main` aggiornato e crea un branch:
   - `feature/<descrizione>` per una funzionalità nuova (es. `feature/anagrafica-soci`)
   - `fix/<descrizione>` per una correzione (es. `fix/nome-vuoto`)
   - `chore/<descrizione>` per manutenzione, configurazione, aggiornamenti
2. Committa sul branch e fai push.
3. Apri una pull request verso `main`.
4. La CI (GitHub Actions) controlla backend e frontend. Si fa merge solo con entrambi i controlli verdi.
5. Merge con **Squash and merge**, poi cancella il branch.

### Cosa controlla la CI

| Job        | Controlli                                                                                     |
|------------|-----------------------------------------------------------------------------------------------|
| `Backend`  | formattazione (`dotnet format`), build, nessuna migration mancante rispetto ai modelli         |
| `Frontend` | formattazione (Prettier), build di produzione, test                                           |

Per non scoprire gli errori solo sulla pull request, gli stessi controlli si lanciano in locale (vedi [Controlli prima del push](#controlli-prima-del-push)).

### Dipendenze

Dependabot apre ogni lunedì pull request raggruppate con gli aggiornamenti di NuGet, npm e GitHub Actions. Le major di Angular sono escluse: si fanno a mano con `ng update`.

## Ambienti

| Ambiente    | Server database               | Database     | Backend (`ASPNETCORE_ENVIRONMENT`) | Frontend (`--configuration`) |
|-------------|-------------------------------|--------------|------------------------------------|------------------------------|
| Development | `localhost` (il proprio PC)   | `ScacchiASD` | `Development`                      | `development`                |
| Production  | `scacchiasd-sql.database.windows.net` (Azure SQL, offerta gratuita) | `ScacchiASD` | `Production` | `production` |

Il database si chiama uguale in tutti gli ambienti: cambia solo il server.

- Dev: la stringa di connessione è in `backend/ScacchiASD.Api/appsettings.Development.json`. Il backend entra con il proprio utente Windows.
- Prod: la stringa di connessione è in `backend/ScacchiASD.Api/appsettings.Production.json` e **non contiene password**. L'app entra nel database con la sua identità gestita di Azure (utente `scacchiasd` nel database, con i ruoli `db_datareader`, `db_datawriter`, `db_ddladmin`).

In produzione il backend serve anche il frontend compilato (cartella `wwwroot`): si rilascia un unico pacchetto.

## Produzione (Azure)

Tutto sta nel gruppo di risorse `rg-scacchiasd` (Italy North):

| Risorsa                  | Cosa è                                                           |
|--------------------------|------------------------------------------------------------------|
| `plan-scacchiasd`        | piano App Service F1 (gratuito)                                  |
| `scacchiasd`             | App Service: il sito (backend + frontend)                        |
| `scacchiasd`             | Application Insights: errori e richieste del sito                |
| `scacchiasd-sql`         | server SQL (solo autenticazione Microsoft Entra)                 |
| `ScacchiASD`             | database, offerta gratuita (va in pausa dopo 15 minuti senza uso) |
| `id-scacchiasd-github`   | identità usata da GitHub Actions per rilasciare                  |

Il rilascio parte da solo a ogni merge su `main` (workflow `.github/workflows/deploy.yml`), oppure a mano da GitHub: **Actions → Deploy → Run workflow**. All'avvio l'app applica da sola le migration mancanti.

Limiti del piano gratuito: 60 minuti di CPU al giorno, l'app si spegne dopo circa 20 minuti senza visite (la prima pagina dopo è lenta), il database va in pausa dopo 15 minuti e si sospende fino al mese successivo se finisce la quota gratuita.

## Sviluppo locale

### Porte in sviluppo

| Pezzo    | Indirizzo                | Note                                                     |
|----------|--------------------------|----------------------------------------------------------|
| Backend  | https://localhost:7244   | quella da usare                                          |
| Backend  | http://localhost:5019    | stesso backend senza https (dal modello di .NET, non usata) |
| Frontend | http://localhost:4201    | `/api` viene girato al backend su 7244 dal proxy         |
| Database | SQL Server su `localhost` | database `ScacchiASD`                                   |

Il frontend usa la 4201 (non la 4200 predefinita di Angular) per poter girare insieme ad altri progetti Angular sullo stesso PC.

Tutto insieme (due finestre PowerShell: parte il backend, il frontend parte solo quando il backend risponde, poi si apre il browser). Il comando funziona sia da cmd sia da PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\startup-dev.ps1
```

Per fermare tutto (chiude le due finestre e libera le porte, anche se backend o frontend sono stati avviati a mano):

```powershell
powershell -ExecutionPolicy Bypass -File .\stop-dev.ps1
```

Oppure separatamente.

Backend (https://localhost:7244), da Visual Studio aprendo `backend/ScacchiASD.slnx` con il profilo `Development`, oppure:

```bash
cd backend
dotnet run --project ScacchiASD.Api --launch-profile Development
```

Frontend (http://localhost:4201). Le chiamate a `/api` vengono girate al backend dal proxy (`proxy.conf.json`):

```bash
cd frontend
npm install
npm start
```

## Database (migration EF Core)

Lo schema del database è definito nel backend (`Models/` e `Data/ScacchiASDContext.cs`). Le migration lo portano sul database.

Da `backend`:

```bash
dotnet tool restore
dotnet dotnet-ef database update --project ScacchiASD.Api
```

Dopo aver cambiato un modello, crea una nuova migration e applicala:

```bash
dotnet dotnet-ef migrations add NomeMigration --project ScacchiASD.Api
dotnet dotnet-ef database update --project ScacchiASD.Api
```

Le migration generate da EF usano 4 spazi: per riportarle a 2 spazi (`.editorconfig`), altrimenti la CI fallisce:

```bash
dotnet format ScacchiASD.slnx
```

## Test

```bash
cd frontend
npm test
```

## Controlli prima del push

Gli stessi controlli della CI.

Backend, da `backend`:

```bash
dotnet format ScacchiASD.slnx --verify-no-changes
dotnet build ScacchiASD.slnx
dotnet dotnet-ef migrations has-pending-model-changes --project ScacchiASD.Api
```

Se la formattazione non passa, `dotnet format ScacchiASD.slnx` la sistema.

Frontend, da `frontend`:

```bash
npm run format:check
npm run build
npm run test:ci
```

Se la formattazione non passa, `npm run format` la sistema.
