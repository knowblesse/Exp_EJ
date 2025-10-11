function [output] = generatePeriEventDataset(tankPath, timewindow, timewindow_bin, kernel_size, kernel_std)
%% generateEventClassifierDataset()
% Generalized dataset generator. This function takes two event times,
% eventTime1 and eventTime2, and parse neural data.
% tank_location : string. location of tank
% eventTime1 : 1D array. timepoint of event 1 (ms)
% eventTIme2 : 1D array. timepoint of event 2 (ms)
% timewindow : [TIMEWINDOW_LEFT(ms), TIMEWINDOW_RIGHT(ms)] default=[-1000, +1000](ms)
% timewindow_bin : bin size(ms) of the window. reshape function is used for binning. default=100(ms)
% kernel_size : size of the gaussian kernel. default= 1000(ms)
% kernel_width : width(std) of the gaussian kernel. default=100(ms)
arguments
    tankPath string = ''
    timewindow (1,2) = [-2000, +2000]
    timewindow_bin = 50
    kernel_size = 1000;
    kernel_std = 100;
end

BASEPATH = "H:\Data\Kim Data";
addpath('lib/Neuralynx/');

%% Get filepaths
if tankPath == ''
    tankPath = uigetdir(BASEPATH);
end

fprintf("generateEventClassifierDataset : Processing tank %s\n", tankPath);
tankName = regexp(tankPath, '\\(?:|#|##|$#|@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

%% Get unit file Paths
unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);

%% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

%% Load Event file
eventFilePath = fullfile(tankPath, strcat(tankName, '_event.mat'));
load(eventFilePath);

%% Read unit file
fprintf("generateEventClassifierDataset : Loading unit data\n");
unitData = table([], [], {}, 'VariableName', {'unitNumber', 'numSpike', 'time_ms'});

unitNumber = 1;
for unitFilePath = unitFilePaths
    % Load Unit Data
    [Timestamps, ~, CellNumbers, ~, Samples] = Nlx2MatSpike(...
        unitFilePath{1},...
        [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
        0,... %Extract Header
        1);

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
    end
end
numUnit = size(unitData, 1);
clearvars numunit i unitfilepath unittype unitfilepaths temp_ numUnit_
fprintf("generateEventclassifierdataset : all unit data loaded\n");

%% Generate gaussian kernel
kernel = gausswin(ceil(kernel_size/2)*2-1, (kernel_size - 1) / (2 * kernel_std)); % kernel size is changed into an odd number for symmetrical kernel application. see Matlab gausswin docs for the second parameter.

%% Generate Array for Data
windowsize = diff(timewindow);
binnedDataSize = windowsize / timewindow_bin;

%% Preallocate Dataset variable
output = struct();
output.PR_NP = [];
output.PR_P = [];
output.R_NP = [];
output.R_P = [];

%% Setup event times
time_PR_NP = eventDataRaw.Time_ms(eventDataRaw.Trial <= 10 & eventDataRaw.PelletType == "NP");
time_PR_P = eventDataRaw.Time_ms(eventDataRaw.Trial <= 10 & eventDataRaw.PelletType == "P");
time_R_NP = eventDataRaw.Time_ms(eventDataRaw.Trial > 10 & eventDataRaw.PelletType == "NP");
time_R_P = eventDataRaw.Time_ms(eventDataRaw.Trial > 10 & eventDataRaw.PelletType == "P");

%% Load Unit and apply Generate Serial Data from spike timestamps(fs:1000)
for u = 1 : numUnit
    % use max(10s from the last spike, 10s from the last NP) as the length of the serial data
    serial_data = zeros(max(round(unitData.time_ms{u}(end)), eventDataRaw.Time_ms(end) + 10000),1);
    
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
    temp_unit_activity = zeros(numel(time_PR_NP), binnedDataSize);
    for i_time = 1 : numel(time_PR_NP)
        signal_window = round(timewindow + double(time_PR_NP(i_time)));
        % Check if the window is out of range
        if (signal_window(1) >= 1) && (signal_window(2) <= numel(whole_serial_data))
            % The index of the whole_serial_data is actual timepoint in ms.
            % So retrive the value in the window by index.
            temp_unit_activity(i_time, :) = mean(reshape(...
                (conv(serial_data(signal_window(1)+1:signal_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                timewindow_bin, binnedDataSize), 1);
        end
    end
    output.PR_NP = [output.PR_NP; mean(temp_unit_activity)];

    temp_unit_activity = zeros(numel(time_PR_P), binnedDataSize);
    for i_time = 1 : numel(time_PR_P)
        signal_window = round(timewindow + double(time_PR_P(i_time)));
        % Check if the window is out of range
        if (signal_window(1) >= 1) && (signal_window(2) <= numel(whole_serial_data))
            % The index of the whole_serial_data is actual timepoint in ms.
            % So retrive the value in the window by index.
            temp_unit_activity(i_time, :) = mean(reshape(...
                (conv(serial_data(signal_window(1)+1:signal_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                timewindow_bin, binnedDataSize), 1);
        end
    end
    output.PR_P = [output.PR_P; mean(temp_unit_activity)];

    temp_unit_activity = zeros(numel(time_R_NP), binnedDataSize);
    for i_time = 1 : numel(time_R_NP)
        signal_window = round(timewindow + double(time_R_NP(i_time)));
        % Check if the window is out of range
        if (signal_window(1) >= 1) && (signal_window(2) <= numel(whole_serial_data))
            % The index of the whole_serial_data is actual timepoint in ms.
            % So retrive the value in the window by index.
            temp_unit_activity(i_time, :) = mean(reshape(...
                (conv(serial_data(signal_window(1)+1:signal_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                timewindow_bin, binnedDataSize), 1);
        end
    end
    output.R_NP = [output.PR_NP; mean(temp_unit_activity)];

    temp_unit_activity = zeros(numel(time_R_P), binnedDataSize);
    for i_time = 1 : numel(time_R_P)
        signal_window = round(timewindow + double(time_R_P(i_time)));
        % Check if the window is out of range
        if (signal_window(1) >= 1) && (signal_window(2) <= numel(whole_serial_data))
            % The index of the whole_serial_data is actual timepoint in ms.
            % So retrive the value in the window by index.
            temp_unit_activity(i_time, :) = mean(reshape(...
                (conv(serial_data(signal_window(1)+1:signal_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                timewindow_bin, binnedDataSize), 1);
        end
    end
    output.R_P = [output.PR_P; mean(temp_unit_activity)];

end

fprintf('generateEventClassifierDataset : Complete %s\n',tankName)
end
