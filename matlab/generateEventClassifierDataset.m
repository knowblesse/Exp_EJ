function [X, y] = generateEventClassifierDataset(tankPath, timewindow, timewindow_bin, kernel_size, kernel_std)
%% generateEventClassifierDataset()
% generate dataset for event(head entry, avoid, escape) classifier
% tank_location : string. location of tank
% timewindow : [TIMEWINDOW_LEFT(ms), TIMEWINDOW_RIGHT(ms)] default=[-1000, +1000](ms)
% timewindow_bin : bin size(ms) of the window. reshape function is used for binning. default=100(ms)
% kernel_size : size of the gaussian kernel. default= 1000(ms)
% kernel_width : width(std) of the gaussian kernel. default=100(ms)
arguments
    tankPath string = ''
    timewindow (1,2) = [-2000, +2000]
    timewindow_bin = 100
    kernel_size = 1000;
    kernel_std = 100;
end

BASEPATH = "D:\Data\Kim Data";
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

%% Load event file
load(fullfile(tankPath, strcat(tankName, '_event.mat')));
if ~exist('eventData', 'var')
    error("Event data not loaded properly")
end

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
        fprintf("UnitDataCheck: Unit %d data loaded\n", unitNumber);
        unitNumber = unitNumber + 1;
    end
end
numUnit = size(unitData, 1);
clearvars numunit i unitfilepath unittype unitfilepaths temp_ numUnit_
fprintf("generateEventclassifierdataset : all unit data loaded\n");

%% Generate gaussian kernel
kernel = gausswin(ceil(kernel_size/2)*2-1, (kernel_size - 1) / (2 * kernel_std)); % kernel size is changed into an odd number for symmetrical kernel application. see Matlab gausswin docs for the second parameter.

%% Generate Array for Data
warning('P vs NP in pre-robot session');
windowsize = diff(timewindow);
binnedDataSize = windowsize / timewindow_bin;
numData = numUnit * binnedDataSize;

% Check valid trials
validTrials = find(~cell2mat({eventData(1:10).isE}));
numTrial = numel(validTrials); 

X = cell(numTrial*2, numData);
y = zeros(numTrial * 2, 1);

%% Load Unit and apply Generate Serial Data from spike timestamps(fs:1000)
for u = 1 : numUnit
    % use max(10s from the last spike, 10s from the last NP) as the length of the serial data
    serial_data = zeros(max(round(unitData.time_ms{u}(end)), eventData(end).NP + 10),1);
    
    % set 1 for every spike timepoint. But only take positive values
    serial_data(round(unitData.time_ms{u})) = 1;

    %% Convolve Gaussian kernel 
    serial_data_kerneled =  conv(serial_data,kernel,'same');
    
    %% Get mean and std of serialized signal and apply normalization
    serial_data_mean = mean(serial_data_kerneled);
    serial_data_std = std(serial_data_kerneled);
    whole_serial_data = (serial_data_kerneled - serial_data_mean) ./ serial_data_std;
    
    clearvars serial_data_kerneled

    %% Divide by EVENT Marker
    P = cell(numTrial,1);
    NP = cell(numTrial,1);
    
    for trial = validTrials
        % Get Peri-Event Window
        P_window = round(timewindow + double(eventData(trial).P));
        NP_window = round(timewindow + double(eventData(trial).NP));

        % Check if the window is out of range
        if (P_window(1) >= 1) && (P_window(2) <= numel(whole_serial_data))
            % Since the index of the whole_serial_data is actual timepoint in ms,
            % retrive the value in the window by index.
            P{trial} = mean(reshape(...
                (conv(serial_data(P_window(1)+1:P_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                timewindow_bin, binnedDataSize), 1);
        end

        if (NP_window(1) >= 1) && (NP_window(2) <= numel(whole_serial_data))
            NP{trial} = mean(reshape(...
                (conv(serial_data(NP_window(1)+1:NP_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                timewindow_bin, binnedDataSize), 1);
        end
    end
    
    %% Remove Empty Data resulted by index out of the range
    % ex. when you generate -8 ~ -6s offset data, -8 sec goes behind the exp start time in the first
    % trial. 
    P = P(~cellfun('isempty',P));
    NP = NP(~cellfun('isempty',NP));
    
    %% Save Data
    % if the dataset size is reduced because of the index output the range issue, reinitialize the X
    % Main loop of this code is based on unit. So if the index issue occurs, from the first unit, the
    % size of the X will be changed. From the next unit, since the X size match,, size changing code
    % part will not run.
    if size([P; NP], 1) ~= size(X,1) 
        X = cell(size([P; NP], 1), numUnit_);
    end
    X(:,u) = [P; NP];
end

%% Generate X array
X = cell2mat(X);

%% Generate y array
y = [1*ones(numTrial,1);...
     2*ones(numTrial,1)];
fprintf('generateEventClassifierDataset : Complete %s\n',tankName)
end
