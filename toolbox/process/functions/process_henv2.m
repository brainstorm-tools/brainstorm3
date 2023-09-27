function varargout = process_henv2(varargin)
% PROCESS_HENV2: Compute the time-varying Coherence and envelope measures using Hilbert transform and Morlet Wavelet

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
% Author: Hossein Shahabi, Francois Tadel, 2022
%         Marc Lalancette, 2023

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() 
    % === Description the process
    sProcess.Comment     = 'Envelope Correlation AxB [2023]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 658;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % === Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    
    % === CONNECT INPUT
    sProcess = process_corr2('DefineConnectOptions', sProcess);
    % === REMOVE EVOKED REPONSE
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    sProcess.options.removeevoked.Group   = 'input';
    sProcess.options.removeevoked.Hidden  = 1;
    % === Connectivity measure 
    sProcess.options.label1.Comment = '<B>Connectivity Metric:</B>';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.cohmeasure.Comment = {'Envelope correlation (no orthogonalization)','Envelope correlation (orthogonalized) '; ...
                                           'penv', 'oenv'}; % 'coh', 'msc', 'lcoh', 
%                                            'Magnitude coherence: |C|= |Cxy|/sqrt(Cxx*Cyy)', ...
%                                            'Magnitude-squared coherence: |C|^2 = |Cxy|^2/(Cxx*Cyy)', ...
%                                            'Lagged coherence: LC = |imag(C)|/sqrt(1-real(C)^2)', ...
                                           
    sProcess.options.cohmeasure.Type    = 'radio_label';
    sProcess.options.cohmeasure.Value   = 'penv';
    % === TIME-FREQUENCY OPTIONS
    sProcess.options.tfmeasure.Comment = {'Hilbert transform', 'Morlet wavelets', '<B>Time-frequency decomposition:</B>'; ...
                                          'hilbert', 'morlet', ''};
    sProcess.options.tfmeasure.Type    = 'radio_linelabel';
    sProcess.options.tfmeasure.Value   = 'hilbert';
    % === Edit Panel 
    sProcess.options.tfedit.Comment = {'panel_timefreq_options', 'Options: '};
    sProcess.options.tfedit.Type    = 'editpref';
    sProcess.options.tfedit.Value   = [];
%     sProcess.options.tfedit.Class   = 'hilbert';
%     % === Split a Large Signal into Blocks
%     sProcess.options.tfsplit.Comment = 'Split large data in';
%     sProcess.options.tfsplit.Type    = 'value';
%     sProcess.options.tfsplit.Value   = {1, 'time block(s)', 0};
%     sProcess.options.tfsplit.Class   = 'hilbert';
    % === TIME AVERAGING
    sProcess.options.timeres.Comment = {'Windowed', 'None', '<B>Time resolution:</B>'; ... % 'Full (requires epochs)', 
                                     'windowed', 'none', ''}; % 'full', 
    sProcess.options.timeres.Type    = 'radio_linelabel';
    sProcess.options.timeres.Value   = 'windowed';
    % === Hilbert/Morlet: WINDOW LENGTH
    sProcess.options.avgwinlength.Comment = '&nbsp;&nbsp;&nbsp;Time window length:';
    sProcess.options.avgwinlength.Type    = 'value';
    sProcess.options.avgwinlength.Value   = {1, 's', []};
    % === Hilbert/Morlet: OVERLAP
    sProcess.options.avgwinoverlap.Comment = '&nbsp;&nbsp;&nbsp;Time window overlap:';
    sProcess.options.avgwinoverlap.Type    = 'value';
    sProcess.options.avgwinoverlap.Value   = {50, '%', []};
    % === Parallel processing
    sProcess.options.parallel.Comment = 'Use the parallel processing toolbox';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 0;  
    % === OUTPUT MODE / FILE AVERAGING
    sProcess.options.outputmode.Comment = {'separately for each file', 'average over files/epochs', 'Estimate & save:'; ...
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
function OutputFiles = Run(sProcess, sInputA, sInputB) 
    % Initialize returned values
    OutputFiles = {};
    
    % === Input options
    OPTIONS = process_corr2('GetConnectOptions', sProcess, sInputA, sInputB);
    if isempty(OPTIONS)
        return
    end
    
    % === Metric options
    OPTIONS.Method        = 'henv';
    OPTIONS.CohMeasure    = sProcess.options.cohmeasure.Value;
    OPTIONS.RemoveEvoked  = sProcess.options.removeevoked.Value;
    OPTIONS.isSave        = 1;
    OPTIONS.isSymmetric   = 1; 
    
    % === Time-freq method 
    % Get time-freq panel options
    tfOPTIONS = sProcess.options.tfedit.Value;
    if isempty(tfOPTIONS)
        [bstPanelNew, panelName] = panel_timefreq_options('CreatePanel', sProcess, sInputA);
        gui_show(bstPanelNew, 'JavaWindow', panelName, 0, 0, 0); 
        drawnow;
        tfOPTIONS = panel_timefreq_options('GetPanelContents');
        gui_hide(panelName);
    end
    % Fill bst_henv options structure
    OPTIONS.tfMeasure = sProcess.options.tfmeasure.Value;
    switch OPTIONS.tfMeasure
        case 'hilbert'
            OPTIONS.Freqs        = tfOPTIONS.Freqs;
        case 'morlet'
            OPTIONS.Freqs        = tfOPTIONS.Freqs(:);
            OPTIONS.MorletFc     = tfOPTIONS.MorletFc;
            OPTIONS.MorletFwhmTc = tfOPTIONS.MorletFwhmTc;
    end
    
    % === Number of Blocks
    if isfield(sProcess.options, 'tfsplit')
        OPTIONS.tfSplit = sProcess.options.tfsplit.Value{1};
        if OPTIONS.tfSplit <= 1
            OPTIONS.tfSplit = 1; 
        elseif OPTIONS.tfSplit > 20
            OPTIONS.tfSplit = 20;
        else
            OPTIONS.tfSplit = round(OPTIONS.tfSplit);
        end
    else
        OPTIONS.tfSplit = 1; 
    end
    
    if isfield(sProcess.options, 'win_length')
        % Compatibility (before 2023)
        OPTIONS.WinLen     = sProcess.options.win_length.Value{1};
        OPTIONS.WinOverlap = sProcess.options.win_overlap.Value{1} / 100;
        if strcmpi(sProcess.options.statdyn.Value, 'static')
            OPTIONS.TimeRes = 'none';
        else % 'dynamic'
            OPTIONS.TimeRes = 'windowed';
        end
    else
        % Harmonized options (2023)
        OPTIONS.WinLen     = sProcess.options.avgwinlength.Value{1};
        OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1} / 100;
        OPTIONS.TimeRes    = sProcess.options.timeres.Value;
    end
    
    % === Parallel Processing 
    OPTIONS.isParallel = sProcess.options.parallel.Value; 

    % === Computing connectivity matrix
    OutputFiles = bst_connectivity(sInputA, sInputB, OPTIONS);
end
