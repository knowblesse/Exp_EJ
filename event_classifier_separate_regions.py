import numpy as np
from pathlib import Path
from sklearn.svm import LinearSVC
from scipy.io import loadmat
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut, cross_val_score, permutation_test_score
import csv

def run_classification(matlab_dataset_path):
    # Load matlab data
    data = loadmat(matlab_dataset_path)
    X = np.asarray(data.get('X'), dtype=float)
    y = np.ravel(data.get('y')).astype(int)
    isPFC = np.ravel(data.get('region')).astype(int)

    if np.sum(isPFC == 0) == 0 or np.sum(isPFC == 1) == 0:
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

    # LOO accuracy

    accs_bla = cross_val_score(clf_bla, X[:, :np.where(isPFC)[0][0] * 40], y, cv=cv_bla, scoring='accuracy', n_jobs=-1)
    mean_acc_bla = float(np.mean(accs_bla))

    # Permutation test (how often chance beats your score)
    score, perm_scores_bla, pval = permutation_test_score(
        clf_bla, X[:, :np.where(isPFC)[0][0] * 40], y, cv=cv_bla, scoring='accuracy',
        n_permutations=100, n_jobs=-1, random_state=0
    )

    accs_pfc = cross_val_score(clf_pfc, X[:, np.where(isPFC)[0][0] * 40:], y, cv=cv_pfc, scoring='accuracy', n_jobs=-1)
    mean_acc_pfc = float(np.mean(accs_pfc))

    # Permutation test (how often chance beats your score)
    score, perm_scores_pfc, pval = permutation_test_score(
        clf_pfc, X[:, np.where(isPFC)[0][0] * 40:], y, cv=cv_pfc, scoring='accuracy',
        n_permutations=100, n_jobs=-1, random_state=0
    )

    return mean_acc_bla, np.mean(perm_scores_bla), mean_acc_pfc, np.mean(perm_scores_pfc), np.sum(isPFC == 0), np.sum(isPFC == 1)

if __name__ == "__main__":
    BASE_PATH = Path(r"H:\Data\Kim Data")

    dataset_name = 'PreRobotNP_RobotNP_far'

    session_paths = sorted(list(BASE_PATH.glob('@*')))

    rows = []
    for i, session_path in enumerate(session_paths, 1):
        mat_path = next(session_path.glob(dataset_name + '.mat'), None)
        if mat_path is None:
            print(f"No dataset found in {session_path}")
            continue
        acc_bla, acc_bla_random, acc_pfc, acc_pfc_random, numBLA, numPFC = run_classification(mat_path)
        rows.append([session_path.name, f"{acc_bla:.4f}", f"{acc_bla_random:.4f}", f"{acc_pfc:.4f}", f"{acc_pfc_random:.4f}", f"{numBLA:d}", f"{numPFC:d}"])
        print(f"Session {i}/{len(session_paths)}: {session_path.name}")

    out_path = BASE_PATH / (dataset_name + '_split_results.csv')
    with open(out_path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['Session', 'Accuracy(BLA)', 'Accuracy(BLA random)', 'Accuracy(PFC)', 'Accuracy(PFC random)', 'NumBLA', 'NumPFC'])
        w.writerows(rows)
    print(f"Results saved to {out_path}")





