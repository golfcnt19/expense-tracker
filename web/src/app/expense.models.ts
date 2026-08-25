/** ชนิดข้อมูลฝั่ง client ให้ตรงกับที่ API ส่งมา */

export const CATEGORIES = [
  'FOOD',
  'TRANSPORT',
  'HOUSING',
  'UTILITIES',
  'HEALTH',
  'ENTERTAINMENT',
  'OTHER',
] as const;

export type Category = (typeof CATEGORIES)[number];

export interface Expense {
  id: string;
  amount: number;
  category: Category;
  note: string | null;
  spentOn: string;
  createdAt: string;
  updatedAt: string;
}

export interface ExpenseRequest {
  amount: number;
  category: Category;
  note?: string | null;
  spentOn: string;
}

export interface PageResponse<T> {
  items: T[];
  page: number;
  size: number;
  totalItems: number;
  totalPages: number;
}

export interface CategoryTotal {
  category: Category;
  total: number;
  count: number;
}

export interface Summary {
  from: string;
  to: string;
  grandTotal: number;
  byCategory: CategoryTotal[];
}

/** รูปแบบ error ที่ API ส่งกลับมา */
export interface ApiError {
  status: number;
  error: string;
  message: string;
  fieldErrors?: Record<string, string>;
  timestamp: string;
}

/** ป้ายภาษาไทยของแต่ละหมวด */
export const CATEGORY_LABEL: Record<Category, string> = {
  FOOD: 'อาหาร',
  TRANSPORT: 'เดินทาง',
  HOUSING: 'ที่อยู่อาศัย',
  UTILITIES: 'สาธารณูปโภค',
  HEALTH: 'สุขภาพ',
  ENTERTAINMENT: 'บันเทิง',
  OTHER: 'อื่น ๆ',
};
