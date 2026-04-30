%% Generate_Classification_Dataset
% 2026 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
n = 17;

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

vals = cell(0);
temp = [];

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);

    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);

    %Load event file
    eventFilePath = fullfile(tankPath, strcat(tankName(2:end), '_event.mat'));
    load(eventFilePath);
    
    switch n
        case 1
            % 1 : Event1 vs Event2: pre-robot NP vs. post-robot NP
            % PreRobotNP_RobotNP
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_RobotNP.mat"), "X", "y", "region");
        case 2
            % 2 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % PreRobotNP_PreRobotP
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 0).P]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP.mat"), "X", "y", "region");
        case 3
            % 3 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % PreRobotNP_PreRobotP_far
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]) - 5000;
            eventTime2 = double([eventData([eventData.Robot] == 0).P]) - 5000;
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_far.mat"), "X", "y", "region");
        case 4
            % 4 : Event1 vs Event2: pre-robot NP vs. Robot P
            % PreRobotNP_RobotNP_far
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]) - 5000;
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]) - 5000;
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_RobotNP_far.mat"), "X", "y", "region");
        case 5
            % 5 : Event1 vs Event2: pre-robot NP vs. Robot P
            % PreRobotNP_RobotNP_farfar
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]) - 10000;
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]) - 10000;

            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);

            save(fullfile(tankPath,"PreRobotNP_RobotNP_farfar.mat"), "X", "y", "region");
        case 6
            % 6 : Event1 vs Event2: pre-robot NP vs. pre-robot P far far
            % PreRobotNP_PreRobotP_farfar
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]) - 10000;
            eventTime2 = double([eventData([eventData.Robot] == 0).P]) - 10000;
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_farfar.mat"), "X", "y", "region");
        case 7
            % 7 : Event1 vs Event2: pre-robot NP vs. Robot P
            % eventTime1 = double([eventData(1:10).NP]);
            % eventTime2 = double([eventData(11:15).NP]);
            % [X1, y1] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
            %     [-2000, +2000], 100, 1000, 100);
            % 
            % eventTime1 = double(eventDataRaw.Time_ms(...
            %     find( ([eventDataRaw.Trial] >= 11) & ([eventDataRaw.PelletType] == "NP"), 1)...
            %     ));
            % eventTime2 = double([eventData(15:20).NP]);
            % [X2, y2] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
            %     [-2000, +2000], 100, 1000, 100);
            % y2 = y2 + 2;
            % 
            % X = [X1; X2];
            % y = [y1; y2];
            % save(fullfile(tankPath,"PreRobotNP_PreRobotP_RobotFirstNP_RobotFirstP.mat"), "X", "y");
        case 8
            % 8 : Event1 vs Event2: pre-robot P vs. robot NP
            % PreRobotP_RobotNP
            eventTime1 = double([eventData([eventData.Robot] == 0).P]);
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotP_RobotNP.mat"), "X", "y", "region");
        case 9
            % 9 : Event1 vs Event2: pre-robot P vs. robot NP
            % PreRobotP_RobotNP_far
            eventTime1 = double([eventData([eventData.Robot] == 0).P]) - 5000;
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]) - 5000;
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, +2000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotP_RobotNP_far.mat"), "X", "y", "region");
        case 10
            % 10 : Event1 vs Event2: robot NP vs. robot P
            % RobotNP_RobotP_pred
            eventTime1 = [];
            eventTime2 = [];

            for i = 1 : size(eventDataRaw,1)
                if ... % Robot session + P 
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "P"
                    eventTime1 = [eventTime1; double(eventDataRaw.Time_ms(i))];
                end

                if ... % Robot session + NP
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "NP" 
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
            if numel(eventTime1) < 3 | numel(eventTime2) <3
                fprintf("Skipped due to small event number\n");
                continue;
            end
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-10000, 0], 100, 1000, 100);
            save(fullfile(tankPath,"RobotNP_RobotP_pred.mat"), "X", "y", "region");
        case 11
            % 11 : Event1 vs Event2: robot NP vs. robot P
            % RobotNP_RobotP_pred2
            eventTime1 = [];
            eventTime2 = [];

            for i = 1 : size(eventDataRaw,1)
                if ... % Robot session + P 
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "P"
                    eventTime1 = [eventTime1; double(eventDataRaw.Time_ms(i))];
                end

                if ... % Robot session + NP
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "NP" 
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
            if numel(eventTime1) < 3 | numel(eventTime2) <3
                fprintf("Skipped due to small event number\n");
                continue;
            end
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-6000, -2000], 100, 1000, 100);
            save(fullfile(tankPath,"RobotNP_RobotP_pred2.mat"), "X", "y", "region");
        case 12
            % 12 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % PreRobotNP_PreRobotP_10sec
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 0).P]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-10000, 0000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_10sec.mat"), "X", "y", "region");
        case 13
            % 13 : Event1 vs Event2: pre-robot NP vs. robot NP
            % PreRobotNP_RobotNP_10sec
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-10000, 0000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_RobotNP_10sec.mat"), "X", "y", "region");
        case 14
            % 14 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % PreRobotNP_PreRobotP_pred15
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 0).P]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-5000, -1000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_pred15.mat"), "X", "y", "region");
        case 15
            % 15 : Event1 vs Event2: pre-robot P vs. robot NP
            % PreRobotP_RobotNP_10sec
            eventTime1 = double([eventData([eventData.Robot] == 0).P]);
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]);
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-10000, 0000], 100, 1000, 100);
            save(fullfile(tankPath,"PreRobotP_RobotNP_10sec.mat"), "X", "y", "region");
        case 16
            % 16 : Event1 vs Event2: robot NP vs. P using data right after P
            % RobotNP_RobotP_using_postP
            % Using data right after P, predict whether the animal will
            % approach again in the next attempt or give up
            eventTime1 = [];
            eventTime2 = [];
            for i = 1 : size(eventDataRaw,1) - 1
                if ... % Robot session + P + Next is also P
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "P" &...
                        eventDataRaw.PelletType(i+1) == "P"
                    eventTime1 = [eventTime1; double(eventDataRaw.Time_ms(i))];
                end

                if ... % Robot session + P + Next is changed to NP
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "P" &...
                        eventDataRaw.PelletType(i+1) == "NP"
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
            if numel(eventTime1) < 3 | numel(eventTime2) <3
                fprintf("Skipped due to small event number\n");
                continue;
            end
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [0000, 4000], 100, 1000, 100);
            save(fullfile(tankPath,"RobotNP_RobotP_using_postP.mat"), "X", "y", "region");

        case 17
            % 11 : Event1 vs Event2: robot NP vs. robot P
            % RobotNP_RobotP
            eventTime1 = [];
            eventTime2 = [];

            for i = 1 : size(eventDataRaw,1)
                if ... % Robot session + P 
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "P"
                    eventTime1 = [eventTime1; double(eventDataRaw.Time_ms(i))];
                end

                if ... % Robot session + NP
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "NP" 
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
            if numel(eventTime1) < 3 | numel(eventTime2) <3
                fprintf("Skipped due to small event number\n");
                continue;
            end
            [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
                [-2000, 2000], 100, 1000, 100);
            save(fullfile(tankPath,"RobotNP_RobotP.mat"), "X", "y", "region");
    end

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")