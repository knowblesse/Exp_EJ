%% Batch Scripts
% 2023 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "D:\Data\Kim Data";
addpath('Lib/Neuralynx/');

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'(|#|##|@)AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));
for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);

    createHelperFiles(tankPath);
    
    clearvars p_;
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")