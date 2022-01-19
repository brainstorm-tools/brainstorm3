function varargout = panel_timefreq_options(varargin)
% PANEL_TIMEFREQ_OPTIONS: Options for time-frequency computation.
% 
% USAGE:  bstPanelNew = panel_timefreq_options('CreatePanel')
%                   s = panel_timefreq_options('GetPanelContents')

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
% Authors: Francois Tadel, 2010-2021
%          Hossein Shahabi, 2020-2021

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>  
    panelName = 'TimefreqOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % No input
    if isempty(sFiles) || strcmpi(sFiles(1).FileType, 'import')
        bstPanelNew = [];
        panelName = [];
        return;
    end
    % Build all the panel options
    procOPTIONS.TimeVector = in_bst(sFiles(1).FileName, 'Time');
    procOPTIONS.nInputs    = length(sFiles);
    procOPTIONS.DataType   = sFiles(1).FileType;
    if isfield(sProcess.options, 'clusters') && ~isempty(sProcess.options.clusters) && ~isempty(sProcess.options.clusters.Value)
        procOPTIONS.Clusters = sProcess.options.clusters.Value;
    else
        procOPTIONS.Clusters = [];
    end
    isCluster = ~isempty(procOPTIONS.Clusters);
    if isCluster
        % Get scouts structures
        FileMat = in_bst_results(sFiles(1).FileName, 0, 'SurfaceFile');
        sScouts = process_extract_scout('GetScoutsInfo', 'panel_timefreq', [], FileMat.SurfaceFile, procOPTIONS.Clusters);
        % Override scouts function
        if isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value') && ~isempty(sProcess.options.scoutfunc.Value)
            switch lower(sProcess.options.scoutfunc.Value)
                case {1, 'mean'}, ScoutFunc = 'mean';
                case {2, 'max'},  ScoutFunc = 'max';
                case {3, 'pca'},  ScoutFunc = 'pca';
                case {4, 'std'},  ScoutFunc = 'std';
                case {5, 'all'},  ScoutFunc = 'all';
                otherwise,  bst_report('Error', sProcess, [], 'Invalid scout function.');  return;
            end
            isClusterAll = strcmpi(ScoutFunc, 'All');
        % Else: Check if some scouts are using the function "All"
        else
            ScoutFunc = sScouts(1).Function;
            isClusterAll = any(strcmpi({sScouts.Function}, 'All'));
        end
    else
        isClusterAll = 0;
    end
    
    % Determine which function is calling this pannel
    isProcHenv = ismember(func2str(sProcess.Function), {'process_henv1', 'process_henv1n', 'process_henv2'});
    if isProcHenv
        Method = sProcess.options.tfmeasure.Value;
    else
        Method = strrep(strrep(func2str(sProcess.Function), 'process_', ''), 'timefreq', 'morlet');
    end
    
    hFigWavelet = [];
    % Restrict time vector to selected time window
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value) && (length(sProcess.options.timewindow.Value{1}) == 2)
        iTime = find((procOPTIONS.TimeVector >= sProcess.options.timewindow.Value{1}(1)) & (procOPTIONS.TimeVector <= sProcess.options.timewindow.Value{1}(2)));
        procOPTIONS.TimeVector = procOPTIONS.TimeVector(iTime);
    end
    % Get time description string
    if (nargin < 1) || isempty(procOPTIONS.TimeVector)
        strTimeInput = '[N/A]';
    elseif any(abs(procOPTIONS.TimeVector) > 2)
        strTimeInput = sprintf('[%1.3fs : %1.2fms : %1.3fs]', procOPTIONS.TimeVector(1), (procOPTIONS.TimeVector(2)-procOPTIONS.TimeVector(1))*1000, procOPTIONS.TimeVector(end));
    else
        strTimeInput = sprintf('[%1.2f : %1.2f : %1.2f] ms', procOPTIONS.TimeVector(1)*1000, (procOPTIONS.TimeVector(2)-procOPTIONS.TimeVector(1))*1000, procOPTIONS.TimeVector(end)*1000);
    end
    % Are we procesing only one file ?
    isOneFile = (procOPTIONS.nInputs == 1);
    % Processing sources? kernels?
    isSource = (strcmpi(procOPTIONS.DataType, 'results') && ~isCluster);
    if isSource
        % Get which files are based on inversion kernels
        isKernel = zeros(1, length(sFiles));
        for iFile = 1:length(sFiles)
            isKernel(iFile) = ~isempty(strfind(sFiles(iFile).FileName, '_KERNEL_'));
        end
    end
    % Get number of sources
    if isSource && isKernel(1)
        % Results
        ResFile = file_fullpath(sFiles(1).FileName);
        w = whos(ResFile, '-file', ResFile, 'ImagingKernel');
        nSources = w.size(1);
    elseif isSource
        ResFile = file_fullpath(sFiles(1).FileName);
        w = whos(ResFile, '-file', ResFile, 'ImageGridAmp');
        nSources = w.size(1);
    end
    % Get number of sensors
    if ~isCluster && (~isSource || isKernel(1)) && ~isempty(sFiles(1).ChannelFile)
        ChanFile = file_fullpath(sFiles(1).ChannelFile);
        if isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes.Value)
            ChanMat = load(ChanFile, 'Channel');
            nChannels = length(channel_find(ChanMat.Channel, sProcess.options.sensortypes.Value));
        else
            w = whos(ChanFile, '-file', ChanFile, 'Channel');
            nChannels = max(w.size);
        end
    else
        nChannels = 0;
    end
    % Get time-frequency saved options
    TimefreqOptions = bst_get(['TimefreqOptions_', Method]);

    % Create main main panel
    jPanelNew = gui_river();
    
    % ===== COMMENT =====
    gui_component('label', jPanelNew, [], 'Comment:  ');
    jTextComment = gui_component('text', jPanelNew, 'hfill', ' ');
    
    % ===== TIME PANEL =====
    jPanelTime = gui_river([2,2], [0,10,15,10], 'Time definition');
        % Radio: Time mode
        jButtonGroup = ButtonGroup();
        jRadioTimeInput = gui_component('radio', jPanelTime, [],   'Same as input files', jButtonGroup, [], @UpdatePanel);
        jLabelTimeInput = gui_component('label', jPanelTime, 'br', strTimeInput);
        jRadioTimeBands = gui_component('radio', jPanelTime, 'br', 'Group in time bands (ms)', jButtonGroup, [], @UpdatePanel);
        % Text: time bands
        strTimeBands = process_tf_bands('FormatBands', TimefreqOptions.TimeBands);
        jTextTimeBands = gui_component('textfreq', jPanelTime, 'br hfill', strTimeBands, [], [], @UpdatePanel);
        if strcmpi(Method, 'morlet')
            jTextTimeBands.setRows(10);
        end
        % Button: Generate
        jButtonTimeBands = gui_component('button', jPanelTime, 'br', 'Generate', [], [], @CreateTimeBands);
        jButtonTimeBands.setMargin(Insets(0,3,0,3));
    if ~ismember(Method, {'fft', 'psd'}) && ~isProcHenv
        jPanelNew.add('br', jPanelTime);
    else
        gui_component('label', jPanelNew, 'br', '');
    end

    % ===== FREQUENCY PANEL =====
    jPanelFreq = gui_river([2,2], [0,10,15,10], 'Frequency definition');
        % Radio: Same as input files
        jButtonGroup = ButtonGroup();
        % Hilbert/FFT: Cannot specify the output frequency vector
        if strcmpi(Method, 'morlet')
            jRadioFreqLinear = gui_component('radio', jPanelFreq, [],         'Linear (start:step:stop)',      jButtonGroup, [], @UpdatePanel);
            jTextFreqLinear  = gui_component('text',  jPanelFreq, 'br hfill', TimefreqOptions.Freqs,           [],           [], @UpdatePanel);
            jRadioFreqLog    = gui_component('radio', jPanelFreq, 'br',       'Log (start:N:stop)',            jButtonGroup, [], @UpdatePanel);
            jTextFreqLog     = gui_component('text',  jPanelFreq, 'br hfill', TimefreqOptions.FreqsLog,        [],           [], @UpdatePanel);
            jRadioFreqBands  = gui_component('radio', jPanelFreq, 'br',       'Group in frequency bands (Hz)', jButtonGroup, [], @UpdatePanel);
        % TF: Setting the output vector
        elseif ismember(Method, {'fft', 'psd'}) || strcmpi(Method, 'hilbert')
            jRadioFreqLinear = gui_component('radio', jPanelFreq, [],   'Matlab''s FFT defaults',        jButtonGroup, [], @UpdatePanel);
            jTextFreqLinear  = [];
            jRadioFreqLog    = [];
            jTextFreqLog     = [];
            jRadioFreqBands  = gui_component('radio', jPanelFreq, 'br', 'Group in frequency bands (Hz)', jButtonGroup, [], @UpdatePanel);
        end
        % Text: freq bands
        strFreqBands = process_tf_bands('FormatBands', TimefreqOptions.FreqBands);
        jTextFreqBands = gui_component('textfreq', jPanelFreq, 'br hfill', strFreqBands, [], [], @UpdatePanel);
        % Button Reset
        jButtonFreqBands = gui_component('button', jPanelFreq, 'br', 'Reset', [], [], @ResetFreqBands);
        jButtonFreqBands.setMargin(Insets(0,3,0,3));
    jPanelNew.add('hfill', jPanelFreq);
    
    % ===== WAVELET OPTIONS =====
    if strcmpi(Method, 'morlet')
        jPanelWave= gui_river([2,2], [0,10,15,10], 'Morlet wavelet options');
        % Central frenquency
                  gui_component('label',    jPanelWave, '', 'Central frequency: ');
        jTextFc = gui_component('texttime', jPanelWave, 'tab', num2str(TimefreqOptions.MorletFc));
                  gui_component('label',    jPanelWave, '', 'Hz  (default=1)');
        java_setcb(jTextFc, 'ActionPerformedCallback', @DisplayTimeResolution);
        % Display wavelets
        gui_component('label',  jPanelWave, '', '      ');
        jButtonDisplay = gui_component('toggle', jPanelWave, '', 'Display', [], [], @DisplayTimeResolution);
        % Time resolution
                  gui_component('label',    jPanelWave, 'br', 'Time resolution (FWHM):  ');
        jTextTr = gui_component('texttime', jPanelWave, 'tab', num2str(TimefreqOptions.MorletFwhmTc));
                  gui_component('label',    jPanelWave, '', 's   (default=3)');
        jPanelNew.add('br hfill', jPanelWave);
        java_setcb(jTextTr, 'ActionPerformedCallback', @DisplayTimeResolution);
    else
        jTextFc = [];
        jTextTr = [];
    end
    
    % ===== PROCESSING OPTIONS =====
    jPanelProc = gui_river([2,2], [0,10,15,10], 'Processing options');       
        % === KERNEL SOURCE ===
        if isSource && all(isKernel) && ismember(Method, {'morlet', 'hilbert'})
            % Cluster function
            jButtonGroup = ButtonGroup();
                              gui_component('label', jPanelProc, 'p',  'Optimize the storage of the time-frequency files:');
                              gui_component('label', jPanelProc, 'br', '     ');
            jRadioKernelYes = gui_component('radio', jPanelProc, '',   ['Yes, save ' Method '(sensors) and inversion kernel'], jButtonGroup, [], @UpdatePanel);
                              gui_component('label', jPanelProc, 'br', '     ');
            jRadioKernelNo  = gui_component('radio', jPanelProc, '',   ['No, save full ' Method '(sources)'], jButtonGroup, [], @UpdatePanel);
        else
            jRadioKernelYes = [];
            jRadioKernelNo = [];
        end
        
        % === CLUSTER FUNCTION ===
        % Cluster name
        switch (procOPTIONS.DataType)
            case 'data',     ClusterName = 'Cluster';
            case 'results',  ClusterName = 'Scout'; 
            case 'timefreq', ClusterName = 'Scout';
            otherwise,      ClusterName = '';
        end
        % Scout/cluster function
        if isCluster && ~isClusterAll
            % Cluster function
            jButtonGroup = ButtonGroup();
                                gui_component('label', jPanelProc, 'p',  [ClusterName ' function (' ScoutFunc '):']);
                                gui_component('label', jPanelProc, 'br', '     ');
            jRadioClustBefore = gui_component('radio', jPanelProc, '',   'Before: Apply function and then compute TF', jButtonGroup, [], @UpdatePanel);
                                gui_component('label', jPanelProc, 'br', '     ');
            jRadioClustAfter  = gui_component('radio', jPanelProc, '',   'After: Compute TF and then apply function', jButtonGroup, [], @UpdatePanel);
            % Default: depends on the function selected
            if strcmpi(ScoutFunc, 'PCA') || strcmpi(ScoutFunc, 'FastPCA')
                jRadioClustBefore.setSelected(1);
                jRadioClustAfter.setEnabled(0);
            elseif strcmpi(TimefreqOptions.ClusterFuncTime, 'before')
                jRadioClustBefore.setSelected(1);
            else
                jRadioClustAfter.setSelected(1);
            end
        else
            jRadioClustBefore = [];
            jRadioClustAfter = [];
        end
        
        % === MEASURE ===
        if ~strcmpi(Method, 'psd')
            % Compute measure
            jButtonGroup = ButtonGroup();
                            gui_component('label', jPanelProc, 'p',  'Compute the following measure:');
                            gui_component('label', jPanelProc, 'br', '     ');
            jRadioMeasPow = gui_component('radio', jPanelProc, '',   'Power', jButtonGroup, [], @UpdatePanel);
            jRadioMeasMag = gui_component('radio', jPanelProc, '',   'Magnitude', jButtonGroup, [], @UpdatePanel);
            jRadioMeasNon = gui_component('radio', jPanelProc, '',   'None (save complex values)', jButtonGroup, [], @UpdatePanel);
        else
            jRadioMeasNon = [];
            jRadioMeasMag = [];
            jRadioMeasPow = [];
        end
        
        % === AVERAGE ===
        switch(Method)
            case 'morlet',   strMap = 'time-frequency maps';
            case 'hilbert',  strMap = 'Hilbert maps';
            case 'fft',      strMap = 'FFT values';
            case 'psd',      strMap = 'PSD values';
        end
        % Compute average
        if ~isOneFile
            jButtonGroup = ButtonGroup();
                           gui_component('label', jPanelProc, 'br', 'Output:');
                           gui_component('label', jPanelProc, 'br', '     ');
            jRadioOutAll = gui_component('radio', jPanelProc, '',   ['Save individual ' strMap ' (for each trial)'], jButtonGroup, [], @UpdatePanel);
                           gui_component('label', jPanelProc, 'br', '     ');
            jRadioOutAvg = gui_component('radio', jPanelProc, '',   ['Save average ' strMap ' (across trials)'], jButtonGroup, [], @UpdatePanel);
        else
            jRadioOutAll = [];
            jRadioOutAvg = [];
        end
        % Remove evoked response
        if ~isOneFile && ismember(Method, {'morlet','hilbert'})
            gui_component('label', jPanelProc, 'br', '     ');
            jCheckEvoked = gui_component('checkbox', jPanelProc, '', 'Remove evoked response from each trial before computing TF', [], [], @UpdatePanel);
        else
            jCheckEvoked = [];
        end
        
        % === FILE SIZE ===
        jTextOutputSize = gui_component('label', jPanelProc, 'br', '');
    if ~isProcHenv
        jPanelNew.add('br hfill', jPanelProc);
    end
    
    % ===== SET DEFAULT =====
    if TimefreqOptions.isTimeBands
        jRadioTimeBands.setSelected(1);
    else
        jRadioTimeInput.setSelected(1);
    end
    % Hilbert: Only allow freq bands
    if strcmpi(Method, 'hilbert')
        jRadioFreqLinear.setEnabled(0);
        jRadioFreqBands.setSelected(1);
    % PSD with normalized units: frequency bands not available
    elseif strcmpi(Method, 'psd') && isfield(sProcess.options, 'units') && isfield(sProcess.options.units, 'Value') && isequal(sProcess.options.units.Value, 'normalized')
        jRadioFreqLinear.setSelected(1);
    elseif TimefreqOptions.isFreqBands
        jRadioFreqBands.setSelected(1);
    elseif TimefreqOptions.isFreqLog
        jRadioFreqLog.setSelected(1);
    else
        jRadioFreqLinear.setSelected(1);
    end
    % Kernel
    if ~isempty(jRadioKernelYes)
        if TimefreqOptions.SaveKernel
            jRadioKernelYes.setSelected(1);
        else
            jRadioKernelNo.setSelected(1);
        end
    end
    % Measure
    if ~isempty(jRadioMeasNon)
        switch lower(TimefreqOptions.Measure)
            case 'none',      jRadioMeasNon.setSelected(1);
            case 'power',     jRadioMeasPow.setSelected(1);
            case 'magnitude', jRadioMeasMag.setSelected(1);
        end
    end
    % Output
    if ~isempty(jRadioOutAvg)
        if strcmpi(TimefreqOptions.Output, 'all')
            jRadioOutAll.setSelected(1);
        else
            jRadioOutAvg.setSelected(1);
        end
    end
    if ~isempty(jCheckEvoked)
        jCheckEvoked.setSelected(TimefreqOptions.RemoveEvoked);
    end
    
    % ===== VALIDATION BUTTON =====
    gui_component('Button', jPanelNew, 'br right', 'OK', [], [], @ButtonOk_Callback);

    % ===== PANEL CREATION =====
    % Put everything in a big scroll panel
    jPanelScroll = javax.swing.JScrollPane(jPanelNew);
    %jPanelScroll.add(jPanelNew);
    %jPanelScroll.setPreferredSize(jPanelNew.getPreferredSize());
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jTextComment',    jTextComment, ...
                  'jRadioTimeInput', jRadioTimeInput, ...
                  'jRadioTimeBands', jRadioTimeBands, ...
                  'jTextTimeBands',  jTextTimeBands, ...
                  'jButtonTimeBands', jButtonTimeBands, ...
                  'jRadioFreqLinear', jRadioFreqLinear, ...
                  'jTextFreqLinear', jTextFreqLinear, ...
                  'jRadioFreqLog',   jRadioFreqLog, ...
                  'jTextFreqLog',    jTextFreqLog, ...
                  'jRadioFreqBands', jRadioFreqBands, ...
                  'jTextFreqBands',  jTextFreqBands, ...
                  'jButtonFreqBands',jButtonFreqBands, ...
                  'jTextFc',         jTextFc, ...
                  'jTextTr',         jTextTr, ...
                  'jRadioKernelYes', jRadioKernelYes, ...
                  'jRadioKernelNo',  jRadioKernelNo, ...
                  'jRadioClustBefore', jRadioClustBefore, ...
                  'jRadioClustAfter',  jRadioClustAfter, ...
                  'jRadioMeasNon',   jRadioMeasNon, ...
                  'jRadioMeasMag',   jRadioMeasMag, ...
                  'jRadioMeasPow',   jRadioMeasPow, ...
                  'jRadioOutAll',    jRadioOutAll, ...
                  'jRadioOutAvg',    jRadioOutAvg, ...
                  'jCheckEvoked',    jCheckEvoked, ...
                  'jTextOutputSize', jTextOutputSize, ...
                  'Method',          Method);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelScroll, ctrl);
    
    UpdatePanel();
    
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        % Close "display resolution" figure
        if ~isempty(hFigWavelet) && ishandle(hFigWavelet)
            close(hFigWavelet);
        end
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        % === KERNEL ===
        if ~isempty(jRadioKernelYes)
            isSaveKernel = jRadioKernelYes.isSelected();
            if isSaveKernel
                jRadioTimeInput.setSelected(1);
                jRadioTimeBands.setEnabled(0);
            else
                jRadioTimeBands.setEnabled(1);
            end
        else
            isSaveKernel = 0;
        end
        % === TIME SELECTION ===
        isTimeInput = jRadioTimeInput.isSelected();
        jLabelTimeInput.setEnabled(isTimeInput);
        jTextTimeBands.setEnabled(~isTimeInput);
        jButtonTimeBands.setEnabled(~isTimeInput);
        % === FREQUENCY SELECTION ===
        if strcmpi(Method, 'hilbert')
            jRadioFreqLinear.setEnabled(0);
            jRadioFreqBands.setEnabled(1);
            jRadioFreqBands.setSelected(1);
            if ~isempty(jRadioFreqLog)
                jRadioFreqLog.setEnabled(0);
            end
        elseif isSaveKernel
            jRadioFreqLinear.setEnabled(1);
            jRadioFreqBands.setEnabled(0);
            jRadioFreqLinear.setSelected(1);
            if ~isempty(jRadioFreqLog)
                jRadioFreqLog.setEnabled(1);
            end
        else
            jRadioFreqLinear.setEnabled(1);
            if isProcHenv || (strcmpi(Method, 'psd') && isfield(sProcess.options, 'units') && isfield(sProcess.options.units, 'Value') && isequal(sProcess.options.units.Value, 'normalized'))
                jRadioFreqBands.setEnabled(0);
            else
                jRadioFreqBands.setEnabled(1);
            end
            if ~isempty(jRadioFreqLog)
                jRadioFreqLog.setEnabled(1);
            end
        end
        isFreqLinear = jRadioFreqLinear.isSelected();
        isFreqLog    = ~isempty(jRadioFreqLog) && jRadioFreqLog.isSelected();
        jTextFreqBands.setEnabled(~isFreqLinear && ~isFreqLog);
        jButtonFreqBands.setEnabled(~isFreqLinear && ~isFreqLog);
        if ~isempty(jTextFreqLinear)
            jTextFreqLinear.setEnabled(isFreqLinear);
        end
        if ~isempty(jTextFreqLog)
            jTextFreqLog.setEnabled(isFreqLog);
        end
        % === MEASURE ===
        if ~isempty(jRadioMeasNon)
            if isSaveKernel
                jRadioMeasNon.setEnabled(1);
                jRadioMeasMag.setEnabled(0);
                jRadioMeasPow.setEnabled(0);
                jRadioMeasNon.setSelected(1);
            else
                % If time bands / freq bands / clusters / source => Measure is forced
                isForceMeas = ((isCluster && ~isClusterAll && (isempty(jRadioClustAfter) || jRadioClustAfter.isSelected())) || ...
                               jRadioTimeBands.isSelected() || ...
                               (jRadioFreqBands.isSelected() && ~strcmpi(Method, 'hilbert')));
                jRadioMeasNon.setEnabled(~isForceMeas);
                jRadioMeasMag.setEnabled(1);
                jRadioMeasPow.setEnabled(1);
                if isForceMeas && jRadioMeasNon.isSelected()
                    jRadioMeasPow.setSelected(1);
                end                
            end
        end
        % Disable some options when called through process_henv*
        if isProcHenv
            jRadioMeasNon.setSelected(1);
            jRadioMeasPow.setEnabled(0);
            jRadioMeasMag.setEnabled(0);
        end
        % === OUTPUT ===
        if ~isempty(jRadioOutAvg)
            if ~isempty(jRadioMeasNon)
                isMeas = ~jRadioMeasNon.isSelected();
            else
                isMeas = 1;
            end
            isAvgWasDisabled = ~jRadioOutAvg.isEnabled();
            jRadioOutAll.setEnabled(1);
            jRadioOutAvg.setEnabled(isMeas);
            jRadioOutAll.setSelected(~isMeas);
            if ~isMeas
                jRadioOutAll.setSelected(1);
            elseif isAvgWasDisabled
                jRadioOutAvg.setSelected(1);
            end
        end
        if ~isempty(jCheckEvoked)
            if isSaveKernel
                jCheckEvoked.setEnabled(0);
                jCheckEvoked.setSelected(0);
            else
                jCheckEvoked.setEnabled(1);
            end
        end
        % === OUTPUT SIZE ===
        % Get number of rows
        if isCluster
            nRows = length(sScouts);
        elseif isSource && ~isSaveKernel
            nRows = nSources;
        else
            nRows = nChannels;
        end
        % Get input time length
        if strcmpi(Method, 'psd')
            sfreq = 1 ./ (procOPTIONS.TimeVector(2) - procOPTIONS.TimeVector(1));
            nTimeInput = round(sProcess.options.win_length.Value{1} * sfreq);
        else
            nTimeInput = length(procOPTIONS.TimeVector);
        end
        % Get output time length
        if ismember(Method, {'fft', 'psd'})
            nTimeOutput = 1;
        elseif isTimeInput
            nTimeOutput = nTimeInput;
        else
            nTimeOutput = size(process_tf_bands('ParseBands', char(jTextTimeBands.getText())), 1);
        end
        % Get frequencies
        if jRadioFreqLinear.isSelected()
            if ~isempty(jTextFreqLinear)
                try
                    nFreq = length(eval(char(jTextFreqLinear.getText())));
                catch
                    nFreq = 0;
                end
            else
                nFreq = 2 ^ nextpow2(nTimeInput) / 2;
            end
        elseif jRadioFreqBands.isSelected()
            nFreq = size(process_tf_bands('ParseBands', char(jTextFreqBands.getText())), 1);
        else
            nFreq = length(GetLogFreq(char(jTextFreqLog.getText())));
        end
        % Initial estimate
        EstimateSize = nRows * nTimeOutput * nFreq * 8 / 1024 / 1024;
        % If complex values: double size
        if ~isempty(jRadioMeasNon) && jRadioMeasNon.isSelected()
            EstimateSize = EstimateSize * 2;
        end
        EstimateSize = ceil(EstimateSize);
        % If saving many files
        if ~isempty(jRadioOutAll) && jRadioOutAll.isSelected()
            strEstimate = sprintf('%d * %d = %d Mb', length(sFiles), EstimateSize, length(sFiles) * EstimateSize);
        else
            strEstimate = sprintf('%d Mb', EstimateSize);
        end
        if (EstimateSize > 500)
            strEstimate = ['<FONT color=red>' strEstimate '<FONT>'];
        end
        % Update estimate
        jTextOutputSize.setText(['<HTML><BR>Estimated output file size:&nbsp;&nbsp;&nbsp;<B>' strEstimate '</B>']);
        % Update comment
        UpdateComment();
    end

