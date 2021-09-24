function varargout = process_mne_maxwell( varargin )
% PROCESS_MNE_MAXWELL: MNE-Python call to mne.preprocessing.maxwell_filter: Maxwell filtering / SSS /tSSS
%
% USAGE:   sProcess = process_mne_maxwell('GetDescription')
%            sInput = process_mne_maxwell('Run', sProcess, sInput, method=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
    % fine_calibration_file (site specific)
    sProcess.options.calibration.Comment = 'fine-calibration file:';
    sProcess.options.calibration.Type    = 'filename';
    sProcess.options.calibration.Value = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import fine-calibration file...', ...     % Window title
        'ImportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        {'.dat', 'fine-calibration file (*.dat)', 'calibration'}, ... % Specify file type
        'DataIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % cross_talk_file (site specific)    
    sProcess.options.ctc.Comment = 'cross-talk file:';
    sProcess.options.ctc.Type    = 'filename';
    sProcess.options.ctc.Value   = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import cross-talk file...', ...     % Window title
        'ImportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        {'.fif', 'cross-talk file (*.fif)', 'ctc'}, ... % Specify file type
        'DataIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn   
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = process_mne_maxwell_py('Run', sProcess, sInput);
end



