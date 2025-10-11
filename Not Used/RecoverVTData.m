figure(3);
newData = data;
flagSet = false;
flagSetIndex = 0;

speedStd = std(sum(diff(data).^2, 2).^0.5);

for i = 2 : size(data,1)
    %% Check Weird
    if data(i, 1) < 210 & flagSet == false
        flagSetIndex = i-1;
        flagSet = true;
        continue
    end

    if data(i, 1) > 210 & flagSet == true
        flagSet = false;
        data(flagSetIndex:i, :) = [...
            linspace(data(flagSetIndex, 1), data(i, 1), i-flagSetIndex+1)', ...
            linspace(data(flagSetIndex, 2), data(i, 2), i-flagSetIndex+1)'];
        continue
    end
end
plot(data(:,1), data(:,2));