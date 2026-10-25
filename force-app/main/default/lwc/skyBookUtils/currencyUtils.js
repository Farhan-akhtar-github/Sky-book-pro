export function formatCurrency(amount, currencyCode = 'USD') {
    if (amount === undefined || amount === null || isNaN(amount)) {
        amount = 0;
    }
    try {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: currencyCode
        }).format(amount);
    } catch (e) {
        return `${currencyCode} ${Number(amount).toFixed(2)}`;
    }
}
