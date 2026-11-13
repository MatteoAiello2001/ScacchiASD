import { Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { RouterOutlet } from '@angular/router';
import { catchError, of } from 'rxjs';
import { InfoService } from './services/info.service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  // Se /api/info non risponde l'header resta senza scritte: il resto del sito funziona.
  private readonly info = toSignal(
    inject(InfoService)
      .getInfo()
      .pipe(catchError(() => of(null))),
    { initialValue: null },
  );

  // Scritta gialla solo fuori da prod (DEVELOPMENT, STAGING).
  protected readonly ambiente = computed(() => {
    const ambiente = this.info()?.ambiente;
    return ambiente && ambiente !== 'Production' ? ambiente : null;
  });

  protected readonly versione = computed(() => this.info()?.versione ?? '');
}
