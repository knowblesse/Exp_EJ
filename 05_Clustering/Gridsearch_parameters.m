%% GroupUnits - Grid Search Visualization
%% Parameters
eventTypeList = [4];
distanceCutoffs = 0.70:0.05:1.00;
numberCutoff = 20;

%% Load Aligned Data
load('AllActivity_44.mat');

%% Setup
eventName = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];
colors = lines(20);
isValid = NumSpikesEvents(:,4)./NumEvents(:,4) >= 1;
regions = {"BLA", "PFC"};
nCutoffs = numel(distanceCutoffs);

for eventType = eventTypeList

    fig = figure('Position', [100, 100, 400 * numel(regions), 300 * nCutoffs]);
    tiledlayout(nCutoffs, numel(regions), 'TileSpacing', 'compact', 'Padding', 'compact');

    for ci = 1:nCutoffs
        distanceCutoff = distanceCutoffs(ci);

        for ri = 1:numel(regions)
            region = regions{ri};

            zscoreMatrix = ActivityData(Region == region & isValid, :, eventType);

            %% Cluster
            Z_ = linkage(zscoreMatrix, 'average', 'cosine');
            unitClusterId = cluster(Z_, 'cutoff', distanceCutoff, 'criterion', 'distance');

            cnt = histcounts(unitClusterId, 0.5:1:(max(unitClusterId)+0.5));
            [val, idx] = sort(cnt, 'descend');

            numGroup = 0;
            groupingResult = zeros(size(zscoreMatrix, 1), 1);
            for clt = 1:max(unitClusterId)
                if val(clt) >= numberCutoff
                    numGroup = numGroup + 1;
                    groupingResult(unitClusterId == idx(clt)) = numGroup;
                end
            end

            %% Plot
            nexttile;
            hold on;
            plot_lines = [];
            legends = {};
            for group = 1:numGroup
                [~, obj_line, ~] = shadeplot(...
                    zscoreMatrix(groupingResult == group, :),...
                    'SD', 'sem',...
                    'LineWidth', 1.3,...
                    'FaceAlpha', 0.3,...
                    'Color', colors(group, :));
                plot_lines = [plot_lines, obj_line];
                legends = [legends, sprintf("G%d (%d)", group, sum(groupingResult == group))];
            end

            xlim([0, size(zscoreMatrix, 2)]);
            ylim([-0.5, 3]);
            line(xlim, [0, 0], 'LineStyle', ':', 'Color', [0.3, 0.3, 0.3]);

            % Labels
            if ci == nCutoffs
                xlabel('Time (sec)');
                xticks(0:40:size(zscoreMatrix, 2));
                xticklabels(string((-size(zscoreMatrix,2)/40:2:size(zscoreMatrix,2)/40)));
            else
                xticks([]);
            end

            if ri == 1
                ylabel(sprintf('cutoff=%.2f', distanceCutoff));
            end

            if ci == 1
                title(sprintf('%s - %s', region, eventName(eventType)));
            end

            if numGroup > 0
                legend(plot_lines, legends, 'FontSize', 7, 'Location', 'northeast');
            end

            set(gca, 'FontName', 'Noto Sans', 'FontSize', 8);
            hold off;
        end
    end

    %% Save
    sgtitle(sprintf('%s | min=%d | cosine distance | 44', eventName(eventType), numberCutoff), 'FontSize', 14);
    saveas(fig, sprintf('ClusterGrid_%s_min%d_44.png', strrep(eventName(eventType), ' ', '_'), numberCutoff));
    fprintf('Saved: ClusterGrid_%s_min%d.png\n', strrep(eventName(eventType), ' ', '_'), numberCutoff);
end