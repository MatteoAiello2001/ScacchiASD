# ScacchiASD

Web app per la gestione dell'ASD di scacchi. Frontend Angular, backend ASP.NET Core con Entity Framework Core, database SQL Server.

```
ws-scacchiasd/
├── .github/     CI (workflows/ci.yml), rilascio (workflows/deploy.yml), merge automatico di Dependabot (workflows/dependabot-automatico.yml), Dependabot (dependabot.yml)
├── backend/     Soluzione .NET (ScacchiASD.slnx) con il progetto ScacchiASD.Api
├── frontend/    Angular
├── infra/       script di creazione delle risorse Azure
├── startup-dev.ps1   avvia il dev (backend + frontend)
└── stop-dev.ps1      ferma il dev
```

## Come si lavora

Due branch fissi, entrambi protetti (niente push diretto, solo pull request con i controlli verdi):

| Branch    | È sempre uguale a | Ci si arriva con |
|-----------|-------------------|------------------|
| `staging` | ciò che c'è in **staging** | PR di sviluppo e di Dependabot, **Squash and merge** |
| `main`    | ciò che c'è in **produzione** | PR `staging` → `main`, **Create a merge commit** (l'unica permessa: così i due branch restano collegati) |

`staging` è il branch principale del repo: le PR nuove si aprono lì di default. Per sapere cosa è in staging ma non ancora in prod basta confrontare i due branch (in Sourcetree o su GitHub: `main...staging`).

1. Parti da `staging` aggiornato e crea un branch:
   - `feature/<descrizione>` per una funzionalità nuova (es. `feature/anagrafica-soci`)
   - `fix/<descrizione>` per una correzione (es. `fix/nome-vuoto`)
   - `chore/<descrizione>` per manutenzione, configurazione, aggiornamenti
2. Committa sul branch e fai push.
3. Apri una pull request verso `staging`.
4. La CI (GitHub Actions) controlla backend e frontend. Si fa merge solo con entrambi i controlli verdi.
5. **Squash and merge**: il branch si cancella da solo e staging si aggiorna da solo.
6. Per portare in produzione: PR da `staging` a `main` → **Create a merge commit** → la produzione si aggiorna da sola.

Correzione urgente in produzione: branch da `main`, PR verso `main`, poi la stessa correzione va riportata su `staging` (PR `main` → `staging`).

### Cosa controlla la CI

| Job        | Controlli                                                                                     |
|------------|-----------------------------------------------------------------------------------------------|
| `Backend`  | formattazione (`dotnet format`), build, nessuna migration mancante rispetto ai modelli         |
| `Frontend` | formattazione (Prettier), build di produzione, test                                           |

