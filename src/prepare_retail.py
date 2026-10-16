"""Export both XLSX sheets and independently reconcile the SQL exercise.

Standard library only. Run from any directory: python src/prepare_retail.py
No source workbook is modified. Outputs are regenerated in data/processed and outputs.
"""
from pathlib import Path
import csv
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from contextlib import closing
import hashlib
import json
import sqlite3
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
import os
SOURCE = Path(os.environ.get('RETAIL_SOURCE_XLSX', ROOT / 'data/raw/online_retail_II.xlsx'))
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
HEADERS = ['Invoice', 'StockCode', 'Description', 'Quantity', 'InvoiceDate',
           'Price', 'Customer ID', 'Country']
CSV_HEADERS = ['SourceSheet', 'SourceRow', 'Invoice', 'StockCode', 'Description',
               'Quantity', 'InvoiceDate', 'Price', 'CustomerID', 'Country']


def rows(archive, sheet_path, strings):
    """Stream XML; clear completed rows to bound memory use."""
    with archive.open(sheet_path) as stream:
        root = None
        sheet_data = None
        for event, element in ET.iterparse(stream, events=('start', 'end')):
            if event == 'start':
                if root is None:
                    root = element
                if element.tag == f"{{{NS['m']}}}sheetData":
                    sheet_data = element
                continue
            if element.tag != f"{{{NS['m']}}}row":
                continue
            values = [''] * 8
            for cell in element:
                letters = ''.join(c for c in cell.get('r', '') if c.isalpha())
                index = 0
                for char in letters:
                    index = index * 26 + ord(char) - ord('A') + 1
                if not 1 <= index <= 8:
                    continue
                value = cell.find('m:v', NS)
                text = value.text if value is not None else ''
                if cell.get('t') == 's':
                    text = strings[int(text)]
                elif cell.get('t') == 'inlineStr':
                    text = ''.join(cell.itertext())
                values[index - 1] = text or ''
            yield int(element.get('r')), values
            element.clear()
            if sheet_data is not None:
                sheet_data.clear()


def write_csv(path, headers, records):
    with path.open('w', encoding='utf-8', newline='') as stream:
        writer = csv.writer(stream, lineterminator='\n')
        writer.writerow(headers)
        writer.writerows(records)


