import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { App } from './app';

describe('App', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])],
    }).compileComponents();
  });

  async function creaConInfo(ambiente: string, versione: string) {
    const fixture = TestBed.createComponent(App);
    TestBed.inject(HttpTestingController).expectOne('/api/info').flush({ ambiente, versione });
    await fixture.whenStable();
    fixture.detectChanges();
    return fixture.nativeElement as HTMLElement;
  }

  it('mostra il titolo', async () => {
    const el = await creaConInfo('Production', '2026.11.13-1');
    expect(el.querySelector('h1')?.textContent).toContain('ScacchiASD');
  });

  it('in staging mostra la scritta STAGING e la versione', async () => {
    const el = await creaConInfo('Staging', '2026.11.13-42');
    expect(el.querySelector('.ambiente')?.textContent).toContain('Staging');
    expect(el.querySelector('.versione')?.textContent).toContain('2026.11.13-42');
  });

  it('in prod mostra solo la versione, senza scritta', async () => {
    const el = await creaConInfo('Production', '2026.11.13-42');
    expect(el.querySelector('.ambiente')).toBeNull();
    expect(el.querySelector('.versione')?.textContent).toContain('2026.11.13-42');
  });
});
