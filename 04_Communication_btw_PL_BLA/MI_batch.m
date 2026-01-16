%% MI_batch
% 2026 Ji Hoon Jeong
% Script for tank batch — mutual information

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
K = 10;

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));
output = [];
output_session_names = strings(0);
output_bla = [];
output_pfc = [];
for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);
    
    fprintf("%s || ", tankName);

    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);

    if expStat.numBLAUnit < 3 | expStat.numPLUnit < 3
        fprintf("Small unit number. Skipping... \n");
        continue;
    end
    %[o, o_bla, o_pfc] = calculateEventMarkerMI(tankPath, K);
    %[o, o_bla, o_pfc] = calculateTemporalMI(tankPath, K);

    output = [output; o];
    output_session_names = [output_session_names; string(tankName)];
    output_bla = [output_bla; o_bla];
    output_pfc = [output_pfc; o_pfc];
    
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")