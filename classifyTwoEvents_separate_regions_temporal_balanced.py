import numpy as np
from pathlib import Path
from sklearn.svm import LinearSVC
from scipy.io import loadmat
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut, cross_val_predict
from sklearn.metrics import balanced_accuracy_score
import csv

single_unit_datapoint = 40  # 4 sec * 100ms bins = 40 features per single unit

TIME_WINDOWS = [(-7, -3), (-6, -2), (-5, -1), (-4, 0), (-3, 1),
                (-2, 2), (-1, 3), (0, 4), (1, 5), (2, 6)]


def loo_score_with_null(X, y, n_shuffles=100, random_state=516):
    """Run LOO classification and a label-shuffle null distribution."""
    clf = make_pipeline(
        StandardScaler(with_mean=True),
        LinearSVC(C=1.0, class_weight='balanced', dual=True, random_state=0)
    )
    cv = LeaveOneOut()

    # True accuracy
    y_pred = cross_val_predict(clf, X, y, cv=cv, n_jobs=-1)
    acc = balanced_accuracy_score(y, y_pred)

    # Null distribution
    rng = np.random.RandomState(random_state)
    null_dist = np.empty(n_shuffles)
    for i in range(n_shuffles):
        y_shuf = rng.permutation(y)
        y_pred_shuf = cross_val_predict(clf, X, y_shuf, cv=cv, n_jobs=-1)
        null_dist[i] = balanced_accuracy_score(y_shuf, y_pred_shuf)

    return acc, float(np.mean(null_dist))


def run_classification(matlab_dataset_path):
    """Returns (acc_bla, null_bla_mean, acc_pfc, null_pfc_mean) or all-NaN if skipped."""
    data = loadmat(matlab_dataset_path)
    X = np.asarray(data.get('X'), dtype=float)
    X = np.clip(X, -5, 5)
    y = np.ravel(data.get('y')).astype(int)
    isPFC = np.ravel(data.get('region')).astype(int)

    # Sample-size guards
    if np.sum(isPFC == 0) < 3 or np.sum(isPFC == 1) < 3:
        return np.nan, np.nan, np.nan, np.nan
    for lb in np.unique(y):
        if np.sum(y == lb) < 3:
            print(f"Not enough samples for label {lb} in {matlab_dataset_path.name}. Skipping.")
            return np.nan, np.nan, np.nan, np.nan

    if np.isnan(X).any() or np.isnan(y).any():
        raise ValueError("NaN values found in the dataset.")

    split = np.where(isPFC)[0][0] * single_unit_datapoint
    X_bla = X[:, :split]
    X_pfc = X[:, split:]

    acc_bla, null_bla = loo_score_with_null(X_bla, y)
    acc_pfc, null_pfc = loo_score_with_null(X_pfc, y)

    return acc_bla, null_bla, acc_pfc, null_pfc


if __name__ == "__main__":
    BASE_PATH = Path(r"H:\Data\Kim Data")
    session_paths = sorted(list(BASE_PATH.glob('@*')))

    # Storage: {session_name: {window_idx: (acc_bla, null_bla, acc_pfc, null_pfc)}}
    results = {sp.name: {} for sp in session_paths}

    for w_idx, (t0, t1) in enumerate(TIME_WINDOWS):
        dataset_name = f'RobotNP_RobotP_{t0}_{t1}'
        print(f"\n=== Window {w_idx+1}/{len(TIME_WINDOWS)}: {dataset_name} ===")

        for i, session_path in enumerate(session_paths, 1):
            mat_path = next(session_path.glob(dataset_name + '.mat'), None)
            if mat_path is None:
                print(f"  No dataset found in {session_path.name}")
                continue

            acc_bla, null_bla, acc_pfc, null_pfc = run_classification(mat_path)
            results[session_path.name][w_idx] = (acc_bla, null_bla, acc_pfc, null_pfc)
            print(f"  Session {i}/{len(session_paths)}: {session_path.name}")

    # Build per-region CSVs
    # Layout: Session, T1_Random, T1_Real, T2_Random, T2_Real, ..., T10_Random, T10_Real
    def write_region_csv(out_path, region_idx_acc, region_idx_null):
        header = ['Session']
        for (t0, t1) in TIME_WINDOWS:
            header.append(f'T({t0},{t1})_Random')
            header.append(f'T({t0},{t1})_Real')

        rows = []
        for session_name in sorted(results.keys()):
            session_data = results[session_name]
            # Skip session if it has no successful windows
            if not session_data:
                continue
            # Skip session if any window was NaN (sample-size guard tripped)
            # — keeps Prism paste clean. Comment out if you want to keep partial sessions.
            if any(np.isnan(session_data.get(w, (np.nan,)*4)[region_idx_acc])
                   for w in range(len(TIME_WINDOWS))):
                print(f"Skipping {session_name}: incomplete across windows")
                continue

            row = [session_name]
            for w_idx in range(len(TIME_WINDOWS)):
                acc_b, null_b, acc_p, null_p = session_data[w_idx]
                acc_val = (acc_b, acc_p)[region_idx_acc == 2]
                null_val = (null_b, null_p)[region_idx_null == 3]
                row.append(f"{null_val:.4f}")
                row.append(f"{acc_val:.4f}")
            rows.append(row)

        with open(out_path, 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(header)
            w.writerows(rows)
        print(f"Wrote {out_path} ({len(rows)} sessions)")

    write_region_csv(BASE_PATH / 'temporal_BLA.csv', region_idx_acc=0, region_idx_null=1)
    write_region_csv(BASE_PATH / 'temporal_PFC.csv', region_idx_acc=2, region_idx_null=3)