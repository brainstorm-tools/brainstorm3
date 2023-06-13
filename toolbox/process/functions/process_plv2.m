function varargout = process_plv2( varargin )
% PROCESS_PLV2: Compute the coherence between one signal in one file, and all the signals in another file.

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

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Phase locking value AxB';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 656;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    
    % === CONNECT INPUT
    sProcess = process_corr2('DefineConnectOptions', sProcess);
    % === Time-freq options
    sProcess.options.label2.Comment = 'Time-frequency decomposition:';
    sProcess.options.label2.Type    = 'label';
    % === Hilbert/Morlet
    sProcess.options.tfmeasure.Comment = {'Instantaneous (Hilbert)', 'Spectral (Fourier)', ''; 'hilbert', 'fourier', ''};
    sProcess.options.tfmeasure.Type    = 'radio_linelabel';
    sProcess.options.tfmeasure.Value   = 'hilbert';
    sProcess.options.tfmeasure.Controller = struct('hilbert', 'hilbert', 'fourier', 'fourier');
    % === KEEP TIME
    sProcess.options.keeptime.Comment = 'Time-resolved: estimate for each time point, requires many trials';
    sProcess.options.keeptime.Type    = 'checkbox';
    sProcess.options.keeptime.Value   = 0;
    sProcess.options.keeptime.Class   = 'hilbert';
    % === FREQ BANDS Panel 
    sProcess.options.freqbands.Comment = {'panel_timefreq_options', 'Frequency bands: '};
    sProcess.options.freqbands.Type    = 'editpref';
    sProcess.options.freqbands.Value   = [];
    sProcess.options.freqbands.Class   = 'hilbert';
%     % === FREQ BANDS
%     sProcess.options.freqbands.Comment = 'Frequency bands for the Hilbert transform:';
%     sProcess.options.freqbands.Type    = 'groupbands';
%     sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');

    % === PLV METHOD
    sProcess.options.plvmethod.Comment = {'<B>PLV</B>: Phase locking value', '<B>ciPLV</B>:  Corrected imaginary phase locking value', '<B>wPLI</B>: Weighted phase lag index'; ...
                                          'plv', 'ciplv', 'wpli'};
    sProcess.options.plvmethod.Type    = 'radio_label';
    sProcess.options.plvmethod.Value   = 'plv';
    % === PLV MEASURE
    sProcess.options.plvmeasure.Comment = {'None (complex)', 'Magnitude', 'Measure:'};
    sProcess.options.plvmeasure.Type    = 'radio_line';
    sProcess.options.plvmeasure.Value   = 2;
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Estimate separately for each input file (save one file per input)', 'Estimate across files (save one file)'; ...
                                            'input', 'avg'};
    sProcess.options.outputmode.Type    = 'radio_label';
    sProcess.options.outputmode.Value   = 'input';
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    if ~isempty(sProcess.options.plvmethod.Value)
        iMethod = find(strcmpi(sProcess.options.plvmethod.Comment(2,:), sProcess.options.plvmethod.Value));
        if ~isempty(iMethod)
            Comment = str_striptag(sProcess.options.plvmethod.Comment{1,iMethod});
        else
            Comment = sProcess.Comment;
        end
    else
        Comment = sProcess.Comment;
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA, sInputB)
    % Input options
    OPTIONS = process_corr2('GetConnectOptions', sProcess, sInputA, sInputB);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    OPTIONS.Method = sProcess.options.plvmethod.Value;

    % === Time-freq method 
    % Get time-freq panel options
    tfOPTIONS = sProcess.options.edit.Value;
    if isempty(tfOPTIONS) % possible?
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
            OPTIONS.Freqs = tfOPTIONS.Freqs;
            OPTIONS.isMirror = 0;
            % Keep time or not: different methods, only with Hilbert
            if sProcess.options.keeptime.Value
                OPTIONS.Method = [OPTIONS.Method 't'];
            end
        case 'fourier'
            OPTIONS.Freqs = [];
    end
%     % Hilbert and frequency bands options
%     OPTIONS.Freqs = sProcess.options.freqbands.Value;
%     OPTIONS.isMirror = 0;

    % PLV measure
    if isfield(sProcess.options, 'plvmeasure') && isfield(sProcess.options.plvmeasure, 'Value') && ~isempty(sProcess.options.plvmeasure.Value) 
        switch (sProcess.options.plvmeasure.Value)
            case 1,  OPTIONS.PlvMeasure = 'none';
            case 2,  OPTIONS.PlvMeasure = 'magnitude';
        end
    else
        OPTIONS.PlvMeasure = 'magnitude';
    end
    
    % Compute metric
    OutputFiles = bst_connectivity(sInputA, sInputB, OPTIONS);
end




