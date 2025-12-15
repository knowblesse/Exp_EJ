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

    # Clip
    X = np.clip(X, -5, 5)

    # Raise error if nan in data
    if np.isnan(X).any() or np.isnan(y).any():
        raise ValueError("NaN values found in the dataset.")

    # Use Leave-One-Out method
    clf = make_pipeline(
        StandardScaler(with_mean=True),
        LinearSVC(C=1.0, class_weight='balanced', dual=True, random_state=0)
    ) # features >> samples => dual should be True


    cv = LeaveOneOut()

    # LOO accuracy
    accs = cross_val_score(clf, X, y, cv=cv, scoring='accuracy', n_jobs=-1)
    mean_acc = float(np.mean(accs))

    # Permutation test (how often chance beats your score)
    score, perm_scores, pval = permutation_test_score(
        clf, X, y, cv=cv, scoring='accuracy',
        n_permutations=100, n_jobs=-1, random_state=0
    )

    return mean_acc, np.mean(perm_scores), float(pval)

if __name__ == "__main__":
    BASE_PATH = Path(r"H:\Data\Kim Data")

    dataset_name = 'PreRobotP_RobotNP'

    session_paths = sorted(list(BASE_PATH.glob('@*')))

    rows = []
    for i, session_path in enumerate(session_paths, 1):
        mat_path = next(session_path.glob(dataset_name + '.mat'), None)
        if mat_path is None:
            print(f"No dataset found in {session_path}")
            continue
        acc, acc_random, pval = run_classification(mat_path)
        rows.append([session_path.name, f"{acc:.4f}", f"{acc_random:.4f}",f"{pval:.4f}"])
        print(f"Session {i}/{len(session_paths)}: {session_path.name}, Acc: {acc:.4f}, Perm_p: {pval:.4f}")

    out_path = BASE_PATH / (dataset_name + '_results.csv')
    with open(out_path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['Session', 'Accuracy', 'Accuracy(random)', 'Perm_p'])
        w.writerows(rows)
    print(f"Results saved to {out_path}")





