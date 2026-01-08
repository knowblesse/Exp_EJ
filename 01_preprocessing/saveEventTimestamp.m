%% saveEventTimestamp
% 2026 Ji Hoon Jeong
% Function for reading bookmark file,
% check bookmark integrity,
% and save it in a time from the exp. start in ms. 2023DEC20
% Remember that "Time" means the relative time in ms from the expStat.startTS timestamp 
function saveEventTimestamp(tankPath)
arguments
    tankPath string = ''
end

BASEPATH = "H:\Data\Kim Data";

%% Get filepaths
if tankPath == ''
    tankPath = uigetdir(BASEPATH);
end

fprintf("saveEventTime : Processing tank %s\n", tankPath);
tankName = regexp(tankPath, '\\(?:|@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

bookmarkFilePaths = glob(tankPath, '\.pbf', true);

%% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

clearvars p_;

%% Read Bookmark File
fprintf("saveEventTime: Loading bookmark data\n");
% Only one video
if ~iscell(bookmarkFilePaths)
    bookmarkFilePaths = {bookmarkFilePaths};
end

% Event data table
eventDataRaw = table([], [], [], [], [], 'VariableNames', {'Trial', 'Robot', 'PelletType', 'Attempts', 'Time_ms'});

% for all bookmark files, 
robotPhaseFlag = false;
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

        % Detect ROBOT separator, set the flag
        if contains(bm, 'ROBOT')
            robotPhaseFlag = true;
            continue;
        end
    
        % Extract info using regexp
        % e.g. 1=19300*04_NP*293039....
        % e.g. 10=1928300*17_P1*293039....
        % number(1~) = (time) * (Trial 2 digit) _ (type P or NP) (attemp none or digit) 
        temp_ = regexp(bm, "\d+=(?<time>\d+)\*(?<trial>\d\d)_(?<type>(P|NP))(?<attempt>\d*)*", "names");
    
        % remove any corrupted line
        if numel(temp_) == 0
            continue;
        end

        trial = str2double(temp_.trial);
        pelletType = string(temp_.type);
        time = str2double(temp_.time);

        % During robot phase & P pellet, add attempt data
        if robotPhaseFlag && strcmp(pelletType, 'P')
            attempt = str2double(temp_.attempt);
        else
            attempt = 0;
        end
    
        % Change bookmark's time into timestamp using smi data
        idx_ = find(time2TS{time2TS_idx} >= time, 1);
        if isempty(idx_)
            error('Can not convert time to timestamp');
        end
        time_ms = (time2TS{time2TS_idx}(idx_, 2) - expStat.startTS) / 1000; % in ms
    
        eventDataRaw = [eventDataRaw; table(trial, robotPhaseFlag, pelletType, attempt, time_ms, 'VariableNames', {'Trial', 'Robot', 'PelletType', 'Attempts', 'Time_ms'})];
    end

end

clearvars bm temp_ i trial pelletType time_ms attempt bookmarkFilePath bookmarkFilePaths
fprintf("saveEventTime: Bookmark info loaded\n");

%% Data Integrity Check
robotPhaseStart = max(eventDataRaw.Trial(eventDataRaw.Robot == 0)) + 1;
totalTrial = max(eventDataRaw.Trial);
% Check Each Pre-robot phase has NP and P data
temp1 = eventDataRaw.Trial(eventDataRaw.Robot == 0);
temp2 = reshape(repmat(1:max(temp1), 2), 1, []);
if temp1 ~= temp2
    error('Odd number of Pre-robot phase data');
end

temp1 = sum(eventDataRaw.PelletType(eventDataRaw.Robot == 0) == "P");
temp2 = sum(eventDataRaw.PelletType(eventDataRaw.Robot == 0) == "NP");
if temp1 ~= temp2
    error('Imbalance NP and P in pre-robot phase');
end

% Check each robot phase has NP data
for t = robotPhaseStart : max(eventDataRaw.Trial)
    if ~any(eventDataRaw.PelletType(eventDataRaw.Trial == t) == "NP")
        error('Trial %d do not have NP data', t);
    end
end

clearvars t
fprintf("saveEventTime: Data integrity check passed\n");

%% Create eventData
eventData = struct();
for trial = 1 : robotPhaseStart-1
    if eventDataRaw.PelletType(eventDataRaw.Trial == trial) == 'E'
        error('Error trial');
    end
    eventData(trial).P = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == 'P'],2));
    eventData(trial).NP = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == "NP"],2));
    eventData(trial).Robot = 0;
end

for trial = robotPhaseStart : totalTrial
    if eventDataRaw.PelletType(eventDataRaw.Trial == trial) == 'E'
        error('Error trial');
    end
    eventData(trial).P = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == 'P', eventDataRaw.Attempts == 1],2));
    eventData(trial).NP = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == "NP"],2));
    eventData(trial).Robot = 1;
end

%% Save
save(fullfile(tankPath, strcat(tankName, '_event.mat')), "eventData", "eventDataRaw");

%% Done
fprintf("saveEventTime : Done\n");

