function [output, pfc_entropy, bla_entropy, pfc_unit_idx] = calculateEventMarkerMI_perPFC(tankPath, K)

%% Parameters
timewindow_bin = 50; % msec
kernel_size = 1000;
kernel_std = 100;

%% Load Session data
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

%% Define event markers
% Group1 (General control): -10 ~ +10 data of mid-point
if eventDataRaw.Trial(20) ~= 10 || eventDataRaw.Trial(21) ~= 11
    error("Check eventDataRaw file");
end
marker1_range = [-5000, +5000];
marker1 = double(round( ...
    (eventDataRaw.Time_ms(21) - eventDataRaw.Time_ms(20)) /2 + eventDataRaw.Time_ms(20)...
    ));

% Group2 (Pre-robot): -1 ~ +1 data during NP and P
marker2_range = [-1000, +1000];
marker2 = sort(double([eventData(1:10).NP, eventData(1:10).P]));

% Group 3 (Robot before P): -5 ~ 0 data during P
% Group 4 (Robot after P): 0 ~ +5 data during P
marker3_range = [-5000, 0];
marker4_range = [0, +5000];
marker3 = double(eventDataRaw.Time_ms(eventDataRaw.Trial >= 11 & eventDataRaw.PelletType == "P"));
marker4 = marker3;
fprintf("Num P during Robot phase: %d", numel(marker3));

% Group 5 (Robot before NP right after P): -5 ~ 0 data during NP
marker5_range = [-5000, 0];
marker5 = [];
for i = 22:size(eventDataRaw,1)
    if eventDataRaw.PelletType(i) == "NP" && eventDataRaw.PelletType(i-1) == "P"
        marker5 = [marker5, double(eventDataRaw.Time_ms(i))];
    end
end
fprintf(" | Num NP after P: %d\n", numel(marker5));

num_marker = 5;
marker_ranges = {marker1_range, marker2_range, marker3_range, marker4_range, marker5_range};
markers = {marker1, marker2, marker3, marker4, marker5};

%% Read unit file
unitData = table([], [], {}, 'VariableName', {'unitNumber', 'numSpike', 'time_ms'});
unitNumber = 1;
region = string([]);
for unitFilePath = unitFilePaths
    [Timestamps, ~, CellNumbers, ~, ~] = Nlx2MatSpike(...
        unitFilePath{1},...
        [1, 1, 1, 1, 1],...
        0,...
        1);

    regResult = regexp(unitFilePath{1}, '(?<sessionName>@AP.*)\\(?<region>(BLA|PFC)).*TT(?<electrodeNumber>\d\d).\w\w\w', 'names');
    region_ = regResult.region;

    unitType = unique(CellNumbers);
    numUnit_ = numel(unitType);
    for i = 1 : numUnit_
        temp_ = Timestamps(CellNumbers == unitType(i))';
        temp_ = (temp_ - expStat.startTS) / 1000;
        temp_ = temp_(temp_ > 0);
        
        unitData = [unitData; table(...
            unitNumber,...
            numel(temp_),...
            {temp_},...
            'VariableName', {'unitNumber', 'numSpike', 'time_ms'})];
        unitNumber = unitNumber + 1;
        region = [region; region_];
    end
end
numUnit = size(unitData, 1);

%% Generate gaussian kernel
kernel = gausswin(ceil(kernel_size/2)*2-1, (kernel_size - 1) / (2 * kernel_std));

%% Parse neural data
marker_datasize = zeros(num_marker,1);
marker_data = cell(num_marker, 1);
for i = 1 : num_marker
    marker_datasize(i) = diff(marker_ranges{i}) / timewindow_bin;
    marker_data{i} = zeros(numUnit, marker_datasize(i) * numel(markers{i}));
end

for u = 1 : numUnit
    serial_data = zeros(max(round(unitData.time_ms{u}(end)), eventDataRaw.Time_ms(end) + 10000),1);
    serial_data(round(unitData.time_ms{u})) = 1;
    serial_data_kerneled = conv(serial_data, kernel, 'same');
    serial_data_mean = mean(serial_data_kerneled);
    serial_data_std = std(serial_data_kerneled);
    
    clearvars serial_data_kerneled

    for i_marker = 1 : num_marker
        for i_time = 1 : numel(markers{i_marker})
            signal_window = round(marker_ranges{i_marker} + markers{i_marker}(i_time));
            if ~( (signal_window(1) >= 1) && (signal_window(2) <= numel(serial_data)) )
                error('Window out of range');
            end
            marker_data{i_marker}(u, ...
                marker_datasize(i_marker) * (i_time-1) + 1 : ...
                marker_datasize(i_marker) * (i_time) ) = mean(reshape(...
                    (conv(serial_data(signal_window(1)+1:signal_window(2)), kernel, 'same') - serial_data_mean) ./ serial_data_std,...
                    timewindow_bin, []), 1);
        end
    end
end

clearvars *serial_data* signal_window i_time kernel*

%% Split BLA and PFC
bla_idx = region == "BLA";
pfc_idx = region == "PFC";
num_pfc = sum(pfc_idx);
pfc_unit_idx = find(pfc_idx);

marker_data_BLA = cell(num_marker, 1);
marker_data_PFC = cell(num_marker, 1);
for i = 1 : num_marker
    marker_data_BLA{i} = marker_data{i}(bla_idx, :);
    marker_data_PFC{i} = marker_data{i}(pfc_idx, :);
end

BLA_all = cell2mat(marker_data_BLA');
PFC_all = cell2mat(marker_data_PFC');

%% KMean Clustering
rng(516);
% BLA: population 전체를 클러스터링
BLA_labels_all = kmeans(BLA_all', K, 'Replicates', 10, 'MaxIter', 1000);

% PFC: 각 뉴런별로 개별 클러스터링
PFC_labels_all = zeros(size(PFC_all, 2), num_pfc);
for n = 1 : num_pfc
    PFC_labels_all(:, n) = kmeans(PFC_all(n, :)', K, 'Replicates', 10, 'MaxIter', 1000);
end

%% Split labels by marker
Ti = cellfun(@(X) size(X, 2), marker_data_BLA);
cs = [0; cumsum(Ti)];

marker_label_BLA = cell(num_marker, 1);
marker_label_PFC = cell(num_marker, num_pfc);
for i = 1 : num_marker
    idx = (cs(i)+1):cs(i+1);
    marker_label_BLA{i} = BLA_labels_all(idx);
    for n = 1 : num_pfc
        marker_label_PFC{i, n} = PFC_labels_all(idx, n);
    end
end

%% Compute normalized MI for each PFC neuron
output = zeros(num_pfc, num_marker);
pfc_entropy = zeros(num_pfc, num_marker);
bla_entropy = zeros(1, num_marker);

% 전체 데이터에서 H_BLA 계산 (정규화용)
[~, H_BLA_total, ~] = mutual_information(BLA_labels_all, BLA_labels_all, K);

for n = 1 : num_pfc
    % 해당 PFC 뉴런의 전체 엔트로피 (정규화용)
    [~, ~, H_PFC_total] = mutual_information(PFC_labels_all(:, n), PFC_labels_all(:, n), K);
    
    for i = 1 : num_marker
        [mi, h_bla, h_pfc] = mutual_information(marker_label_BLA{i}, marker_label_PFC{i, n}, K);
        output(n, i) = mi / sqrt(H_BLA_total * H_PFC_total);
        pfc_entropy(n, i) = h_pfc;
        if n == 1
            bla_entropy(i) = h_bla;
        end
    end
end

end