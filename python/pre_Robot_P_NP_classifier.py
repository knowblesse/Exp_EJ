import numpy as np
from pathlib import Path
import sklearn
from sklearn.svm import SVC
from scipy.io import loadmat, savemat
from tkinter.filedialog import askdirectory
from sklearn.model_selection import LeaveOneOut
from sklearn.metrics import accuracy_score

# Set tankPath
tankPath = Path(askdirectory())
print(tankPath)

# Load matlab data
data = loadmat(str(tankPath / 'eventClfData.mat'))
X = data.get('X')
y = np.squeeze(data.get('y'))

# Clip
X = np.clip(X, -5, 5)

# Use Leave-One-Out method
loo = LeaveOneOut()

accuracies = []

# Run through all of the samples
for train_index, test_index in loo.split(X):
    X_train, X_test = X[train_index], X[test_index]
    y_train, y_test = y[train_index], y[test_index]

    # Train the classifier on the training set
    svc = SVC()
    svc.fit(X_train, y_train)

    # Make predictions on the test set
    y_pred = svc.predict(X_test)

    # Compute the accuracy for this iteration
    acc = accuracy_score(y_test, y_pred)
    accuracies.append(acc)

average_accuracy = sum(accuracies) / len(accuracies)

print("Average LOO Classification Accuracy:", average_accuracy)

