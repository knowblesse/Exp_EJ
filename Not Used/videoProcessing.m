vr = VideoReader('D:\Data\Kim Data\AP18_031418\AP18_031418_VT1.mpg');
vr.NumFrames % 2182
% Pot plyaer : 2182 frame


for i = 1 : 2178
    val = vr.readFrame();
end

% Error when reading frame from 2178
% vr.hasFrame() shows false in 2178's frame
% vr.Duration of that time is 72.8322
% However, `vr.read(2078);` works.

% Time Header after `vr.read(2078)` has called is 69.4361.