%% Generate_Classification_Dataset
% 2023 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
n = 8;

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

    if numel(eventData) ~= 20
        error("event Data size is not 20");
    end
    
    switch n
        case 1
            % 1 : Event1 vs Event2: pre-robot NP vs. post-robot NP
            % PreRobotNP_RobotNP
            eventTime1 = double([eventData(1:10).NP]);
            eventTime2 = double([eventData(11:20).NP]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_RobotNP.mat"), "X", "y", "region");
        case 2
            % 2 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % PreRobotNP_PreRobotP
            eventTime1 = double([eventData(1:10).NP]);
            eventTime2 = double([eventData(1:10).P]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP.mat"), "X", "y", "region");
        case 3
            % 3 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % PreRobotNP_PreRobotP_far
            eventTime1 = double([eventData(1:10).NP]) - 5000;
            eventTime2 = double([eventData(1:10).P]) - 5000;
            [X, y] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_far.mat"), "X", "y");
        case 4
            % 4 : Event1 vs Event2: pre-robot NP vs. Robot P
            % PreRobotNP_RobotNP_far
            eventTime1 = double([eventData(1:10).NP]) - 5000;
            eventTime2 = double([eventData(11:20).NP]) - 5000;
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_RobotNP_far.mat"), "X", "y", "region");
        case 5
            % 5 : Event1 vs Event2: pre-robot NP vs. Robot P
            % PreRobotNP_RobotNP_farfar
            eventTime1 = double([eventData(1:10).NP]) - 10000;
            eventTime2 = double([eventData(11:20).NP]) - 10000;

            [X, y] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);

            save(fullfile(tankPath,"PreRobotNP_RobotNP_farfar.mat"), "X", "y");
        case 6
            % 6 : PreRobot NP & P, Robot first NP, first P
            eventTime1 = double([eventData(1:10).NP]);
            eventTime2 = double([eventData(1:10).P]);
            [X1, y1] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);

            eventTime1 = double(eventDataRaw.Time_ms(...
                find( ([eventDataRaw.Trial] >= 11) & ([eventDataRaw.PelletType] == "NP"), 1)...
                ));
            eventTime2 = double(eventDataRaw.Time_ms(...
                find( ([eventDataRaw.Trial] >= 11) & ([eventDataRaw.PelletType] == "P"), 1)...
                ));
            [X2, y2] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            y2 = y2 + 2;

            X = [X1; X2];
            y = [y1; y2];
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_RobotFirstNP_RobotFirstP.mat"), "X", "y");
        case 7
            % 7 : Event1 vs Event2: pre-robot NP vs. Robot P
            eventTime1 = double([eventData(1:10).NP]);
            eventTime2 = double([eventData(11:15).NP]);
            [X1, y1] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);

            eventTime1 = double(eventDataRaw.Time_ms(...
                find( ([eventDataRaw.Trial] >= 11) & ([eventDataRaw.PelletType] == "NP"), 1)...
                ));
            eventTime2 = double([eventData(15:20).NP]);
            [X2, y2] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            y2 = y2 + 2;

            X = [X1; X2];
            y = [y1; y2];
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_RobotFirstNP_RobotFirstP.mat"), "X", "y");
        case 8
            % 8 : Event1 vs Event2: pre-robot P vs. robot NP
            % PreRobotNP_RobotNP
            eventTime1 = double([eventData(1:10).P]);
            eventTime2 = double([eventData(11:20).NP]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotP_RobotNP.mat"), "X", "y", "region");
    end

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")