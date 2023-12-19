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
trackingFilePath = glob(tankPath, '\.nvt', true);
bookmarkFilePaths = glob(tankPath, '\.pbf', true);

% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

% path sanity check
for p_ = {bookmarkFilePaths, unitFilePaths, trackingFilePath}
    if isempty(p_{1})
        error("File could not be loaded");
    end
end
clearvars p_;

% Show info
fprintf("================================================================================\n", tankName);
fprintf("Tank Name : %s\n", tankName);
%fprintf("Num unit : %d\n", numel(unitFilePaths));

%% Read unit file
fprintf("UnitDataCheck: Loading unit data\n");
unitData = table([], [], {}, 'VariableName', {'unitNumber', 'numSpike', 'timestamps'});

unitNumber = 1;
for unitFilePath = unitFilePaths
    % Load Unit Data
    Timestamps = int64([]);
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
            'VariableName', {'unitNumber', 'numSpike', 'timestamps'})];
        fprintf("UnitDataCheck: Unit %d data loaded\n", unitNumber);
        unitNumber = unitNumber + 1;
    end
end
clearvars numUnit i unitFilePath unitType unitFilePaths
fprintf("UnitDataCheck: All unit data loaded\n");

%% Read Bookmark File
fprintf("UnitDataCheck: Loading bookmark data\n");
% Only one video
if ~iscell(bookmarkFilePaths)
    bookmarkFilePaths = {bookmarkFilePaths};
end

% Event data table
eventDataRaw = table([], [], [], [], 'VariableNames', {'Trial', 'PelletType', 'Attempts', 'Timestamp'});

% for all bookmark files, 
for b_idx = 1 : numel(bookmarkFilePaths)
    % Get bookmark data
    temp_ = readlines(bookmarkFilePaths{b_idx});
    bookmarkData = temp_(2:end);

    % Select which time2TS to use (from smi file)
    temp_ = regexp(bookmarkFilePaths{b_idx}, "\\([^\\]*)\.pbf", 'tokens');
    time2TS_idx = find(strcmp(time2TS_filename, temp_{1}{1}));
    if isempty(time2TS_idx)
        error("Check time2TS data");
    end

    % for all bookmark lines
    for i = 1 : size(bookmarkData,1)
        bm = bookmarkData(i);
        % Remove ROBOT separator
        if contains(bm, 'ROBOT')
            continue;
        end
    
        % Extract info using regexp
        temp_ = regexp(bm, "\d+=(?<time>\d+)\*(?<trial>\d\d)_(?<type>(P|NP|E))(?<attempt>\d*)*", "names");
    
        % remove any corrupted line
        if numel(temp_) == 0
            continue;
        end

        trial = str2double(temp_.trial);
        pelletType = string(temp_.type);
        time = str2double(temp_.time);
        if trial > 10
            attempt = str2double(temp_.attempt);
        else
            attempt = 0;
        end
    
        % Change bookmark's time into timestamp using smi data
        idx_ = find(time2TS{time2TS_idx} >= time, 1);
        if isempty(idx_)
            error('Can not convert time to timestamp');
        end
        timestamp = (time2TS{time2TS_idx}(idx_, 2) - expStat.startTS) / 1000; % in ms
    
        eventDataRaw = [eventDataRaw; table(trial, pelletType, attempt, timestamp, 'VariableNames', {'Trial', 'PelletType', 'Attempts', 'Timestamp'})];
    end

end

clearvars bm temp_ i trial pelletType timestamp attempt bookmarkFilePath bookmarkFilePaths
fprintf("UnitDataCheck: Bookmark info loaded\n");

%% Data Integrity Check
if ~all(unique(eventDataRaw.Trial) == (1:20)') % don't have all 20 trials
    error('Trial Missing');
end

for t = 1 : 10
    if sum(eventDataRaw.Trial == t) ~= 2 % don't have two pellet parts in all pre-robot trials
        if (sum(eventDataRaw.Trial == t) == 1) && (eventDataRaw.PelletType(eventDataRaw.Trial == t) == 'E')
            % if not, check if it is an error trial
            continue;
        else
            error('Pre-robot %d trial does not have two pellet part', t);
        end
    end
    if all(unique(eventDataRaw.PelletType(eventDataRaw.Trial == t)) ~= ["NP";"P"])
        % check NP and P
        error('Pre-robot %d trial has weird pellet type', t);
    end
end
for t = 11 : 20
    if all(unique(eventDataRaw.PelletType(eventDataRaw.Trial == t)) ~= ["NP";"P"])
        % check NP and P
        error('Robot %d trial has weird pellet type', t);
    end
end
clearvars t
fprintf("UnitDataCheck: Data integrity check passed\n");

%% Create eventData
eventData = struct();
for trial = 1 : 10
    if eventDataRaw.PelletType(eventDataRaw.Trial == trial) == 'E'
        eventData(trial).isE = true;
        continue;
    else
        eventData(trial).isE = false;
    end
    eventData(trial).P = eventDataRaw.Timestamp(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == 'P'],2));
    eventData(trial).NP = eventDataRaw.Timestamp(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == "NP"],2));
end

for trial = 11 : 20
    if eventDataRaw.PelletType(eventDataRaw.Trial == trial) == 'E'
        eventData(trial).isE = true;
        continue;
    else
        eventData(trial).isE = false;
    end
    eventData(trial).P = eventDataRaw.Timestamp(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == 'P', eventDataRaw.Attempts == 1],2));
    eventData(trial).NP = eventDataRaw.Timestamp(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == "NP"],2));
end

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


