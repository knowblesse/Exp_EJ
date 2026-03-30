function [output] = calculateEventMarkerTE(tankPath, K, k_past, n_surrogates)
%% Parameters
min_events = 3;
n_subsamples = 10; % number of random subsamples for blocks with excess events
timewindow_bin = 50;        % msec
kernel_size = 500;          % msec
kernel_std = 50;            % msec
event_duration = 6000;      % 6 sec for all events
bins_per_event = event_duration / timewindow_bin; % 120 bins

%% Load Session data
tankName = regexp(tankPath, '\\(?:@)(AP.*)$', 'tokens');
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

%% Define event times
attack_times = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 1 & eventDataRaw.PelletType == "P"));
pre_robot_NP_times = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 0 & eventDataRaw.PelletType == "NP"));
robot_NP_times = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 1 & eventDataRaw.PelletType == "NP"));

%% Determine matched event count
N_matched = min([numel(pre_robot_NP_times), numel(attack_times), numel(robot_NP_times)]);
if N_matched < min_events
    warning('Session %s: Only %d matched events (min: %d). Skipping.', tankName, N_matched, min_events);
    output = [];
    return;
end

%% Define event markers
% 1. Control: midpoint, cut into N_matched chunks
firstRobotIdx = find(eventDataRaw.Robot, 1);
lastPreRobotIdx = firstRobotIdx - 1;
midpoint = double(round( ...
    (eventDataRaw.Time_ms(firstRobotIdx) - eventDataRaw.Time_ms(lastPreRobotIdx)) / 2 ...
    + eventDataRaw.Time_ms(lastPreRobotIdx)));
control_start = midpoint - N_matched * (event_duration / 2);
marker1_times = control_start + (0:N_matched-1) * event_duration;
marker1_range = [0, event_duration];

% 2. Pre-robot NP: -6 ~ 0 sec from NP
marker2_range = [-event_duration, 0];

% 3. After-attack: 0 ~ +6 sec from attack
marker3_range = [0, event_duration];

% 4. NP-robot: -6 ~ 0 sec from NP during robot
marker4_range = [-event_duration, 0];

num_marker = 4;
marker_names = {'Control', 'PreRobotNP', 'AfterAttack', 'NP_Robot'};
all_marker_times = {marker1_times, pre_robot_NP_times, attack_times, robot_NP_times};
marker_ranges = {marker1_range, marker2_range, marker3_range, marker4_range};
needs_subsample = [false, true, true, true];


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

%% Check minimum neuron count
nBLA = sum(region == "BLA");
nPFC = sum(region == "PFC");
fprintf("BLA neurons: %d | PFC neurons: %d\n", nBLA, nPFC);
if nBLA < 4 || nPFC < 4
    warning("Too few neurons (BLA: %d, PFC: %d). Skipping.", nBLA, nPFC);
    output = [];
    return;
end

BLA_idx = find(region == "BLA");
PFC_idx = find(region == "PFC");

%% Generate gaussian kernel
kernel = gausswin(ceil(kernel_size/2)*2-1, (kernel_size - 1) / (2 * kernel_std));

%% Build full convolved, z-scored signal for each unit
% Store as cell array for later snippet extraction
whole_signals = cell(numUnit, 1);
for u = 1:numUnit
    serial_data = zeros(max(round(unitData.time_ms{u}(end)), ...
        eventDataRaw.Time_ms(end) + 10000), 1);
    serial_data(round(unitData.time_ms{u})) = 1;

    serial_data_kerneled = conv(serial_data, kernel, 'same');
    serial_data_mean = mean(serial_data_kerneled);
    serial_data_std = std(serial_data_kerneled);
    if serial_data_std == 0
        serial_data_std = 1;
    end
    whole_signals{u} = (serial_data_kerneled - serial_data_mean) ./ serial_data_std;
end

%% Extract ALL events and bin them
% marker_data_3d{m}: numUnit x bins_per_event x nEvents
marker_data_3d = cell(num_marker, 1);
for m = 1:num_marker
    nEvents = numel(all_marker_times{m});
    marker_data_3d{m} = zeros(numUnit, bins_per_event, nEvents);
    for u = 1:numUnit
        for e = 1:nEvents
            signal_window = round(marker_ranges{m} + all_marker_times{m}(e));
            if signal_window(1) < 1 || signal_window(2) > numel(whole_signals{u})
                error('Window out of range: marker %d, unit %d, event %d.', m, u, e);
            end
            snippet = whole_signals{u}(signal_window(1)+1 : signal_window(2));
            marker_data_3d{m}(u, :, e) = mean(reshape(snippet, timewindow_bin, []), 1);
        end
    end
