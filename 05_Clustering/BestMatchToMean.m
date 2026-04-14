%% Best match to mean

%% GroupUnits

%% Parameters
distanceCutoff = 0.70;
numberCutoff = 20;
showGraph = false;
eventType = 4;
targetRegion = "PFC";
colors = lines(20);

%% Load Aligned Data
load('AllActivity_1010.mat');

%% Loop through event types
% Pre-robot NP
% Pre-robot P
% Robot NP
% Robot P
eventName = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];

% Check validity of neurons using number of spikes per event
isValid = NumSpikesEvents(:,4)./NumEvents(:,4) >= 1;


numNeurons = sum(Region == targetRegion & isValid);
groups = zeros(numNeurons, 4);

zscoreMatrix = ActivityData(Region == targetRegion & isValid, :, eventType);
sessionNames = SessionNames(Region == targetRegion & isValid, :);
unitFile = UnitFile(Region == targetRegion & isValid, :);
unitId = UnitId(Region == targetRegion & isValid, :);

%% Use 'correlation' as distance between unit's activity
Z_ = linkage(zscoreMatrix, 'average', 'cosine');

unitClusterId = cluster(Z_, 'cutoff', distanceCutoff, 'criterion', 'distance');

cnt = histcounts(unitClusterId, 0.5:1:(max(unitClusterId)+0.5));
[val, idx] = sort(cnt, 'descend');

numGroup = 0;
groupingResult = zeros(size(zscoreMatrix,1),1);

for clt = 1 : max(unitClusterId)
    if val(clt) >= numberCutoff
        numGroup = numGroup + 1;
        groupingResult(unitClusterId == idx(clt)) = numGroup;
    end
end

similarityTables = cell(numGroup, 1);

% Loop through groups
for groupIdx = 1:numGroup
    % Get indices of neurons in this group
    neuronsInGroup = find(groupingResult == groupIdx);
    
    % Get the group's averaged activity
    groupAvg = mean(zscoreMatrix(groupingResult == groupIdx, :), 1);
    
    % Initialize arrays to store results
    numNeuronsInGroup = length(neuronsInGroup);
    similarityScores = zeros(numNeuronsInGroup, 1);
    sessionNamesGroup = cell(numNeuronsInGroup, 1);
    unitFileGroup = cell(numNeuronsInGroup, 1);
    unitIdsGroup = zeros(numNeuronsInGroup, 1);
    idGroup = zeros(numNeuronsInGroup, 1);
    
    % Calculate similarity for each neuron in the group
    for i = 1:numNeuronsInGroup
        neuronIdx = neuronsInGroup(i);
        neuronActivity = zscoreMatrix(neuronIdx, :);
        
        % Calculate correlation similarity
        similarityScores(i) = dot(neuronActivity, groupAvg) / (norm(neuronActivity) * norm(groupAvg));
        
        % Get session name and unit ID
        sessionNamesGroup{i} = "@" + sessionNames{neuronIdx};
        unitFileGroup{i} = unitFile{neuronIdx};
        unitIdsGroup(i) = unitId(neuronIdx);
        idGroup(i) = neuronIdx;
    end
    
    % Create table for this group
    similarityTables{groupIdx} = table(similarityScores, sessionNamesGroup, unitFileGroup, unitIdsGroup, idGroup, ...
        'VariableNames', {'SimilarityScore', 'SessionName', 'UnitFileName', 'UnitID', 'ID'});
    
    % Sort by similarity score (descending)
    similarityTables{groupIdx} = sortrows(similarityTables{groupIdx}, 'SimilarityScore', 'descend');
end

filename = 'neuron_similarity_results_PFC.xlsx';

writetable(similarityTables{1}, filename, 'Sheet', 'Group1');
writetable(similarityTables{2}, filename, 'Sheet', 'Group2');
writetable(similarityTables{3}, filename, 'Sheet', 'Group3');

