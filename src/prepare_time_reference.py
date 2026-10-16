"""Independent time-series expectations from the reconciled monthly reference."""
from pathlib import Path
from decimal import Decimal, ROUND_HALF_UP
import csv

ROOT=Path(__file__).resolve().parents[1]


def main():
    with (ROOT/'outputs/monthly_expected.csv').open(encoding='utf-8-sig',newline='') as f:
        source={r['Period']:r for r in csv.DictReader(f)}
    key=lambda i:f'{i//12}-{i%12+1:02d}'
    fmt=lambda n:'' if n is None else str(n.quantize(Decimal('.000001'),rounding=ROUND_HALF_UP))
    records=[]
    for month,row in sorted(source.items()):
        y,m=map(int,month.split('-'));index=y*12+m-1
        value=Decimal(row['SalesRevenue']);complete=month!='2011-12'
        changes=[]
        for offset in [1,12]:
            prior=key(index-offset);denominator=Decimal(source[prior]['SalesRevenue']) if prior in source else None
            changes.append((value-denominator)/denominator*100 if complete and denominator and prior!='2011-12' else None)
        ytd=sum(Decimal(r['SalesRevenue']) for k,r in source.items() if k[:4]==month[:4] and k<=month)
        window=[key(index-i) for i in range(3)]
        avg=sum(Decimal(source[k]['SalesRevenue']) for k in window)/3 if complete and all(k in source for k in window) else None
        records.append([month,value,int(complete),fmt(changes[0]),fmt(changes[1]),fmt(ytd),fmt(avg)])
    with (ROOT/'outputs/time_reference.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f);w.writerow(['Period','SalesRevenue','WithinObservedCoverage','MoMPercent','YoYPercent','ObservedYTD','MovingAverage3Months']);w.writerows(records)
    print('Prepared 25 monthly comparisons independently; this is not a SQL execution receipt.')


if __name__=='__main__':main()