%% ===== UPDATE COMMENT =====
    function UpdateComment(varargin)
        % Get panel contents
        tfOPTIONS = GetPanelContents(ctrl);
        % Initial comment (defined in Process options panel)
        Comment = '';
        % Cluster/scout/recordings/sources
        if isCluster
            % Cluster name
            Comment = [Comment, ClusterName];
            % Cluster description
            if (length(sScouts) == 1)
                Comment = [Comment, ' ' sScouts(1).Label, ','];
            elseif (length(sScouts) > 1)
                Comment = [Comment, 's,'];
            end
        end
        % Average
        if strcmpi(tfOPTIONS.Output, 'average')
            Comment = [Comment, 'Avg,'];
        end
        % Measure
        if strcmpi(tfOPTIONS.Measure, 'power')
            Comment = [Comment, 'Power'];
            strComa = ',';
        elseif strcmpi(tfOPTIONS.Measure, 'magnitude')
            Comment = [Comment, 'Magnitude'];
            strComa = ',';
        else
            Comment = [Comment, 'Complex'];
            strComa = ',';
        end
        % Time
        if ~isempty(tfOPTIONS.TimeBands)
            Comment = [Comment, strComa, 'TimeBands'];
        end
        % Frequencies
        if ~isempty(jTextFreqLinear) && isempty(tfOPTIONS.Freqs)
            Comment = [Comment, strComa, 'Invalid frequencies'];
        elseif ~isempty(jTextFreqLinear) && ~iscell(tfOPTIONS.Freqs)
            Comment = [Comment, strComa, sprintf('%d-%dHz', round(tfOPTIONS.Freqs(1)), round(tfOPTIONS.Freqs(end)))];
        elseif iscell(tfOPTIONS.Freqs) && ~strcmpi(Method, 'hilbert')
            Comment = [Comment, strComa, 'FreqBands'];
        end
        % Set control text
        jTextComment.setText(Comment);
    end

