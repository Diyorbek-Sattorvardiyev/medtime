export const formatNumber = (value?: number) => new Intl.NumberFormat('uz-UZ').format(value || 0);

export const formatDate = (value?: string | null) => {
  if (!value) return '-';
  return new Intl.DateTimeFormat('uz-UZ', { day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(value));
};

export const getErrorMessage = (error: unknown) => {
  if (typeof error === 'object' && error && 'response' in error) {
    const response = (error as { response?: { data?: { message?: string } } }).response;
    return response?.data?.message || 'Xatolik yuz berdi';
  }
  return 'Xatolik yuz berdi';
};
