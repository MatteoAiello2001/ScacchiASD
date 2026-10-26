# ScacchiASD

Web app per la gestione dell'ASD di scacchi. Frontend Angular, backend ASP.NET Core con Entity Framework Core, database SQL Server.

```
ws-scacchiasd/
├── backend/     Soluzione .NET (ScacchiASD.slnx) con il progetto ScacchiASD.Api
├── frontend/    Angular
└── startup-dev.ps1
```

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

Le migration generate da EF usano 4 spazi: per riportarle a 2 spazi (`.editorconfig`):

```bash
dotnet format whitespace ScacchiASD.slnx
```

## Test

```bash
cd frontend
npm test
```
