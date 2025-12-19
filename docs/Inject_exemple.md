import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface AppConfig {
  apiUrl: string;
}

@Injectable({ providedIn: 'root' })
export class SummaryService {
  private http = inject(HttpClient);
  private config = inject<any>('APP_CONFIG');

  private baseUrl = this.config.apiUrl;

  getMonthlySummary() {
    return this.http.get(`${this.baseUrl}/summary/monthly`);
  }
}