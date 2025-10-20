%% saveEventTimestamp
% 2023 Ji Hoon Jeong
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
tankName = regexp(tankPath, '\\(?:|#|##|$#|@)(AP.*)$', 'tokens');
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
eventDataRaw = table([], [], [], [], 'VariableNames', {'Trial', 'PelletType', 'Attempts', 'Time_ms'});

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

        % During robot phase & P pellet, add attempt data
        if trial > 10 && strcmp(pelletType, 'P')
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
    
        eventDataRaw = [eventDataRaw; table(trial, pelletType, attempt, time_ms, 'VariableNames', {'Trial', 'PelletType', 'Attempts', 'Time_ms'})];
    end

end

clearvars bm temp_ i trial pelletType time_ms attempt bookmarkFilePath bookmarkFilePaths
fprintf("saveEventTime: Bookmark info loaded\n");

%% Data Integrity Check
if ~isequal(unique(eventDataRaw.Trial)', 1:20) % don't have all 20 trials
    disp(unique(eventDataRaw.Trial)');
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
fprintf("saveEventTime: Data integrity check passed\n");

%% Create eventData
eventData = struct();
for trial = 1 : 10
    if eventDataRaw.PelletType(eventDataRaw.Trial == trial) == 'E'
        eventData(trial).isE = true;
        continue;
    else
        eventData(trial).isE = false;
    end
    eventData(trial).P = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == 'P'],2));
    eventData(trial).NP = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == "NP"],2));
end

for trial = 11 : 20
    if eventDataRaw.PelletType(eventDataRaw.Trial == trial) == 'E'
        eventData(trial).isE = true;
        continue;
    else
        eventData(trial).isE = false;
    end
    eventData(trial).P = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == 'P', eventDataRaw.Attempts == 1],2));
    eventData(trial).NP = eventDataRaw.Time_ms(all([eventDataRaw.Trial == trial, eventDataRaw.PelletType == "NP"],2));
end

%% Save
save(fullfile(tankPath, strcat(tankName, '_event.mat')), "eventData", "eventDataRaw");

%% Done
fprintf("saveEventTime : Done\n");

