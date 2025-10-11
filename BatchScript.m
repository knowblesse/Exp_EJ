%% Batch Scripts
% 2023 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
addpath('lib/Neuralynx/');
addpath('01_preprocessing');

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

    % helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    % load(helperFilePath);
    % 
    % if int64(expStat.startTS(1)) ~= time2TS{1}(1, 2)
    %     fprintf("%s - %d ms difference\n", tankName, (time2TS{1}(1, 2) - int64(expStat.startTS(1))) / 1000);
    % end
    
    %saveEventTimestamp(tankPath);

    % Load event file
    eventFilePath = fullfile(tankPath, strcat(tankName(2:end), '_event.mat'));
    load(eventFilePath);

    if numel(eventData) ~= 20
        error("event Data size is not 20");
    end
    
    %% 1 : Event1 vs Event2: pre-robot NP vs. post-robot NP
    % PreRobotNP_RobotNP
    %eventTime1 = double([eventData(1:10).NP]);
    %eventTime2 = double([eventData(11:20).NP]);

    %% 2 : Event1 vs Event2: pre-robot NP vs. pre-robot P
    % PreRobotNP_PreRobotP
    %eventTime1 = double([eventData(1:10).NP]);
    %eventTime2 = double([eventData(1:10).P]);

    %% 3 : Event1 vs Event2: pre-robot NP vs. pre-robot P
    % PreRobotNP_PreRobotP_far
    %eventTime1 = double([eventData(1:10).NP]) - 5000;
    %eventTime2 = double([eventData(1:10).P]) - 5000;

    %% 4 : Event1 vs Event2: pre-robot NP vs. Robot P
    % PreRobotNP_RobotNP_far
    %eventTime1 = double([eventData(1:10).NP]) - 5000;
    %eventTime2 = double([eventData(11:20).NP]) - 5000;

    %% 5 : Event1 vs Event2: pre-robot NP vs. Robot P
    % PreRobotNP_RobotNP_farfar
    % eventTime1 = double([eventData(1:10).NP]) - 10000;
    % eventTime2 = double([eventData(11:20).NP]) - 10000;
    % 
    % [X, y] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
    %     [-2000, +2000], 100, 1000, 100);
    % 
    % save(fullfile(tankPath,"PreRobotNP_RobotNP_farfar.mat"), "X", "y");

    %% 6 : PreRobot NP & P, Robot first NP, first P
    % 
    % 
    % eventTime1 = double([eventData(1:10).NP]);
    % eventTime2 = double([eventData(1:10).P]);
    % [X1, y1] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
    %     [-2000, +2000], 100, 1000, 100);
    % 
    % eventTime1 = double(eventDataRaw.Time_ms(...
    %     find( ([eventDataRaw.Trial] >= 11) & ([eventDataRaw.PelletType] == "NP"), 1)...
    %     ));
    % eventTime2 = double(eventDataRaw.Time_ms(...
    %     find( ([eventDataRaw.Trial] >= 11) & ([eventDataRaw.PelletType] == "P"), 1)...
    %     ));
    % [X2, y2] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
    %     [-2000, +2000], 100, 1000, 100);
    % y2 = y2 + 2;
    % 
    % 
    % X = [X1; X2];
    % y = [y1; y2];
    % save(fullfile(tankPath,"PreRobotNP_PreRobotP_RobotFirstNP_RobotFirstP.mat"), "X", "y");

    %% 7 : Event1 vs Event2: pre-robot NP vs. Robot P
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
    

    %vals = [vals, {cumsum(eventDataRaw.Attempts(find([eventDataRaw.Trial] == 11, 1):end) > 0)}];

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")

%%

% figure(1);
% histogram(Accuracy3, 0:0.05:1, 'FaceColor', 'k', 'FaceAlpha', 0.8, 'LineStyle', 'none');
% xline(0.5, 'r');
% xlabel('Accuracy');
% ylabel('Count');

figure(2);
clf;
for i = 1 : numel(vals)
    plot(vals{i}, lineWidth=numel(vals{i})/5);
    hold on;
end
xlabel('Approach to a pellet');
ylabel('Approach to the preferred pellet')