def main():
    processed = ROOT / 'data' / 'processed'
    output = ROOT / 'outputs'
    processed.mkdir(parents=True, exist_ok=True)
    output.mkdir(exist_ok=True)
    counts = Counter()
    sheets = Counter()
    missing = Counter()
    monthly = defaultdict(lambda: [0, 0, 0, 0, 0])
    quarterly = defaultdict(lambda: [0, 0, 0, 0, 0])
    dates = []
    minmax = {}
    # Integer millionths provide exact arithmetic matching SQL decimal(19,6).
    scale = Decimal(1_000_000)
    def add(bucket, quantity, price_units, is_sale):
        value = quantity * price_units
        bucket[0] += value
        bucket[1] += max(value, 0)
        bucket[2] += min(value, 0)
        bucket[3] += value if is_sale else 0
        bucket[4] += 1

    with tempfile.TemporaryDirectory(prefix='retail_audit_') as temp, closing(
            sqlite3.connect(str(Path(temp) / 'audit.sqlite'))) as db:
        db.execute('CREATE TABLE line_keys (signature TEXT NOT NULL)')
        with zipfile.ZipFile(SOURCE) as archive, (processed / 'retail_raw.csv').open(
                'w', encoding='utf-8', newline='') as stream:
            writer = csv.writer(stream, lineterminator='\n')
            writer.writerow(CSV_HEADERS)
            strings = []
            with archive.open('xl/sharedStrings.xml') as shared:
                for _, element in ET.iterparse(shared, events=('end',)):
                    if element.tag == f"{{{NS['m']}}}si":
                        strings.append(''.join(t.text or '' for t in element.iter(f"{{{NS['m']}}}t")))
                        element.clear()
            workbook = ET.fromstring(archive.read('xl/workbook.xml'))
            props = workbook.find('m:workbookPr', NS)
            if props is not None and props.get('date1904') in ('1', 'true'):
                raise ValueError('1904 date system not supported by this export.')
            sheet_names = [s.get('name') for s in workbook.find('m:sheets', NS)]
            if sheet_names != ['Year 2009-2010', 'Year 2010-2011']:
                raise ValueError(f'Unexpected sheets: {sheet_names}')
            relationships = ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))
            targets = {r.get('Id'): r.get('Target') for r in relationships}
            batch = []
            for sheet in workbook.find('m:sheets', NS):
                sheet_name = sheet.get('name')
                target = targets[sheet.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')]
                path = target.lstrip('/') if target.startswith('/') else 'xl/' + target
                for row_number, values in rows(archive, path, strings):
                    if row_number == 1:
                        if values != HEADERS:
                            raise ValueError(f'Unexpected columns: {values}')
                        continue
                    if not any(values):
                        counts['fully_blank_excel_rows_skipped'] += 1
                        continue
                    invoice, stock, description, quantity, date, price, customer, country = values
                    # XLSX stores dates as serial days; round to nearest second.
                    serial = Decimal(date)
                    seconds = int((serial * 86400).quantize(Decimal('1')))
                    timestamp = datetime(1899, 12, 30) + timedelta(seconds=seconds)
                    values[4] = timestamp.isoformat(timespec='seconds')
                    counts['rows'] += 1
                    sheets[sheet_name] += 1
                    for header, value in zip(HEADERS, values):
                        if not value.strip():
                            missing[header] += 1
                    q = Decimal(quantity)
                    p = Decimal(price)
                    if q != q.to_integral_value():
                        raise ValueError('Non-integer quantity found')
                    counts['price_rounded_to_six_decimals'] += int(p * scale != (p * scale).to_integral_value())
                    q = int(q)
                    p_units = int((p * scale).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
                    values[5] = format(p, 'f')
                    writer.writerow([sheet_name, row_number] + values)
                    is_cancel = invoice.strip().upper().startswith('C')
                    for name, condition in [('quantity_negative', q < 0), ('quantity_zero', q == 0),
                                            ('price_negative', p < 0), ('price_zero', p == 0),
                                            ('invoice_C', is_cancel), ('blank_invoice', not invoice.strip()),
                                            ('blank_stock', not stock.strip())]:
                        counts[name] += int(condition)
                    counts['valid_numeric_and_date'] += 1
                    eligible = bool(invoice.strip() and stock.strip() and p > 0 and q != 0)
                    counts['eligible_rows'] += int(eligible)
                    is_sale = q > 0 and not is_cancel
                    counts['positive_sale_rows'] += int(eligible and is_sale)
                    counts['C_positive_quantity'] += int(is_cancel and q > 0)
                    if eligible:
                        month = timestamp.strftime('%Y-%m')
                        quarter = f'{timestamp.year}-Q{(timestamp.month-1)//3+1}'
                        add(monthly[month], q, p_units, is_sale)
                        add(quarterly[quarter], q, p_units, is_sale)
                    dates.append(timestamp.date().isoformat())
                    for name, value in [('quantity', q), ('price', p)]:
                        if name not in minmax:
                            minmax[name] = [value, value]
                        minmax[name] = [min(minmax[name][0], value), max(minmax[name][1], value)]
                    signature = hashlib.sha256(json.dumps(values, ensure_ascii=False).encode()).hexdigest()
                    batch.append((signature,))
                    if len(batch) >= 10000:
                        db.executemany('INSERT INTO line_keys VALUES (?)', batch)
                        batch.clear()
                print(f'Exported {sheet_name}: {sheets[sheet_name]:,} rows', flush=True)
            db.executemany('INSERT INTO line_keys VALUES (?)', batch)
        db.commit()
        duplicates = db.execute('SELECT COUNT(*), COALESCE(SUM(n-1),0) FROM '
                               '(SELECT COUNT(*) n FROM line_keys GROUP BY signature HAVING COUNT(*)>1)').fetchone()
        db.close()
    def records(groups):
        for period, vals in sorted(groups.items()):
            yield [period] + [format(Decimal(v)/scale, '.6f') for v in vals[:4]] + [vals[4]]
    aggregate_headers = ['Period', 'NetRecordedValue', 'PositiveRecordedValue',
                         'NegativeRecordedValue', 'SalesRevenue', 'EligibleRows']
    write_csv(output / 'monthly_expected.csv', aggregate_headers, records(monthly))
    write_csv(output / 'quarterly_expected.csv', aggregate_headers, records(quarterly))
    assert sum(v[0] for v in monthly.values()) == sum(v[0] for v in quarterly.values())
    assert all(v[0] == v[1] + v[2] for v in monthly.values())
    with (processed / 'retail_raw.csv').open(encoding='utf-8', newline='') as stream:
        reader = csv.reader(stream)
        assert next(reader) == CSV_HEADERS
        reread_rows = 0
        for row in reader:
            assert len(row) == len(CSV_HEADERS)
            reread_rows += 1
        assert reread_rows == counts['rows']
    report = {'source': SOURCE.name, 'sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'counts': dict(counts), 'sheet_rows': dict(sheets), 'missing': dict(missing),
              'date_min': min(dates), 'date_max': max(dates),
              'min_max': {k: [str(x) for x in v] for k, v in minmax.items()},
              'duplicate_groups': duplicates[0], 'duplicate_extra_rows': duplicates[1],
              'duplicate_policy': 'Keep: no transaction-line identifier to prove accidental duplication.',
              'totals': list(records({'ALL': [sum(v[i] for v in monthly.values()) for i in range(5)]}))[0],
              'checks': {'csv_reread_rows': reread_rows, 'monthly_equals_quarterly': True,
                         'net_equals_positive_plus_negative': True},
              'sql_server_execution': 'Independent preparation only; see outputs/sql_server/ for separately executed SQL checks.'}
    (output / 'data_profile.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == '__main__':
    main()
