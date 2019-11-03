function varargout = process_mne_maxwell( varargin )
% PROCESS_MNE_MAXWELL: MNE-Python call to mne.preprocessing.maxwell_filter: Maxwell filtering / SSS /tSSS
%
% USAGE:   sProcess = process_mne_maxwell('GetDescription')
%            sInput = process_mne_maxwell('Run', sProcess, sInput, method=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'MNE-Python: maxwell_filter (SSS/tSSS)';
    sProcess.FileTag     = 'sss';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 85;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = [];    % Do not split matrix
    sProcess.Description = 'https://www.nmr.mgh.harvard.edu/mne/stable/generated/mne.preprocessing.maxwell_filter.html';
    % Definition of the options
    % Help
    sProcess.options.help.Comment = '<B>mne.preprocessing.maxwell_filter</B><BR><I>For information about the parameters, click on "Online tutorial"</I><BR><BR>';
    sProcess.options.help.Type    = 'label';
    % int_order: Order of internal component of spherical expansion
    sProcess.options.int_order.Comment = 'int_order <FONT color="#777777"><I>(default=8)</I></FONT>: ';
    sProcess.options.int_order.Type    = 'value';
    sProcess.options.int_order.Value   = {8,'',0};
    % ext_order: Order of external component of spherical expansion
    sProcess.options.ext_order.Comment = 'ext_order <FONT color="#777777"><I>(default=3)</I></FONT>: ';
    sProcess.options.ext_order.Type    = 'value';
    sProcess.options.ext_order.Value   = {3,'',0};
    % origin: Origin of internal and external multipolar moment space in meters
    sProcess.options.origin.Comment = 'origin <FONT color="#777777"><I>(auto or 3D point)</I></FONT>: ';
    sProcess.options.origin.Type    = 'text';
    sProcess.options.origin.Value   = 'auto';
    % coord_frame: Origin of internal and external multipolar moment space in meters
    sProcess.options.coord_frame.Comment = {'head', 'meg', 'coord_frame <FONT color="#777777"><I>(default=head)</I></FONT>: '; ...
                                            'head', 'meg', ''};
    sProcess.options.coord_frame.Type    = 'radio_linelabel';
    sProcess.options.coord_frame.Value   = 'head';
    % destination: The destination location for the head.
    sProcess.options.destination.Comment = 'destination <FONT color="#777777"><I>(empty or 3D-point)</I></FONT>:';
    sProcess.options.destination.Type    = 'value';
    sProcess.options.destination.Value   = {[], 'list', 3};
    % regularize
    sProcess.options.regularize.Comment = 'regularize <FONT color="#777777"><I>(default=on)</I></FONT>';
    sProcess.options.regularize.Type    = 'checkbox';
    sProcess.options.regularize.Value   = 1;
    % ignore_ref
    sProcess.options.ignore_ref.Comment = 'ignore_ref <FONT color="#777777"><I>(default=off)</I></FONT>';
    sProcess.options.ignore_ref.Type    = 'checkbox';
    sProcess.options.ignore_ref.Value   = 0;
    % st_duration: tSSS
    sProcess.options.st_duration.Comment = 'st_duration <FONT color="#777777"><I>(0=disable tSSS, default=10)</I></FONT>: ';
    sProcess.options.st_duration.Type    = 'value';
    sProcess.options.st_duration.Value   = {0,'s',3};
    % st_correlation
    sProcess.options.st_correlation.Comment = 'st_correlation <FONT color="#777777"><I>(default=0.98)</I></FONT>: ';
    sProcess.options.st_correlation.Type    = 'value';
    sProcess.options.st_correlation.Value   = {0.98,'',2};
    % st_fixed
    sProcess.options.st_fixed.Comment = 'st_fixed <FONT color="#777777"><I>(default=on)</I></FONT>';
    sProcess.options.st_fixed.Type    = 'checkbox';
    sProcess.options.st_fixed.Value   = 1;
    % st_only
    sProcess.options.st_only.Comment = 'st_only <FONT color="#777777"><I>(default=off)</I></FONT>';
    sProcess.options.st_only.Type    = 'checkbox';
    sProcess.options.st_only.Value   = 0;
    % mag_scale
    sProcess.options.mag_scale.Comment = 'mag_scale <FONT color="#777777"><I>(default=100)</I></FONT>: ';
    sProcess.options.mag_scale.Type    = 'value';
    sProcess.options.mag_scale.Value   = {100,'',4};
    % skip_by_annotation
    sProcess.options.skip_by_annotation.Comment = 'skip_by_annotation: ';
    sProcess.options.skip_by_annotation.Type    = 'text';
    sProcess.options.skip_by_annotation.Value   = 'edge, bad_acq_skip';
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    % Initialize MNE-Python
    bst_mne_init('Initialize', 0);
    
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
    
    % ===== CALL MNE-PYTHON FUNCTION =====
    % Convert input to MNE-Python object
    pyRaw = out_mne_data(sInput.FileName, 'Raw');
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



