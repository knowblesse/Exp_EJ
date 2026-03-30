function [te_JtoI, te_ItoJ, diagnostics] = transfer_entropy(I_events, J_events, K, k_past, n_surrogates, u)
%% transfer_entropy
% Compute transfer entropy with prediction time parameter and surrogate testing.
%
% Inputs:
%   I_events      - cell array, each cell is a column vector of state labels (1 to K)
%   J_events      - cell array, each cell is a column vector of state labels (1 to K)
%   K             - number of possible states
%   k_past        - number of past bins to condition on
%   n_surrogates  - number of surrogate permutations (default: 200)
%   u             - prediction time in bins (default: 1)
%                   u=1: predict next bin from immediate past
%                   u=4: predict 4 bins ahead from past (skipping 3 bins)
%
% The prediction time u controls the temporal gap between the past window
% and the predicted state. With u=1 (standard TE), we predict i_{n+1} from
% i_{n}, i_{n-1}, ..., i_{n-k+1}. With u>1, we predict i_{n+u} from the
% same past window, allowing detection of interactions with longer delays.

if nargin < 6; u = 1; end
if nargin < 5; n_surrogates = 200; end

%% Sanity checks
nEvents = numel(I_events);
assert(nEvents == numel(J_events), 'Must have same number of events');
for e = 1:nEvents
    assert(numel(I_events{e}) == numel(J_events{e}), ...
        sprintf('Event %d: I and J must have same length', e));
end

%% Compute real TE
[te_JtoI, te_ItoJ, total_bins, valid_bins, pattern_info] = ...
    compute_te_both_directions(I_events, J_events, k_past, u);

%% Surrogate testing
surr_JtoI = zeros(n_surrogates, 1);
surr_ItoJ = zeros(n_surrogates, 1);

for s = 1:n_surrogates
    shuf_idx = randperm(nEvents);
    J_shuffled = J_events(shuf_idx);
    [surr_JtoI(s), surr_ItoJ(s), ~, ~, ~] = ...
        compute_te_both_directions(I_events, J_shuffled, k_past, u);
end

% P-values (conservative)
p_JtoI = (sum(surr_JtoI >= te_JtoI) + 1) / (n_surrogates + 1);
p_ItoJ = (sum(surr_ItoJ >= te_ItoJ) + 1) / (n_surrogates + 1);

% Z-scores
z_JtoI = (te_JtoI - mean(surr_JtoI)) / std(surr_JtoI);
z_ItoJ = (te_ItoJ - mean(surr_ItoJ)) / std(surr_ItoJ);

%% Diagnostics
diagnostics = struct();
diagnostics.total_bins = total_bins;
diagnostics.valid_bins = valid_bins;
diagnostics.num_events = nEvents;
diagnostics.K = K;
diagnostics.k_past = k_past;
diagnostics.u = u;

diagnostics.JtoI = pattern_info.JtoI;
diagnostics.ItoJ = pattern_info.ItoJ;

diagnostics.surrogate.n_surrogates = n_surrogates;
diagnostics.surrogate.JtoI.p_value = p_JtoI;
diagnostics.surrogate.JtoI.z_score = z_JtoI;
diagnostics.surrogate.JtoI.surr_mean = mean(surr_JtoI);
diagnostics.surrogate.JtoI.surr_std = std(surr_JtoI);
diagnostics.surrogate.JtoI.surr_values = surr_JtoI;

diagnostics.surrogate.ItoJ.p_value = p_ItoJ;
diagnostics.surrogate.ItoJ.z_score = z_ItoJ;
diagnostics.surrogate.ItoJ.surr_mean = mean(surr_ItoJ);
diagnostics.surrogate.ItoJ.surr_std = std(surr_ItoJ);
diagnostics.surrogate.ItoJ.surr_values = surr_ItoJ;

end

