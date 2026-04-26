import numpy as np
from pathlib import Path
from sklearn.svm import LinearSVC
from scipy.io import loadmat
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut, cross_val_score, permutation_test_score, cross_val_predict
from sklearn.metrics import balanced_accuracy_score
import csv

import warnings
warnings.filterwarnings('ignore', message='y_pred contains classes not in y_true')
warnings.filterwarnings('ignore', message='A single label was found')

single_unit_datapoint = 40 # number of features per single unit (4 sec * 100ms bins = 40)

def run_classification(matlab_dataset_path):
    # Load matlab data
    data = loadmat(matlab_dataset_path)
    X = np.asarray(data.get('X'), dtype=float)
    y = np.ravel(data.get('y')).astype(int)
    isPFC = np.ravel(data.get('region')).astype(int)

    # Check minimum number of events
    for lb in np.unique(y):
        if np.sum(y == lb) < 3:
            print(f"Not enough samples for label {lb} in {matlab_dataset_path.name} {np.sum(lb == y)}. Skipping session.")
            return np.nan, np.nan, np.nan, np.nan, np.sum(isPFC == 0), np.sum(isPFC == 1)

    # Clip
    X = np.clip(X, -5, 5)

    # Raise error if nan in data
    if np.isnan(X).any() or np.isnan(y).any():
        raise ValueError("NaN values found in the dataset.")

    # Use Leave-One-Out method
    clf_bla = make_pipeline(
        StandardScaler(with_mean=True),
        LinearSVC(C=1.0, class_weight='balanced', dual=True, random_state=0)
    ) # features >> samples => dual should be True

    clf_pfc = make_pipeline(
        StandardScaler(with_mean=True),
        LinearSVC(C=1.0, class_weight='balanced', dual=True, random_state=0)
    )  # features >> samples => dual should be True

    cv_bla = LeaveOneOut()
    cv_pfc = LeaveOneOut()

    # Check minimum number of neurons (3)
    if np.sum(isPFC == 0) < 3:
        perm_scores_bla = np.nan
        mean_acc_bla = np.nan
    else:
        # LOO accuracy
        y_pred_bla = cross_val_predict(clf_bla, X[:, :np.where(isPFC)[0][0] * single_unit_datapoint], y, cv=cv_bla, n_jobs=-1)
        mean_acc_bla = balanced_accuracy_score(y, y_pred_bla)

        # Permutation test (how often chance beats your score)
        # BLA always comes first
        score, perm_scores_bla, pval = permutation_test_score(
            clf_bla, X[:, :np.where(isPFC)[0][0] * single_unit_datapoint], y, cv=cv_bla, scoring='balanced_accuracy',
            n_permutations=100, n_jobs=-1, random_state=0
        )

    if np.sum(isPFC == 1) < 3:
        perm_scores_pfc = np.nan
        mean_acc_pfc = np.nan
    else:
        y_pred_pfc = cross_val_predict(clf_bla, X[:, np.where(isPFC)[0][0] * single_unit_datapoint:], y, cv=cv_bla, n_jobs=-1)
        mean_acc_pfc = balanced_accuracy_score(y, y_pred_pfc)

        # Permutation test (how often chance beats your score)
        score, perm_scores_pfc, pval = permutation_test_score(
            clf_pfc, X[:, np.where(isPFC)[0][0] * single_unit_datapoint:], y, cv=cv_pfc, scoring='balanced_accuracy',
            n_permutations=100, n_jobs=-1, random_state=0
        )

    return mean_acc_bla, np.mean(perm_scores_bla), mean_acc_pfc, np.mean(perm_scores_pfc), np.sum(isPFC == 0), np.sum(isPFC == 1)

if __name__ == "__main__":
    BASE_PATH = Path(r"H:\Data\Kim Data")
    for idx in [(-7, -3), (-6, -2), (-5, -1), (-4, 0), (-3, 1), (-2, 2), (-1, 3), (0, 4), (1, 5), (2, 6)]:
        dataset_name = 'RobotNP_RobotP_' + str(idx[0]) + '_' + str(idx[1])

        session_paths = sorted(list(BASE_PATH.glob('@*')))

        rows = []
        for i, session_path in enumerate(session_paths, 1):

            mat_path = next(session_path.glob(dataset_name + '.mat'), None)
            if mat_path is None:
                print(f"No dataset found in {session_path}")
                continue
            acc_bla, acc_bla_random, acc_pfc, acc_pfc_random, numBLA, numPFC = run_classification(mat_path)
            if np.isnan(acc_bla):
                continue
            rows.append([session_path.name, f"{acc_bla_random:.4f}", f"{acc_bla:.4f}", f"{acc_pfc_random:.4f}", f"{acc_pfc:.4f}", f"{numBLA:d}", f"{numPFC:d}"])
            print(f"Session {i}/{len(session_paths)}: {session_path.name}")

        out_path = BASE_PATH / (dataset_name + '_split_results.csv')
        with open(out_path, 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['Session', 'Accuracy(BLA random)', 'Accuracy(BLA)', 'Accuracy(PFC random)', 'Accuracy(PFC)', 'NumBLA', 'NumPFC'])
            w.writerows(rows)
        print(f"Results saved to {out_path}")





