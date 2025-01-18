function [dataStruct, tags] = integrateCTAGGER(dataStruct, varargin)

    jarFile = fullfile(pwd, 'CTagger.jar');
    if ~ismember(jarFile, javaclasspath('-dynamic'))
        javaaddpath(jarFile);
    end
    % Parse input arguments
    p = parseArguments(dataStruct, varargin{:});
    
    % Step 1: Load JSON
    if ~isempty(p.sidecar) && exist(p.sidecar, 'file')
        tags = fileread(p.sidecar); % Read directly from the file
    else
        % Hardcoded default JSON with proper formatting for MATLAB
        tags = ['{' ...
                   '"onset":{"Description":"Time at which the event occurred, in seconds.","Units":"seconds"},' ...
                   '"duration":{"Description":"Duration of the event, in seconds.","Units":"seconds"},' ...
                   '"trial_type":{"Description":"Type of trial.","Levels":{' ...
                       '"stimulus":"Event indicating stimulus",' ...
                       '"response":"Event indicating response"' ...
                   '}}' ...
               '}'];
    end

    % Step 2: Pass JSON to CTAGGER
    try
        [tags, canceled] = useCTAGGER(tags);
        
        if canceled
            disp('Tagging process canceled.');
            return;
        end
    catch ME
        error('CTAGGER Error: %s', ME.message);
    end

    % Step 3: Update the data structure
    dataStruct.tags = tags;
    disp('Tagging complete.');
end

function [tags, canceled] = useCTAGGER(tags)
    % Wrapper for launching CTAGGER
    canceled = false;
    [newTags, canceled] = loadCTAGGER(tags);
    if ~canceled
        tags = newTags;
    end
end

function [result, canceled] = loadCTAGGER(json)
    % Launch CTAGGER
    canceled = false;
    notified = false;

    try
        loader = javaObject('TaggerLoader', json);
    catch ME
        error('Error initializing CTAGGER: %s', ME.message);
    end

    % Wait for user interaction
    timeout = 300; % seconds
    tStart = tic;
    while ~notified && toc(tStart) < timeout
        pause(0.5);
        notified = loader.isNotified();
    end

    if ~notified
        error('CTAGGER did not respond within the timeout period.');
    end

    % Check if tagging was canceled
    if loader.isCanceled()
        canceled = true;
        result = '';
    else
        result = char(loader.getHEDJson());
    end
end

function p = parseArguments(dataStruct, varargin)
    % Parse input arguments
    parser = inputParser;
    parser.addRequired('dataStruct', @(x) isstruct(x));
    parser.addParameter('sidecar', '', @ischar); % Add 'sidecar' as a recognized parameter
    parser.parse(dataStruct, varargin{:});
    p = parser.Results;
end
