import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

// Ambiente (Development, Staging, Production) e versione, letti dal backend.
export interface InfoApp {
  ambiente: string;
  versione: string;
}

@Injectable({ providedIn: 'root' })
export class InfoService {
  private readonly http = inject(HttpClient);

  getInfo(): Observable<InfoApp> {
    return this.http.get<InfoApp>(`${environment.apiBaseUrl}/info`);
  }
}
