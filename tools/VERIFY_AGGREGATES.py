#!/usr/bin/env python3
"""Verify the immutable aggregate evidence behind the October 2026 research note.

Standard library only. No respondent-level files are read. This is an arithmetic,
consistency and provenance gate; it does not constitute econometric re-estimation.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

REFERENCE = {'N': 104848, 'people': 12644, 'psus': 1511, 'strata': 122}
MAIN = {
    ('save', 'ages18_34'): 4.19498766576891,
    ('save', 'ages35_59'): 0.39271012688986,
    ('save', 'young_minus_older'): 3.80227753887905,
    ('next_save', 'ages18_34'): -5.15463,
    ('next_save', 'ages35_59'): -3.06883,
    ('next_minus_current', 'ages18_34'): -9.34962,
    ('next_minus_current', 'ages35_59'): -3.46154,
    ('next_minus_current', 'young_minus_older'): -5.88808,
}

def require(condition, message):
    if not condition:
        raise ValueError(message)


def table(path):
    require(path.is_file(), f'Missing aggregate file: {path}')
    with path.open('r', newline='', encoding='utf-8-sig') as handle:
        return list(csv.DictReader(handle))


def yes(s):
    return str(s).strip().lower() in ('true', '1', 'yes', 'pass')


def close(a, b, tolerance=1e-7):
    return abs(float(a) - float(b)) <= tolerance


def baseline(root, full):
    base = root / 'aggregate_results' / 'supplementary_final_20261019_204702'
    require(base.is_dir(), f'Supplementary snapshot is absent: {base}')
    stages = table(base/'STAGE_STATUS.csv')
    require(len(stages)==9 and all(x['status']=='PASS' for x in stages), 'Supplementary run must have exactly nine PASS stages')
    require(len({x['stage'] for x in stages})==9, 'Duplicate stage labels')
    pre = table(base/'BASELINE_CANONICAL_REPLICATION.csv')
    require(len(pre)==9, 'Nine BHPS baseline contrasts required')
    found = set()
    for r in pre:
        key=(r['outcome'], r['contrast'])
        require(key not in found, f'Duplicate precheck {key}')
        found.add(key)
        for col,val in REFERENCE.items(): require(int(r[col])==val, f'Wrong baseline {col} in {key}')
        require(yes(r['pass']), f'Baseline gate failed for {key}')
        require(close(r['calculated_pp'],r['frozen_pp'],1e-5), f'Baseline coefficient moved for {key}')
        require(close(r['calculated_SE_pp'],r['frozen_SE_pp'],1e-5), f'Baseline SE moved for {key}')
        if key in MAIN: require(close(r['calculated_pp'], MAIN[key],2e-5),f'Wrong original BHPS estimate {key}')
    require(len(found)==9,'Incorrect keys for baseline')
    vals=table(base/'REGRESSION_CONTRASTS.csv')
    require(len(vals)==96, 'Expecting all 96 contrasts from the completed v1.1 run')
    keys=set()
    for r in vals:
        key=(r['stage'],r['specification'],r['outcome'],r['comparison'])
        require(key not in keys, f'Duplicate supplementary contrast {key}')
        keys.add(key)
        est,se,lo,hi=[float(r[c]) for c in ('estimate','se','lo95','hi95')]
        require(lo<=est<=hi and se >= 0,'Broken estimate, SE, or CI: '+str(key))
        require(int(r['N']) >= int(r['people']) > 0,'Invalid sample counts in '+str(key))
        require(int(r['psus'])-int(r['strata'])==int(r['survey_df']), 'Wrong survey df '+str(key))
        scale=100 if r['outcome_scale']=='probability' else 1
        require(close(float(r['estimate_display']),est*scale,1e-7), 'Broken display units '+str(key))
        require(close(float(r['lo95_display']),lo*scale,1e-7), 'Broken CI display units '+str(key))
    expected_stage_n={
        '01_CANONICAL_PRECHECK':9,'03B_GROSS_PERSONAL_INCOME':18,
        '03C_GROSS_HOUSEHOLD_INCOME':18,'03D_EMPLOYMENT_TRANSITIONS':6,
        '04_MONTHLY_SAVING_AMOUNTS':9,'05_AMOUNTS_CONTINUING_SAVERS':3,
        '06_AGE_HETEROGENEITY':33,
    }
    for s,n in expected_stage_n.items():
        require(sum(r['stage']==s for r in vals)==n, f'Unexpected number of rows in {s}')
    # The same-sample saving amount transformation must satisfy the timing identity.
    def locate(stage,spec,outcome,contrast):
        z=[r for r in vals if (r['stage'],r['specification'],r['outcome'],r['comparison'])==(stage,spec,outcome,contrast)]
        require(len(z)==1, 'Missing unique row '+str((stage,spec,outcome,contrast)))
        return z[0]
    for g in ('ages18_34','ages35_59','young_minus_older'):
        k=('04_MONTHLY_SAVING_AMOUNTS','exact_same_amount_valid_pairs')
        y0=float(locate(*k,'amt_ihs_t','pess_'+g)['estimate'])
        y1=float(locate(*k,'amt_ihs_t1','pess_'+g)['estimate'])
        dy=float(locate(*k,'amt_ihs_change','pess_'+g)['estimate'])
        require(close(dy,y1-y0,1e-8),f'Saving amount identity failed for {g}')
        require(int(locate(*k,'amt_ihs_change','pess_'+g)['N'])==98054,'Wrong amount N')
    for name, nrows in [('RESOURCE_SOURCE_AUDIT.csv',18),('HETEROGENEITY_TESTS.csv',3)]:
        require(len(table(base/name))==nrows, f'Wrong number of rows: {name}')
    for r in table(base/'RESOURCE_SOURCE_AUDIT.csv'):
        require(yes(r['gross_person_col_in_indresp']),f'Missing personal gross income field, wave {r["wave"]}')
        require(yes(r['gross_household_col_in_hhresp']),f'Missing household gross income field, wave {r["wave"]}')
        require(int(r['valid_gross_person_income'])==int(r['canonical_endpoint_rows_needed']),f'Incomplete gross income coverage wave {r["wave"]}')
    coverage=table(base/'COVERAGE_AUDIT.csv')
    require(len(coverage)>50,'Coverage audit unexpectedly short')
    for r in coverage:
        require(0<=int(r['valid_n'])<=int(r['n']), 'Invalid sample-coverage counts')
    report=(base/'FINAL_CHECKS_REPORT.md').read_text(encoding='utf-8')
    require('Completed stages: 9; failed stages: 0' in report, 'Supplementary status report is not the successful run')
    print('[PASS] v1.1 supplementary: 9 stages; 96 contrasts; 9 canonical matches; survey CIs and amount identities')
    if not full: return
    pydir = root/'aggregate_results'/'canonical_python_20261016_140555'
    ref=table(pydir/'CANONICAL_REPLAY_COEFFICIENT_COMPARISON.csv')
    require(len(ref)==21,'Canonical Python must contain exactly 21 contrasts')
    require(all(yes(r['pass']) for r in ref),'Original Python replay contains a failed comparison')
    require(len({(r['model'],r['outcome'],r['contrast']) for r in ref})==21,'Duplicate Python contrast')
    py_report=(pydir/'CANONICAL_REPLAY_REPORT.md').read_text(encoding='utf-8')
    require('Canonical replay: PASS' in py_report,'Canonical Python replay report is not PASS')
    for r in table(pydir/'CANONICAL_REPLAY_SAMPLE_SUMMARY.csv'):
        if r['model']=='BHPS_gross_published_lw':
            for k,v in REFERENCE.items(): require(int(r[k])==v,'Canonical sample summary mismatch '+k)
    rd=root/'aggregate_results'/'independent_r_20261016_144150'
    rrows=table(rd/'R_CANONICAL_COEFFICIENT_CHECK.csv')
    require(len(rrows)==21,'Independent R verification must contain exactly 21 contrasts')
    require(len({(r['model'],r['outcome'],r['contrast']) for r in rrows})==21,'Duplicate R contrast')
    require(all(yes(r['point_pass']) and yes(r['survey_se_pass']) and yes(r['complete_term_count_pass']) for r in rrows), 'R verification failure')
    rreport=(rd/'R_CANONICAL_VERIFICATION_REPORT.md').read_text(encoding='utf-8')
    require('Status: PASS' in rreport, 'Independent R report is not PASS')
    q=root/'aggregate_results'/'optimism_20261019_100019'/'BHPS_CANONICAL_OPTIMISM.csv'
    o=table(q)
    require(len(o)==9,'Expected nine canonical optimism contrasts')
    print('[PASS] frozen canonical Python: 21/21; independent R: 21/21; optimism: 9 rows')


def verify_zip_contents(path):
    import zipfile
    with zipfile.ZipFile(path) as z:
        members=z.namelist()
        require('manifest.json' in members,'Original Codex archive missing its own manifest')
        orig=json.loads(z.read('manifest.json').decode('utf-8-sig'))
        required={'analysis/prepare_pilot.py','analysis/checks/prepare_checks.py',
                  'analysis/checks/run_remaining.py','analysis/checks/check_stats.py',
                  'analysis/checks/results/resource_weight_estimates.csv'}
        require(required <= set(members),'Original archive missing canonical source/result members')
        require(set(orig) <= set(members),'Archived internal manifest has absent files')
        for name, rec in orig.items():
            data=z.read(name)
            require(len(data)==int(rec['bytes']),f'Original archive byte size mismatch {name}')
            require(hashlib.sha256(data).hexdigest()==rec['sha256'],f'Original archive member changed {name}')
            low=name.lower()
            require(not (low.endswith(('.tab','.dta','.sav','.pkl','.pickle','.rds','.parquet')) or 'private_model_ready' in low),f'Private-data member in original archive: {name}')
    print(f'[PASS] Original Codex ZIP: {len(orig)} embedded SHA256 member checks')


def manifest_check(root):
    mf=root/'SHA256_MANIFEST.csv'
    if not mf.exists(): return
    records=table(mf)
    actual={p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p!=mf}
    names={r['path'] for r in records}
    require(names==set(actual),'Release hash manifest does not cover exactly its files')
    for r in records:
        p=actual[r['path']]
        require(int(r['size_bytes'])==p.stat().st_size and hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'],f'Hash verification failed {p}')
    print(f'[PASS] Whole release manifest: {len(records)} files SHA256 matched')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release_root',type=Path)
    parser.add_argument('--full',action='store_true',help='also check canonical Python, R, optimism, source archive and file SHA256 manifest')
    args=parser.parse_args()
    root=args.release_root.resolve()
    try:
        baseline(root,args.full)
        if args.full:
            verify_zip_contents(root/'code'/'original_codex'/'canonical_original_20261016.zip')
            manifest_check(root)
    except (ValueError,KeyError,FileNotFoundError,IndexError) as e:
        print('[FAIL]',e)
        return 2
    print('[PASS] All requested aggregate and integrity gates passed')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
