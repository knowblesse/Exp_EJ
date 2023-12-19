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

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);

    unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);
    numCell = 0;
    for unitFilePath = unitFilePaths
        [Timestamps, ScNumbers, CellNumbers, Features, Samples] = Nlx2MatSpike(...
        unitFilePath{1},...
        [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
        0,... %Extract Header
        1);
    
        numCell = numCell + numel(unique(CellNumbers));
    end

    % Show info
    fprintf("================================================================================\n", tankName);
    fprintf("Tank Name : %s\n", tankName);
    fprintf("Num unit : %d\n", numCell);
    
    clearvars p_;
end
