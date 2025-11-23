%% CellClustering
% Load all recorded neurons, parce activity around key events, and
% perform unsuperviced cell clustering to find out functional subset

% Key Events:
% Pre-robot NP
% Pre-robot P
% Robot NP
% Robot P

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
timewindow = [-4000, +4000];
timewindow_bin = 50;  % same as temporal mutual information
kernel_size = 1000; % same as all
kernel_std = 100; % same as all

windowsize = diff(timewindow);
binnedDataSize = windowsize / timewindow_bin;

ActivityData = zeros(580, binnedDataSize, 4);  % unit x 160 (for 8sec) x 4 events;
TotalUnit = 0;
Region = strings(580, 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. Load all session, extract peri-event activity, average, and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Get Session lists
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);
    tankName = tankName(2:end);

    %% Get unit file Paths
    unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);

    %% Load helper file
    load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
    if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
        error("Helper file not loaded properly")
    end
    
    %% Load event file
    eventFilePath = fullfile(tankPath, strcat(tankName, '_event.mat'));
    load(eventFilePath);

    %% Define event times
    % Key Events:
    % Pre-robot NP
    % Pre-robot P
    % Robot NP
    % Robot P
    eventTime_PR_NP = double(eventDataRaw.Time_ms(eventDataRaw.Trial < 11 & eventDataRaw.PelletType == "NP"));
    eventTime_PR_P = double(eventDataRaw.Time_ms(eventDataRaw.Trial < 11 & eventDataRaw.PelletType == "P"));
    eventTime_R_NP = double(eventDataRaw.Time_ms(eventDataRaw.Trial >= 11 & eventDataRaw.PelletType == "NP"));
    eventTime_R_P = double(eventDataRaw.Time_ms(eventDataRaw.Trial >= 11 & eventDataRaw.PelletType == "P"));

    %% Read unit file
    unitData = table([], [], {}, 'VariableName', {'unitNumber', 'numSpike', 'time_ms'});
    unitNumber = 1;
    region = string([]);
    for unitFilePath = unitFilePaths
        % Load Unit Data
        [Timestamps, ~, CellNumbers, ~, Samples] = Nlx2MatSpike(...
            unitFilePath{1},...
            [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
            0,... %Extract Header
            1);
    
        % Classify recording region
        regResult = regexp(unitFilePath{1}, '(?<sessionName>@AP.*)\\(?<region>(BLA|PFC)).*TT(?<electrodeNumber>\d\d).\w\w\w', 'names');
        region_ = regResult.region;
    
        % Separate Unit Data
        unitType = unique(CellNumbers);
        numUnit_ = numel(unitType);
        for i = 1 : numUnit_
            temp_ = Timestamps(CellNumbers == unitType(i))'; % selected unit's timestamps
            temp_ = (temp_ - expStat.startTS) / 1000; % timestamp to relative ms
    
            % Check if all spike occur after startTS.
            % => sometimes, spike occur before expStat.startTS. remove such data.
            temp_ = temp_(temp_ > 0);
            
            % Turn it into table
            unitData = [unitData; table(...
                unitNumber,...
                numel(temp_),...
                {temp_},...
                'VariableName', {'unitNumber', 'numSpike', 'time_ms'})];
            %fprintf("UnitDataCheck: Unit %d data loaded\n", unitNumber);
            unitNumber = unitNumber + 1;
            region = [region; region_];
        end
    end
    numUnit = size(unitData, 1);
    clearvars numunit i unitfilepath unittype unitfilepaths temp_ numUnit_ region_
    
    %% Generate gaussian kernel
    kernel = gausswin(ceil(kernel_size/2)*2-1, (kernel_size - 1) / (2 * kernel_std)); % kernel size is changed into an odd number for symmetrical kernel application. see Matlab gausswin docs for the second parameter.

    %% Load Unit and apply Generate Serial Data from spike timestamps(fs:1000)
    for u = 1 : numUnit
        % use max(10s from the last spike, 10s from the last NP) as the length of the serial data
        serial_data = zeros(max(...
            round(unitData.time_ms{u}(end)), ...
            max([...
                eventTime_PR_NP(end), ...
                eventTime_PR_P(end), ...
                eventTime_R_NP(end), ...
                eventTime_R_P(end)]) + 10000),...
            1);
        
        % set 1 for every spike timepoint. But only take positive values
        serial_data(round(unitData.time_ms{u})) = 1;
    
        %% Convolve Gaussian kernel 
        serial_data_kerneled =  conv(serial_data,kernel,'same');
        
        %% Get mean and std of serialized signal and apply normalization
        serial_data_mean = mean(serial_data_kerneled);
        serial_data_std = std(serial_data_kerneled);
        whole_serial_data = (serial_data_kerneled - serial_data_mean) ./ serial_data_std;
        
        clearvars serial_data_kerneled
    
        %% Select data around event time
        %eventTime_PR_NP, eventTime_PR_P, eventTime_R_NP, eventTime_R_P
        eventTimes = {eventTime_PR_NP, eventTime_PR_P, eventTime_R_NP, eventTime_R_P};
        eventData = zeros(4, binnedDataSize); 
        for eventType = 1 : 4
            eventData_ = zeros(numel(eventTimes{eventType}), binnedDataSize);
            for i_time = 1 : numel(eventTimes{eventType})
                signal_window = round(timewindow + eventTimes{eventType}(i_time));
                % Check if the window is out of range
                if (signal_window(1) >= 1) && (signal_window(2) <= numel(whole_serial_data))
                    % The index of the whole_serial_data is actual timepoint in ms.
                    % So retrive the value in the window by index.
                    eventData_(i_time, :) = mean(reshape(...
                        (conv(serial_data(signal_window(1)+1:signal_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                        timewindow_bin, binnedDataSize), 1);
                end
            end
            eventData(eventType, :) = mean(eventData_, 1);  % average across all eventTimes
        end
        ActivityData(TotalUnit + 1, :, :) = eventData';
        Region(TotalUnit + 1) = region(u);
        TotalUnit = TotalUnit + 1;
        
        %clearvars *serial_data* signal_window i_time kernel*
    end
end

%% Save
save("AllActivity.mat", 'TotalUnit', 'Region', 'ActivityData');