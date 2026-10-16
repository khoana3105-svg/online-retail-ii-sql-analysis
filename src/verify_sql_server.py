"""Reconcile executed T-SQL with independent aggregate references, using Decimal."""
from pathlib import Path
from decimal import Decimal
import csv
import json
import hashlib
from datetime import date

ROOT = Path(__file__).resolve().parents[1]


def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def main():
    live = ROOT / 'outputs/sql_server'
    if not (live / 'execution.json').is_file():
        raise SystemExit('SQL execution has not completed. Run src/run_sql_server.ps1 and wait for its success message before verification.')
    manifest = json.loads((live / 'execution.json').read_text(encoding='utf-8-sig'))
    results = [(x, rows(live / x['File'])) for x in manifest['ResultSets']]
    expected = {r['Period']:r for r in rows(ROOT / 'outputs/monthly_expected.csv')}
    checks = []
    def find(column, required=()):
        matches = [r for m,r in results if m['Source']=='02_thuc_hanh.sql' and column in m['Columns']
                   and all(k in m['Columns'] for k in required)]
        assert len(matches)==1,(column,len(matches))
        return matches[0]
    monthly = find('SalesMonth', ('EligibleRows',))
    assert len(monthly)==len(expected)==25
    for r in monthly:
        key=f"{int(r['SalesYear'])}-{int(r['SalesMonth']):02d}"
        for field in ['NetRecordedValue','PositiveRecordedValue','NegativeRecordedValue','SalesRevenue','EligibleRows']:
            assert Decimal(r[field])==Decimal(expected[key][field]),(key,field)
    checks.append('25 monthly SQL periods exactly match independent Decimal expectations')
    quarterly_expected={r['Period']:r for r in rows(ROOT/'outputs/quarterly_expected.csv')}
    quarterly=find('SalesQuarter')
    assert len(quarterly)==len(quarterly_expected)
    for r in quarterly:
        key=f"{r['SalesYear']}-Q{r['SalesQuarter']}"
        for field in ['NetRecordedValue','PositiveRecordedValue','NegativeRecordedValue','SalesRevenue','EligibleRows']:
            assert Decimal(r[field])==Decimal(quarterly_expected[key][field]),(key,field)
    checks.append('Quarterly totals reconcile with monthly and independent expectations')
    overall=find('RawRows')[0]
    assert int(overall['RawRows'])==1067371 and int(overall['EligibleRows'])==1061164
    assert Decimal(overall['SalesRevenue'])==sum(Decimal(r['SalesRevenue']) for r in expected.values())
    assert Decimal(overall['NetRecordedValue'])==Decimal(overall['PositiveRecordedValue'])+Decimal(overall['NegativeRecordedValue'])
    checks.append('Raw/eligible/excluded counts and signed-value reconciliation')
    advanced=rows(live/'03_time_comparisons_01.csv')
    assert len(advanced)==25
    def close(actual, reference):
        if reference is None:assert actual=='',actual
        else:assert abs(Decimal(actual)-reference)<=Decimal('.00001'),(actual,reference)
    for r in advanced:
        month=r['MonthStart'][:7]
        y,m=map(int,month.split('-'))
        index=y*12+m-1
        key=lambda i:f'{i//12}-{i%12+1:02d}'
        value=Decimal(expected[month]['SalesRevenue'])
        close(r['SalesRevenue'],value)
        close(r['NetRecordedValue'],Decimal(expected[month]['NetRecordedValue']))
        complete=month!='2011-12'
        assert int(r['WithinObservedCoverage'])==int(complete)
        for offset,field in [(1,'MoMPercent'),(12,'YoYPercent')]:
            prior=key(index-offset)
            ref=None
            if prior in expected and complete and prior!='2011-12':
                denominator=Decimal(expected[prior]['SalesRevenue'])
                if denominator:ref=(value-denominator)/denominator*100
            close(r[field],ref)
        close(r['ObservedYTD'],sum(Decimal(v['SalesRevenue']) for k,v in expected.items() if k[:4]==month[:4] and k<=month))
        window=[key(index-i) for i in range(3)]
        moving=sum(Decimal(expected[k]['SalesRevenue']) for k in window)/3 if complete and all(k in expected for k in window) else None
        close(r['MovingAverage3Months'],moving)
    checks.append('CTE/window MoM, YoY, observed YTD, moving average and incomplete-month NULLs')
    same=rows(live/'03_time_comparisons_02.csv')
    totals={year:sum(Decimal(v['SalesRevenue']) for k,v in expected.items() if k[:4]==year and k[5:]<='11') for year in ['2010','2011']}
    for r in same:
        close(r['JanToNovSalesRevenue'],totals[r['SalesYear']])
        close(r['SamePeriodGrowthPercent'],None if r['SalesYear']=='2010' else (totals['2011']-totals['2010'])/totals['2010']*100)
    checks.append('Same Jan-Nov population reconciles across years')
    countries=rows(live/'03_time_comparisons_03.csv')
    close(str(sum(Decimal(r['SalesRevenue']) for r in countries)),sum(Decimal(v['SalesRevenue']) for v in expected.values()))
    assert abs(sum(Decimal(r['SampleSalesSharePercent']) for r in countries)-100)<Decimal('.0001')
    checks.append('Country sales total and shares reconcile')
    report={'status':'passed','database':manifest['Database'],'executed_at_utc':manifest['ExecutedAtUTC'],
            'sql_server_version':manifest['SqlServerVersion'],'checks':checks,
            'sql_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'sql').glob('*.sql'))},
            'limitations':['No fresh workbook download comparison','No accounting ledger reconciliation','Date-span coverage does not prove daily completeness']}
    (live/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
