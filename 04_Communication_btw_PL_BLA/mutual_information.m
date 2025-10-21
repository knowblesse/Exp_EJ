function [mi, Hx, Hy] = mutual_information(X, Y, K)
%% mutual_information
% X, Y => same length with discrete state (starts from 1)
% K => number of observable States
%% Sanity check
% Ensure column vectors
X = X(:);
Y = Y(:);
assert(numel(X) == numel(Y), 'X and Y must have the same length.');

% Remove NaNs if any
valid = ~isnan(X) & ~isnan(Y);
X = X(valid);
Y = Y(valid);

%% Compute mutual information
C = histcounts2(X, Y, 0.5:1:K+0.5, 0.5:1:K+0.5);
Pxy = C / sum(C(:));
Px = sum(Pxy, 2);
Py = sum(Pxy, 1);

% Compute Entropy of X and Y
Hx = -sum(Px(Px>0) .* log2(Px(Px>0)));
Hy = -sum(Py(Py>0) .* log2(Py(Py>0)));

% Compute MI (bits)
[ix, iy] = find(Pxy > 0);
mi = 0;
for k = 1:numel(ix)
    mi = mi + Pxy(ix(k), iy(k)) * log2( Pxy(ix(k), iy(k)) / (Px(ix(k)) * Py(iy(k))) );
end
end