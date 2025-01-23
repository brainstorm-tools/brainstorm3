function varargout = process_cohere1( varargin )
% PROCESS_COHERE1N: Compute the coherence between all the pairs of signals, in one file.

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
% Authors: Francois Tadel, 2012-2020
%          Marc Lalancette, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Coherence 1xN [2023]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 656;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 0);
    % === REMOVE EVOKED REPONSE
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    sProcess.options.removeevoked.Group   = 'input';
    sProcess.options.removeevoked.Hidden  = 1;
    % === COHERENCE METHOD
    sProcess.options.label1.Comment = '<B>Connectivity Metric:</B>';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.cohmeasure.Comment = {...
        'Magnitude-squared coherence', ...
        'Imaginary coherence', ...
        'Lagged coherence / Corrected imaginary coherence'; ...
        'mscohere', 'icohere2019','lcohere2019'}; % , 'icohere'
%         '<FONT color="#777777"> Squared Lagged Coherence ("imaginary coherence" before 2019)</FONT>' ...
    sProcess.options.cohmeasure.Type    = 'radio_label';
    sProcess.options.cohmeasure.Value   = 'mscohere';
    % === Time-freq options
    sProcess.options.label2.Comment = '<B>Time-frequency decomposition:</B>';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.tfmeasure.Comment = {'Hilbert transform', 'Morlet wavelets', 'Fourier transform', ''; ...
                                          'hilbert', 'morlet', 'stft', ''};
    sProcess.options.tfmeasure.Type    = 'radio_linelabel';
    sProcess.options.tfmeasure.Value   = 'hilbert';
    % === TF OPTIONS Panel 
    sProcess.options.tfedit.Comment = {'panel_timefreq_options', 'Options: '};
    sProcess.options.tfedit.Type    = 'editpref';
    sProcess.options.tfedit.Value   = [];
    % === TIME AVERAGING
    sProcess.options.timeres.Comment = {'Full (requires epochs)', 'Windowed', 'None', '<B>Time resolution:</B>'; ...
                                        'full', 'windowed', 'none', ''};
    sProcess.options.timeres.Type    = 'radio_linelabel';
    sProcess.options.timeres.Value   = 'full';
    sProcess.options.timeres.Controller = struct('full', 'nowindowed', 'windowed', 'windowed', 'none', 'nowindowed');
    % === WINDOW LENGTH
    sProcess.options.avgwinlength.Comment = '&nbsp;&nbsp;&nbsp;Time window length:';
    sProcess.options.avgwinlength.Type    = 'value';
    sProcess.options.avgwinlength.Value   = {1, 's', []};
    sProcess.options.avgwinlength.Class   = 'windowed';
    % === WINDOW OVERLAP
    sProcess.options.avgwinoverlap.Comment = '&nbsp;&nbsp;&nbsp;Time window overlap:';
    sProcess.options.avgwinoverlap.Type    = 'value';
    sProcess.options.avgwinoverlap.Value   = {50, '%', []};
    sProcess.options.avgwinoverlap.Class   = 'windowed';
    % === OUTPUT MODE / FILE AVERAGING
    % Ideally, 'input' would be disabled for 'full' time resolution.
    sProcess.options.outputmode.Comment = {'separately for each file', 'across combined files/epochs', 'Estimate & save:'; ...
                                            'input', 'avg', ''};
    sProcess.options.outputmode.Type    = 'radio_linelabel';
    sProcess.options.outputmode.Value   = 'input';
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA)
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end

    OPTIONS.Method = 'cohere';
    OPTIONS.CohMeasure = sProcess.options.cohmeasure.Value; 
    OPTIONS.RemoveEvoked = sProcess.options.removeevoked.Value;

    % === Time-freq method 
    OPTIONS.tfMeasure = sProcess.options.tfmeasure.Value;
    if ismember(OPTIONS.tfMeasure, {'hilbert','morlet','stft'})
        % Get time-freq panel options
        tfOPTIONS = sProcess.options.tfedit.Value;
        if isempty(tfOPTIONS)
            [bstPanelNew, panelName] = panel_timefreq_options('CreatePanel', sProcess, sInputA);
            gui_show(bstPanelNew, 'JavaWindow', panelName, 0, 0, 0);
            drawnow;
            tfOPTIONS = panel_timefreq_options('GetPanelContents');
            gui_hide(panelName);
        end
    end
    switch OPTIONS.tfMeasure
        case 'hilbert'
            OPTIONS.Freqs = tfOPTIONS.Freqs;
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
                OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
            OPTIONS.isMirror = 0;
        case 'morlet'
            OPTIONS.Freqs        = tfOPTIONS.Freqs(:);
            OPTIONS.MorletFc     = tfOPTIONS.MorletFc;
            OPTIONS.MorletFwhmTc = tfOPTIONS.MorletFwhmTc;            
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
                OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
        case 'stft'
            OPTIONS.Freqs = [];
            OPTIONS.StftWinLen = tfOPTIONS.StftWinLen;
            OPTIONS.StftWinOvr = tfOPTIONS.StftWinOvr/100;
            OPTIONS.MaxFreq    = tfOPTIONS.StftFrqMax;
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
                OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
    end
    % Keep time or not; now option, no longer separate process
    OPTIONS.TimeRes = sProcess.options.timeres.Value;

    % Compute metric
    OutputFiles = bst_connectivity(sInputA, sInputA, OPTIONS);
end