%% =====================================================================
function [te_JtoI, te_ItoJ, total_bins, valid_bins, pattern_info] = ...
    compute_te_both_directions(I_events, J_events, k_past, u)

    i_current_all = [];
    j_current_all = [];
    i_past_keys = {};
    j_past_keys = {};
    j_past_keys_rev = {};
    i_past_keys_rev = {};

    total_bins = 0;
    valid_bins = 0;

    for e = 1:numel(I_events)
        I_seq = I_events{e}(:);
        J_seq = J_events{e}(:);
        nBins = numel(I_seq);
        total_bins = total_bins + nBins;

        % Need at least k_past bins of history + u bins of prediction gap
        % Valid prediction indices: from (k_past + u) to nBins
        for n = (k_past + u):nBins
            valid_bins = valid_bins + 1;

            % Current state to predict (u steps ahead of the past window)
            i_cur = I_seq(n);

            % Past states: from n-u back to n-u-k_past+1 (the window before the gap)
            i_past_vec = I_seq(n-u : -1 : n-u-k_past+1)';
            j_past_vec = J_seq(n-u : -1 : n-u-k_past+1)';

            i_past_key = strjoin(string(i_past_vec), '_');
            j_past_key = strjoin(string(j_past_vec), '_');

            i_current_all = [i_current_all; i_cur];
            i_past_keys = [i_past_keys; i_past_key];
            j_past_keys = [j_past_keys; j_past_key];

            % For TE(I -> J)
            j_cur = J_seq(n);
            j_current_all = [j_current_all; j_cur];
            j_past_keys_rev = [j_past_keys_rev; j_past_key];
            i_past_keys_rev = [i_past_keys_rev; i_past_key];
        end
    end

    %% TE(J -> I)
    ij_past_keys = strcat(i_past_keys, '|', j_past_keys);
    ci_ipast_keys = strcat(string(i_current_all), '|', i_past_keys);
    ci_ijpast_keys = strcat(string(i_current_all), '|', ij_past_keys);

    H_ci_ipast = compute_entropy(ci_ipast_keys, valid_bins);
    H_ipast = compute_entropy(i_past_keys, valid_bins);
    H_ci_ijpast = compute_entropy(ci_ijpast_keys, valid_bins);
    H_ijpast = compute_entropy(ij_past_keys, valid_bins);

    te_JtoI = H_ci_ipast - H_ipast - H_ci_ijpast + H_ijpast;

    %% TE(I -> J)
    ji_past_keys = strcat(j_past_keys_rev, '|', i_past_keys_rev);
    cj_jpast_keys = strcat(string(j_current_all), '|', j_past_keys_rev);
    cj_jipast_keys = strcat(string(j_current_all), '|', ji_past_keys);

    H_cj_jpast = compute_entropy(cj_jpast_keys, valid_bins);
    H_jpast = compute_entropy(j_past_keys_rev, valid_bins);
    H_cj_jipast = compute_entropy(cj_jipast_keys, valid_bins);
    H_jipast = compute_entropy(ji_past_keys, valid_bins);

    te_ItoJ = H_cj_jpast - H_jpast - H_cj_jipast + H_jipast;

    %% Pattern info
    pattern_info = struct();

    [unique_ipast, ~, ic] = unique(i_past_keys);
    ipast_counts = accumarray(ic, 1);
    pattern_info.JtoI.num_i_past_patterns = numel(unique_ipast);
    pattern_info.JtoI.i_past_count_median = median(ipast_counts);
    pattern_info.JtoI.patterns_with_1_count = sum(ipast_counts == 1);

    [unique_ijpast, ~, ic2] = unique(ij_past_keys);
    ijpast_counts = accumarray(ic2, 1);
    pattern_info.JtoI.num_ij_past_patterns = numel(unique_ijpast);
    pattern_info.JtoI.ij_past_count_median = median(ijpast_counts);
    pattern_info.JtoI.ij_past_patterns_with_1_count = sum(ijpast_counts == 1);

    [unique_jpast, ~, ic3] = unique(j_past_keys_rev);
    jpast_counts = accumarray(ic3, 1);
    pattern_info.ItoJ.num_j_past_patterns = numel(unique_jpast);
    pattern_info.ItoJ.j_past_count_median = median(jpast_counts);
    pattern_info.ItoJ.patterns_with_1_count = sum(jpast_counts == 1);

    [unique_jipast, ~, ic4] = unique(ji_past_keys);
    jipast_counts = accumarray(ic4, 1);
    pattern_info.ItoJ.num_ji_past_patterns = numel(unique_jipast);
    pattern_info.ItoJ.ji_past_count_median = median(jipast_counts);
    pattern_info.ItoJ.ji_past_patterns_with_1_count = sum(jipast_counts == 1);

end

%% Helper: Shannon entropy from string keys
function H = compute_entropy(keys, N)
    [~, ~, ic] = unique(keys);
    counts = accumarray(ic, 1);
    p = counts / N;
    H = -sum(p .* log2(p));
end