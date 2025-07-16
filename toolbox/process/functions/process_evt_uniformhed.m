function varargout = process_evt_uniformhed(varargin)
% PROCESS_EVT_UNIFORMHED: Uniform protocol event HEDs
% USAGE:  bst_process('CallProcess', sProcess, sInputs, sOutputs);
    eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Uniform protocol event HEDs';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Record';
    sProcess.Index       = 1002;
    sProcess.Description = 'Copy the HED JSON from the master block into every block';
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;   
    sProcess.nMinFiles   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(~) %#ok<DEFNU>
    Comment = 'HED: Uniform tags';
end

%% ===== RUN =====
function OutputFiles = Run(~, sInputs) %#ok<DEFNU>
    % Load the master file (first in the list) to get its hedTags
    masterFile = sInputs(1).FileName;
    matMaster  = in_bst_data(masterFile, 'F');
    if ~isfield(matMaster.F, 'hedTags') || isempty(matMaster.F.hedTags)
        bst_report('Warning', [], ...
            'process_evt_uniformhed', ...
            'No hedTags found in master block: nothing to propagate.');
        OutputFiles = { masterFile };
        return;
    end
    masterTags = matMaster.F.hedTags;

    nFiles = numel(sInputs);
    hasTags = false(1, nFiles);
    % Check which files already have hedTags
    for iF = 1:nFiles
        matF = in_bst_data(sInputs(iF).FileName, 'F');
        if isfield(matF.F, 'hedTags') && ~isempty(matF.F.hedTags)
            hasTags(iF) = true;
        end
    end

    % If any conflicts, ask the user once
    overwrite = true;
    if any(hasTags)
        msg = sprintf('%d/%d files already have HED tags.\nOverwrite them?', sum(hasTags), nFiles);
        overwrite = java_dialog('confirm', msg, 'Overwrite existing HED tags?');
    end

    OutputFiles = cell(1, nFiles);
    for iF = 1:nFiles
        fn = sInputs(iF).FileName;
        % Skip if it already has tags and user chose NOT to overwrite
        if hasTags(iF) && ~overwrite
            OutputFiles{iF} = fn;
            continue;
        end
        % Otherwise write masterTags
        DataMat = in_bst_data(fn, 'F');
        DataMat.F.hedTags = masterTags;
        bst_save(fn, DataMat);
        OutputFiles{iF} = fn;
    end
end
