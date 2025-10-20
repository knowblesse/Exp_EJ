%% Descriptive Data
% 2025 Ji Hoon Jeong
% Go through each session and check trial informations

%% Set Variables
BASEPATH = "H:/Data/Kim Data";

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

numSession = numel(sessionPaths);

val_session = strings(numSession, 1);
val_numVideo = zeros(numSession, 1);
val_numUnit = zeros(numSession, 1);
val_numBLAUnit = zeros(numSession, 1);
val_numPLUnit = zeros(numSession, 1);
val_pre_p = zeros(numSession, 1);
val_pre_np = zeros(numSession, 1);
val_robot_p = zeros(numSession, 1);
val_robot_np = zeros(numSession, 1);

%% Batch
for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);
    
    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);
    
    val_session(session) = tankName;
    val_numVideo(session) = expStat.numVideo;
    val_numUnit(session) = expStat.numUnit;
    val_numBLAUnit(session) = expStat.numBLAUnit;
    val_numPLUnit(session) = expStat.numPLUnit;

    clearvars p_;
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")

%% Create Table
outputTable = table((1:numel(val_session))', val_session, val_numVideo, val_numUnit, val_numBLAUnit, val_numPLUnit, 'VariableNames',["#", "TankName", "NumVideo", "NumUnit", "NumBLAUnit", "NumPLUnit"]);
writetable(outputTable, 'descriptive_data.xlsx');