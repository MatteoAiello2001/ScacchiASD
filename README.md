# ScacchiASD

Web app per la gestione dell'ASD di scacchi. Frontend Angular, backend ASP.NET Core con Entity Framework Core, database SQL Server.

```
ws-scacchiasd/
├── .github/     CI (workflows/ci.yml) e aggiornamenti automatici delle dipendenze (dependabot.yml)
├── backend/     Soluzione .NET (ScacchiASD.slnx) con il progetto ScacchiASD.Api
├── frontend/    Angular
└── startup-dev.ps1
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
| Production  | Azure SQL (da configurare)    | `ScacchiASD` | `Production`                       | `production`                 |

Il database si chiama uguale in tutti gli ambienti: cambia solo il server.

- Dev: la stringa di connessione è in `backend/ScacchiASD.Api/appsettings.Development.json`.
- Prod: la stringa di connessione **non sta nel repo**. La fornisce Azure come impostazione `ConnectionStrings__ScacchiASD`.

In produzione il backend serve anche il frontend compilato (cartella `wwwroot`): si rilascia un unico pacchetto.

## Sviluppo locale

Tutto insieme (due finestre PowerShell, poi apre il browser):

```powershell
powershell -ExecutionPolicy Bypass -File .\startup-dev.ps1
```

Oppure separatamente.

Backend (https://localhost:7244), da Visual Studio aprendo `backend/ScacchiASD.slnx` con il profilo `Development`, oppure:

```bash
cd backend
dotnet run --project ScacchiASD.Api --launch-profile Development
```

Frontend (http://localhost:4200). Le chiamate a `/api` vengono girate al backend dal proxy (`proxy.conf.json`):

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