end

%% Concatenate all data for k-means
BLA_all = [];
PFC_all = [];
for m = 1:num_marker
    data = marker_data_3d{m};
    BLA_all = [BLA_all, reshape(data(BLA_idx, :, :), nBLA, [])];
    PFC_all = [PFC_all, reshape(data(PFC_idx, :, :), nPFC, [])];
end

%% K-means clustering (once, on all data)
rng(516);
BLA_labels_all = kmeans(BLA_all', K, 'Replicates', 10, 'MaxIter', 1000);
PFC_labels_all = kmeans(PFC_all', K, 'Replicates', 10, 'MaxIter', 1000);

%% Split labels into per-marker, per-event cell arrays
marker_label_events = cell(num_marker, 2); % {marker, region(1=BLA,2=PFC)}
idx_cursor = 0;
for m = 1:num_marker
    nEvents = numel(all_marker_times{m});
    bla_events = cell(nEvents, 1);
    pfc_events = cell(nEvents, 1);
    for e = 1:nEvents
        bin_idx = idx_cursor + (1:bins_per_event);
        bla_events{e} = BLA_labels_all(bin_idx);
        pfc_events{e} = PFC_labels_all(bin_idx);
        idx_cursor = idx_cursor + bins_per_event;
    end
    marker_label_events{m, 1} = bla_events;
    marker_label_events{m, 2} = pfc_events;
end

%% Compute TE for each block
te_bla2pfc = nan(1, num_marker);
te_pfc2bla = nan(1, num_marker);
p_bla2pfc = nan(1, num_marker);
p_pfc2bla = nan(1, num_marker);

for m = 1:num_marker
    fprintf('\n--- Processing: %s ---\n', marker_names{m});

    if needs_subsample(m)
        % Subsample N_matched events, repeat n_subsamples times
        te_b2p_subs = zeros(n_subsamples, 1);
        te_p2b_subs = zeros(n_subsamples, 1);
        p_b2p_subs = zeros(n_subsamples, 1);
        p_p2b_subs = zeros(n_subsamples, 1);

        nAvailable = numel(marker_label_events{m, 1});
        for s = 1:n_subsamples
            sub_idx = randperm(nAvailable, N_matched);
            bla_ev = marker_label_events{m, 1}(sub_idx);
            pfc_ev = marker_label_events{m, 2}(sub_idx);

            [te_JtoI, te_ItoJ, diag_] = transfer_entropy(pfc_ev, bla_ev, K, k_past, n_surrogates);
            te_b2p_subs(s) = te_JtoI;
            te_p2b_subs(s) = te_ItoJ;
            p_b2p_subs(s) = diag_.surrogate.JtoI.p_value;
            p_p2b_subs(s) = diag_.surrogate.ItoJ.p_value;
            fprintf('  Subsample %d/%d done\n', s, n_subsamples);
        end

        te_bla2pfc(m) = mean(te_b2p_subs);
        te_pfc2bla(m) = mean(te_p2b_subs);
        p_bla2pfc(m) = mean(p_b2p_subs);
        p_pfc2bla(m) = mean(p_p2b_subs);

    else
        % Control block: exactly N_matched events, no subsampling
        bla_ev = marker_label_events{m, 1};
        pfc_ev = marker_label_events{m, 2};

        [te_JtoI, te_ItoJ, diag_] = transfer_entropy(pfc_ev, bla_ev, K, k_past, n_surrogates);
        te_bla2pfc(m) = te_JtoI;
        te_pfc2bla(m) = te_ItoJ;
        p_bla2pfc(m) = diag_.surrogate.JtoI.p_value;
        p_pfc2bla(m) = diag_.surrogate.ItoJ.p_value;
    end

    fprintf('  TE(BLA->PFC)=%.4f (p=%.3f) | TE(PFC->BLA)=%.4f (p=%.3f)\n', ...
        te_bla2pfc(m), p_bla2pfc(m), te_pfc2bla(m), p_pfc2bla(m));
end

%% Package output
output = struct();
output.te_bla2pfc = te_bla2pfc;
output.te_pfc2bla = te_pfc2bla;
output.p_bla2pfc = p_bla2pfc;
output.p_pfc2bla = p_pfc2bla;
output.N_matched = N_matched;
output.nBLA = nBLA;
output.nPFC = nPFC;
output.K = K;
output.k_past = k_past;
output.n_surrogates = n_surrogates;
output.tankName = tankName;
output.marker_names = marker_names;
end