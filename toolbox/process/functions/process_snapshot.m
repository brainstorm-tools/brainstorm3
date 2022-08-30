function varargout = process_snapshot( varargin )
% PROCESS_SNAPSHOT: Save snapshot.
%
% USAGE:     sProcess = process_snapshot('GetDescription')
%                       process_snapshot('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Save snapshot';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 982;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'dipoles', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'dipoles', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === TARGET
    sProcess.options.type.Comment = 'Snapshot: ';
    sProcess.options.type.Type    = 'combobox_label';
    sProcess.options.type.Value   = {1, {...
        'Sensors/MRI registration',              'registration'; ...    % 1
        'SSP projectors',                        'ssp'; ...             % 2
        'Noise covariance',                      'noiscov'; ...         % 3
        'Data covariance',                       'ndatacov'; ...        % 12
        'Headmodel spheres',                     'headmodel'; ...       % 4
        'Recordings time series',                'data'; ...            % 5
        'Recordings topography (one time)',      'topo'; ...            % 6
        'Recordings topography (contact sheet)', 'topo_contact'; ...    % 7
        'Sources (one time)',                    'sources'; ...         % 8
        'Sources (contact sheet)',               'sources_contact'; ... % 9
        'Sources (MRI viewer)',                  'mriviewer'; ...    
        'Frequency spectrum',                    'spectrum'; ...        % 10  
        'Time-frequency maps',                   'timefreq'; ...        % 14
        'Connectivity matrix',                   'connectimage'; ...    % 11 
        'Connectivity graph',                    'connectgraph'; ...
        'Dipoles',                               'dipoles'; ...         % 13
        }'};
    % === SENSORS 
    sProcess.options.modality.Comment    = 'Sensor type: ';
    sProcess.options.modality.Type       = 'combobox';
    sProcess.options.modality.Value      = {1, {'MEG (All)', 'MEG (Gradiometers)', 'MEG (Magnetometers)', 'EEG', 'ECOG', 'SEEG', 'NIRS', 'EOG', 'ECG', 'EMG'}};
    sProcess.options.modality.InputTypes = {'raw', 'data', 'timefreq', 'pdata', 'ptimefreq'};
    % === Orientation 
    sProcess.options.orient.Comment    = 'Orientation: ';
    sProcess.options.orient.Type       = 'combobox';
    sProcess.options.orient.Value      = {1, {'left', 'right', 'top', 'bottom', 'front', 'back', 'left_intern', 'right_intern'}};
    sProcess.options.orient.InputTypes = {'raw', 'data', 'results', 'timefreq', 'dipoles', 'pdata', 'presults', 'ptimefreq'};
    % === TIME: Single view
    sProcess.options.time.Comment = 'Time (in seconds):';
    sProcess.options.time.Type    = 'value';
    sProcess.options.time.Value   = {0, 's', 4};
    % === TIME: Contact sheet
    sProcess.options.contact_time.Comment = 'Contact sheet (start time, stop time):';
    sProcess.options.contact_time.Type    = 'value';
    sProcess.options.contact_time.Value   = {[0,.1], 'list', 4};
    sProcess.options.contact_nimage.Comment = 'Contact sheet (number of images):';
    sProcess.options.contact_nimage.Type    = 'value';
    sProcess.options.contact_nimage.Value   = {12, '', 0};
    % === THRESHOLD
    sProcess.options.threshold.Comment = 'Amplitude threshold:';
    sProcess.options.threshold.Type    = 'value';
    sProcess.options.threshold.Value   = {30, '%', 0};
    sProcess.options.threshold.InputTypes = { 'results', 'timefreq', 'presults', 'ptimefreq'};
    % === SMOOTHING
    sProcess.options.surfsmooth.Comment = 'Surface smoothing:';
    sProcess.options.surfsmooth.Type    = 'value';
    sProcess.options.surfsmooth.Value   = {30, '%', 0};
    sProcess.options.surfsmooth.InputTypes = {'results', 'timefreq', 'presults', 'ptimefreq'};
    % === FREQUENCY 
    sProcess.options.freq.Comment = 'Frequency:';
    sProcess.options.freq.Type    = 'value';
    sProcess.options.freq.Value   = {0, 'Hz', 2};
    sProcess.options.freq.InputTypes = {'timefreq', 'ptimefreq'};
    % === ROW NAMES
    sProcess.options.rowname.Comment    = 'Signal name (empty=all): ';
    sProcess.options.rowname.Type       = 'text';
    sProcess.options.rowname.Value      = '';
    sProcess.options.rowname.InputTypes = {'raw', 'data', 'timefreq', 'matrix', 'pdata', 'ptimefreq', 'pmatrix'};
    % === MNI coordinates
    sProcess.options.mni.Comment = 'MNI coordinates:';
    sProcess.options.mni.Type    = 'value';
    sProcess.options.mni.Value   = {[0,0,0], 'list', 3};
    sProcess.options.mni.InputTypes = {'results', 'timefreq', 'presults', 'ptimefreq'};
    % === COMMENT
    sProcess.options.Comment.Comment = 'Comment: ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    iType = find(strcmpi(sProcess.options.type.Value{1}, sProcess.options.type.Value{2}(2,:)));
    Comment = ['Snapshot: ' sProcess.options.type.Value{2}{1,iType}];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Returned files: same as input
    OutputFiles = {sInputs.FileName};
    % Get options
    if isfield(sProcess.options, 'target') && isfield(sProcess.options.target, 'Value') && ~isempty(sProcess.options.target.Value)
        switch (sProcess.options.target.Value)
            case 1,  SnapType = 'registration';
            case 2,  SnapType = 'ssp';
            case 3,  SnapType = 'noiscov';
            case 4,  SnapType = 'spheres';
            case 5,  SnapType = 'data';
            case 6,  SnapType = 'topo';
            case 7,  SnapType = 'topo_contact';
            case 8,  SnapType = 'sources';
            case 9,  SnapType = 'sources_contact';
            case 10, SnapType = 'spectrum';
            case 11, SnapType = 'connectimage';
            case 12, SnapType = 'ndatacov';
            case 13, SnapType = 'dipoles';
            case 14, SnapType = 'timefreq';
        end
    else
        SnapType = sProcess.options.type.Value{1};
    end
    if isfield(sProcess.options, 'modality') && isfield(sProcess.options.modality, 'Value') && ~isempty(sProcess.options.modality.Value) && iscell(sProcess.options.modality.Value)
        switch (sProcess.options.modality.Value{1})
            case 1,  Modality = 'MEG';
            case 2,  Modality = 'MEG GRAD';
            case 3,  Modality = 'MEG MAG';
            case 4,  Modality = 'EEG';
            case 5,  Modality = 'ECOG';
            case 6,  Modality = 'SEEG';
            case 7,  Modality = 'NIRS';
            case 8,  Modality = 'EOG';
            case 9,  Modality = 'ECG';
            case 10, Modality = 'EMG';
            otherwise, Modality = [];
        end
    else
        Modality = [];
    end
    Time           = sProcess.options.time.Value{1};
    contact_time   = sProcess.options.contact_time.Value{1};
    contact_nimage = sProcess.options.contact_nimage.Value{1};
    if isfield(sProcess.options, 'orient') && isfield(sProcess.options.orient, 'Value') && ~isempty(sProcess.options.orient.Value) && iscell(sProcess.options.orient.Value)
        Orient = sProcess.options.orient.Value{2}{sProcess.options.orient.Value{1}};
    else
        Orient = [];
    end
    if isfield(sProcess.options, 'freq') && isfield(sProcess.options.freq, 'Value') && ~isempty(sProcess.options.freq.Value) && iscell(sProcess.options.freq.Value) && ~isequal(sProcess.options.freq.Value{1}, 0)
        Freq = sProcess.options.freq.Value{1};
    else
        Freq = [];
    end
    if isfield(sProcess.options, 'mni') && isfield(sProcess.options.mni, 'Value') && iscell(sProcess.options.mni.Value) && (length(sProcess.options.mni.Value{1}) == 3)
        XYZmni = sProcess.options.mni.Value{1};
    else
        XYZmni = [];
    end
    % If using "comment" instead of "Comment" (common scripting error)
    Comment = sProcess.options.Comment.Value;
    if isempty(Comment) && isfield(sProcess.options, 'comment') && isfield(sProcess.options.comment, 'Value') && ~isempty(sProcess.options.comment.Value)
        Comment = sProcess.options.comment.Value;
    end
    % Amplitude threshold
    if isfield(sProcess.options, 'threshold') && isfield(sProcess.options.threshold, 'Value') && ~isempty(sProcess.options.threshold.Value) && iscell(sProcess.options.threshold.Value)
        Threshold = sProcess.options.threshold.Value{1} / 100;
    else
        Threshold = 0.3;
    end
    % Surface smoothing
    if isfield(sProcess.options, 'surfsmooth') && isfield(sProcess.options.surfsmooth, 'Value') && ~isempty(sProcess.options.surfsmooth.Value) && iscell(sProcess.options.surfsmooth.Value)
        SurfSmooth = sProcess.options.surfsmooth.Value{1} / 100;
    else
        SurfSmooth = 0.3;
    end
    % Row names
    if isfield(sProcess.options, 'rowname') && isfield(sProcess.options.rowname, 'Value') && ~isempty(sProcess.options.rowname.Value)
        RowName = strtrim(sProcess.options.rowname.Value);
        iComa = find(RowName == ',');
        if ~isempty(iComa)
            bst_report('warning', sProcess, [], 'The option "signal name" should be empty or include only one signal.');
            RowName = strtrim(RowName(1,iComa-1));
        end
    else
        RowName = [];
    end
    % Contact sheet
    Contact = [contact_time, contact_nimage];
    % Select only one input file per channel file
    if ismember(SnapType, {'registration', 'ssp', 'noiscov', 'ndatacov', 'headmodel'})
        [AllChannelFile, iAllChan] = unique({sInputs.ChannelFile});
        sInputs = sInputs(iAllChan);
    end
    % For each file, capture view for each file
    for iFile = 1:length(sInputs)
        FileName = sInputs(iFile).FileName;        
        switch (SnapType)
            case 'registration'
                bst_report('Snapshot', 'registration', FileName, Comment, Modality, Orient);
            case 'ssp'
                bst_report('Snapshot', 'ssp', FileName, Comment);
            case 'noiscov'
                bst_report('Snapshot', 'noisecov', FileName, Comment);
            case 'ndatacov'
                bst_report('Snapshot', 'ndatacov', FileName, Comment);
            case 'headmodel'
                bst_report('Snapshot', 'headmodel', FileName, Comment);
            case 'data'
                bst_report('Snapshot', 'data', FileName, Comment, Modality, Time, RowName);
            case 'topo'
                bst_report('Snapshot', 'topo', FileName, Comment, Modality, Time, Freq);
            case 'topo_contact'
                if (length(Contact) ~= 3)
                    bst_report('Error', sProcess, [], 'Invalid contact sheet time values');
                    return;
                end
                bst_report('Snapshot', 'topo', FileName, Comment, Modality, Contact, Freq);
            case 'sources'
                bst_report('Snapshot', 'sources', FileName, Comment, Time, Threshold, Orient, SurfSmooth, Freq);
            case 'sources_contact'
                if (length(Contact) ~= 3)
                    bst_report('Error', sProcess, [], 'Invalid contact sheet time values');
                    return;
                end
                bst_report('Snapshot', 'sources', FileName, Comment, Contact, Threshold, Orient, SurfSmooth, Freq);
            case 'mriviewer'
                bst_report('Snapshot', 'mriviewer', FileName, Comment, Time, Threshold, Freq, XYZmni);
            case 'spectrum'
                bst_report('Snapshot', 'spectrum', FileName, Comment, RowName, Freq);
            case 'timefreq'
                bst_report('Snapshot', 'timefreq', FileName, Comment, RowName, Time, Freq);
            case 'connectimage'
                bst_report('Snapshot', 'connectimage', FileName, Comment, Time, Freq);
            case 'connectgraph'
                bst_report('Snapshot', 'connectgraph', FileName, Comment, Threshold, Time, Freq);
            case 'dipoles'
                bst_report('Snapshot', 'dipoles', FileName, Comment, Threshold, Orient);
        end
    end
end



