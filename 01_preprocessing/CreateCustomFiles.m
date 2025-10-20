%% CreateCustomFiles
% 2025 Ji Hoon Jeong
% Script for creating helper and event.mat files

%% Set Variables
BASEPATH = "H:\Data\Kim Data";

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

vals = cell(0);

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);
    
    % if session < 17
    %     continue;
    % end

    createHelperFiles(tankPath);    
    saveEventTimestamp(tankPath);

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")