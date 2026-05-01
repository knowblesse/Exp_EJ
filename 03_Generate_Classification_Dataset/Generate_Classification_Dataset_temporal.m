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
    % ranges = [...
    %     -8, -6;...
    %     -6, -4;...
    %     -4, -2;...
    %     -2, 0;...
    %     0, 2;
    %     2, 4;...
    %     4, 6;...
    %     6, 8] .* 1000;

    for idx_range = 1 : size(ranges, 1)
        % 18 : Event1 vs Event2: robot NP vs. robot P (with large ITI)
        % RobotNP_RobotP_ITI
        eventTime1 = [];
        eventTime2 = [];

        for i = 1 : size(eventDataRaw,1)
            if ... % Robot session + P 
                    eventDataRaw.Robot(i) == 1 &...
                    eventDataRaw.PelletType(i) == "P"
                if eventDataRaw.Time_ms(i) - eventDataRaw.Time_ms(i-1) > 5000
                    eventTime1 = [eventTime1; double(eventDataRaw.Time_ms(i))];
                end
            end

            if ... % Robot session + NP
                    eventDataRaw.Robot(i) == 1 &...
                    eventDataRaw.PelletType(i) == "NP" 
                if eventDataRaw.Time_ms(i) - eventDataRaw.Time_ms(i-1) > 5000
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
        end
        if numel(eventTime1) < 3 | numel(eventTime2) <3
            fprintf("Skipped due to small event number\n");
            continue;
        end
        [X, y, region] = generateEventClassifierDataset(tankPath, eventTime1, eventTime2, ...
            ranges(idx_range, :), 100, 1000, 100);
        save(fullfile(tankPath,"RobotNP_RobotP_ITI_" + num2str(ranges(idx_range, 1)/1000) + "_" + num2str(ranges(idx_range, 2)/1000) + ".mat"), "X", "y", "region");
    end

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")