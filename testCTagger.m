% Load the events.json file
eventsJsonFile = 'events.json';

if exist(eventsJsonFile, 'file')
    disp('Using events.json as input...');
    sidecar = eventsJsonFile;
else
    sidecar = '';
end

%example data structure
dataStruct.events = struct('onset', {0.5, 1.0, 1.5}, ...
                           'duration', {0.5, 0.5, 0.5}, ...
                           'trial_type', {'stimulus', 'response', 'stimulus'});

% Integrate CTAGGER
[dataStruct, tags] = integrateCTAGGER(dataStruct, 'sidecar', sidecar);

disp('Updated JSON:');
disp(tags);