%% ===== DISPLAY TIME RESOLUTION =====
    function DisplayTimeResolution(varargin)
        % Close previous figure
        if ~isempty(hFigWavelet) && ishandle(hFigWavelet)
            close(hFigWavelet);
        end
        % If view selected
        if jButtonDisplay.isSelected()
            % Hide panel timefreq options temporarily
            jPanelNew.getTopLevelAncestor().setModal(0);
        else
            % Restore modality status and exit
            jPanelNew.getTopLevelAncestor().setModal(1);
            return
        end
        % Get wavelet options
        sOptions = GetPanelContents(ctrl);
        if isempty(sOptions.MorletFc) || isempty(sOptions.MorletFwhmTc)
            error('Invalid values');
        end
        % If valid values: show time resolution
        [f, FWHM_t, FWHM_f, t, W] = morlet_design(sOptions.MorletFc, sOptions.MorletFwhmTc);

        % Plot the values
        isJavacomponent = bst_get('isJavacomponent');
        if isJavacomponent
            hFigWavelet = figure(...
                'MenuBar',     'none', ...
                'Toolbar',     'none', ...
                'NumberTitle', 'off', ...
                'Name',        'Morlet wavelet', ...
                'Pointer',     'arrow');
            hAxes1 = axes();
            hAxes2 = axes();
            hAxes3 = axes();
        else
            bst_progress('start', 'Morlet wavelets', 'Opening figure...');
            hFigWavelet = uifigure(...
                'NumberTitle', 'off', ...
                'Name',        'Morlet wavelet', ...
                'Pointer',     'arrow', ...
                'AutoResizeChildren', 'on');
            hAxes1 = axes(hFigWavelet);
            hAxes2 = axes(hFigWavelet);
            hAxes3 = axes(hFigWavelet);
        end
        fontSize = bst_get('FigFont');
        % Frequency resolution
        plot(hAxes1, f, FWHM_f);
        title(hAxes1, 'Spectral resolution', 'Interpreter', 'none', 'FontSize', fontSize);
        xlabel(hAxes1, 'Frequency (Hz)', 'FontSize', fontSize);
        ylabel(hAxes1, 'FWHM (Hz)', 'FontSize', fontSize);
        set(hAxes1, 'Position', [.08, .64, .34, .28], 'FontSize', fontSize, 'XGrid', 'on', 'YGrid', 'on');
        % Time resolution
        plot(hAxes2, f, FWHM_t);
        title(hAxes2, 'Temporal resolution', 'Interpreter', 'none', 'FontSize', fontSize);
        xlabel(hAxes2, 'Frequency (Hz)', 'FontSize', fontSize);
        ylabel(hAxes2, 'FWHM (sec)', 'FontSize', fontSize);
        set(hAxes2, 'Position', [.08, .22, .34, .28], 'FontSize', fontSize, 'XGrid', 'on', 'YGrid', 'on');
        % Plot morlet wavelet
        plot(hAxes3, t,real(W),'linewidth',2)
        hold(hAxes3, 'on');
        plot(hAxes3, t,imag(W),'r','linewidth',2)
        title(hAxes3, 'Complex Morlet wavelet');
        set(hAxes3, 'XLim', [t(1), t(end)], 'YLim', [-1,1]*1.05*max(real(W)), ...
                   'Position', [.50, .22, .44, .70], 'FontSize', fontSize, 'XGrid', 'on', 'YGrid', 'on');
        % Text
        strDesc = ['<HTML>The complex Morlet wavelet is a Gaussian weighted sinusoid (blue for real values, ' ...
                   'red for imaginary values). It has point spread function with Gaussian shape both ' ...
                   'in time (temporal resolution) and in frequency (spectral resolution). Resolution is ' ...
                   'given in units of FWHM (full width half maximum) for several frequencies.'];
        if isJavacomponent
            [jLabelDesc, hLabelDesc] = javacomponent(javax.swing.JLabel(strDesc), [0 0 1 1], hFigWavelet);
            set(hLabelDesc, 'Units', 'Normalized', 'Position', [.01, .0, .99, .13], 'BackgroundColor', get(hFigWavelet, 'Color'));
            bgColor = get(hFigWavelet, 'Color');
            jLabelDesc.setBackground(java.awt.Color(bgColor(1),bgColor(2),bgColor(3)));
        else
            figPos = get(hFigWavelet, 'Position');
            hLabelDesc = uihtml(hFigWavelet, 'Position', [5, 5, figPos(3)*.99, figPos(4)*.13], 'HTMLSource', strDesc);
            drawnow;
            bst_progress('stop');
        end
    end

