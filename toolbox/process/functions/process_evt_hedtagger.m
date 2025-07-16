function varargout = process_evt_hedtagger(varargin)
% PROCESS_EVT_HEDTAGGER: Add HED tags from CTagger to events
% USAGE: bst_process('CallProcess', sProcess, sInputs, sOutputs);
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Add HED from CTagger';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Record';
    sProcess.Index       = 1001;
    sProcess.Description = 'Launch CTagger and integrate HED';
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(~) %#ok<DEFNU>
    Comment = 'HED: CTagger';
end


%% ===== RUN =====
function OutputFiles = Run(~, sInputs) %#ok<DEFNU>
    OutputFiles = { sInputs.FileName };
    DataMat     = in_bst_data(sInputs.FileName, 'F');
    sFile       = DataMat.F;

    % === Launch CTagger ===
    [sFile, tags] = integrateCTAGGER(sFile);

    % === Store tags back in the .mat ===
    sFile.hedTags = tags;
    DataMat.F     = sFile;
    bst_save(sInputs.FileName, DataMat);
end


%% ===== INTEGRATE CTAGGER (no sidecar) =====
function [dataStruct, tags] = integrateCTAGGER(dataStruct)
    scriptFolder = fileparts( mfilename('fullpath') );
    jarFile      = fullfile( scriptFolder, 'CTagger.jar' );
    if ~ismember(jarFile, javaclasspath('-dynamic'))
        javaaddpath(jarFile);
    end

    % Default JSON template
    tags = [ ...
        '{' ...
          '"onset":{"Description":"Time of event (s).","Units":"seconds"},' ...
          '"duration":{"Description":"Duration (s).","Units":"seconds"},' ...
          '"trial_type":{"Description":"Trial type.","Levels":{' ...
                '"stimulus":"Stimulus event",' ...
                '"response":"Response event"' ...
          '}}' ...
        '}' ...
    ];

    % Launch CTAGGER
    try
        [tags, canceled] = useCTAGGER(tags);
        if canceled
            disp('Tagging process canceled.');
            return;
        end
    catch ME
        error('CTAGGER Error: %s', ME.message);
    end

    % Return the updated struct + the JSON tags
    dataStruct.tags = tags;
end


function [tags, canceled] = useCTAGGER(tags)
    canceled = false;
    [newTags, canceled] = loadCTAGGER(tags);
    if ~canceled
        tags = newTags;
    end
end


function [result, canceled] = loadCTAGGER(json)
    canceled  = false;
    notified  = false;
    try
        loader = javaObject('TaggerLoader', json);
    catch ME
        error('Error initializing CTAGGER: %s', ME.message);
    end

    timeout = 300;  % secs
    tStart  = tic;
    while ~notified && toc(tStart) < timeout
        pause(0.5);
        notified = loader.isNotified();
    end
    if ~notified
        error('CTAGGER did not respond within the timeout period.');
    end

    if loader.isCanceled()
        canceled = true;
        result   = '';
    else
        result = char(loader.getHEDJson());
    end
end
