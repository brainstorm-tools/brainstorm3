function varargout = process_mne_maxwell_py( varargin )
% PROCESS_MNE_MAXWELL_PY: Python calls of process_fooof.m

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2020

eval(macro_method);
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = [];
    % Initialize MNE-Python
    [isOk, errorMsg] = bst_mne_init('Initialize', 0);
    if ~isOk
        if isempty(errorMsg)
            errorMsg = 'Could not initialize MNE-Python.';
        end
        bst_report('Error', sProcess, sInput, errorMsg);
        return;
    end
    
    % ===== GET OPTIONS =====
    opt = {};
    % int_order
    if isfield(sProcess.options, 'int_order') && isfield(sProcess.options.int_order, 'Value') && ~isempty(sProcess.options.int_order.Value) && ~isempty(sProcess.options.int_order.Value{1}) && isnumeric(sProcess.options.int_order.Value{1})
        opt = cat(2, opt, {'int_order', py.int(sProcess.options.int_order.Value{1})});
    end
    % ext_order
    if isfield(sProcess.options, 'ext_order') && isfield(sProcess.options.ext_order, 'Value') && ~isempty(sProcess.options.ext_order.Value) && ~isempty(sProcess.options.ext_order.Value{1}) && isnumeric(sProcess.options.ext_order.Value{1})
        opt = cat(2, opt, {'ext_order', py.int(sProcess.options.ext_order.Value{1})});
    end
    % origin
    if isfield(sProcess.options, 'origin') && isfield(sProcess.options.origin, 'Value') && ~isempty(sProcess.options.origin.Value)
        if strcmpi(sProcess.options.origin.Value, 'auto')
            opt = cat(2, opt, {'origin', 'auto'});
        else
            origin = str2num(sProcess.options.origin.Value);
            if (length(origin) == 3)
                opt = cat(2, opt, {'origin', origin});
            end
        end
    end
    % coord_frame
    if isfield(sProcess.options, 'coord_frame') && isfield(sProcess.options.coord_frame, 'Value') && ~isempty(sProcess.options.coord_frame.Value)
        opt = cat(2, opt, {'coord_frame', py.str(sProcess.options.coord_frame.Value)});
    end
    % destination
    if isfield(sProcess.options, 'destination') && isfield(sProcess.options.destination, 'Value') && ~isempty(sProcess.options.destination.Value) && ~isempty(sProcess.options.destination.Value{1}) && isnumeric(sProcess.options.destination.Value{1}) && (length(sProcess.options.destination.Value{1}) == 3)
        opt = cat(2, opt, {'destination', sProcess.options.destination.Value{1}});
    end
    % regularize
    if isfield(sProcess.options, 'regularize') && isfield(sProcess.options.regularize, 'Value') && ~isempty(sProcess.options.regularize.Value)
        opt = cat(2, opt, {'regularize', py.str('in')});
    else
        opt = cat(2, opt, {'regularize', py.None});
    end
    % ignore_ref
    if isfield(sProcess.options, 'ignore_ref') && isfield(sProcess.options.ignore_ref, 'Value') && ~isempty(sProcess.options.ignore_ref.Value)
        opt = cat(2, opt, {'ignore_ref', py.bool(sProcess.options.ignore_ref.Value)});
    end
    % st_duration
    if isfield(sProcess.options, 'st_duration') && isfield(sProcess.options.st_duration, 'Value') && ~isempty(sProcess.options.st_duration.Value) && ~isempty(sProcess.options.st_duration.Value{1}) && isnumeric(sProcess.options.st_duration.Value{1}) && (sProcess.options.st_duration.Value{1} > 0)
        opt = cat(2, opt, {'st_duration', sProcess.options.st_duration.Value{1}});
        isTemporal = 1;
    else
        opt = cat(2, opt, {'st_duration', py.None});
        isTemporal = 0;
    end   
    % st_correlation
    if isfield(sProcess.options, 'st_correlation') && isfield(sProcess.options.st_correlation, 'Value') && ~isempty(sProcess.options.st_correlation.Value) && ~isempty(sProcess.options.st_correlation.Value{1}) && isnumeric(sProcess.options.st_correlation.Value{1})
        opt = cat(2, opt, {'st_correlation', sProcess.options.st_correlation.Value{1}});
    end
    % st_fixed
    if isfield(sProcess.options, 'st_fixed') && isfield(sProcess.options.st_fixed, 'Value') && ~isempty(sProcess.options.st_fixed.Value)
        opt = cat(2, opt, {'st_fixed', py.bool(sProcess.options.st_fixed.Value)});
    end
    % st_only
    if isfield(sProcess.options, 'st_only') && isfield(sProcess.options.st_only, 'Value') && ~isempty(sProcess.options.st_only.Value)
        opt = cat(2, opt, {'st_only', py.bool(sProcess.options.st_only.Value)});
    end
    % mag_scale
    if isfield(sProcess.options, 'mag_scale') && isfield(sProcess.options.mag_scale, 'Value') && ~isempty(sProcess.options.mag_scale.Value) && ~isempty(sProcess.options.mag_scale.Value{1}) && isnumeric(sProcess.options.mag_scale.Value{1})
        opt = cat(2, opt, {'mag_scale', sProcess.options.mag_scale.Value{1}});
    end
    % skip_by_annotation
    if isfield(sProcess.options, 'skip_by_annotation') && isfield(sProcess.options.skip_by_annotation, 'Value') && ~isempty(sProcess.options.skip_by_annotation.Value)
        skip_by_annotation = strtrim(str_split(sProcess.options.skip_by_annotation.Value, ','));
        opt = cat(2, opt, {'skip_by_annotation', skip_by_annotation});
    end
    % calibration
    if isfield(sProcess.options, 'calibration') && isfield(sProcess.options.calibration, 'Value') && ~isempty(sProcess.options.calibration.Value{1})
        opt = cat(2, opt, {'calibration', py.str(sProcess.options.calibration.Value{1})});
    end
    % cross-talk
    if isfield(sProcess.options, 'ctc') && isfield(sProcess.options.ctc, 'Value') && ~isempty(sProcess.options.ctc.Value{1})
        opt = cat(2, opt, {'cross_talk', py.str(sProcess.options.ctc.Value{1})});
    end
    
    % ===== CALL MNE-PYTHON FUNCTION =====
    bst_progress('text', 'Loading input as Python object...');
    % Convert input to MNE-Python object
    pyRaw = out_mne_data(sInput.FileName, 'Raw');
    % Progress bar
    bst_progress('text', 'Calling: py.mne.preprocessing.maxwell_filter...');
    % Call MNE-Python function
    pyRaw_sss = py.mne.preprocessing.maxwell_filter(pyRaw, pyargs(opt{:}));
    % Release the memory used by the original file
    delete(pyRaw);
    % Open as new raw file
    sFile = in_fopen(pyRaw_sss, 'MNE-PYTHON');
    
    % ===== LOAD INPUTS =====
    % Get input study (to copy the creation date)
    sInputStudy = bst_get('AnyFile', sInput.FileName);
    % Load sFile
    sMat = in_bst_data(sInput.FileName);
    % Read the channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    
    % ===== CREATE OUTPUT FILE ====
    bst_progress('text', 'Saving output file...');
    % New folder name
    pathIn = bst_fileparts(file_fullpath(sInput.FileName));
    [pathSubj, rawBaseIn] = bst_fileparts(pathIn);
    % Get new condition name
    if isTemporal
        fileTag = 'tsss';
    else
        fileTag = 'sss';
    end
    newStudyPath = file_unique(bst_fullfile(pathSubj, [rawBaseIn, '_', fileTag]));
    % New file comment
    Comment = [strrep(sMat.Comment, 'Link to raw file', 'Raw') ' | ' fileTag];
    % Add hitory enty
    sMat = bst_history('add', sMat, 'process', sProcess.Comment);
    % Save raw file to database
    [OutputFile, errMsg] = bst_process('SaveRawFile', sFile, ChannelMat, newStudyPath, sInputStudy.DateOfStudy, Comment, sMat.History);
    % Error management
    if isempty(OutputFile) || ~isempty(errMsg)
        if isempty(OutputFile)
            bst_report('Error', sProcess, sInput, errMsg);
        else
            bst_report('Warning', sProcess, sInput, errMsg);
        end
    end
    % Delete python object
    delete(pyRaw_sss);
end



