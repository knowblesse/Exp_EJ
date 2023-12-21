tankPath = uigetdir(BASEPATH);
[X, y] = generateEventClassifierDataset(tankPath);
save(fullfile(tankPath, 'eventClfData.mat'), 'X', 'y');


for i = 1 : size(unitData,1)


unit_time = unitData.time_ms{i};
event_time = double(cell2mat({eventData(cell2mat({eventData(1:10).isE})==0).P}));
fig = figure('Position', [1094, 592, 560, 301]);
ax_raster1 = subplot(3,1,1:2);
title(num2str(i));
ax_histo1 = subplot(3,1,3);
drawPETH(unit_time, event_time, timewindow, ax_raster1, ax_histo1, false)
end