%% ===== CREATE TIME BANDS =====
    function CreateTimeBands(varargin)
        % Get time units
        if (nargin < 1) || isempty(procOPTIONS.TimeVector)
            error('No time defined.');
        end
        % Ask the duration of each time band
        strDuration = java_dialog('input', 'Enter the duration of each time band (in miliseconds)', 'Create time bands', [], '100');
        if isempty(strDuration)
            return
        end
        % Get duration set by the user
        duration = str2num(strDuration);
        if isempty(duration)
            bst_error('Invalid duration value.', 'Create time bands', 0);
            return
        end
        % Convert into seconds
        duration = duration / 1000;
        
        % Create time bands
        TimeBands = {};
        smpRate = procOPTIONS.TimeVector(2) - procOPTIONS.TimeVector(1);
        len = round(duration / smpRate);
        % Negative time bands
        if (procOPTIONS.TimeVector(1) < 0)
            iPos = find(procOPTIONS.TimeVector < 0);
            nbBands = ceil(length(iPos) / len);
            for i = nbBands:-1:1
                TimeBands{end+1,1} = sprintf('t-%d', i);
                TimeBands{end,2} = sprintf('%1.4f, %1.4f', procOPTIONS.TimeVector(iPos(max(length(iPos) - i*len + 1, 1))), procOPTIONS.TimeVector(iPos(length(iPos) - (i-1) * len)));
                TimeBands{end,3} = 'mean';
            end
        end
        % Positive time bands
        if (procOPTIONS.TimeVector(end) >= 0)
            iPos = find(procOPTIONS.TimeVector >= 0);
            nbBands = ceil(length(iPos) / len);
            for i = 1:nbBands
                TimeBands{end+1,1} = sprintf('t%d', i);
                TimeBands{end,2} = sprintf('%1.4f, %1.4f', procOPTIONS.TimeVector(iPos((i-1) * len + 1)), procOPTIONS.TimeVector(iPos(min(i * len, length(iPos)))));
                TimeBands{end,3} = 'mean';
            end
        end
        % Update text field
        strTimeBands = process_tf_bands('FormatBands', TimeBands);
        jTextTimeBands.setText(strTimeBands);
        % Update file size
        UpdatePanel();
    end

    %% ===== RESET FREQ BANDS =====
    function ResetFreqBands(varargin)
        % Get default options
        TimefreqOptions = bst_get(['TimefreqOptions_', Method]);
        TimefreqOptions = rmfield(TimefreqOptions, 'FreqBands');
        bst_set(['TimefreqOptions_', Method], TimefreqOptions);
        TimefreqOptions = bst_get(['TimefreqOptions_', Method]);
        % Update text field
        strFreqBands = process_tf_bands('FormatBands', TimefreqOptions.FreqBands);
        jTextFreqBands.setText(strFreqBands);
        % Update file size
        UpdatePanel();
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents(ctrl)
    % Get panel controls
    if (nargin == 0) || isempty(ctrl)
        ctrl = bst_get('PanelControls', 'TimefreqOptions');
    end
    
    % Get comment
    s.Comment = char(ctrl.jTextComment.getText());
    % Get times bands
    isTimeBands = ctrl.jRadioTimeBands.isSelected();
    if isTimeBands
        s.TimeBands = process_tf_bands('ParseBands', char(ctrl.jTextTimeBands.getText()));
    else
        s.TimeBands = [];
    end
    % Get frequencies
    isFreqBands = ctrl.jRadioFreqBands.isSelected();
    isFreqLog   = ~isempty(ctrl.jRadioFreqLog) && ctrl.jRadioFreqLog.isSelected();
    if isFreqBands
        s.Freqs = process_tf_bands('ParseBands', char(ctrl.jTextFreqBands.getText()));
        strFreqs = [];
    elseif isFreqLog
        strFreqs = char(ctrl.jTextFreqLog.getText());
        s.Freqs = GetLogFreq(strFreqs);
    elseif ~isempty(ctrl.jTextFreqLinear) && ctrl.jRadioFreqLinear.isSelected()
        strFreqs = char(ctrl.jTextFreqLinear.getText());
        warning on
        try
            s.Freqs = eval(strFreqs);
        catch
            s.Freqs = [];
        end
        warning off;
    else
        s.Freqs = [];
        strFreqs = [];
    end
    % Get wavelet options
    if ~isempty(ctrl.jTextFc)
        s.MorletFc     = str2num(char(ctrl.jTextFc.getText()));
        s.MorletFwhmTc = str2num(char(ctrl.jTextTr.getText()));
    end
    % Get time to apply cluster function
    if ~isempty(ctrl.jRadioClustBefore)
        if ctrl.jRadioClustBefore.isSelected()
            s.ClusterFuncTime = 'before';
        elseif ctrl.jRadioClustAfter.isSelected()
            s.ClusterFuncTime = 'after';
        end
    else
        s.ClusterFuncTime = 'none';
    end
    % Get measure
    if ~isempty(ctrl.jRadioMeasNon)
        if ctrl.jRadioMeasNon.isSelected()
            s.Measure = 'none';
        elseif ctrl.jRadioMeasMag.isSelected()
            s.Measure = 'magnitude';
        elseif ctrl.jRadioMeasPow.isSelected()
            s.Measure = 'power';
        end
    else
        s.Measure = 'power';
    end
    % Get output type
    if ~isempty(ctrl.jRadioOutAvg)
        if ctrl.jRadioOutAll.isSelected()
            s.Output = 'all';
        elseif ctrl.jRadioOutAvg.isSelected()
            s.Output = 'average';
        end
    else
        s.Output = 'all';
    end
    % Remove evoked response
    if ~isempty(ctrl.jCheckEvoked)
        s.RemoveEvoked = ctrl.jCheckEvoked.isSelected();
    end
    % Save kernel mode
    if ~isempty(ctrl.jRadioKernelYes)
        s.SaveKernel = ctrl.jRadioKernelYes.isSelected();
    else
        s.SaveKernel = 0;
    end
    
    % === SAVE OPTIONS ===
    TimefreqOptions = bst_get(['TimefreqOptions_', ctrl.Method]);
    % Time
    TimefreqOptions.isTimeBands = isTimeBands;
    if iscell(s.TimeBands)
        TimefreqOptions.TimeBands = s.TimeBands;
    end
    % Freqs
    TimefreqOptions.isFreqBands = isFreqBands;
    TimefreqOptions.isFreqLog   = isFreqLog;
    if isFreqBands
        TimefreqOptions.FreqBands = s.Freqs;
    elseif isFreqLog
        TimefreqOptions.FreqsLog = strFreqs;
    else
        TimefreqOptions.Freqs = strFreqs;
    end
    % Measure
    TimefreqOptions.Measure = s.Measure;
    TimefreqOptions.ClusterFuncTime = s.ClusterFuncTime;
    % Output options
    if ~isempty(ctrl.jRadioOutAvg)
        TimefreqOptions.Output = s.Output;
    end
    if ~isempty(ctrl.jRadioKernelYes)
        TimefreqOptions.SaveKernel = s.SaveKernel;
    end
    if ~isempty(ctrl.jCheckEvoked)
        TimefreqOptions.RemoveEvoked = s.RemoveEvoked;
    end
    % Morlet options
    if ~isempty(ctrl.jTextFc)
        TimefreqOptions.MorletFc     = s.MorletFc;
        TimefreqOptions.MorletFwhmTc = s.MorletFwhmTc;
    end
    % Other options
    bst_set(['TimefreqOptions_', ctrl.Method], TimefreqOptions);
end


%% ===== GET FREQUENCY VECTOR IN LOG SCALE =====
% String: "start:N:stop"
function Freqs = GetLogFreq(strFreq)
    Freqs = 0;
    % Split around ":"
    strSplit = str_split(strFreq, ':');
    if (length(strSplit) ~= 3)
        return;
    end
    % Get three values
    start = str2num(strSplit{1});
    nval  = str2num(strSplit{2});
    stop  = str2num(strSplit{3});
    if (length(start) ~= 1) || (length(nval) ~= 1) || (length(stop) ~= 1)
        return;
    end
    % Log-vector
    Freqs = (logspace(0, 1, nval) - 1) ./ 9 * (stop-start) + start;
    % Round the vector
    Freqs = unique(round(Freqs .* 10) ./ 10);
end

