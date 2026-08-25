import { HttpClient, httpResource } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import type {
  Category,
  Expense,
  ExpenseRequest,
  PageResponse,
  Summary,
} from './expense.models';

/**
 * ที่อยู่ของ API
 *
 * ตอน dev เว้นว่างไว้ แล้วให้ proxy.conf.json ส่ง /api ไปที่ localhost:8080
 * ตอน deploy ตั้งค่าใน index.html เป็น origin เต็ม เช่น https://api.example.com
 *
 * ทำเป็นค่า runtime ไม่ใช่ build-time เพื่อให้ build ชุดเดียวย้ายไปหลาย
 * environment ได้โดยไม่ต้อง compile ใหม่ — แค่แก้บรรทัดเดียวใน index.html
 */
const API_BASE =
  (globalThis as { __API_BASE__?: string }).__API_BASE__?.replace(/\/$/, '') ?? '';

const API = `${API_BASE}/api/expenses`;

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

@Injectable({ providedIn: 'root' })
export class ExpenseService {
  private readonly http = inject(HttpClient);

  // ── ตัวกรอง เป็น signal เพื่อให้ httpResource ยิงใหม่เองเมื่อค่าเปลี่ยน ──
  readonly from = signal(isoDate(new Date(Date.now() - 30 * 864e5)));
  readonly to = signal(isoDate(new Date()));
  readonly category = signal<Category | ''>('');
  readonly page = signal(0);
  readonly size = signal(20);

  /** บวกค่านี้เพื่อบังคับให้โหลดใหม่หลังเพิ่ม/แก้/ลบ */
  private readonly revision = signal(0);

  /**
   * รายการค่าใช้จ่าย
   *
   * httpResource ใช้กับ GET เท่านั้น ส่วน mutation ใช้ HttpClient ตรง ๆ
   * ตามที่เอกสาร Angular แนะนำ
   */
  readonly list = httpResource<PageResponse<Expense>>(
    () => {
      this.revision();
      const params: Record<string, string | number> = {
        from: this.from(),
        to: this.to(),
        page: this.page(),
        size: this.size(),
      };
      const c = this.category();
      if (c) params['category'] = c;
      return { url: API, method: 'GET', params };
    },
    { defaultValue: { items: [], page: 0, size: 20, totalItems: 0, totalPages: 0 } },
  );

  readonly summary = httpResource<Summary>(
    () => {
      this.revision();
      return {
        url: `${API}/summary`,
        method: 'GET',
        params: { from: this.from(), to: this.to() },
      };
    },
    { defaultValue: { from: '', to: '', grandTotal: 0, byCategory: [] } },
  );

  readonly loading = computed(() => this.list.isLoading() || this.summary.isLoading());

  // ── mutation ────────────────────────────────────────────────────────────

  async create(body: ExpenseRequest): Promise<void> {
    await firstValueFrom(this.http.post<Expense>(API, body));
    this.refresh();
  }

  async update(id: string, body: ExpenseRequest): Promise<void> {
    await firstValueFrom(this.http.put<Expense>(`${API}/${id}`, body));
    this.refresh();
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete<void>(`${API}/${id}`));
    this.refresh();
  }

  /** กลับหน้าแรกเมื่อเปลี่ยนตัวกรอง ไม่งั้นอาจค้างอยู่หน้าที่ไม่มีข้อมูลแล้ว */
  resetPage(): void {
    this.page.set(0);
  }

  private refresh(): void {
    this.revision.update((n) => n + 1);
  }
}
