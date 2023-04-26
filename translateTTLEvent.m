function event = translateTTLEvent(ttl)
%% translateTTLEvent
% Translate TTL event acquired from .nev file

%% Not TTL Event
if contains(ttl, "Recording")
    if contains(ttl, "Starting")
        event = "Recording Start";
        return;
    else if contains(ttl, "Stopping")
        event = "Recording Stop";
        return;
    end
end

%% TTL Event
result = regexp(ttl, "\(0x(?<id>.*?)\)", 'names');
id = result.id;

%% Case

switch (id)
    case '3000'
        event = "Deactivation";
        break;
    case '3003'
        event = "Enter F1";
        break;
    case '3008'
        event = "Enter F2";
        break;
    case '3003'
        event = "Enter F1";
        break;
    case '3003'
        event = "Enter F1";
        break;
    case '3003'
        event = "Enter F1";
        break;
    case '3003'
        event = "Enter F1";
        break;
        



end
regexp(ttl)
