function varargout = process_ssp( varargin )
% PROCESS_SSP: Artifact rejection for a group of recordings file
%
% USAGE:  OutputFiles = process_ssp('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, Elizabeth Bock, 2011-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<*DEFNU>
    % Description the process
    sProcess.Comment     = 'SSP: Generic';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 112;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsSsp#SSP:_Generic';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Time window
    sProcess.options.timewindow.Comment = 'Time window: ';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Event name
    sProcess.options.eventname.Comment = 'Event name (empty=continuous): ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'blink';
    % Event window
    sProcess.options.eventtime.Comment = 'Event window (ignore if no event): ';
    sProcess.options.eventtime.Type    = 'range';
    sProcess.options.eventtime.Value   = {[-.200, .200], 'ms', []};
    % Filter
    sProcess.options.bandpass.Comment = 'Frequency band: ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[1.5, 15], 'Hz', 2};
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    % Use existing SSPs
    sProcess.options.usessp.Comment = 'Compute using existing SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % Save ERP
    sProcess.options.saveerp.Comment = 'Save averaged artifact in the database';
    sProcess.options.saveerp.Type    = 'checkbox';
    sProcess.options.saveerp.Value   = 0;
    % Method: Average or PCA
    sProcess.options.label1.Comment = '<BR>Method to calculate the projectors:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.method.Comment = {'PCA: One component per sensor', 'Average: One component only'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
    % Examples: EOG, ECG
    sProcess.options.example.Comment = ['<BR>Examples:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;- EOG: [-200,+200] ms, [1.5-15] Hz<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;- ECG: [-40,+40] ms, [13-40] Hz<BR><BR>'];
    sProcess.options.example.Type    = 'label';
    % Default selection of components
    sProcess.options.select.Comment = 'Selected components:';
    sProcess.options.select.Type    = 'value';
    sProcess.options.select.Value   = {1, 'list', 0};
    sProcess.options.select.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    if isfield(sProcess.options, 'eventname') && ~isempty(sProcess.options.eventname.Value)
        Comment = ['SSP: ' sProcess.options.eventname.Value];
    else
        Comment = 'SSP';
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Process each RAW file separately
    OutputFiles = {};
    % Check for multiple files of the same channel file
    uniqueChannel = unique({sInputs.ChannelFile});
    if (length(uniqueChannel) ~= length(sInputs))
        bst_report('Error', sProcess, sInputs, ...
            ['The files you selected share the same channel file. This process considers each file independently, ' 10 ...
             'and requires the multiple input files to be using different channel files. Each file will result ' 10 ...
             'into one new category of SSP projectors in its channel file.' 10 10 ...
             'To calculate the SSP from multiple runs and/or save the results into one channel file only, ' 10 ...
             'please use the corresponding SSP process from the Process2 tab.']);
        return;
    end
    % Call recursively the function on each RAW file
    for iFile = 1:length(sInputs)
        OutputFiles = cat(2, OutputFiles, process_ssp2('Run', sProcess, sInputs(iFile), sInputs(iFile)));
    end
end


