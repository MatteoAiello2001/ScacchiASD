import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Socio, SocioService } from '../../services/socio.service';

@Component({
  selector: 'app-soci',
  imports: [FormsModule],
  templateUrl: './soci.html',
  styleUrl: './soci.css',
})
export class SociPage {
  private readonly socioService = inject(SocioService);

  protected readonly nomeMaxLength = 200;
  protected readonly soci = signal<Socio[]>([]);
  protected readonly caricamento = signal(true);
  protected readonly errore = signal<string | null>(null);
  protected readonly invioInCorso = signal(false);
  protected nuovoNome = '';

  constructor() {
    this.caricaSoci();
  }

  protected caricaSoci(): void {
    this.socioService.getSoci().subscribe({
      next: (soci) => {
        this.soci.set(soci);
        this.caricamento.set(false);
      },
      error: () => {
        this.caricamento.set(false);
        this.errore.set('Impossibile caricare i soci.');
      },
    });
  }

  protected aggiungiSocio(): void {
    const nome = this.nuovoNome.trim();
    if (!nome) return;

    this.invioInCorso.set(true);
    this.errore.set(null);

    this.socioService.creaSocio(nome).subscribe({
      next: () => {
        this.nuovoNome = '';
        this.invioInCorso.set(false);
        this.caricaSoci();
      },
      error: () => {
        this.invioInCorso.set(false);
        this.errore.set('Impossibile salvare il socio. Riprova.');
      },
    });
  }
}
