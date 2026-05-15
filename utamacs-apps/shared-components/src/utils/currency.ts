// Indian currency formatting utilities
// All monetary values in the system are stored as numbers in INR (paise = 0)

const INR_FORMATTER = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
});

const INR_COMPACT_FORMATTER = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  notation: 'compact',
  minimumFractionDigits: 0,
  maximumFractionDigits: 1,
});

export const formatINR = (amount: number): string => INR_FORMATTER.format(amount);

export const formatAmount = (amount: number, compact = false): string =>
  compact ? INR_COMPACT_FORMATTER.format(amount) : INR_FORMATTER.format(amount);

export const parseINR = (value: string): number => {
  const cleaned = value.replace(/[₹,\s]/g, '');
  const num = parseFloat(cleaned);
  return isNaN(num) ? 0 : num;
};
