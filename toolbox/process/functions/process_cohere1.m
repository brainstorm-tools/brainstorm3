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
    % TODO: option to be removed once a process exists
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    sProcess.options.removeevoked.Group   = 'input';
    % === COHERENCE METHOD
    sProcess.options.label1.Comment = '<B>Connectivity Metric:</B>';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.cohmeasure.Comment = {...
        'Magnitude-squared coherence:  |C|^2 = |Cxy|^2/(Cxx*Cyy)', ...
        'Imaginary coherence:  IC = |imag(C)|', ...
        'Lagged coherence / Corrected imaginary coherence:  LC = |imag(C)|/sqrt(1-real(C)^2)'; ...
        'mscohere', 'icohere2019','lcohere2019'}; % , 'icohere'
%         '<FONT color="#777777"> Squared Lagged Coherence ("imaginary coherence" before 2019)</FONT>' ...
    sProcess.options.cohmeasure.Type    = 'radio_label';
    sProcess.options.cohmeasure.Value   = 'mscohere';
    % === Time-freq options
    sProcess.options.label2.Comment = '<B>Time-frequency decomposition:</B>';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.tfmeasure.Comment = {'Hilbert transform', 'Morlet wavelets', 'Fourier transform', ''; ...
                                          'hilbert', 'morlet', 'fourier', ''};
    sProcess.options.tfmeasure.Type    = 'radio_linelabel';
    sProcess.options.tfmeasure.Value   = 'hilbert';
    sProcess.options.tfmeasure.Controller = struct('hilbert', 'hilbert', 'morlet', 'hilbert', 'fourier', 'fourier');
    % === TF OPTIONS Panel 
    sProcess.options.tfedit.Comment = {'panel_timefreq_options', 'Options: '};
    sProcess.options.tfedit.Type    = 'editpref';
    sProcess.options.tfedit.Value   = [];
    sProcess.options.tfedit.Class   = 'hilbert';
%     % === Split a Large Signal into Blocks
%     sProcess.options.tfsplit.Comment = 'Split large data in';
%     sProcess.options.tfsplit.Type    = 'value';
%     sProcess.options.tfsplit.Value   = {1, 'time block(s)', 0};
%     sProcess.options.tfsplit.Class   = 'hilbert';
    % === WINDOW LENGTH
    sProcess.options.fftlength.Comment = 'Fourier transform window length:';
    sProcess.options.fftlength.Type    = 'value';
    sProcess.options.fftlength.Value   = {1, 's', []};
    sProcess.options.fftlength.Class   = 'fourier';
    % === OVERLAP
    sProcess.options.fftoverlap.Comment = 'Fourier transform window overlap:';
    sProcess.options.fftoverlap.Type    = 'value';
    sProcess.options.fftoverlap.Value   = {50, '%', []};
    sProcess.options.fftoverlap.Class   = 'fourier';
    % === HIGHEST FREQUENCY OF INTEREST
    sProcess.options.maxfreq.Comment = 'Highest frequency of interest:';
    sProcess.options.maxfreq.Type    = 'value';
    sProcess.options.maxfreq.Value   = {59,'Hz',2};
    sProcess.options.maxfreq.Class   = 'fourier';
    % === TIME AVERAGING
    sProcess.options.timeres.Comment = {'Full (requires epochs)', 'Windowed', 'None', '<B>Time resolution:</B>'; ...
                                        'full', 'windowed', 'none', ''};
    sProcess.options.timeres.Type    = 'radio_linelabel';
    sProcess.options.timeres.Value   = 'full';
    % === Hilbert/Morlet: WINDOW LENGTH
    sProcess.options.avgwinlength.Comment = '&nbsp;&nbsp;&nbsp;Time window length:';
    sProcess.options.avgwinlength.Type    = 'value';
    sProcess.options.avgwinlength.Value   = {1, 's', []};
    sProcess.options.avgwinlength.Class   = 'hilbert';
%     % === Hilbert/Morlet: OVERLAP
%     sProcess.options.avgwinoverlap.Comment = '&nbsp;&nbsp;&nbsp;Time window overlap:';
%     sProcess.options.avgwinoverlap.Type    = 'value';
%     sProcess.options.avgwinoverlap.Value   = {50, '%', []};
%     sProcess.options.avgwinoverlap.Class   = 'hilbert';
    % === Fourier: MOVING AVERAGE 
    sProcess.options.avgwinnum.Comment = '&nbsp;&nbsp;&nbsp;Time window length:';
    sProcess.options.avgwinnum.Type    = 'value';
    sProcess.options.avgwinnum.Value   = {3, 'Fourier transform windows', 0};
    sProcess.options.avgwinnum.Class   = 'fourier';
    % === OUTPUT MODE / FILE AVERAGING
    % Ideally, 'input' would be disabled for 'full' time resolution.
    sProcess.options.outputmode.Comment = {'separately for each file', 'once across files/epochs', 'Estimate & save:'; ...
                                            'input', 'avg', ''};
    sProcess.options.outputmode.Type    = 'radio_linelabel';
    sProcess.options.outputmode.Value   = 'input';
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    if ~isempty(sProcess.options.cohmeasure.Value)
        iMethod = find(strcmpi(sProcess.options.cohmeasure.Comment(2,:), sProcess.options.cohmeasure.Value));
        if ~isempty(iMethod)
            Comment = str_striptag(sProcess.options.cohmeasure.Comment{1,iMethod});
        else
            Comment = sProcess.Comment;
        end
    else
        Comment = sProcess.Comment;
    end
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
    if ismember(OPTIONS.tfMeasure, {'hilbert','morlet'})
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
                %OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
            OPTIONS.isMirror = 0;
        case 'morlet'
            OPTIONS.Freqs        = tfOPTIONS.Freqs(:);
            OPTIONS.MorletFc     = tfOPTIONS.MorletFc;
            OPTIONS.MorletFwhmTc = tfOPTIONS.MorletFwhmTc;            
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
                %OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
            end
        case 'fourier'
            OPTIONS.Freqs = [];
            OPTIONS.WinLen = sProcess.options.fftlength.Value{1};
            OPTIONS.WinOverlap = sProcess.options.fftoverlap.Value{1}/100;
            OPTIONS.MaxFreq = sProcess.options.maxfreq.Value{1};
            if strcmpi(sProcess.options.timeres.Value, 'windowed')
                OPTIONS.nAvgLen = sProcess.options.avgwinnum.Value{1};
            end
    end
    % Keep time or not; now option, no longer separate process
    OPTIONS.TimeRes = sProcess.options.timeres.Value;

    % Compute metric
    OutputFiles = bst_connectivity(sInputA, sInputA, OPTIONS);
end




