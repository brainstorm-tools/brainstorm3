function varargout = process_export_spmsurf( varargin )
% PROCESS_EXPORT_SPMVOL: Export source files to NIFTI files readable by SPM.
%
% USAGE:     sProcess = process_export_spmvol('GetDescription')
%                       process_export_spmvol('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Export to SPM12 (surface)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 981;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/ExportSpm12';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq'};
    sProcess.OutputTypes = {'results', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === OUTPUT FOLDER
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'save', ...                        % Dialog type: {open,save}
        'Select output folder...', ...     % Window title
        'ExportData', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        {{'.folder'}, 'GIfTI (*.gii)', 'GIFTI'}, ... % Available file formats
        'SpmOut'};                         % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option definition
    sProcess.options.outputdir.Comment = 'Output folder:';
    sProcess.options.outputdir.Type    = 'filename';
    sProcess.options.outputdir.Value   = SelectOptions;
    % === OUTPUT FILE TAG
    sProcess.options.filetag.Comment = 'Output file tag (default=Subj_Cond):';
    sProcess.options.filetag.Type    = 'text';
    sProcess.options.filetag.Value   = '';
    % === TIME WINDOW
    % sProcess.options.label1.Comment = '<BR><B>Time options</B>:';
    % sProcess.options.label1.Type    = 'label';
    sProcess.options.timewindow.Comment = 'Average time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === FREQUENCY
    sProcess.options.labelfreq.Comment    = '<BR><B>Frequency options</B>:';
    sProcess.options.labelfreq.Type       = 'label';
    sProcess.options.labelfreq.InputTypes = {'timefreq'};
    sProcess.options.freq_export.Comment    = 'Frequency band to export:';
    sProcess.options.freq_export.Type       = 'freqsel';
    sProcess.options.freq_export.Value      = [];
    sProcess.options.freq_export.InputTypes = {'timefreq'};
    % === ABSOLUTE VALUES
    sProcess.options.isabs.Comment = 'Use absolute values of the sources';
    sProcess.options.isabs.Type    = 'checkbox';
    sProcess.options.isabs.Value   = 1;
    sProcess.options.isabs.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Default options
    sProcess.options.timedownsample.Value = {1,'(integer)',0};
    sProcess.options.timemethod.Value = 1;
    sProcess.options.voldownsample.Value = {1,'(integer)',0};
    sProcess.options.iscut.Value = 1;
    sProcess.options.isconcat.Value = 0;
    % Call SPM export
    OutputFiles = process_export_spmvol('Run', sProcess, sInputs);
end



