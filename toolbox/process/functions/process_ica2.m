function varargout = process_ica2( varargin )
% PROCESS_ICA2: Calls ICA decomposition functions analysis.
%
% DESCRIPTION:
%    This process exists only to select ICA-specific options, the calculation is done in process_ssp2.m

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
% Authors: Francois Tadel, 2015-2018
%          Peter Donhauser, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'ICA components';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 303;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ICA';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'raw'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    % Notice
    sProcess.options.label1.Comment = '<B>Files A</B> = Artifacts samples (raw or epoched)<BR>&nbsp;<B>Files B</B> = Files to clean (raw)<BR><BR>';
    sProcess.options.label1.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window: ';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    sProcess.options.timewindow.InputTypes = {'raw'};
    % Event name
    sProcess.options.eventname.Comment = 'Event name (empty=continuous): ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    sProcess.options.eventname.InputTypes = {'raw'};
    % Event window
    sProcess.options.eventtime.Comment = 'Event window (ignore if no event): ';
    sProcess.options.eventtime.Type    = 'range';
    sProcess.options.eventtime.Value   = {[-.200, .200], 'ms', []};
    sProcess.options.eventtime.InputTypes = {'raw'};
    % Resample
    sProcess.options.resample.Comment = 'Resample input signals (0=disable): ';
    sProcess.options.resample.Type    = 'value';
    sProcess.options.resample.Value   = {0, 'Hz', 2};
    % Band-pass filter
    sProcess.options.bandpass.Comment = 'Frequency band (0=ignore): ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[0, 0], 'Hz', 2};
    % Number of components
    sProcess.options.nicacomp.Comment = 'Number of ICA components (0=default): ';
    sProcess.options.nicacomp.Type    = 'value';
    sProcess.options.nicacomp.Value   = {20, '', 0};
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    % Select components
    sProcess.options.icasort.Comment = 'Sort components based on correlation with (empty=none):';
    sProcess.options.icasort.Type    = 'text';
    sProcess.options.icasort.Value   = 'EOG, ECG';
    % Use existing SSPs
    sProcess.options.usessp.Comment    = 'Compute using existing SSP/ICA projectors';
    sProcess.options.usessp.Type       = 'checkbox';
    sProcess.options.usessp.Value      = 1;
    sProcess.options.usessp.InputTypes = {'raw'};
    % Ignore bad segments
    sProcess.options.ignorebad.Comment    = 'Ignore bad segments';
    sProcess.options.ignorebad.Type       = 'checkbox';
    sProcess.options.ignorebad.Value      = 1;
    sProcess.options.ignorebad.InputTypes = {'raw'};
    sProcess.options.ignorebad.Hidden  = 1;
    % Save ERP
    sProcess.options.saveerp.Comment = 'Save averaged artifact in the database';
    sProcess.options.saveerp.Type    = 'checkbox';
    sProcess.options.saveerp.Value   = 0;
    % ICA method
    sProcess.options.method_label.Comment = '<BR>ICA method: ';
    sProcess.options.method_label.Type    = 'label';
    sProcess.options.method.Comment = {'<B>Infomax</B>: &nbsp;&nbsp;&nbsp;<I>EEGLAB / RunICA', ...
                                       '<B>JADE</B>: &nbsp;&nbsp;&nbsp;<I>JF Cardoso @ Telecom-ParisTech</I>'};
                                       % '<B>FastICA</B>: &nbsp;&nbsp;&nbsp;<I>http://research.ics.aalto.fi/ica/fastica</I>', ...
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    switch (sProcess.options.method.Value)
        case 1,     Comment = [sProcess.Comment, ': Infomax'];
        case 2,     Comment = [sProcess.Comment, ': JADE'];
        case 3,     Comment = [sProcess.Comment, ': FastICA'];
        otherwise,  error('Invalid method.');
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Process each RAW file separately
    OutputFiles = {};
    % ICA method
    switch (sProcess.options.method.Value)
        case 1,  sProcess.options.method.Value = 'ICA_infomax';
        case 2,  sProcess.options.method.Value = 'ICA_jade';
        case 3,  sProcess.options.method.Value = 'ICA_fastica';
        otherwise,  error('Invalid method.');
    end
    % Call the SSP/ICA function
    OutputFiles = cat(2, OutputFiles, process_ssp2('Run', sProcess, sInputsA, sInputsB));
end






