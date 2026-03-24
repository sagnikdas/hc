/// Formats [d] as 'YYYY-MM-DD' for SQLite date columns and streak logic.
String dateToDbString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
