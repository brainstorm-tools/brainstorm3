function varargout = process_ft_mtmconvol( varargin )
% PROCESS_FT_MTMCONVOL: Call FieldTrip function ft_mtmconvol.
%
% REFERENCES: 
%     - http://www.fieldtriptoolbox.org/tutorial/timefrequencyanalysis

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_mtmconvol (Multitaper)';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 506;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/tutorial/timefrequencyanalysis';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import', 'data'};
    sProcess.OutputTypes = {'import', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    sProcess.options.sensortypes.Group   = 'input';
    % Options: Scouts
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'scout_confirm';
    sProcess.options.clusters.Value   = {};
    sProcess.options.clusters.InputTypes = {'results'};
    sProcess.options.clusters.Group   = 'input';
    % Options: Scout function
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    sProcess.options.scoutfunc.Group   = 'input';

    % Options: Taper
    sProcess.options.mt_taper.Comment = 'Taper: ';
    sProcess.options.mt_taper.Type    = 'combobox';
    sProcess.options.mt_taper.Value   = {1, {'dpss', 'hanning', 'rectwin', 'sine'}};
    % Options: Frequencies
    sProcess.options.mt_frequencies.Comment = 'Frequencies (start:step:stop): ';
    sProcess.options.mt_frequencies.Type    = 'text';
    sProcess.options.mt_frequencies.Value   = '1:2:120';
    % Options: Frequency resolution
    sProcess.options.mt_freqmod.Comment = 'Modulation factor: ';
    sProcess.options.mt_freqmod.Type    = 'value';
    sProcess.options.mt_freqmod.Value   = {10, ' (freqres=frequencies/modfactor)', 0};
    % Options: Time resolution
    sProcess.options.mt_timeres.Comment = 'Time resolution: ';
    sProcess.options.mt_timeres.Type    = 'value';
    sProcess.options.mt_timeres.Value   = {1, 'ms', []};
    % Options: Time step
    sProcess.options.mt_timestep.Comment = 'Time step: ';
    sProcess.options.mt_timestep.Type    = 'value';
    sProcess.options.mt_timestep.Value   = {0.1, 'ms', []};

    % === MEASURE
    sProcess.options.measure.Comment = {'Power', 'Magnitude', 'None (save complex values)', 'Measure: '; ...
                                        'power', 'magnitude', 'none', ''};
    sProcess.options.measure.Type    = 'radio_linelabel';
    sProcess.options.measure.Value   = 'power';
    sProcess.options.measure.Group   = 'output';
    % === AVERAGE OUTPUT FILES
    sProcess.options.avgoutput.Comment = 'Save average power of FFT values across files<BR>(do not save one new file per input file)';
    sProcess.options.avgoutput.Type    = 'checkbox';
    sProcess.options.avgoutput.Value   = 1;
    sProcess.options.avgoutput.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize fieldtrip
    if ~exist('ft_specest_mtmconvol', 'file')
        bst_ft_init();
    end
    % Call TIME-FREQ process
    OutputFiles = process_timefreq('Run', sProcess, sInputs);
end



