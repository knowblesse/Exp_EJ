function [output, bla, pfc] = calculateTemporalMI(tankPath, K)

%% Parameters
timewindow_bin = 50; % msec
kernel_size = 1000;
kernel_std = 100;

%% Load Session data
%tankPath = 'H:\Data\Kim Data\@AP18_032618';

%fprintf("generateEventClassifierDataset : Processing tank %s\n", tankPath);
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
eventFilePath = fullfile(tankPath, strcat(tankName, '_event.mat'));
load(eventFilePath);

%% Define markers around P during Robot phase
num_marker = 11;

% check sanity
if eventDataRaw.Trial(20) ~= 10 | eventDataRaw.Trial(21) ~= 11
    error("Check eventDataRaw file");
end
marker_ranges = {[-5000, +5000]};
% Setup control marker
markers = {double(round( ...
    (eventDataRaw.Time_ms(21) - eventDataRaw.Time_ms(20)) /2 + eventDataRaw.Time_ms(20)...
    ))}; % index 20 : last NP or P in Pre-robot phase

%Setup marker around P during robot phase
for i = 1 : 10
    marker_ranges = [marker_ranges, [-6000 + 2000*(i-1), -6000 + 2000*i]];
    markers = [markers, double(eventDataRaw.Time_ms(eventDataRaw.Trial >= 11 & eventDataRaw.PelletType == "P"))];
end

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

%% Parse neural data
% ex) -10 ~ +10 sec & 100ms bin
% => each unit's activity during 100ms is summarized as one value.
marker_datasize = zeros(num_marker,1);
marker_data = cell(num_marker, 1);
for i = 1 : num_marker
    marker_datasize(i) = diff(marker_ranges{i}) / timewindow_bin;
    marker_data{i} = zeros(numUnit, marker_datasize(i) * numel(markers{i}));
end

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

    %% Select data around marker time
    for i_marker = 1 : num_marker
        for i_time = 1 : numel(markers{i_marker})
            signal_window = round(marker_ranges{i_marker} + markers{i_marker}(i_time));
            % Check if the window is out of range
            if ~( (signal_window(1) >= 1) && (signal_window(2) <= numel(whole_serial_data)) )
                error('Window out of range');
            end
            % The index of the whole_serial_data is actual timepoint in ms.
            % So retrive the value in the window by index.
            marker_data{i_marker}(u, ...
                marker_datasize(i_marker) * (i_time-1) + 1 : ...
                marker_datasize(i_marker) * (i_time) ) = mean(reshape(...
                    (conv(serial_data(signal_window(1)+1:signal_window(2)),kernel,'same') - serial_data_mean) ./ serial_data_std,...
                    timewindow_bin, []), 1);
        end
    end
end

clearvars *serial_data* signal_window i_time kernel*

% now we have marker_data

%% Split BLA and PFC
marker_data_split = cell(num_marker, 2);
for i = 1 : num_marker
    marker_data_split{i, 1} = marker_data{i}(region == "BLA", :); % num neuron x num bin 
    marker_data_split{i, 2} = marker_data{i}(region == "PFC", :);
end

% each marker_data_split{i, 1} has same row but different bin.
% call marker_data_split(:,1), transpose by '.
% now we can use cell2mat
BLA_all = cell2mat(marker_data_split(:,1)'); % num neuron x all bins
PFC_all = cell2mat(marker_data_split(:,2)');

%% KMean Clustering to reduce state space
rng(516);
BLA_labels_all = kmeans(BLA_all', K, 'Replicates', 10, 'MaxIter', 1000); % row should be samples and col should be dimension (neuron)
PFC_labels_all = kmeans(PFC_all', K, 'Replicates', 10, 'MaxIter', 1000);

%% Split BLA and PFC data
marker_label = cell(num_marker, 2);
Ti = cellfun(@(X) size(X,2), marker_data_split(:,1));
cs = [0; cumsum(Ti)];
for i = 1:num_marker
    idx = (cs(i)+1):cs(i+1);
    marker_label{i,1} = BLA_labels_all(idx);
    marker_label{i,2} = PFC_labels_all(idx);
end

clearvars *_data_BLA *_data_PFC *labels_

%% Compute zMI
[~, Hx, Hy] = mutual_information(BLA_labels_all, PFC_labels_all, K);

if Hx == 0 | Hy == 0
    error("Weird entropy");
end

output = zeros(1, num_marker);
bla = zeros(1, num_marker);
pfc = zeros(1, num_marker);
for i = 1 : num_marker
    [m_, hx, hy] = mutual_information(marker_label{i, 1}, marker_label{i, 2}, K);
    output(i) = m_ / sqrt(Hx * Hy);
    bla(i) = hx;
    pfc(i) = hy;
end



end