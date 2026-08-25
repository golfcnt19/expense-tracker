import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ExpenseService } from './expense.service';
import {
  CATEGORIES,
  CATEGORY_LABEL,
  type ApiError,
  type Category,
  type Expense,
} from './expense.models';

@Component({
  selector: 'app-root',
  imports: [FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  protected readonly svc = inject(ExpenseService);

  protected readonly categories = CATEGORIES;
  protected readonly label = CATEGORY_LABEL;

  // ── ฟอร์ม ──────────────────────────────────────────────────────────────
  protected readonly editingId = signal<string | null>(null);
  // input[type=number] ผูกกับ ngModel แล้วคืนค่าเป็น number ไม่ใช่ string
  // ประกาศให้ตรงกับความจริง ไม่งั้นเรียกเมธอดของ string แล้วพัง
  protected readonly amount = signal<number | null>(null);
  protected readonly category = signal<Category>('FOOD');
  protected readonly note = signal<string>('');
  protected readonly spentOn = signal<string>(new Date().toISOString().slice(0, 10));

  protected readonly saving = signal(false);
  protected readonly errors = signal<Record<string, string>>({});
  protected readonly generalError = signal<string>('');

  protected readonly isEditing = computed(() => this.editingId() !== null);

  /** สัดส่วนของแต่ละหมวดสำหรับวาดแถบ */
  protected readonly bars = computed(() => {
    const s = this.svc.summary.value();
    const max = Math.max(...s.byCategory.map((c) => c.total), 1);
    return s.byCategory.map((c) => ({ ...c, pct: (c.total / max) * 100 }));
  });

  protected async save(): Promise<void> {
    this.errors.set({});
    this.generalError.set('');

    // ช่องว่างเปล่า ngModel จะให้ null มา ไม่ใช่ 0
    const raw = this.amount();
    const amount = raw === null ? NaN : Number(raw);
    if (Number.isNaN(amount) || amount <= 0) {
      this.errors.set({ amount: 'กรอกจำนวนเงินมากกว่า 0' });
      return;
    }

    this.saving.set(true);
    const body = {
      amount,
      category: this.category(),
      note: this.note().trim() || null,
      spentOn: this.spentOn(),
    };

    try {
      const id = this.editingId();
      if (id) {
        await this.svc.update(id, body);
      } else {
        await this.svc.create(body);
      }
      this.resetForm();
    } catch (e: unknown) {
      this.applyServerError(e);
    } finally {
      this.saving.set(false);
    }
  }

  /** แสดง error รายฟิลด์ที่ API ส่งกลับมา ไม่ใช่แค่ข้อความรวม */
  private applyServerError(e: unknown): void {
    const body = (e as { error?: ApiError })?.error;
    if (body?.fieldErrors && Object.keys(body.fieldErrors).length > 0) {
      this.errors.set(body.fieldErrors);
      return;
    }
    this.generalError.set(body?.message ?? 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
  }

  protected edit(e: Expense): void {
    this.editingId.set(e.id);
    this.amount.set(e.amount);
    this.category.set(e.category);
    this.note.set(e.note ?? '');
    this.spentOn.set(e.spentOn);
    this.errors.set({});
    this.generalError.set('');
  }

  protected async remove(e: Expense): Promise<void> {
    if (!confirm(`ลบรายการ ${e.amount} บาท (${this.label[e.category]}) ?`)) return;
    try {
      await this.svc.remove(e.id);
      if (this.editingId() === e.id) this.resetForm();
    } catch {
      this.generalError.set('ลบไม่สำเร็จ');
    }
  }

  protected resetForm(): void {
    this.editingId.set(null);
    this.amount.set(null);
    this.category.set('FOOD');
    this.note.set('');
    this.spentOn.set(new Date().toISOString().slice(0, 10));
    this.errors.set({});
    this.generalError.set('');
  }

  // ── ตัวกรอง ────────────────────────────────────────────────────────────

  protected onFilterChange(): void {
    this.svc.resetPage();
  }

  protected prevPage(): void {
    this.svc.page.update((p) => Math.max(0, p - 1));
  }

  protected nextPage(): void {
    const total = this.svc.list.value().totalPages;
    this.svc.page.update((p) => Math.min(total - 1, p + 1));
  }

  protected money(n: number): string {
    return n.toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }
}