Per non scoprire gli errori solo sulla pull request, gli stessi controlli si lanciano in locale (vedi [Controlli prima del push](#controlli-prima-del-push)).

### Dipendenze

Dependabot apre ogni lunedì, **su `staging`**, pull request raggruppate con gli aggiornamenti di NuGet, npm e GitHub Actions. Le major di Angular sono escluse: si fanno a mano con `ng update`.

Il workflow **Dependabot automatico** (`.github/workflows/dependabot-automatico.yml`) gestisce da solo gli aggiornamenti **piccoli** (correzioni e versioni minori): aspetta i controlli verdi, fa il merge su `staging` e avvia il rilascio su staging. Gli aggiornamenti **grandi** (salti di versione) restano aperti da guardare a mano. In produzione arrivano solo con la PR `staging` → `main`.

## Ambienti

| Ambiente    | Branch | Indirizzo | Server database | Database | `ASPNETCORE_ENVIRONMENT` |
|-------------|--------|-----------|-----------------|----------|--------------------------|
| Development | il proprio branch | http://localhost:4201 | `localhost` (il proprio PC) | `ScacchiASD` | `Development` |
| Staging     | `staging` | https://scacchiasd-staging-ffh9gyhjgsdcbcgd.italynorth-01.azurewebsites.net | `scacchiasd-sql-staging.database.windows.net` | `ScacchiASD` | `Staging` |
| Production  | `main` | https://scacchiasd-c7gxdch7amgsb4cf.italynorth-01.azurewebsites.net | `scacchiasd-sql.database.windows.net` | `ScacchiASD` | `Production` |

Il database si chiama uguale in tutti gli ambienti: cambia solo il server. Staging e prod hanno ciascuno il proprio server e il proprio database: le prove su staging non toccano i dati di prod.

- Dev: la stringa di connessione è in `backend/ScacchiASD.Api/appsettings.Development.json`. Il backend entra con il proprio utente Windows.
- Staging e prod: la stringa di connessione è in `appsettings.Staging.json` / `appsettings.Production.json` e **non contiene password**. L'app entra nel database con la sua identità gestita di Azure (utente `scacchiasd-staging` / `scacchiasd` nel database, con i ruoli `db_datareader`, `db_datawriter`, `db_ddladmin`).

Il frontend chiede al backend (`/api/info`) in che ambiente si trova e che versione è. Nell'header compaiono la scritta gialla dell'ambiente (non in prod) e la versione (es. `2026.11.13-42`, in dev `locale`).

## Rilascio

```
merge su staging ──► Pacchetto ──► Staging    ──► controllo
merge su main    ──► Pacchetto ──► Produzione ──► controllo
```

1. Un merge su `staging` o su `main` fa partire il workflow **Deploy** (`.github/workflows/deploy.yml`).
2. **Pacchetto**: compila frontend e backend con la versione `AAAA.MM.GG-<numero esecuzione>`.
3. **Staging** (da `staging`) o **Produzione** (da `main`): pubblica il pacchetto. Il merge su `main` è l'approvazione per la produzione.
4. **Controllo**: chiama `/api/info` e verifica che il sito risponda con la versione appena pubblicata; se no, il rilascio diventa rosso.

Staging e produzione partono dallo stesso codice ma ognuno ha il proprio pacchetto, compilato al momento del merge (quindi con un numero di versione diverso). Lo storico dei rilasci (cosa c'è in ogni ambiente, con il commit) è in **Settings → Environments** o nella pagina del repo, sezione *Deployments*. Il rilascio si può lanciare anche a mano: **Actions → Deploy → Run workflow**, scegliendo il branch.

All'avvio l'app applica da sola le migration mancanti al suo database.

## Azure

Tutto sta nel gruppo di risorse `rg-scacchiasd` (Italy North):

| Risorsa                         | Ambiente | Cosa è                                                      |
|---------------------------------|----------|-------------------------------------------------------------|
| `plan-scacchiasd`               | entrambi | piano App Service F1 (gratuito), condiviso dalle due app    |
| `scacchiasd`                    | prod     | App Service: il sito (backend + frontend)                   |
| `scacchiasd-staging`            | staging  | App Service: il sito                                        |
| `scacchiasd`                    | prod     | Application Insights: errori e richieste del sito           |
| `scacchiasd-staging`            | staging  | Application Insights (tetto di 100 MB di dati al giorno)    |
| `scacchiasd-sql` / `ScacchiASD` | prod     | server SQL (solo autenticazione Microsoft Entra) e database, offerta gratuita |
| `scacchiasd-sql-staging` / `ScacchiASD` | staging | come sopra                                       |
| `id-scacchiasd-github`          | prod     | identità con cui GitHub Actions pubblica su prod            |
| `id-scacchiasd-github-staging`  | staging  | identità con cui GitHub Actions pubblica su staging (non può toccare prod) |
| `la-scacchiasd-sveglia`         | entrambi | Logic App: ogni 10 minuti chiama `/api/info` di prod e staging, così le app non si spengono |

Staging è stato creato con `infra/crea-staging.ps1`: lo script documenta cosa esiste su Azure e su GitHub (environment `staging`). In seguito `production` si pubblica solo da `main`, senza altra approvazione: il merge su `main` è l'approvazione.

Limiti del piano gratuito:
- App: 60 minuti di CPU al giorno; l'app si spegne dopo circa 20 minuti senza visite e la prima pagina dopo è lenta (circa 2 minuti). Per evitarlo la Logic App `la-scacchiasd-sveglia` (creata con `infra/crea-sveglia.ps1`) chiama ogni 10 minuti `/api/info` di prod e staging: non usa il database, quindi non consuma le sue ore. Costo circa 0,20 € al mese. Cronologia: portale Azure → `la-scacchiasd-sveglia` → **Cronologia esecuzioni**.
- Database: va in pausa dopo 60 minuti senza uso (fisso con l'offerta gratuita). Quota di 100.000 secondi vCore al mese, circa 55 ore di database acceso; se finisce, il database si sospende fino al mese successivo. Ogni database (staging e prod) ha la sua quota.

### Accesso ai database da SSMS

| Campo          | Valore |
|----------------|--------|
| Server name    | `scacchiasd-sql.database.windows.net` (prod) o `scacchiasd-sql-staging.database.windows.net` (staging) |
| Authentication | Microsoft Entra MFA, con il proprio account amministratore |
| Encryption     | Mandatory |

Il firewall del server accetta solo Azure e gli indirizzi IP aggiunti a mano: se cambia l'IP di casa, va aggiunto in **server SQL → Rete → Aggiungi l'indirizzo IPv4 client**.

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
