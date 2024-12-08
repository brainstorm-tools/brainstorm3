function varargout = process_sprint( varargin )
% PROCESS_SPRINT: Computes the Spectral Parameterization Resolved iN Time (SPRiNT) of any signal in the database.
% 
% USAGE:  sProcess = process_sprint('GetDescription')
%           sInput = process_sprint('Run',     sProcess, sInput)

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
% Author: Luc Wilson, 2021-2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'SPRiNT: Spectral Parameterization Resolved in Time';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 502;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SPRiNT';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    sProcess.options.sensortypes.Group   = 'input';
    % Options: Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    sProcess.options.timewindow.Group   = 'input';
    
    % === STFT options === %
    % Label for STFT options
    sProcess.options.stft.Comment    = 'Short-time Fourier transform options:';
    sProcess.options.stft.Type       = 'label';
    sProcess.options.stft.Value      = [];
    % Option: Window (Length)
    sProcess.options.win_length.Comment    = 'Window length: ';
    sProcess.options.win_length.Type       = 'value';
    sProcess.options.win_length.Value      = {1, 's', []};
    % Option: Window (Overlapping ratio)
    sProcess.options.win_overlap.Comment    = 'Window overlap ratio (default=50%): ';
    sProcess.options.win_overlap.Type       = 'value';
    sProcess.options.win_overlap.Value      = {50, '%', 1};
    % Option: Local average 
    sProcess.options.loc_average.Comment    = 'Averaged FFTs per time point (default=5): ';
    sProcess.options.loc_average.Type       = 'value';
    sProcess.options.loc_average.Value      = {5, '', 0};
    % Options: CLUSTERS
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'scout_confirm';
    sProcess.options.clusters.Value   = {};
    sProcess.options.clusters.InputTypes = {'results'};
    % Options: Scout function
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    
    % === specparam options === %
    % Label for FOOOF options
    sProcess.options.fooof.Comment    = '<BR><BR>specparam options:';
    sProcess.options.fooof.Type       = 'label';
    sProcess.options.fooof.Value      = [];
    % Option: Frequency range
    sProcess.options.freqrange.Comment = 'Frequency range for analysis: ';
    sProcess.options.freqrange.Type    = 'freqrange_static';
    sProcess.options.freqrange.Value   = {[1 40], 'Hz', 1};
    % Option: Peak type
    sProcess.options.peaktype.Comment = {'Gaussian', 'Cauchy (experimental)', 'Peak model:'; 'gaussian', 'cauchy', ''};
    sProcess.options.peaktype.Type    = 'radio_linelabel';
    sProcess.options.peaktype.Value   = 'gaussian';
    % Option: Peak width limits
    sProcess.options.peakwidth.Comment = 'Peak width limits (default=[0.5-12]): ';
    sProcess.options.peakwidth.Type    = 'freqrange_static';
    sProcess.options.peakwidth.Value   = {[0.5 12], 'Hz', 1};
    % Option: Max peaks
    sProcess.options.maxpeaks.Comment = 'Maximum number of peaks (default=3): ';
    sProcess.options.maxpeaks.Type    = 'value';
    sProcess.options.maxpeaks.Value   = {3, '', 0};
    % Option: Min peak height
    sProcess.options.minpeakheight.Comment = 'Minimum peak height (default=3): ';
    sProcess.options.minpeakheight.Type    = 'value';
    sProcess.options.minpeakheight.Value   = {3, 'dB', 1};
    % Option: Proximity threshold
    sProcess.options.proxthresh.Comment = 'Proximity threshold (default=2): ';
    sProcess.options.proxthresh.Type    = 'value';
    sProcess.options.proxthresh.Value   = {2, 'stdev of peak model', 1};
    % Option: Aperiodic mode
    sProcess.options.apermode.Comment = {'Fixed', 'Knee', 'Aperiodic mode (default=fixed):'; 'fixed', 'knee', ''};
    sProcess.options.apermode.Type    = 'radio_linelabel';
    sProcess.options.apermode.Value   = 'fixed';
    % Option: Guess weight
    sProcess.options.guessweight.Comment = {'None', 'Weak', 'Strong', 'Guess weight (default=none):'; 'none', 'weak', 'strong', ''};
    sProcess.options.guessweight.Type    = 'radio_linelabel';
    sProcess.options.guessweight.Value   = 'none';
    
    % === Post-processing options === %
    % Label for FOOOF options
    sProcess.options.postproc.Comment    = '<BR><BR>Post-processing options:';
    sProcess.options.postproc.Type       = 'label';
    sProcess.options.postproc.Value      = [];
    % Option: Remove outliers
    sProcess.options.rmoutliers.Comment = {'Yes', 'No', 'Remove outliers (default=yes):'; 'yes', 'no', ''};
    sProcess.options.rmoutliers.Type    = 'radio_linelabel';
    sProcess.options.rmoutliers.Value   = 'yes';
    sProcess.options.rmoutliers.Controller.yes = 'Yes';
    sProcess.options.rmoutliers.Controller.no = 'No';
    % Option: Frequency range
    sProcess.options.maxfreq.Comment = 'Maximum frequency distance (default=2.5): ';
    sProcess.options.maxfreq.Type    = 'value';
    sProcess.options.maxfreq.Value   = {2.5, 'Hz', 1};
    sProcess.options.maxfreq.Class = 'Yes';
    % Option: Temporal range
    sProcess.options.maxtime.Comment = 'Maximum temporal distance (default=6): ';
    sProcess.options.maxtime.Type    = 'value';
    sProcess.options.maxtime.Value   = {6, 'windows', 0};
    sProcess.options.maxtime.Class = 'Yes';
    % Option: Minimum neighbours
    sProcess.options.minnear.Comment = 'Minimum number of neighbors (default=3): ';
    sProcess.options.minnear.Type    = 'value';
    sProcess.options.minnear.Value   = {3, '', 0};
    sProcess.options.minnear.Class = 'Yes';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = process_timefreq('Run', sProcess, sInputs);
end
