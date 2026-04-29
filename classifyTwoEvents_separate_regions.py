import numpy as np
from pathlib import Path
from sklearn.svm import LinearSVC
from scipy.io import loadmat
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut, cross_val_predict
from sklearn.metrics import balanced_accuracy_score
import csv

single_unit_datapoint = 40 # number of features per single unit (4 sec * 100ms bins = 40)

# Define classification function
def loo_score_with_null(X, y, n_shuffles=100, random_state=516):
    # Run LOO classification and a label-shuffle null distribution.
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

    # Per-session p-value
    pval = (np.sum(null_dist >= acc) + 1) / (n_shuffles + 1)

    return acc, null_dist, pval

def run_classification(matlab_dataset_path):
    # Load matlab data
    data = loadmat(matlab_dataset_path)
    X = np.asarray(data.get('X'), dtype=float)
    X = np.clip(X, -5, 5)  # Clip data
    y = np.ravel(data.get('y')).astype(int)
    isPFC = np.ravel(data.get('region')).astype(int)

    # Check minimum number of neurons (3)
    if np.sum(isPFC == 0) < 3 or np.sum(isPFC == 1) < 3:
        return np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.sum(isPFC == 0), np.sum(isPFC == 1), np.sum(y==1), np.sum(y==2)

    # Check minimum number of events
    for lb in np.unique(y):
        if np.sum(y == lb) < 3:
            print(f"Not enough samples for label {lb} in {matlab_dataset_path.name} {np.sum(lb == y)}. Skipping session.")
            return np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.sum(isPFC == 0), np.sum(isPFC == 1), np.sum(y==1), np.sum(y==2)

    # Split by region
    split = np.where(isPFC)[0][0] * single_unit_datapoint
    X_bla = X[:, :split]
    X_pfc = X[:, split:]

    if np.isnan(X).any() or np.isnan(y).any():
        raise ValueError("NaN values found in the dataset.")

    acc_bla, null_bla, pval_bla = loo_score_with_null(X_bla, y)
    acc_pfc, null_pfc, pval_pfc = loo_score_with_null(X_pfc, y)


    return acc_bla, np.mean(null_bla), pval_bla, acc_pfc, np.mean(null_pfc), pval_pfc, np.sum(isPFC == 0), np.sum(isPFC == 1), np.sum(y == 1), np.sum(y == 2)

if __name__ == "__main__":
    BASE_PATH = Path(r"H:\Data\Kim Data")

    dataset_name = 'RobotNP_RobotP_pred'

    session_paths = sorted(list(BASE_PATH.glob('@*')))

    rows = []
    for i, session_path in enumerate(session_paths, 1):

        mat_path = next(session_path.glob(dataset_name + '.mat'), None)
        if mat_path is None:
            print(f"No dataset found in {session_path}")
            continue
        acc_bla, acc_bla_random, p_bla, acc_pfc, acc_pfc_random, p_pfc, numBLA, numPFC, num_event1, num_event2 = run_classification(mat_path)
        if np.isnan(acc_bla):
            continue
        rows.append([session_path.name, f"{acc_bla_random:.4f}", f"{acc_bla:.4f}", f"{p_bla:.4f}", f"{acc_pfc_random:.4f}", f"{acc_pfc:.4f}", f"{p_pfc:.4f}", f"{numBLA:d}", f"{numPFC:d}", f"{num_event1}", f"{num_event2}"])
        print(f"Session {i}/{len(session_paths)}: {session_path.name}")

    out_path = BASE_PATH / (dataset_name + '_split_results.csv')
    with open(out_path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['Session', 'Accuracy(BLA random)', 'Accuracy(BLA)', 'p(BLA)', 'Accuracy(PFC random)', 'Accuracy(PFC)', 'p(PFC)', 'NumBLA', 'NumPFC', 'NumEvent1', 'NumEvent2'])
        w.writerows(rows)
    print(f"Results saved to {out_path}")





