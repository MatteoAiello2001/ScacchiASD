# Ricetta del container del sito: frontend Angular + backend ASP.NET Core in un'unica immagine.
# Tre passi: 1) compila il frontend, 2) compila il backend, 3) immagine finale leggera con solo
# il necessario per far girare il sito (niente strumenti di compilazione).
# La costruisce GitHub Actions (CI e rilascio); in locale: docker build -t scacchiasd .

FROM node:24-alpine AS frontend
WORKDIR /src/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS backend
# Versione del rilascio (es. 2026.11.20-5), la passa il workflow; si vede nell'header del sito.
ARG VERSIONE=locale
WORKDIR /src/backend
COPY backend/ScacchiASD.Api/ScacchiASD.Api.csproj ScacchiASD.Api/
RUN dotnet restore ScacchiASD.Api/ScacchiASD.Api.csproj
COPY backend/ ./
RUN dotnet publish ScacchiASD.Api/ScacchiASD.Api.csproj --configuration Release --no-restore --output /app \
  -p:InformationalVersion=$VERSIONE -p:IncludeSourceRevisionInInformationalVersion=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS finale
LABEL org.opencontainers.image.source=https://github.com/MatteoAiello2001/ScacchiASD
WORKDIR /app
COPY --from=backend /app ./
COPY --from=frontend /src/frontend/dist/frontend/browser ./wwwroot
# Il sito gira come utente senza privilegi (gia' previsto dall'immagine .NET), sulla porta 8080.
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "ScacchiASD.Api.dll"]
