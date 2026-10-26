import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { SociPage } from './soci';

describe('SociPage', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SociPage],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();
  });

  it('mostra i soci restituiti dal backend', async () => {
    const fixture = TestBed.createComponent(SociPage);
    TestBed.inject(HttpTestingController)
      .expectOne('/api/soci')
      .flush([{ id: 1, nome: 'Mario Rossi' }]);
    await fixture.whenStable();
    fixture.detectChanges();

    const el = fixture.nativeElement as HTMLElement;
    expect(el.querySelector('li')?.textContent).toContain('Mario Rossi');
  });
});
