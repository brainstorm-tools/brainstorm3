function varargout = panel_opticalflow( varargin )
% PANEL_OPTICALFLOW: 

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
% Authors: Syed Ashrafulla, 2010-2013

eval(macro_method);
end

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(TimeVector) %#ok<DEFNU>
    % CREATE_PANEL Setup Java panel for calculating optical flow
    % INPUTS:
    %   TimeVector    - Vector of times in reconstructed map, used to
    %                   automatically correct window chosen by user
    % OUTPUTS:
    %   bstPanelNew   - handle to panel figure
    %   panelName     - name of panel for registration into BrainStorm
    panelName = 'OpticalFlow';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Constants
    DEFAULT_HEIGHT = 20;
    TEXT_WIDTH     = 50;

    % Create tool panel
    jPanelNew = gui_river([4,4], [14,5,0,10]);

    % ==== PANEL: SETUP (Horn-Schunck + HHD) ====
    jPanelSetup = gui_river([1,2], [5,15,15,10], 'Setup');

    % Horn-Schunck parameter (label)
    jLabelHornSchunck = JLabel('Horn-Schunck: ');
    jPanelSetup.add('br', jLabelHornSchunck);
    % Horn-Schunck parameter (Text)
    jTextHornSchunck = JTextField(num2str(0.01));
    jTextHornSchunck.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextHornSchunck.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
    jPanelSetup.add('tab', jTextHornSchunck);

    % Calculate HHD as well as optical flow
    jCheckHHD = JCheckBox('Calculate HHD', 0);
    jCheckHHD.setEnabled(false); % ======>>>>> RIGHT NOW, HHD IS NOT ENABLED
    java_setcb(jCheckHHD, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
    jPanelSetup.add('br', jCheckHHD);

    % Recursive Depth of HHD (label)
    jLabelRecursiveDepth = JLabel('Recursive Depth: ');
    jLabelRecursiveDepth.setEnabled(false); % Initially, no HHD
    jPanelSetup.add('br', jLabelRecursiveDepth);
    % Recursive Depth of HHD (Text)
    jTextRecursiveDepth = JTextField(num2str(2));
    jTextRecursiveDepth.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextRecursiveDepth.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
    jTextRecursiveDepth.setEnabled(false); % Initially, no HHD
    jPanelSetup.add('tab', jTextRecursiveDepth);

    jPanelNew.add('br hfill', jPanelSetup); % Add to main panel (jPanelNew) //

    % ==== PANEL: OPTIONS ====
    jPanelOptions = gui_river([1,2], [5,15,15,10], 'Setup');

    % Show optical flow after calculating
    jCheckVisualize = JCheckBox('Show results', 1);
    jPanelOptions.add('br hfill', jCheckVisualize);

    % Rotate normals of vertex to radius, so flows may fall in line better
    jCheckRotate = JCheckBox('Include inflated-sphere results', 0);
    jPanelOptions.add('br hfill', jCheckRotate);

    jPanelNew.add('br hfill', jPanelOptions); % Add to main panel (jPanelNew) //

    % ==== PANEL: OPTIONS ====
    jPanelStates = gui_river([1,2], [5,15,15,10], 'Flow States');

    % Include microstate results
    jCheckStates = JCheckBox('Calculate stable/transition states', 0);
    java_setcb(jCheckStates, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
    jPanelStates.add('br hfill', jCheckStates);

    % Publish microstate results
    jCheckPublish = JCheckBox('Print stable/transition states', 0);
    jCheckPublish.setEnabled(false);
    jPanelStates.add('br hfill', jCheckPublish);

    % Only calculate microstates
    jCheckStatesOnly = JCheckBox('Only calculate microstates', 0);
    java_setcb(jCheckStatesOnly, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
    jPanelStates.add('br hfill', jCheckStatesOnly);

    jPanelNew.add('br hfill', jPanelStates); % Add to main panel (jPanelNew) //

    % ==== PANEL: TIME INTERVAL ====
    jPanelTime = gui_river([1,1], [0,6,6,6], 'Interval');
    jPanelTime.add('p', JLabel('Start: '));
    jTextTimeStart = JTextField(''); % Flow: Time START
    jTextTimeStart.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextTimeStart.setHorizontalAlignment(JTextField.RIGHT);
    jPanelTime.add('tab', jTextTimeStart);

    jPanelTime.add(JLabel('    End: '));
    jTextTimeStop = JTextField(''); % Flow: Time STOP
    jTextTimeStop.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextTimeStop.setHorizontalAlignment(JTextField.RIGHT);
    jPanelTime.add(jTextTimeStop);

    % Set time controls callbacks
    TimeUnit = gui_validate_text(jTextTimeStart, [], jTextTimeStop, TimeVector, 'time', [], TimeVector(1),   []);
    TimeUnit = gui_validate_text(jTextTimeStop, jTextTimeStart, [], TimeVector, 'time', [], TimeVector(end), []);
    jLabelTimeUnit = JLabel(TimeUnit); % Display time unit
    jPanelTime.add(jLabelTimeUnit);

    jPanelNew.add('br hfill', jPanelTime); % Add to main panel (jPanelNew) //

    % Separator
    jPanelNew.add('br', JLabel(' '));

    % ===== VALIDATION BUTTONS =====
    jButtonCancel = JButton('Cancel'); % Cancel button
    java_setcb(jButtonCancel, 'ActionPerformedCallback', @ButtonCancel_Callback);
    jPanelNew.add('right', jButtonCancel);

    jButtonRun = JButton('Run'); % Run button
    java_setcb(jButtonRun, 'ActionPerformedCallback', @ButtonRun_Callback);
    jPanelNew.add(jButtonRun);

    jPanelNew.add('br',JLabel(' '));  % Add to main panel (jPanelNew) //

    % Insert panel in a scroll panel
    jScrollPanelNew = JScrollPane(jPanelNew);
    jScrollPanelNew.setBorder([]);

    % ===== PANEL CREATION =====
    % Controls list
    ctrl = struct('jScrollPanelTop',     jScrollPanelNew, ...
        'jPanelTop',           jPanelNew, ...
        ... ==== OPTICAL FLOW SETUP ====
        'jPanelSetup',         jPanelSetup, ...
        'jTextHornSchunck',    jTextHornSchunck, ...
        'jCheckHHD',           jCheckHHD, ...
        'jLabelRecursiveDepth',jLabelRecursiveDepth, ...
        'jTextRecursiveDepth', jTextRecursiveDepth, ...
        ... ==== OPTIONS ====
        'jPanelOptions',       jPanelOptions, ...
        'jCheckVisualize',     jCheckVisualize, ...
        'jCheckRotate',        jCheckRotate, ...
        ... ==== STABLE/TRANSIENT STATES ====
        'jCheckStates',        jCheckStates, ...
        'jCheckPublish',       jCheckPublish, ...
        'jCheckStatesOnly',    jCheckStatesOnly, ...
        ... ==== TIME INTERVAL PANEL =====
        'jPanelTime',          jPanelTime, ...
        'jTextTimeStart',      jTextTimeStart, ...
        'jTextTimeStop',       jTextTimeStop, ...
        'jLabelTimeUnit',      jLabelTimeUnit,  ...
        ... ==== Validation ====
        'jButtonRun',          jButtonRun, ...
        'jButtonCancel',       jButtonCancel);
    bst_mutex('create', panelName); % Return a mutex to wait for panel close
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl); % Form panel
    UpdatePanel(); % Update panel

%% ======================================================================
% === INTERNAL CALLBACKS ================================================
% =======================================================================

%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(varargin)
        gui_hide(panelName); % Close panel
        bst_mutex('release', panelName); % Release the MUTEX
    end

%% ===== RUN BUTTON =====
    function ButtonRun_Callback(varargin)
        bst_mutex('release', panelName); % Release the MUTEX
    end

%% ===== UPDATE HHD =====
    function UpdatePanel()
        isDepth = jCheckHHD.isSelected(); % Does the user want HHD?
        jLabelRecursiveDepth.setEnabled(isDepth); % If so, allow them to ...
        jTextRecursiveDepth.setEnabled(isDepth); % choose recursive depth.
        
        isStates = jCheckStates.isSelected(); % Does the user want microstates?
        jCheckPublish.setEnabled(isStates); % If so, allow them to publish results
        jCheckStatesOnly.setEnabled(isStates); % If so, allow them to do states only
        
        isStatesOnly = jCheckStatesOnly.isSelected(); % Does user already have flow?
        jCheckRotate.setEnabled(~(isStates && isStatesOnly)); % If so, no rotation necessary
        jTextTimeStart.setEnabled(~(isStates && isStatesOnly)); % If so, no time start necessary
        jTextTimeStop.setEnabled(~(isStates && isStatesOnly)); % If so, no time end necessary
        jLabelHornSchunck.setEnabled(~(isStates && isStatesOnly)); % If so, no Horn-Schunk parameter label necessary
        jTextHornSchunck.setEnabled(~(isStates && isStatesOnly)); % If so, no Horn-Schunk parameter necessary
        
    end

end

%% ===== PROCESS PANEL INPUTS =====
function inputs = GetPanelContents() %#ok<DEFNU>
    % GETPANELCONTENTS Get inputs from panel to send to computation
    %
    % INPUTS:
    %   inputs              - structure containing all the inputs from the GUI
    %     .hornSchunck      - regularization parameter
    %     .HHDAvailable     - whether user wants HHD
    %     .depthHHD         - if user wants HHD, recursive depth
    %     .showResults      - immediately show optical flow overlaid after
    %                         computation
    %     .rotate           - calculate flow after normals to vertices are
    %                         rotated to point towards the center of the brain
    %     .segment          - calculate states of stable and fast flow
    %     .publishStates    - if states calculated, whether user wants to
    %                         publish states to PDF, etc.
    %     .tStart           - first time point to calculate optical flow
    %     .tEnd             - last time point to calculate optical flow
    ctrl = bst_get('PanelControls', 'OpticalFlow');

    % Horn-Schunck regularization parameter
    inputs.hornSchunck = str2double(char(ctrl.jTextHornSchunck.getText()));

    % HHD choice & amount of recursive depth
    if ctrl.jCheckHHD.isSelected
        inputs.HHDAvailable = true;
        inputs.depthHHD = str2double(char(ctrl.jTextRecursiveDepth.getText()));
    else
        inputs.HHDAvailable = false;
        inputs.depthHHD = -1;
    end

    % Options (show results, rotate results, overwrite results)
    inputs.showResults = ctrl.jCheckVisualize.isSelected();
    inputs.rotate = ctrl.jCheckRotate.isSelected();
    inputs.segment = ctrl.jCheckStates.isSelected();
    inputs.publishStates = ctrl.jCheckPublish.isSelected();
    inputs.statesOnly = ctrl.jCheckStatesOnly.isSelected();
    TimeUnit = char(ctrl.jLabelTimeUnit.getText);
    
    % First time point to calculate optical flow
    inputs.tStart = str2double(char(ctrl.jTextTimeStart.getText()));
    if strcmpi(TimeUnit, 'ms')
        inputs.tStart = inputs.tStart/1000;
    end
    % Last time point to calculate optical flow
    inputs.tEnd = str2double(char(ctrl.jTextTimeStop.getText()));
    if strcmpi(TimeUnit, 'ms')
        inputs.tEnd = inputs.tEnd/1000;
    end
end

%% ===== COMPUTE OPTICAL FLOW =====
function Compute(ResultsFile, inputs) %#ok<DEFNU>
    % COMPUTE       Compute optical flow and save to results
    % INPUTS:
    %   ResultsFile   - filename of results that have activity already
    %                   calculated, so we can add optical flow
    %   inputs        - structure of inputs from GUI or otherwise.
    %                   If otherwise, the structure must have
    %     .hornSchunck      - regularization parameter
    %     .HHDAvailable     - whether user wants HHD
    %     .depthHHD         - if user wants HHD, recursive depth
    %     .showResults      - immediately show optical flow overlaid after
    %                         computation
    %     .rotate           - calculate flow after normals to vertices are
    %                         rotated to point towards the center of the brain
    %     .segment          - calculate states of stable and fast flow
    %     .publishStates    - if states calculated, whether user wants to
    %                         publish states to PDF, etc.
    %     .statesOnly       - if states calculated and flow pre-calculated,
    %                         only calculate and display states.
    %     .overwrite        - overwrite old optical flow results
    %                         otherwise, add a second "result" (for testing
    %                         regularization, etc.)
    %     .tStart           - first time point to calculate optical flow
    %     .tEnd             - last time point to calculate optical flow
    % Read input file
    ResultsMat = in_bst_results(ResultsFile, 1, 'Time', 'SurfaceFile', 'ImageGridAmp');
    Time        = ResultsMat.Time;
    SurfaceFile = ResultsMat.SurfaceFile;
    SamplingInterval = Time(2)-Time(1);
    F = abs(double(ResultsMat.ImageGridAmp));
    clear ResultsMat;

    % Get inputs for optical flow
    if (nargin < 2) % Run GUI to get user inputs
        inputs = gui_show_dialog('Compute optical flow', @panel_opticalflow, 0, [], Time);
        if ~isfield(inputs, 'hornSchunck')% No inputs --> Cancel button was hit
            return
        end
    elseif ~isfield(inputs, 'hornSchunck') || ~isfield(inputs, 'HHDAvailable') ...
            || ~isfield(inputs, 'depthHHD') || ~isfield(inputs, 'showResults') ...
            || ~isfield(inputs, 'rotate') || ~isfield(inputs, 'overwrite') ...
            || ~isfield(inputs, 'tStart') || ~isfield(inputs, 'tEnd')

        bst_error(['Inputs not well-defined, structure must include:\n' ...
            'Horn-Schunck regularization parameter (hornSchunck)\n' ...
            'Desire to calculate HHD (HHDAvailable)\n' ...
            'HHD recursive depth parameter (depthHHD)\n' ...
            'Boolean to show results (showResults)\n' ...
            'Boolean to rotate results (rotate)\n' ...
            'Boolean to overwrite previous results (overwrite)\n' ...
            'First time to calculate optical flow (tStart)\n' ...
            'Last time to calculate optical flow (tEnd)']);
    end

    % Read tesselation
    FV = in_tess_bst(SurfaceFile);

    % Calculate flow
    ResultsMat = in_bst_results(ResultsFile, 1, 'OpticalFlow');
    if isempty(ResultsMat.OpticalFlow) || ~inputs.statesOnly % Calculate flow
        % Evaluate optical flow ...
        [flowField, int_dF, errorData, errorReg, poincare, timeInterval] = ...
            bst_call(@bst_opticalflow, F, FV, Time, ...
            inputs.tStart, inputs.tEnd, inputs.hornSchunck);
        if isfield(inputs, 'depthHHD') %  ... and, optionally, HHD
            % [U A H Vcurl Vdiv index] = ...
            %   HHD(dataFile, FV, Time, inputs.tStart, inputs.tEnd, inputs.depthHHD);
        end

        if inputs.rotate % Rotate flow so that tangent bundle is for circumsphere
            flowFieldRotated = rotate_optical_flow(flowField, FV.Vertices', FV.VertNormals');
        else
            flowFieldRotated = [];
        end

        % Save results into Results file as latest optical flow calculation
        save_flow(ResultsFile, inputs, flowField, flowFieldRotated, ...
            Time, int_dF, errorData, errorReg, poincare);
    else
        flowField = ResultsMat.OpticalFlow.flowField;
        timeInterval = ResultsMat.OpticalFlow.timeInterval;
    end

    % Calculate states
    if inputs.segment
        bst_progress('start', 'Optical Flow', 'Segmenting into stable and transition states ...');

        interval = timeInterval(1) : SamplingInterval : timeInterval(2)+2*eps;
        [stableStates, transientStates, stablePoints, transientPoints, dEnergy] = ...
            bst_opticalflow_states(flowField, FV.Faces, FV.Vertices, 3, interval, SamplingInterval, true);

        % Save states
        Results = in_bst_results(ResultsFile);
        protocol = bst_get('ProtocolInfo');
        Results.OpticalFlow.dEnergy = dEnergy;
        Results.OpticalFlow.microstates = [];
        Results.OpticalFlow.microstates.stableStates = stableStates;
        Results.OpticalFlow.microstates.transientStates = transientStates;
        Results.OpticalFlow.microstates.stablePoints = stablePoints;
        Results.OpticalFlow.microstates.transientPoints = transientPoints;
        bst_save(bst_fullfile(protocol.STUDIES,ResultsFile), Results, 'v6');

        bst_progress('stop');
        if inputs.publishStates
            publish_states(ResultsFile, Results, Time, FV);
        end

    end

    % Show optical flow results on reconstructed map
    if inputs.showResults
        bst_memory('UnloadAll'); % Unload all previous datasets
        bst_call(@view_surface_data, SurfaceFile, ResultsFile);
        panel_time('SetCurrentTime', timeInterval(1)+eps);
    end
end

%% ===== ROTATE OPTICAL FLOW TO INFLATED SPHERE =====
function flowFieldRotated = rotate_optical_flow(flowField, Vertices, VertNormals)
    % ROTATE_OPTICAL_FLOW     Rotate optical flow to preserve angle against
    %                         normal-to-vertex if the normal is rotated
    %                         to point towards the center of the brain.
    %                         Equivalently, rotate optical flow so result
    %                         is as if brain was sphere (for addition of
    %                         flow between neighboring vertices, perhaps.)
    % INPUTS:
    %   flowField           - optical flow at every vertex
    %   Vertices            - locations of vertices
    %   VertNormals         - normals to each vertex
    % OUTPUTS:
    %   flowFieldRotated    - Rotate normals-to-vertex to point to sphere,
    %                         and then rotate optical flow using same
    %                         transformation to get this result
    nVertices = size(Vertices,1);
    centeredVertices = Vertices - repmat(mean(Vertices), nVertices, 1);
    flowFieldRotated = zeros(size(flowField));

    bst_progress('start', 'Optical Flow', ...
        'Rotating flows for visualization ... ', 0, nVertices);
    for m = 1:nVertices
        c = VertNormals(m,:); d = -centeredVertices(m,:);
        current = c/norm(c); desired = d/norm(d);
        perpCurrent = cross(desired,current)/norm(cross(desired,current));
        perpDesired = cross(perpCurrent,desired);
        frameChange = [desired' perpDesired' perpCurrent'];
        rotation = [dot(current,desired) -dot(current,perpDesired) 0; ...
            dot(current,perpDesired) dot(current,desired) 0; ...
            0 0 1];
        transform = (frameChange*rotation)/frameChange;
        flow = squeeze(flowField(m,:,:))';
        flowFieldRotated(m,:,:) = transpose(flow*transform);
        if mod(m,20) == 0
            bst_progress('inc', 20);
        end
    end
    bst_progress('stop');
end

%% ===== SAVE OPTICAL FLOW INTO BRAINSTORM =====
function save_flow(ResultsFile, inputs, flowField, flowFieldRotated, ...
        Time, int_dF, errorData, errorReg, poincare)
    % SAVE_FLOW     Save flow results (and possibly publish microstates)
    % INPUTS:
    %   ResultsFile       - File containing results (and surface file)
    %   inputs            - inputs to error-check whether results are written
    %   flowField         - Optical flow field
    %                       dimension (# of vertices) X length(tStart:tEnd)
    %   flowFieldRotated  - flow field rotated for faux spherical brain
    %   Time              - time when activity was reconstructed (including
    %                       times for which optical flow is not calculated)
    %   int_dF            - Constant term in variational formulation
    %   errorData         - Error in fit to data
    %   errorReg          - Energy in regularization
    %   poincare          - Poincar� index

    opticalFlow.flowField = flowField; % Optical flow results
    opticalFlow.flowFieldRotatedAvailable = inputs.rotate;
    if inputs.rotate % Results with surface normal rotated towards center of boundary's volume
        opticalFlow.flowFieldRotated = flowFieldRotated;
    end
    opticalFlow.timeInterval = [inputs.tStart inputs.tEnd]; % Time interval
    opticalFlow.samplingInterval = Time(2)-Time(1); % Time interval
    opticalFlow.hornSchunck = inputs.hornSchunck; % Regularization
    opticalFlow.int_dF = int_dF;
    opticalFlow.errorData = errorData; % Error in fit to data
    opticalFlow.errorReg = errorReg; % Error from smooth regularization
    opticalFlow.poincare = poincare;
    opticalFlow.HHDAvailable = inputs.HHDAvailable;
    if inputs.HHDAvailable
        opticalFlow.depthHHD = inputs.depthHHD;
    end

    % Save optical flow results in original results file
    Results = in_bst_results(ResultsFile);
    if opticalFlow(end).HHDAvailable
        Results = bst_history('add', Results, 'compute', ...
            ['Optical flow estimated: [' int2str(inputs.tStart*1000) ...
            ', ' int2str(inputs.tEnd*1000) ']ms']);
    else
        Results = bst_history('add', Results, 'compute', ...
            ['Optical flow & HHD estimated: [' ...
            int2str(inputs.tStart*1000) ...
            ', ' int2str(inputs.tEnd*1000) ']ms']);
    end
    Results.OpticalFlow = opticalFlow;

    Protocol = bst_get('ProtocolInfo');
    bst_save(bst_fullfile(Protocol.STUDIES, ResultsFile), Results, 'v6');

end

%% ===== PUBLISH STATES OF FLOW =====
function publish_states(ResultsFile, Results, Time, FV)
    % PUBLISH_STATES    Publish states to an output file (PDF, etc.)
    %
    % INPUTS:
    %   ResultsFile         - File containing results (and surface file)
    %   Results             - results structure (so we don't have to re-load it)
    %   Time                - time points of reconstructed data
    %   FV                  - tesselation for plotting

    opticalFlow = Results.OpticalFlow;

    % Get extrema
    tStartIndex = find(Time < opticalFlow.timeInterval(1)-eps, 1, 'last')+1; % Index of first time point for flow calculation
    tEndIndex = find(Time < opticalFlow.timeInterval(2)-eps, 1, 'last')+1; % Index of last time point for flow calculation
    activity = Results.ImageGridAmp(:,tStartIndex:tEndIndex); % Activity in flow-calculated interval
    extrema = sortrows([ ...
        opticalFlow.microstates.stableStates zeros(length(opticalFlow.microstates.stableStates), 1); ...
        opticalFlow.microstates.transientStates ones(length(opticalFlow.microstates.transientStates),1) ...
        ]); % Sort extrema for timeline visual

    % Setup data for visualization
    [opticalFlowDir, iDS, FigureId] = ...
        publish_setup(ResultsFile, Results.Options.DataTypes);
    if isempty(opticalFlowDir) || ~ischar(opticalFlowDir) % Cancel button!
        return
    end
    if ispc && opticalFlowDir(end) ~= '\'
        opticalFlowDir(end+1) = '\';
    elseif opticalFlowDir(end) ~= '/'
        opticalFlowDir(end+1) = '/';
    end

    % Pre-assigned inputs for demonstration
    viewChoice = [-1.5 0.5 1]; zoomIn = 2;
    bst_progress('start', 'Optical Flow', ['Saving images of states to ...' opticalFlowDir], 0, length(extrema));
    for m = 1:length(extrema)


        if extrema(m,3) > 1-eps % Transition state
            opticalFlowTag = ['transient_' ...
                sprintf('%0.2d', sum(extrema(1:m,3) > 1-eps)) '_' ...
                sprintf('%0.3d', round(Time(extrema(m,1) + tStartIndex - 1)*1000)) 'ms_to_' ...
                sprintf('%0.3d', round(Time(extrema(m,2) + tStartIndex - 1)*1000)) 'ms'];
        else % Stable state
            opticalFlowTag = ['stable_' ...
                sprintf('%0.2d', sum(extrema(1:m,3) > 1-eps)) '_' ...
                sprintf('%0.3d', round(Time(extrema(m,1) + tStartIndex - 1)*1000)) 'ms_to_' ...
                sprintf('%0.3d', round(Time(extrema(m,2) + tStartIndex - 1)*1000)) 'ms'];
        end
        bst_progress('text', ['Writing: ' opticalFlowTag]); % inform user

        % Initialize figure
        [hState, iSurfaceState] = ...
            publish_initialize(iDS, FigureId, ResultsFile, ...
            Results.SurfaceFile, max(abs(activity(:))), viewChoice);
        set(hState, 'PaperPositionMode', 'auto');

        % Plot figure
        if extrema(m,3) > 1-eps % Transition state
            publish_transient(hState, FV.Vertices, opticalFlow, extrema(m,1), zoomIn);
        else % Stable state
            publish_stable(hState, iSurfaceState, activity(:, extrema(m,1):extrema(m,2)));
        end

        % Save and close figure
        print(hState, '-dpng', '-r300', [opticalFlowDir opticalFlowTag]);
        if m < length(extrema)
            bst_figures('DeleteFigure', hState, 'NoUnload') % Delete figure
        else
            bst_figures('DeleteFigure', hState) % Delete figure and unload dataset
        end

        bst_progress('inc', 1); % Update waitbar
    end

    bst_progress('stop'); % Finish waitbar
end

function [opticalFlowDir, iDS, FigureId] = publish_setup(ResultsFile, DataTypes)
    % PUBLISH_SETUP   Setup for publishing stable and transition states
    % INPUTS:
    %   ResultsFile   - filename of reconstructed source signals
    %   DataTypes     - list of data types in results
    % OUTPUTS:
    %   iDS           - index of results in BrainStorm
    %   FigureId      - ID for figure

    bst_memory('UnloadAll'); % Unload all previous datasets

    % Select folder to drop images off
    protocol = bst_get('ProtocolInfo');
    if isempty(strfind(ResultsFile, '/'))
        defaultDir = [protocol.STUDIES '\' ResultsFile(1:(find(ResultsFile == '\', 1, 'last')))];
    else
        defaultDir = [protocol.STUDIES '/' ResultsFile(1:(find(ResultsFile == '/', 1, 'last')))];
    end
    opticalFlowDir = uigetdir(defaultDir, ... % Open 'Select directory' dialog
        'Please select directory to save state maps (default = location of results)');
    if isempty(opticalFlowDir) || ~ischar(opticalFlowDir)
        iDS = -1;
        FigureId = -1;
        return
    end

    iDS = bst_memory('LoadResultsFile', ResultsFile); % Dataset index

    % Modality for classifying figure
    AllModalities = DataTypes;
    if all(ismember({'MEG GRAD', 'MEG MAG'}, AllModalities))
        AllModalities{end+1} = 'MEG';
        AllModalities = setdiff(AllModalities, {'MEG GRAD', 'MEG MAG'});
    end
    Modality = AllModalities{1};

    % Create figure ID setup
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = Modality;
end

function [hState, iSurfaceState] = publish_initialize(iDS, FigureId, ResultsFile, SurfaceFile, DataMinMax, viewChoice)
    % PUBLISH_INITIALIZE    Figure w/ surface for plotting flows or activities
    % INPUTS:
    %   DataTypes     - list of data types in results
    %   iDS           - index of results in BrainStorm
    %   FigureId      - ID for figure
    %   ResultsFile   - filename of reconstructed source signals
    %   SurfaceFile   - filename of surface to plot results on
    %   DataMinMax    - maximum of magnitude of activity for colorbar
    %   viewChoice    - angle to view surface
    % OUTPUTS:
    %   hState          - Figure containing surface to plot flows on
    %   iSurfaceState   - index of surface for sulci, etc.

    % Create and initialize figure with surface
    hState = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    iSurfaceState = panel_surface('AddSurface', hState, SurfaceFile); % Results.SurfaceFile
    setappdata(hState, 'ResultsFile', ResultsFile);

    % Add colormap for the colorbar
    TessInfo = getappdata(hState, 'Surface');
    TessInfo(iSurfaceState).DataMinMax = DataMinMax; % max(abs(activity(:)));
    TessInfo(iSurfaceState).ColormapType = 'source';
    TessInfo(iSurfaceState).SurfSmoothValue = 1; % Completely smoothed surface
    TessInfo(iSurfaceState).SurfShowSulci = true; % Show sulci
    bst_colormaps('AddColormapToFigure', hState, TessInfo(iSurfaceState).ColormapType);

    % Set view just like in BrainStorm (ish)
    hAxes = findobj(hState, '-depth', 1, 'Tag', 'Axes3D'); % Get Axes handle
    view(hAxes, viewChoice); % Update view
    if abs(viewChoice(3)) > abs(viewChoice(2)) + abs(viewChoice(1))
        camup(hAxes, [1 0 0]); % Update camera position for bottom/top
    else
        camup(hAxes, [0 0 1]); % Update camera position for others
    end
    camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight'); % Update head light position
end

function publish_transient(hState, Vertices, opticalFlow, start, zoomIn)
    % PUBLISH_TRANSIENT   Show flows in transient state
    % INPUTS:
    %   hState          - Figure containing surface to plot flows on
    %   iSurfaceState   - index of surface for sulci, etc.
    %   Vertices        - locations of vertices in tesselation
    %   opticalFlow     - flow results
    %   start           - flow at start of state

    % Hold axes to plot on top of surface
    hAxes = findobj(hState, '-depth', 1, 'Tag', 'Axes3D'); % Get Axes handle
    hold(hAxes,'on');
    flowField = opticalFlow.flowField(:,:,start);
    useful = sum(flowField.^2, 2) > max(sum(flowField.^2, 2))*0.1;
    flowField(~useful,:) = 0;
    quiver3(hAxes, ...
        Vertices(:,1), Vertices(:,2), Vertices(:,3), ...
        flowField(:,1), flowField(:,2), flowField(:,3), ...
        6, 'c', 'LineWidth', 2);
    hold(hAxes,'off');

    zoom(zoomIn); % Zoom in plz!

    % % Title of state
    % tagLocation = [mean(FV.Vertices(:,1))-0.025 max(FV.Vertices(:,2))+0.01 mean(FV.Vertices(:,3))-0.03];
    % text(tagLocation(1), tagLocation(2), tagLocation(3), 'TRANSIENT STATE', 'fontsize', 24, 'color', [1 0 0])

end

function publish_stable(hState, iSurfaceState, activity)
    % PUBLISH_STABLE      Show mean activity in stable state
    % INPUTS:
    %   hState          - Figure containing surface to plot flows on
    %   iSurfaceState   - index of surface for sulci, etc.
    %   activity        - reconstructed activity in state
    %   DataMinMax      - maximum of colorbar (as used in initialization)

    % Add overlay of mean activity
    TessInfo = getappdata(hState, 'Surface');
    TessInfo(iSurfaceState).Data = mean(abs(activity), 2); % Plot mean activity
    TessInfo(iSurfaceState).DataMinMax = max(TessInfo(iSurfaceState).Data);
    TessInfo(iSurfaceState).DataLimitValue = [0 TessInfo(iSurfaceState).DataMinMax];
    setappdata(hState, 'Surface', TessInfo);

    % Set maximum value of activity
    hAxes = [findobj(hState, '-depth', 1, 'Tag', 'Axes3D'), ...
        findobj(hState, '-depth', 1, 'Tag', 'axc'), ...
        findobj(hState, '-depth', 1, 'Tag', 'axa'), ...
        findobj(hState, '-depth', 1, 'Tag', 'axs')]; % Figure axes
    set(hAxes, 'CLim', TessInfo(iSurfaceState).DataLimitValue);

    % Add colorbar
    ColormapInfo = getappdata(hState, 'Colormap'); % Default colormap
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type); % Get figure colormap
    set(hState, 'Colormap', sColormap.CMap); % Set figure colormap
    bst_colormaps('SetColorbarVisible', hState, sColormap.DisplayColorbar); % Create/Delete colorbar
    bst_colormaps('ConfigureColorbar', hState, ColormapInfo.Type, 'opticalflow', ColormapInfo.DisplayUnits); % Display only one colorbar (preferentially the results colorbar)

    % Reveal plot!
    figure_3d('UpdateSurfaceColor', hState, iSurfaceState);

    % % Title of state
    % tagLocation = [mean(FV.Vertices(:,1)) mean(FV.Vertices(:,2)) max(FV.Vertices(:,3)) + 0.01];
    % text(tagLocation(1)-0.04, tagLocation(2), tagLocation(3), 'STABLE STATE', 'fontsize', 24, 'color', [0 1 0])
end

%% ===== PLOT OPTICAL FLOW ON BRAINSTORM CURRENT DENSITY FIGURE =====
function PlotOpticalFlow(hFig, opticalFlow, currentTime, sSurf)
    % PLOTOPTICALFLOW     From BrainStorm figure handler, plot optical flow
    %                     results on top of surface with data
    % INPUTS:
    %   hFig          - handle to current figure
    %   opticalFlow   - optical flow results
    %   currentTime   - time point shown in BrainStorm
    %   sSurf         - surface file (to plot arrows in the right spots)

    % Process figure (removing old flows if necessary + getting surface axes)
    nVertices = size(sSurf.Vertices, 1);
    [ax, currentName] = process_surface(hFig);

    % First check if we need to do anything
    flagPlotFlow = 0;
    for n = 1:length(opticalFlow)
        if currentTime > (opticalFlow(n).timeInterval(1)-(opticalFlow(n).samplingInterval/2)) ...
                && currentTime < (opticalFlow(n).timeInterval(2)+(opticalFlow(n).samplingInterval/2))
            flagPlotFlow = 1;
        end
    end
    if ~flagPlotFlow
        return
    end

    % Add ability to see sphere-rotated results if desired
    if opticalFlow.flowFieldRotatedAvailable
        hRotated = checkbox_rotated(hFig, flagPlotFlow, opticalFlow, currentTime, sSurf);
        plotRotatedResults = get(hRotated, 'Value');
    else
        plotRotatedResults = false;
        hRotated = -1;
    end

    button_movie(hFig, hRotated, ... % Push button to play movie!
        opticalFlow.timeInterval(1) : opticalFlow.samplingInterval : opticalFlow.timeInterval(2)+eps);

    % Plot optical flow in a shell outside the brain for rotated results
    if plotRotatedResults
        meanVertex = repmat(mean(sSurf.Vertices), nVertices, 1);
        centeredVertices = sSurf.Vertices - meanVertex;
        radii = sqrt(sum(centeredVertices.^2, 2));
        maxRadius = max(radii) * 1.1;
        Vertices = centeredVertices ./ repmat(radii, 1, 3) * maxRadius + meanVertex;
    else
        Vertices = sSurf.Vertices + sSurf.VertNormals * 0.005;
    end

    % Get time index
    timeIdx = round((currentTime-opticalFlow.timeInterval(1))/opticalFlow.samplingInterval)+1;
    if timeIdx > size(opticalFlow.flowField, 3)
        return
    end
    
    % Remove old quivers (arrows)
    oldQuivers = findobj(ax, 'Type', 'quiver');
    for iQuiver = 1:length(oldQuivers)
        delete(oldQuivers(iQuiver));
    end

    % Hold axes to plot on top of surface
    hold(ax,'on');
    if plotRotatedResults
        flowField = opticalFlow.flowFieldRotated(:,:,timeIdx);
    else
        flowField = opticalFlow.flowField(:,:,timeIdx);
    end
    useful = sum(flowField.^2, 2) > max(sum(flowField.^2, 2))*0.1;
    flowField(~useful,:) = 0;
    quiver3(ax, ...
        Vertices(:,1), Vertices(:,2), Vertices(:,3), ...
        flowField(:,1), flowField(:,2), flowField(:,3), ...
        6, 'c', 'LineWidth', 2); % Color is cyan, works well with hot colormap
    hold(ax,'off');

    % Modify figure name if we are in stable/transient state
    if isfield(opticalFlow, 'microstates')
        stablePoints = opticalFlow.microstates.stablePoints;
        transientPoints = opticalFlow.microstates.transientPoints;
        if find(abs(stablePoints-timeIdx) <= eps)
            currentName = ['STABLE: ' currentName];
        elseif find(abs(transientPoints-timeIdx) <= eps)
            currentName = ['TRANSIENT: ' currentName];
        end
    end
    set(hFig, 'Name', currentName); % Set figure name to microstate label

end

%% ===== PROCESS SURFACE AND CLEAN PREVIOUS FLOWS =====
function [ax, currentName] = process_surface(hFig)
    % PROCESS_SURFACE     Clean surface:
    %                     * get rid of old results
    %                     * get rid of old state results in name of figure
    %                     * get axis handle for surface so we can overlay
    %                       optical flow results
    % INPUTS:
    %   hFig          - handle to figure containing activity
    % OUTPUTS:
    %   ax            - axis containing surface (for plotting flow)
    %   currentName   - name on title of figure
    
    % Get axis handle for surface
    axes = get(hFig, 'children');
    ax = [];
    for n = 1:length(axes)
        if isprop(axes(n), 'CLim')
            cLim = get(axes(n), 'CLim');
            if cLim(1) ~= 1 || cLim(2) ~= 256
                ax = axes(n);
                break;
            end
        end
    end

    % Clean off previous vector fields
    if ~isempty(ax)
        hOld = get(ax, 'Children');
        for n = 1:length(hOld)
            if strcmp(get(hOld(n), 'Type'), 'hggroup') % hggroup is type name for quiver plot
                delete(hOld(n));
            end
        end
    end

    % Clean off stable/transient labeling
    currentName = get(hFig, 'Name');
    if strfind(currentName, 'STABLE: ')
        currentName(strfind(currentName, 'STABLE: ') + (0:7)) = [];
    elseif strfind(currentName, 'TRANSIENT: ')
        currentName(strfind(currentName, 'TRANSIENT: ') + (0:10)) = [];
    end

end

%% ===== MOVIE FOR ITERATING THROUGH FLOWS =====
function hMovieButton = button_movie(hFig, hRotated, flowInterval)
    % BUTTON_MOVIE    Play a loop of flow within some part of interval
    % INPUTS:
    %   hFig          - Figure containing reconstructions and flows
    %   hRotated      - Handle to rotated-flows checkbox for repositioning
    %   flowInterval  - interval over which flow has been calculated
    % OUTPUTS:
    %   hMovieButton  - Handle to button for Movie? or Stop Movie

    % Find if button already exists on figure
    hMovieButton = -1;
    figureParts = get(hFig, 'children');
    for m = 1:length(figureParts)
        if strcmp(get(figureParts(m),'Type'), 'uicontrol') && ...
                strcmp(get(figureParts(m),'Tag'), 'MovieButton')
            hMovieButton = figureParts(m);
        end
    end

    % Make new button if necessary
    if hMovieButton < 0
        hMovieButton = uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Movie?', ...
            'Position', [20 10 70 20], 'Tag', 'MovieButton', ...
            'Callback', {@ButtonMovie_Callback, hFig, flowInterval, hRotated});
    end

    function ButtonMovie_Callback(hMovieButton, ev, hFig, flowInterval, hRotated)
        % BUTTONMOVIE_CALLBACK  Callback function to the movie button
        %
        % INPUTS:
        %   hMovieButton  - Handle to button
        %   event         - ~
        %   hFig          - Handle to figure showing reconstructions and flows
        %   flowInterval  - interval over which flow has been calculated
        %   hRotated      - Handle to rotated-flows checkbox for repositioning
        
        if strcmp(get(hMovieButton, 'String'), 'Movie?') % Start movie controls
            
            set(hMovieButton,  'String', 'Stop Movie'); % Change button to stop movie
            set(hMovieButton, 'Value', 1); % HACK ALERT: current time index stored here
            halt_others(hFig); % Disallow all other figures from trying to play a movie
            
            if hRotated > -1 % If rotated-flows checkbox available, shift it to the right
                set(hRotated, 'Position', [370 10 130 20]);
            end
            
            % Start and end of movie loop
            hMovieStart = uicontrol(hFig, 'Style', 'edit', ...
                'String', 'Start', ...
                'Position', [100 10 60 20], ...
                'Tag', 'MovieStart', ...
                'BackgroundColor', [1 1 1], ...
                'HorizontalAlignment', 'right', ...
                'Callback', {@validate_time, flowInterval});
            uicontrol(hFig, 'Style', 'text', 'String', 'ms', 'Tag', 'TextMovieStart', 'Position', [165 10 20 20]);
            hMovieEnd = uicontrol(hFig, 'Style', 'edit', ...
                'String', 'End', ...
                'Position', [190 10 60 20], ...
                'Tag', 'MovieEnd', ...
                'BackgroundColor', [1 1 1], ...
                'HorizontalAlignment', 'right', ...
                'Callback', {@validate_time, flowInterval});
            uicontrol(hFig, 'Style', 'text', 'String', 'ms', 'Tag', 'TextMovieEnd', 'Position', [255 10 20 20]);
            
            % Movie controls: play and pause
            hMoviePlay = uicontrol(hFig, 'Style', 'pushbutton', ...
                'String', 'Play', ... % BOO NO PLAY BUTTON YOU SUCK MATLAB
                'Tag', 'MoviePlay', ...
                'Position', [280 10 40 20]);
            hMoviePause = uicontrol(hFig, 'Style', 'pushbutton', ...
                'String', 'Pause', ... % BOO NO PAUSE BUTTON YOU SUCK MATLAB
                'Tag', 'MoviePause', ...
                'Position', [325 10 40 20], ...
                'Enable', 'off');
            set(hMoviePlay, 'Callback', ...
                {@ButtonMoviePlay_Callback, hMovieButton, hMoviePause, ...
                hMovieStart, hMovieEnd, flowInterval(2)-flowInterval(1)});
            set(hMoviePause, 'Callback', {@ButtonMoviePause_Callback, hMoviePlay});
            
        else % Stop movie
            set(hMovieButton, 'FontName', 'arial', 'String', 'Movie?'); % Change label to play movie
            
            % Clean everything
            figureParts = get(hFig, 'children');
            for n = 1:length(figureParts)
                if strcmp(get(figureParts(n),'Type'), 'uicontrol') && ...
                        (strcmp(get(figureParts(n),'Tag'), 'MovieStart') || ...
                        strcmp(get(figureParts(n),'Tag'), 'TextMovieStart') || ...
                        strcmp(get(figureParts(n),'Tag'), 'MovieEnd') || ...
                        strcmp(get(figureParts(n),'Tag'), 'TextMovieEnd') || ...
                        strcmp(get(figureParts(n),'Tag'), 'MoviePlay') || ...
                        strcmp(get(figureParts(n),'Tag'), 'MoviePause'))
                    delete(figureParts(n));
                end
            end
            
            allow_others(hFig); % Allow other figures to start movie
            
            if hRotated > -1 % Move rotated-flows checkbox back
                set(hRotated, 'Position', [100 10 130 20]);
            end
            
            % Set current time back to first time of flow
            panel_time('SetCurrentTime', flowInterval(1)+eps);
        end
        
        
        
    end

    function validate_time(hText, ev, interval)
        % VALIDATE_TIME   Check if time asked for by user is legitimately in
        %                 interval for which flow is calculated, and correct
        %                 if necessary
        %
        % INPUTS:
        %   hText     - handle containing text element for verificatino
        %   event     - ~
        %   interval  - hText must be an element in interval
        
        chosen = str2double(get(hText, 'String'))/1000; % Get time
        if isnan(chosen) % NaN -> bad input -> go back to default
            if strcmp(get(hText,'Tag'), 'MovieStart')
                chosen = interval(1);
            elseif strcmp(get(hText,'Tag'), 'MovieEnd')
                chosen = interval(end);
            end
        else
            [tmp,idx] = min(abs(interval-chosen)); % Find closest time point ...
            chosen = interval(idx); % ... and use that as updated value
        end
        set(hText, 'String', sprintf('%0.2f', chosen*1000)); % Show user update
    end

    function ButtonMoviePlay_Callback(hMoviePlay, ev, ...
            hMovieButton, hMoviePause, hMovieStart, hMovieEnd, movieStep)
        set(hMoviePlay, 'Enable', 'off'); % Can't play twice
        set(hMoviePause, 'Enable', 'on'); % Allow pausing
        flowInterval = ... % Interval of times that will be looping
            str2double(get(hMovieStart,'String'))/1000 : ... % Start here
            movieStep : ... % Go this fast
            (str2double(get(hMovieEnd,'String'))/1000)+2*eps; % End here
        
        while ishandle(hMoviePause) && strcmp(get(hMoviePause, 'Enable'), 'on') % Pause only when pause button is enabled
            
            currentTimeIdx = get(hMovieButton, 'Value'); % HACK ALERT: current time index stored here
            if currentTimeIdx == 0
                currentTimeIdx = 1; % Correction for first time (sometimes)
            end
            panel_time('SetCurrentTime', flowInterval(currentTimeIdx)); % Update
            drawnow; pause(0.5); % 120fps
            currentTimeIdx = currentTimeIdx+1; % Advance
            if currentTimeIdx > length(flowInterval) % Wrap around for loop
                currentTimeIdx = 1;
            end
            
            if ishandle(hMovieButton)
                set(hMovieButton, 'Value', currentTimeIdx); % HACK ALERT: current time index stored here after pausing
            end
        end
        
    end

    function ButtonMoviePause_Callback(hMoviePause,ev,hMoviePlay)
        % BUTTONMOUSEPAUSE_CALLBACK   Pauses looping of flows
        %
        % INPUTS
        %   hMoviePlay    - Button for playing it. Enable it so user can
        %                   continue as desired
        %   hMoviePause   - Button for pausing. Disable it to pause loop
        set(hMoviePlay, 'Enable', 'on');
        set(hMoviePause, 'Enable', 'off');
    end

    function halt_others(hFig)
        % HALT_OTHERS   Prevent other figures from trying to play a movie
        %
        % INPUTS:
        %   hFig  - Figure whose movie controls should NOT be touched
        h = findall(0, 'Type', 'figure'); % All figures
        h = setdiff(h, hFig); % Do not touch hFig!
        for o = 1:length(h)
            if ~strcmp(get(h(o), 'Tag'), '3DViz') % Not a reconstruction
                continue
            end
            
            figureParts = get(h(o), 'children');
            for p = 1:length(figureParts) % Delete all movie controls
                if strcmp(get(figureParts(p),'Type'), 'uicontrol') && ...
                        (strcmp(get(figureParts(p),'Tag'), 'MovieStart') || ...
                        strcmp(get(figureParts(p),'Tag'), 'TextMovieStart') || ...
                        strcmp(get(figureParts(p),'Tag'), 'MovieEnd') || ...
                        strcmp(get(figureParts(p),'Tag'), 'TextMovieEnd') || ...
                        strcmp(get(figureParts(p),'Tag'), 'MoviePlay') || ...
                        strcmp(get(figureParts(p),'Tag'), 'MoviePause'))
                    delete(figureParts(n));
                elseif strcmp(get(figureParts(p),'Type'), 'uicontrol') && ...
                        (strcmp(get(figureParts(p),'Tag'), 'MovieButton'))
                    set(figureParts(p), 'Enable', 'off'); % Disable movie button
                end
            end
            
        end
        
    end

    function allow_others(hFig)
        % ALLOW_OTHERS   Turn on all other movie buttons (when movie is stopped)
        %
        % INPUTS:
        %   hFig  - Figure whose movie controls should NOT be touched
        
        h = findall(0, 'Type', 'figure'); % All figures ...
        h = setdiff(h, hFig); % ... except the one that just stopped
        for o = 1:length(h)
            if ~strcmp(get(h(o), 'Tag'), '3DViz') % Not a reconstruction
                continue
            end
            
            figureParts = get(h(o), 'children');
            for p = 1:length(figureParts) % Enable all movie buttons
                if strcmp(get(figureParts(p),'Type'), 'uicontrol') && ...
                        (strcmp(get(figureParts(p),'Tag'), 'MovieButton'))
                    set(figureParts(p), 'Enable', 'on');
                end
            end
            
        end
    end

end

%% ===== CHECKBOX FOR PLOTTING FLOWS ON SPHERE OR SURFACE =====
function hRotated = checkbox_rotated(hFig, flagPlotFlow, opticalFlow, currentTime, sSurf)
    % CHECKBOX_ROTATED  Create checkbox on surface figure with data, so that
    %                   we can choose whether to see the flows on the surface
    %                   or rotated for addition
    % Inquire whether checkbox exists
    figureParts = get(hFig, 'children');
    for n = 1:length(figureParts)
        if strcmp(get(figureParts(n),'Type'), 'uicontrol') && ...
                strcmp(get(figureParts(n),'Tag'), 'CheckboxRotated')
            hRotated = figureParts(n);
        end
    end

    if ~flagPlotFlow
        if exist('hRotated', 'var') % No flow plotted so ...
            delete(hRotated); % ... remove checkbox
        else
            hRotated = -1; % Send some value back
        end
    elseif flagPlotFlow && ~exist('hRotated', 'var') % Flow plotted so ...
        hRotated = uicontrol(hFig, 'Style', 'checkbox', ... % ... add checkbox
            'String', 'Display rotated flows', ...
            'Value', 0, ...
            'Tag', 'CheckboxRotated', ...
            'Position', [100 10 130 20], ...
            'Callback', {@CheckboxRotated_Callback, hFig, opticalFlow, currentTime, sSurf});
    end

        function CheckboxRotated_Callback(h, ev, hFig, opticalFlow, currentTime, sSurf)
            PlotOpticalFlow(hFig, opticalFlow, currentTime, sSurf);
        end
end