%% UnitDataCheck
BASEPATH = "D:\Data\Kim Data";
addpath('lib/Neuralynx/');

%% Get filepaths 
%tankPath = uigetdir(BASEPATH);
warning('MO');% manual override
tankPath = "D:\Data\Kim Data\@AP18_031418";
tankName = regexp(tankPath, '\\(?:|#|##|$#|@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

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

% path sanity check
for p_ = unitFilePaths
    if isempty(p_{1})
        error("File could not be loaded");
    end
end
clearvars p_;

%% Read unit file
fprintf("UnitDataCheck: Loading unit data\n");
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
    numUnit = numel(unitType);
    for i = 1 : numUnit
        temp_ = Timestamps(CellNumbers == unitType(i))'; % selected unit's timestamps
        temp_ = (temp_ - expStat.startTS) / 1000; % timestamp to relative ms
        unitData = [unitData; table(...
            unitNumber,...
            numel(temp_),...
            {temp_},...
            'VariableName', {'unitNumber', 'numSpike', 'time_ms'})];
        fprintf("UnitDataCheck: Unit %d data loaded\n", unitNumber);
        unitNumber = unitNumber + 1;
    end
end
clearvars numUnit i unitFilePath unitType unitFilePaths temp_
fprintf("UnitDataCheck: All unit data loaded\n");

%% Create cell array
unitId = 2;
TIMEWINDOW = int64([-2000, +2000]); % in ms
P_times = {};
NP_times = {};
for trial = 1 : 10
    if eventData(trial).isE == true
        continue;
    end

    window = eventData(trial).P + TIMEWINDOW;
    idx = find(all([window(1) <= unitData.timestamps{unitId}, unitData.timestamps{unitId} < window(2)], 2));
    P_times = [P_times; unitData.timestamps{unitId}(idx) - double(eventData(trial).P)];

    window = eventData(trial).NP + TIMEWINDOW;
    idx = find(all([window(1) <= unitData.timestamps{unitId}, unitData.timestamps{unitId} < window(2)], 2));
    NP_times = [NP_times; unitData.timestamps{unitId}(idx) - double(eventData(trial).NP)];
end

%%
fig1 = figure();
ax_raster1 = subplot(4,1,1:3);
ax_histo1 = subplot(4,1,4);
drawPETH(P_times, TIMEWINDOW, ax_raster1, ax_histo1, false);
title(ax_raster1, 'P Pellet');

fig2 = figure();
ax_raster2 = subplot(4,1,1:3);
ax_histo2 = subplot(4,1,4);
drawPETH(NP_times, TIMEWINDOW, ax_raster2, ax_histo2, false);
title(ax_raster2, 'NP Pellet');


