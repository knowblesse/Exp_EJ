%% Best match to mean

%% GroupUnits

%% Parameters
numCluster = 8;
cutoffLimit = 50;
showGraph = false;
colors = lines(10);

%% Load Aligned Data
load('AllActivity.mat');

%% Loop through event types
% Pre-robot NP
% Pre-robot P
% Robot NP
% Robot P
eventName = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];

targetRegion = "PFC";
eventType = 1;

if targetRegion == "BLA"
    groups = zeros(375, 4); % BLA
    zscoreMatrix = ActivityData(Region == "BLA", :, eventType);
    sessionNames = SessionNames(Region == "BLA", :);
    unitFile = UnitFile(Region == "BLA", :);
    unitId = UnitId(Region == "BLA", :);
else
    groups = zeros(500, 4);% PFC
    zscoreMatrix = ActivityData(Region == "PFC", :, eventType);
    sessionNames = SessionNames(Region == "PFC", :);
    unitFile = UnitFile(Region == "PFC", :);
    unitId = UnitId(Region == "PFC", :);
end



%% Use 'correlation' as distance between unit's activity
Z_ = linkage(zscoreMatrix, 'average', 'correlation');

unitClusterId = cluster(Z_, 'maxclust', numCluster);

cnt = histcounts(unitClusterId, 1:numCluster+1);
[val, idx] = sort(cnt, 'descend');

numGroup = 0;
groupingResult = zeros(size(zscoreMatrix,1),1);

for clt = 1 : numCluster
    if val(clt) >= cutoffLimit
        numGroup = numGroup + 1;
        groupingResult(unitClusterId == idx(clt)) = numGroup;
    end
end

if targetRegion == "BLA"
    groupingResult(groupingResult == 3) = 2;
    groupingResult(groupingResult == 4) = 3;
    numGroup = 3;
end


groups(:, eventType) = groupingResult;
fig = figure();
axes();
hold on;
plot_lines = [];
legends = {};
for group = 1 : numGroup
    [~, obj_line, ~] = shadeplot(...
        zscoreMatrix(groupingResult == group, :),...
        'SD', 'sem',... %'LineWidth', sum(groupingResult == group)/100,...
        'LineWidth', 1.3,...
        'FaceAlpha', 0.3,...
        'Color', colors(group,:));
    plot_lines = [plot_lines, obj_line];
    legends = [legends, strcat("Group " , num2str(group), " (", num2str(sum(groupingResult == group)), ")")];
end
xlim([0, 160]);
ylim([-0.5, 1.5]);
line(xlim, [0,0], 'LineStyle', ':', 'Color', [0.3, 0.3, 0.3]);
ylabel('Z score');
xlabel('Time (sec)');
xticks(0:20:160);
xticklabels(-4:4);
legend(plot_lines, legends, 'FontSize', 10);
set(gca, 'FontName', 'Noto Sans');
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1), pos(2), 400, 400]);
title(eventName(eventType) + " " + targetRegion);
%saveas(fig, eventName(eventType) + ".png");


% Initialize cell array to store tables for each group
similarityTables = cell(3, 1);

% Loop through groups 1 to 3
for groupIdx = 1:3
    % Get indices of neurons in this group
    neuronsInGroup = find(groupingResult == groupIdx);
    
    % Get the group's averaged activity
    groupAvg = mean(zscoreMatrix(groupingResult == group, :), 1);
    
    % Initialize arrays to store results
    numNeuronsInGroup = length(neuronsInGroup);
    similarityScores = zeros(numNeuronsInGroup, 1);
    similarityCos = zeros(numNeuronsInGroup, 1);
    sessionNamesGroup = cell(numNeuronsInGroup, 1);
    unitFileGroup = cell(numNeuronsInGroup, 1);
    unitIdsGroup = zeros(numNeuronsInGroup, 1);
    idGroup = zeros(numNeuronsInGroup, 1);
    
    % Calculate similarity for each neuron in the group
    for i = 1:numNeuronsInGroup
        neuronIdx = neuronsInGroup(i);
        neuronActivity = zscoreMatrix(neuronIdx, :);
        
        % Calculate correlation similarity
        similarityScores(i) = corr(neuronActivity', groupAvg');

        %
        similarityCos(i) = dot(neuronActivity, groupAvg) / (norm(neuronActivity) * norm(groupAvg));
        
        % Get session name and unit ID
        sessionNamesGroup{i} = sessionNames{neuronIdx};
        unitFileGroup{i} = unitFile{neuronIdx};
        unitIdsGroup(i) = unitId(neuronIdx);
        idGroup(i) = neuronIdx;
    end
    
    % Create table for this group
    similarityTables{groupIdx} = table(similarityScores, similarityCos, sessionNamesGroup, unitFileGroup, unitIdsGroup, idGroup, ...
        'VariableNames', {'SimilarityScore', 'SimilarityCos', 'SessionName', 'UnitFileName', 'UnitID', 'ID'});
    
    % Sort by similarity score (descending)
    similarityTables{groupIdx} = sortrows(similarityTables{groupIdx}, 'SimilarityCos', 'descend');
end

filename = 'neuron_similarity_results_PFC.xlsx';

% Write each table to a separate sheet
writetable(similarityTables{1}, filename, 'Sheet', 'Group1');
writetable(similarityTables{2}, filename, 'Sheet', 'Group2');
writetable(similarityTables{3}, filename, 'Sheet', 'Group3');

fprintf('Tables saved to %s\n', filename);
