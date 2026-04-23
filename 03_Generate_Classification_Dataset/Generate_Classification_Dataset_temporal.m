%% Generate_Classification_Dataset
% 2026 Ji Hoon Jeong
% Script for tank batch

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

    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);

    %Load event file
    eventFilePath = fullfile(tankPath, strcat(tankName(2:end), '_event.mat'));
    load(eventFilePath);
    
    ranges = [...
        -7, -3;...
        -6, -2;...
        -5, -1;...
        -4, 0;...
        -3, 1;
        -2, 2;...
        -1, 3;...
        0, 4;...
        1, 5;...
        2, 6] .* 1000;

    for idx_range = 1 : 10
        % 10 : Event1 vs Event2: robot NP vs. robot P
        % RobotNP_RobotP
        eventTime1 = double([eventData([eventData.Robot] == 1).NP]);
        eventTime2 = double([eventData([eventData.Robot] == 1).P]);
        [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
            ranges(idx_range, :), 100, 1000, 100);
        save(fullfile(tankPath,"RobotNP_RobotP_" + num2str(ranges(idx_range, 1)/1000) + "_" + num2str(ranges(idx_range, 2)/1000) + ".mat"), "X", "y", "region");
    end

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")