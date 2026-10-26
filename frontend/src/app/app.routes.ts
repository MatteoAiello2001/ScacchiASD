import { Routes } from '@angular/router';
import { SociPage } from './pages/soci/soci';

export const routes: Routes = [
  { path: '', component: SociPage },
  { path: '**', redirectTo: '' },
];
