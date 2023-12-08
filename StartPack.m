%% Set Variables
BASEPATH = "D:\Data\Kim Data";
addpath('Lib/Neuralynx/');

%% Get filepaths 
%tankPath = uigetdir(BASEPATH);
warning('MO');% manual override
tankPath = "D:\Data\Kim Data\AP18_031418";
tankName = regexp(tankPath, '\\(AP.*)$', 'tokens');
tankName = tankName{1}{1};

eventFilePath = glob(tankPath, '\.nev', true);
videoFilePath = glob(tankPath, '\.nvt', true);
unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);

% path sanity check
for p_ = {eventFilePath, videoFilePath, unitFilePaths}
    if isempty(p_{1})
        error("File could not be loaded");
    end
end

% Show info
fprintf("================================================================================\n", tankName);
fprintf("Tank Name : %s\n", tankName);
fprintf("Num unit : %d\n", numel(unitFilePaths));

clearvars p_;

%% Read Video Tracking File 
[TimeStamps, ExtractedX, ExtractedY, ExtractedAngle, Targets, Points] = Nlx2MatVT(...
    videoFilePath,...
    [1, 1, 1, 1, 1, 1],... % Time, X, Y, angle, targets, points
    0,... %ExtractHeader
    1);
startTimeStamp = TimeStamps(1);

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
% 0x3300 13056 : Enter right pellet C
% 0x7000 28672 : Activate/Deactivate Pellet
% 0x7008 28680 : Retrieve Pellet

codes = [0x0000, 0x3000, 0x3003, 0x3007, 0x3008, 0x300C, 0x3030, 0x30C0, 0x3300, 0x7000, 0x7008]';

eventTable = table(...
    codes,...
    num2str(codes, '0x%X'),...
    ["Experiment Start/End", "Deactivation", "Enter F1", "N/A", "Enter F2", "N/A", "Enter left pellet N",...
        "Return Nest", "Enter right pellet C", "Activate/Deactivate Pellet", "Retrieve Pellet"]',...
        'VariableNames', {'Code', 'Hex Code', 'Event'});


ts = (TimeStamps - startTimeStamp)/1000/1000;
events = strings(numel(TTLs),1);
deactivationList = [];
for i = 1 : numel(TTLs)
    eventTableIndex = find(eventTable.Code == TTLs(i));
    if isempty(eventTableIndex)
        error("New Event! %d", TTLs(i));
    end
    if TTLs(i) == 0x3000 % Deactivation
        deactivationList = [deactivationList; i];
    end
    events(i) = eventTable.Event(eventTableIndex);
end

output = table(ts', events, num2str(TimeStamps'),'VariableNames', {'Time', 'Event', 'Timestamp'});
output(deactivationList,:) = [];

%% Generate smi file

fileID = fopen("Test.smi","w");

linesToWrite = {
    '<SAMI>', ...
    '<HEAD>', ...
    '<TITLE>Neuralynx Video Timestamp</TITLE>', ...
    '<STYLE TYPE="text/css">', ...
    '<!--', ...
    'P {', ...
    'font-size:1 ems;', ...
    'font-family: Arial;', ...
    'font-weight: normal;', ...
    'color: #FFFFFF;', ...
    'background-color: #000000;', ...
    'text-align: center;', ...
    '}', ...
    '.ENUSCC { name: English; lang: EN-US-CC; }', ...
    '-->', ...
    '</STYLE>', ...
    '</HEAD>', ...
    '<BODY>'
};
for i = 1:length(linesToWrite)
    fprintf(fileID, '%s\r\n', linesToWrite{i});
end

for i = 1 : size(output,1)
    fprintf(fileID, '<SYNC Start=%d><P Class=ENUSCC>%s</SYNC>\r\n', round(output.Time(i)*1000), output.Event(i));
    if i < size(output,1)
        fprintf(fileID, '<SYNC Start=%d><P Class=ENUSCC>%s</SYNC>\r\n',...
            min(round(output.Time(i)*1000)+1000, round(output.Time(i+1)*1000)),... 
            '&nbsp');
    end
end
fprintf(fileID, '</BODY>\n</SAMI>');
fclose(fileID);

%% Generate smi file for door open

vr = VideoReader(glob(tankPath, '\.mpg', true));
frame = vr.read(1);


%% Read Video 36sec
tic
for i = 1 : 10000
    frame = vr.read(i);
    if rem(i, 100) == 0
        fprintf("%05d / %05d\n", i, vr.NumFrames);
    end
end
fprintf("%f\n", toc);

%% Read Video 35sec
tic
vr.CurrentTime = 0;
for i = 1 : 10000
    frame = vr.readFrame();
    if rem(i, 100) == 0
        fprintf("%05d / %05d\n", i, vr.NumFrames);
    end
end
fprintf("%f\n", toc);

%% Read Video
tic
vr.CurrentTime = 0;
for i = 5 : 5 : 10000
    vr.CurrentTime = round(i/vr.FrameRate);
    frame = vr.readFrame();
    if rem(i, 100) == 0
        fprintf("%05d / %05d\n", i, vr.NumFrames);
    end
end
fprintf("%f\n", toc);

imshow(frame);
val = ginput(1);

data = zeros(vr.NumFrames, 1);
for i = 1 : vr.NumFrames
    frame = vr.read(i);
    data(i) = mean(frame(...
        round(val(2)-3):round(val(2)+3),...
        round(val(1)-3):round(val(1)+3),...
        :), 'all');
end


fileID = fopen("Door.smi","w");

linesToWrite = {
    '<SAMI>', ...
    '<HEAD>', ...
    '<TITLE>Neuralynx Video Timestamp</TITLE>', ...
    '<STYLE TYPE="text/css">', ...
    '<!--', ...
    'P {', ...
    'font-size:1 ems;', ...
    'font-family: Arial;', ...
    'font-weight: normal;', ...
    'color: #FFFFFF;', ...
    'background-color: #000000;', ...
    'text-align: center;', ...
    '}', ...
    '.ENUSCC { name: English; lang: EN-US-CC; }', ...
    '-->', ...
    '</STYLE>', ...
    '</HEAD>', ...
    '<BODY>'
};
for i = 1:length(linesToWrite)
    fprintf(fileID, '%s\r\n', linesToWrite{i});
end

for i = 1 : size(output,1)
    fprintf(fileID, '<SYNC Start=%d><P Class=ENUSCC>%s</SYNC>\r\n', round(output.Time(i)*1000), output.Event(i));
    if i < size(output,1)
        fprintf(fileID, '<SYNC Start=%d><P Class=ENUSCC>%s</SYNC>\r\n',...
            min(round(output.Time(i)*1000)+1000, round(output.Time(i+1)*1000)),... 
            '&nbsp');
    end
end
fprintf(fileID, '</BODY>\n</SAMI>');
fclose(fileID);


%% Read unit file
i = 1;

[Timestamps, ScNumbers, CellNumbers, Features, Samples] = Nlx2MatSpike(...
    unitFilePaths{1},...
    [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
    0,... %Extract Header
    1);
