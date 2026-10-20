"""Re-estimate ONLY canonical headline model families with unchanged Codex code.

This file is additional diagnostic code. It does not modify canonical scripts.
Licensed row-level samples are written only to FP_CANONICAL_LOCAL_SAMPLES.
Public output comprises aggregate coefficient and sample comparison tables only.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PUBLIC = Path(os.environ['FP_CANONICAL_PUBLIC_OUT']).resolve()
PRIVATE = Path(os.environ['FP_CANONICAL_LOCAL_SAMPLES']).resolve()
PUBLIC.mkdir(parents=True, exist_ok=True)
PRIVATE.mkdir(parents=True, exist_ok=True)

def abort_if_cloud_private(path: Path):
    parts = {part.lower() for part in path.parts}
    if parts & {'dropbox', 'onedrive', 'google drive', 'google_drive'}:
        raise RuntimeError('Refusing to write respondent-level files to cloud-synced path: ' + str(path))

abort_if_cloud_private(PRIVATE)

# Canonical supplied modules live beside this helper. Do not edit their source.
sys.path.insert(0, str(HERE))
from run_remaining import make_panel  # noqa: E402
from check_stats import fit, contrast, synthetic_check  # noqa: E402

ARCHIVED = HERE / 'results' / 'resource_weight_estimates.csv'
if not ARCHIVED.is_file():
    raise FileNotFoundError('Codex saved reference result missing: ' + str(ARCHIVED))
original = pd.read_csv(ARCHIVED)
expected_cols = {'model','outcome','contrast','N','persons','effect','se','lo95','hi95','psus','strata'}
missing = expected_cols - set(original.columns)
if missing:
    raise RuntimeError('Canonical reference CSV missing columns: ' + ','.join(sorted(missing)))

CONTRASTS = [
    ('ages18_34', {'pess':1, 'pess_young':1}),
    ('ages35_59', {'pess':1}),
    ('young_minus_older', {'pess_young':1}),
]

# Sample-selection algorithm copied (not imported) from canonical check_stats.fit,
# solely for exporting the *exact* rows to a private local CSV for later R checking.
# It is asserted against the true canonical estimator N and person count.
def matching_sample(frame, outcomes, terms, weight, minT=2):
    cols = list(dict.fromkeys(outcomes + terms +
        ['pidp','timecell','pess','source','wave','psu','strata',weight]))
    a = frame[cols].replace([np.inf, -np.inf], np.nan).dropna().copy()
    a = a[a[weight] > 0].copy()
    while True:
        keep = ((a.groupby('pidp').pidp.transform('size') >= minT) &
                (a.groupby('timecell').pidp.transform('size') >= 2))
        if bool(keep.all()):
            break
        a = a[keep].copy()
    return a


def csv_sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda:f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def main():
    print('[CANONICAL] Synthetic estimator/covariance check', flush=True)
    synthetic_check()
    print('[CANONICAL] Reconstructing original canonical model panel from local private cache', flush=True)
    q, short, individual, gross, net = make_panel()
    obs = q[q.response == 1]
    b = obs[obs.source == 'BHPS'].copy()
    u = obs[obs.source == 'UKHLS'].copy()
    ut = u[u.previous_gap.between(6,18) & u.previous_save.notna()].copy()
    print('[CANONICAL] Eligible observed baseline pairs: BHPS=', len(b),
          ' UKHLS=',len(u),' UKHLS strict=',len(ut),flush=True,sep='')

    specs = [
      ('BHPS_gross_published_lw', b,
       ['save','next_save','next_minus_current'],'next_published_pair_weight',
       'BHPS_CANONICAL_SAMPLE_LOCAL.csv'),
      ('UKHLS_gross_published_lw', u,
       ['next_save'],'next_published_pair_weight',
       'UKHLS_CANONICAL_SAMPLE_LOCAL.csv'),
      ('UKHLS_gross_timing_published_lw', ut,
       ['previous_save','next_save','next_minus_previous'],'next_published_trip_weight',
       'UKHLS_STRICT_CANONICAL_SAMPLE_LOCAL.csv'),
    ]

    results=[]
    sample_audit=[]
    for model, frame, outcomes, weight, filename in specs:
        print('\n[CANONICAL] MODEL', model, flush=True)
        print('  Initial observed baseline pairs:',len(frame),flush=True)
        canonical_fit = fit(frame, outcomes, gross, weight=weight, fe=True, design=True, minT=2)
        local_sample = matching_sample(frame, outcomes, gross, weight)
        assert len(local_sample) == canonical_fit['N'], (model,'sample N mismatch',len(local_sample),canonical_fit['N'])
        assert local_sample.pidp.nunique() == canonical_fit['persons'], (model,'person mismatch')
        assert len(local_sample) == len(local_sample[['pidp','source','wave']].drop_duplicates()), (model,'duplicate individual-wave')
        local_sample = local_sample.copy()
        local_sample['w_fit'] = local_sample[weight] / local_sample[weight].mean()
        local_path = PRIVATE / filename
        local_sample.to_csv(local_path,index=False,float_format='%.17g')
        print('  Canonical sample:',canonical_fit['N'],'pairs,',canonical_fit['persons'],'people;',
              canonical_fit['psus'],'PSUs,',canonical_fit['strata'],'strata',flush=True)
        print('  Private model-ready sample:', local_path,flush=True)
        sample_audit.append(dict(model=model,eligible_observed_N=len(frame),N=int(canonical_fit['N']),
            people=int(canonical_fit['persons']),psus=int(canonical_fit['psus']),
            strata=int(canonical_fit['strata']),effective_N=float(canonical_fit['effective_N']),
            n_terms=len(canonical_fit['terms']),fit_iterations=int(canonical_fit['iterations']),
            local_csv_sha256=csv_sha256(local_path)))
        for outcome in outcomes:
            for name,ct in CONTRASTS:
                val=contrast(canonical_fit,outcome,ct)
                rows=original[(original.model==model)&(original.outcome==outcome)&(original.contrast==name)]
                if len(rows)!=1:
                    raise RuntimeError('Expected exactly one archived reference row for '+str((model,outcome,name)))
                ref=rows.iloc[0]
                out=dict(model=model,outcome=outcome,contrast=name,
                    N=canonical_fit['N'],persons=canonical_fit['persons'],
                    psus=canonical_fit['psus'],strata=canonical_fit['strata'],
                    effect=val['effect'],se=val['se'],lo95=val['lo95'],hi95=val['hi95'],
                    ref_N=int(ref.N),ref_persons=int(ref.persons),
                    ref_psus=int(ref.psus),ref_strata=int(ref.strata),
                    ref_effect=float(ref.effect),ref_se=float(ref.se),
                    ref_lo95=float(ref.lo95),ref_hi95=float(ref.hi95),
                    gap_estimate_pp=100*(val['effect']-float(ref.effect)),
                    gap_se_pp=100*(val['se']-float(ref.se)))
                out['sample_match']=(out['N']==out['ref_N'] and out['persons']==out['ref_persons'])
                out['design_match']=(out['psus']==out['ref_psus'] and out['strata']==out['ref_strata'])
                out['estimate_match_1e-7']=(abs(out['gap_estimate_pp'])<1e-5) # 1e-7 in probability units
                out['se_match_1e-7']=(abs(out['gap_se_pp'])<1e-5)
                out['pass']=(out['sample_match'] and out['design_match'] and
                             out['estimate_match_1e-7'] and out['se_match_1e-7'])
                results.append(out)
                if name=='ages18_34':
                    print(f"  {outcome}: young={100*val['effect']:+.5f} pp (ref {100*ref.effect:+.5f}); "
                          f"SE={100*val['se']:.5f} (ref {100*ref.se:.5f})",flush=True)
    table=pd.DataFrame(results)
    sample=pd.DataFrame(sample_audit)
    table.to_csv(PUBLIC/'CANONICAL_REPLAY_COEFFICIENT_COMPARISON.csv',index=False)
    sample.to_csv(PUBLIC/'CANONICAL_REPLAY_SAMPLE_SUMMARY.csv',index=False)
    gate=bool(table['pass'].all())
    report=[
      '# Financial pessimism: canonical code replay',
      '',f'Generated: {datetime.now().astimezone().isoformat(timespec="seconds")}',
      '',f'**Canonical replay: {"PASS" if gate else "MISMATCH—INVESTIGATE"}**',
      '',f'- Comparisons: {len(table)} coefficients (three contrasts per outcome).',
      '- This replay uses the actual Codex sample builder and weighted FE/stratified PSU estimator.',
      '- Baseline panel extract and all licensed data remained on the local Windows data drive.',
      '- This does NOT establish independent R equivalence yet: the private model-ready CSV files are the inputs for that next check.',
      '', '## Model sample sizes',
      '', '| Model | Observations | Individuals | PSUs | Strata |',
      '|---|---:|---:|---:|---:|',
    ]
    for r in sample_audit:
        report.append(f"| {r['model']} | {r['N']:,} | {r['people']:,} | {r['psus']:,} | {r['strata']:,} |")
    report+=['',f"- Maximum point-estimate discrepancy: {table['gap_estimate_pp'].abs().max():.8g} percentage points.",
              f"- Maximum SE discrepancy: {table['gap_se_pp'].abs().max():.8g} percentage points.",
              '', '## Next',
              'Compare independent R estimation on the exact locally saved canonical sample.',
              'Do not publish or upload any file ending `_LOCAL.csv`.',
              '']
    (PUBLIC/'CANONICAL_REPLAY_REPORT.md').write_text('\n'.join(report),encoding='utf-8')
    print('\n[CANONICAL] Aggregate report:',PUBLIC/'CANONICAL_REPLAY_REPORT.md',flush=True)
    print('[CANONICAL] RESULT:', 'PASS' if gate else 'MISMATCH',flush=True)
    return 0 if gate else 2

if __name__=='__main__':
    try:
        sys.exit(main())
    except Exception as e:
        # Keep traceback local, not in aggregate output (paths and file names may be private).
        import traceback
        traceback.print_exc()
        sys.exit(1)
