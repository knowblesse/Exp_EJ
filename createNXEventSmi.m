%% createNXEventSmi
% 2023 Ji Hoon Jeong
% Create smi file containing event written in NX's event file.
% Read the default smi file to get the starting timestamp for each video
% (sometimes video is segmented). Using that value, calculate the onset of
% the events, and save it into smi file. 
% I used this file to manually label the video using 'bookmark' function in
% PotPlayer. These bookmarks can be saved as .pdf file. 2023DEC19
function createNXEventSmi(tankPath)
arguments
    tankPath string = ''
end

%% Set Variables
BASEPATH = "D:\Data\Kim Data";
addpath('lib/Neuralynx/');

%% Get filepaths
if tankPath == ''
    tankPath = uigetdir(BASEPATH);
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("createNXEventSmi : Processing tank %s\n", tankPath);

tankName = regexp(tankPath, '\\(?:|#|##|$#|@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

eventFilePath = glob(tankPath, '\.nev', true);
videoFilePaths = glob(tankPath, '\.mpg', true);
% Only one video
if ~iscell(videoFilePaths)
    videoFilePaths = {videoFilePaths};
end

% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

% path sanity check
for p_ = {eventFilePath}
    if isempty(p_{1})
        error("File could not be loaded");
    end
end

clearvars p_;

%% Read Event File
[TimeStamps, ~, TTLs, ~, EventStrings] = Nlx2MatEV(...
    eventFilePath,... % Filename
    [1, 1, 1, 1, 1],... % FieldSelectionFlag
    0,... % HeaderExtractionFlag
    1);
% HEX event codes (TTL)
% 0x0000 00000 : Experiment Start/End
% 0x3000 12288 : Deactivation
% 0x3003 12291 : Enter F1
% 0x3007 12295 : N/A
% 0x3008 12296 : Enter F2
% 0x300C 12300 : N/A
% 0x3030 12336 : Enter left pellet N
% 0x30C0 12480 : Return Nest
% 0x3100 12544 : N/A
% 0x3200 12800 : N/A
% 0x3300 13056 : Enter right pellet C
% 0x7000 28672 : Activate/Deactivate Pellet
% 0x7008 28680 : Retrieve Pellet

codes = [0x0000, 0x3000, 0x3003, 0x3007, 0x3008, 0x300C, 0x3030, 0x30C0,...
    0x3100,  0x3200, 0x3300, 0x7000, 0x7008, 0x700C, 0x7300, 0x3108, 0x31C0]';

eventTable = table(...
    codes,...
    num2str(codes, '0x%X'),...
    ["Experiment Start/End", "Deactivation", "Enter F1", "N/A", "Enter F2", "N/A", "Enter left pellet N",...
        "Return Nest", "N/A", "N/A", "Enter right pellet C", "Activate/Deactivate Pellet", "Retrieve Pellet", ...
        "N/A", "N/A", "N/A", "N/A"]',...
        'VariableNames', {'Code', 'Hex Code', 'Event'});


ts = (TimeStamps - expStat.startTS)/1000/1000;
events = strings(numel(TTLs),1);
deactivationList = [];
for i = 1 : numel(TTLs)
    eventTableIndex = find(eventTable.Code == TTLs(i));
    if isempty(eventTableIndex)
        warning("New Event! %s", dec2hex(TTLs(i)));
        events(i) = "N/A";
    else
        if TTLs(i) == 0x3000 % Deactivation
            deactivationList = [deactivationList; i];
        end
        events(i) = eventTable.Event(eventTableIndex);
    end
end

eventTable = table(ts', events, int64(TimeStamps'),'VariableNames', {'Time', 'Event', 'Timestamp'});
eventTable(deactivationList,:) = [];

%% Generate smi file
% For all video
for videoPath = videoFilePaths
    % Get Video Start TS
    temp_ = regexp(videoPath{1}, '\\([^\\]+)\.mpg$', 'tokens');
    videoName = temp_{1}{1};
    smiFolder = glob(tankPath, [videoName,'.smi'], true);
    fileID_timestamp = fopen(smiFolder, "r");
    while (~strcmp(fgetl(fileID_timestamp), '<BODY>'))
    end
    temp_ = regexp(fgetl(fileID_timestamp), '(\d+)</SYNC>', 'tokens');
    videoStartTS = int64(str2double(temp_{1}{1}));
    fclose(fileID_timestamp);
    
    % Create event smi file
    fileID = fopen(fullfile(tankPath, [videoName, '_event.smi']),"w");
    smiFile = load("smiInitialLine.mat");

    % Write initial part of the smi file
    for i = 1:length(smiFile.initialLine)
        fprintf(fileID, '%s\r\n', smiFile.initialLine{i});
    end
    
    % Write event
    for i = 1 : size(eventTable,1)
        % Only write these events
        targetEvents = ["Enter F2", "Activate/Deactivate Pellet", "Return Nest"];
        if ismember(eventTable.Event(i), targetEvents)
            timeInmSec = round((eventTable.Timestamp(i) - videoStartTS) / 1000);
            fprintf(fileID, '<SYNC Start=%d><P Class=ENUSCC>%s</SYNC>\r\n', timeInmSec, eventTable.Event(i));
            fprintf(fileID, '<SYNC Start=%d><P Class=ENUSCC>%s</SYNC>\r\n', timeInmSec+100, '&nbsp');
        end
    end
    fprintf(fileID, '</BODY>\n</SAMI>');
    fclose(fileID);
end

%% Done
fprintf("createNXEventSmi : Done\n");

end