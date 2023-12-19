%% CreateHelperFiles
% 2023 Ji Hoon Jeong
% Function for creating helperfile
% exp stat, video time vs timestamp
% This video time vs timestamp data can be used to sync the timestampof NX
% device and the video. 2023DEC19
function createHelperFiles(tankPath)
arguments
    tankPath string = ''
end

BASEPATH = "D:\Data\Kim Data";
addpath('Lib/Neuralynx/');

%% Get filepaths
if tankPath == ''
    tankPath = uigetdir(BASEPATH);
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("createHelperFiles : Processing tank %s\n", tankPath);
tankName = regexp(tankPath, '\\(?:|#|##|$#|@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);
trackingFilePath = glob(tankPath, '\.nvt', true);
videoFilePaths = glob(tankPath, '\.mpg', true);
% Only one video
if ~iscell(videoFilePaths)
    videoFilePaths = {videoFilePaths};
end

if iscell(videoFilePaths)
    numVideofile = numel(videoFilePaths);
else
    numVideofile = 1;
end

% path sanity check
for p_ = {unitFilePaths, trackingFilePath}
    if isempty(p_{1})
        error("File could not be loaded");
    end
end 
clearvars p_;

%% Read Video Tracking File 
% Possibly has the initial timestampe of the experiment. 
[TimeStamps, ~, ~, ~, ~, ~] = Nlx2MatVT(...
    trackingFilePath,...
    [1, 1, 1, 1, 1, 1],... % Time, X, Y, angle, targets, points
    0,... %ExtractHeader
    1);
startTimeStamp = TimeStamps(1);

%% Read unit file
numUnit = 0;
for unitFilePath = unitFilePaths
    [Timestamps, ScNumbers, CellNumbers, Features, Samples] = Nlx2MatSpike(...
        unitFilePath{1},...
        [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
        0,... %Extract Header
        1);
    numUnit = numUnit + numel(unique(CellNumbers));
end

%% Generate time2TS matrix
smiFilePaths = [];
for videoFilePath = videoFilePaths
    temp_ = regexp(videoFilePath{1}, '(.*).mpg', 'tokens');
    smiFilePaths = [smiFilePaths; strcat(temp_{1}{1}, ".smi")];
end

time2TS = cell(size(smiFilePaths,1),1);
time2TS_filename = strings(size(smiFilePaths,1),1);

for p = 1 : size(smiFilePaths)
    timeTimestampData_ = readlines(smiFilePaths{p});
    
    % Save name of the video file
    temp_ = regexp(smiFilePaths{p}, '\\([^\\]*).smi', 'tokens');
    time2TS_filename(p) = temp_{1}{1};
    
    % select only data between <BODY> tag
    timeTimestampData = timeTimestampData_(...
        find(timeTimestampData_ == "<BODY>")+1 : ...
        find(timeTimestampData_ == "</BODY>")-1);
    
    % Parse smi and get numbers only
    temp_ = regexp(timeTimestampData, 'Start=(?<time>\d+)>.*>(?<timestamp>\d+)<', 'tokens');
    time2TS{p} = int64(zeros(size(timeTimestampData, 1),2));
    for i = 1 : size(timeTimestampData, 1)    
        time2TS{p}(i,:) = [...
            str2double(temp_{i}{1}(1)),...
            str2double(temp_{i}{1}(2))];
    end
end

%% Write File
expStat = struct();
expStat.numVideo = numVideofile;
expStat.numUnit = numUnit;
expStat.startTS = startTimeStamp;
save(fullfile(tankPath, strcat(tankName, '_helper.mat')), "expStat", "time2TS", "time2TS_filename");

%% Done
fprintf("createHelperFiles : Done\n");
end
