%% Batch Scripts for Transfer Entropy - Final Version
% 2025 Ji Hoon Jeong
%% Set Variables
BASEPATH = "H:\Data\Kim Data";
K = 5;
k_past = 2;
n_surrogates = 10;

%% Get filepaths
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name}, '@AP\S*', 'match');
sessionPaths = sessionPaths(~cellfun('isempty', sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

%% Run all sessions
all_outputs = {};
for session = 1:numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);

    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);

    if expStat.numBLAUnit < 4 || expStat.numPLUnit < 4
        fprintf("%s Small unit number. Skipping...\n", tankName);
        continue;
    end

    try
        output = calculateEventMarkerTE(tankPath, K, k_past, n_surrogates);
    catch ME
        fprintf("%s Error: %s. Skipping...\n", tankName, ME.message);
        continue;
    end

    if isempty(output)
        fprintf("%s Returned empty. Skipping...\n", tankName);
        continue;
    end

    all_outputs{end+1} = output;
end

fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript: All Complete! %d sessions processed.\n", numel(all_outputs));

%% Build results table (one row per session)
results = table();
marker_names = {'Control', 'PreRobotNP', 'AfterAttack', 'NP_Robot'};

for i = 1:numel(all_outputs)
    o = all_outputs{i};
    row = table();
    row.session = string(o.tankName);
    row.nBLA = o.nBLA;
    row.nPFC = o.nPFC;
    row.N_matched = o.N_matched;

    for m = 1:numel(marker_names)
        mn = marker_names{m};
        row.(sprintf('te_bla2pfc_%s', mn)) = o.te_bla2pfc(m);
        row.(sprintf('te_pfc2bla_%s', mn)) = o.te_pfc2bla(m);
        row.(sprintf('p_bla2pfc_%s', mn)) = o.p_bla2pfc(m);
        row.(sprintf('p_pfc2bla_%s', mn)) = o.p_pfc2bla(m);
    end

    results = [results; row];
end

%% Save
save('TE_results_final.mat', 'results', 'all_outputs');
writetable(results, 'TE_results_final.csv');
fprintf("Results saved to TE_results_final.mat and TE_results_final.csv\n");
fprintf("Total sessions in results: %d\n", height(results));