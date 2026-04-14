idx = 15;
tb = similarityTables{1, 1};

temp = tb.SessionName(idx);
sn = char(temp{1}(1));

temp = tb.UnitFileName(idx);
nfn = temp{1};

ui = tb.UnitID(idx);

drawEventPETH(sn, nfn, ui, 4)
fprintf('drawEventPETH(%s, %s, %s, 4)\n', sn, nfn, num2str(ui));
