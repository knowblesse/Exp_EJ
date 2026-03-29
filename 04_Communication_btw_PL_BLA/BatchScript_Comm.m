%% Batch Scripts
% 2026 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
K = 10;

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

output_session = string();
output = [];
output_bla = [];
output_pfc = [];

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);
    
    %fprintf("%s || ", tankName);

    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);

    if expStat.numBLAUnit < 3 | expStat.numPLUnit < 3
        fprintf("%s Small unit number. Skipping... \n", tankName);
        continue;
    end
    
    [o, bla, pfc] = calculateEventMarkerMI(tankPath, K)
    output_session = [output_session; string(tankName)];
    output = [output; o];
    output_bla = [output_bla; bla];
    output_pfc = [output_pfc; pfc];
    
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")