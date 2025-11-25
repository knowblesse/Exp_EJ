%% GroupUnits

%% Parameters
numCluster = 8;
cutoffLimit = 50;
showGraph = false;
colors = lines(10);

%% LoadAlignedData
load('AllActivity.mat');

%% Use 'correlation' as distance between unit's activity
zscoreMatrix = ActivityData(:, :, 4);

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

fig = figure();
axes();
hold on;
lines = [];
legends = {};
for group = 1 : numGroup
    [~, obj_line, ~] = shadeplot(...
        zscoreMatrix(groupingResult == group, :),...
        'SD', 'sem',... %'LineWidth', sum(groupingResult == group)/100,...
        'LineWidth', 1.3,...
        'FaceAlpha', 0.3,...
        'Color', colors(group,:));
    lines = [lines, obj_line];
    legends = [legends, strcat("Group " , num2str(group))];
end
xlim([0, 160])
line(xlim, [0,0], 'LineStyle', ':', 'Color', [0.3, 0.3, 0.3]);
ylabel('Z score');
xlabel('Time (sec)');
xticks(0:20:160);
xticklabels(-4:4);
legend(lines, legends, 'FontSize', 6.6);
set(gca, 'FontName', 'Noto Sans');
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1), pos(2), 288, 236]);

%% Create Dendrogram
figure();

H = dendrogram(Z_, 580, 'ColorThreshold', Z_(end-8, 3));
lineColors = zeros(580,3);
for i = 1 : 579
    lineColors(i,:) = H(i).Color;
end

for i = 1 : 579
    if sum(all(H(i).Color == lineColors, 2)) < 50
        H(i).Color = [1, 1, 1];
    elseif numGroup == 2 % stupid hard coding
        if sum(all(H(i).Color == lineColors, 2)) > 300
            H(i).Color = [0, 0, 0];
        else
            H(i).Color = [0.5, 0.5, 0.5];
        end
    elseif numGroup == 3
        if sum(all(H(i).Color == lineColors, 2)) > 300
            H(i).Color = [0, 0, 0];
        elseif sum(all(H(i).Color == lineColors, 2)) > 100
            H(i).Color = [0.4, 0.4, 0.4];
        else
            H(i).Color = [0.8, 0.8, 0.8]; 
        end
    end
end
xticks([]);
xlabel('Cells');
ylabel('Distance (1-r)');
set(gca, 'FontName', 'Noto Sans');
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1), pos(2), 288, 236]);
