import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface Socio {
  id: number;
  nome: string;
}

@Injectable({ providedIn: 'root' })
export class SocioService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = `${environment.apiBaseUrl}/soci`;

  getSoci(): Observable<Socio[]> {
    return this.http.get<Socio[]>(this.apiUrl);
  }

  creaSocio(nome: string): Observable<Socio> {
    return this.http.post<Socio>(this.apiUrl, { nome });
  }
}
