function bst_headtracking(varargin)
% BST_HEADTRACKING: Displays a subject's head position in realtime; used
% for quality control before recording MEG.
%
% USAGE:    bst_headtracking()              Defaults: isRealtimeAlign=0, hostIP='localhost' and TCPIP=1972
%           bst_headtracking(isRealtimeAlign)
%           bst_headtracking(isRealtimeAlign, hostIP, TCPIP)
%
% Inputs:   isRealtimeAlign = [0,1], 1 turns on realtime alignment with saved headposition
%           hostIP  = IP address of host computer
%           TCPIP   = TCP/IP port of host computer
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Elizabeth Bock & Francois Tadel, 2012-2013

global isSaveAlignChannelFile
%% ===== DEFAULT INPUTS ====

% defaults
isRealtimeAlign = 0;
hostIP  = 'localhost';    % IP address of host computer
TCPIP   = 1972;             % TPC/IP port of host computer
PosFile = [];
if nargin == 1
    if strcmp(varargin{1},'RealtimeAlign')
        isRealtimeAlign = 1;
    end
elseif nargin == 2
    isRealtimeAlign = varargin{1};
    hostIP  = varargin{2};
elseif nargin == 3
    isRealtimeAlign = varargin{1};
    hostIP  = varargin{2};
    TCPIP   = varargin{3};
elseif nargin == 4
    isRealtimeAlign = varargin{1};
    hostIP  = varargin{2};
    TCPIP   = varargin{3};
    PosFile = varargin{4};   
end

%% ===== CONFIGURATION ====
% % User Directory
% user_dir = bst_get('UserDir');

% Database
ProtocolName  =             'HeadTracking';
SubjectName   =             'HeadMaster';
ConditionHeadPoints =       'HeadPoints'; % Used to warp the head surface
ConditionChan =             'SensorPositions'; % Used to update sensor locations in real-time
ConditionRealtimeAlign =    'RealtimeAlign'; % Used for realtime alignment of previous head position
% Brainstorm
bst_dir =       bst_get('BrainstormHomeDir');
% bst_db_dir =    bst_get('BrainstormDbDir');
tmp_dir =       bst_get('BrainstormTmpDir');

% Initialize fieldtrip
ft_dir = bst_get('FieldTripDir');
ft_rtbuffer = bst_fullfile(ft_dir, 'realtime', 'src', 'buffer', 'matlab');
ft_io = bst_fullfile(ft_dir, 'fileio');
if exist(ft_rtbuffer, 'dir') && exist(ft_io, 'dir')
    addpath(ft_rtbuffer);
    addpath(ft_io);
else
    error('Cannot find the FieldTrip buffer and/or io directories');
end
% Newer Fieldtrip version requires multithreading dll.
ft_pthreadlib = bst_fullfile(ft_dir, 'realtime', 'src', 'external', 'pthreads-win64', 'lib'); 
if ispc && ~exist(bst_fullfile(ft_rtbuffer, 'pthreadGC2-w64.dll'), 'file') && ...
        exist(bst_fullfile(ft_pthreadlib, 'pthreadGC2-w64.dll'), 'file') 
    file_copy(bst_fullfile(ft_pthreadlib, 'pthreadGC2-w64.dll'), ...
        bst_fullfile(ft_rtbuffer, 'pthreadGC2-w64.dll'));
end

%% ===== PREPARE DATABASE =====
% Get protocol
iProtocol = bst_get('Protocol', ProtocolName);
% If the protocol doesn't exist yet
if isempty(iProtocol)
    % Create new protocol
    iProtocol = gui_brainstorm('CreateProtocol', ProtocolName, 1, 0); %#ok<NASGU>
else
    % Set as current protocol
    gui_brainstorm('SetCurrentProtocol', iProtocol);
end

%% ===== PREPARE SUBJECT =====
% Get subject
[sSubject, iSubject] = bst_get('Subject', SubjectName);
% If warping: we need to recreate the subject
isWarp = 0;
% Ask subject if the anatomy will be warped
res = java_dialog('question', ...
    'Do you want to warp the anatomy to subject headpoints?', ...
    'Add Headpoints', [], {'Yes', 'No', 'Cancel'});
% User cancelled operation
if isempty(res) || strcmpi(res, 'Cancel')
    return
end

% Warp
if strcmpi(res, 'Yes')    
    isWarp = 1;
end

% Create if subject doesnt exist
if isempty(iSubject)
    [sSubject, iSubject] = db_add_subject(SubjectName, [], 1, 0);
end
% Update subject structure
sSubject = bst_get('Subject', iSubject);
  
if isWarp
    % Delete all the tess and anatomy files in the subject that are not
    % default
    for ii = 1:length(sSubject.Anatomy)
        if isempty(strfind(sSubject.Anatomy(ii).FileName, bst_get('DirDefaultSubject')))
            file_delete(file_fullpath(sSubject.Anatomy(ii).FileName), 1);
        end
    end
    for ii = 1:length(sSubject.Surface)
        if isempty(strfind(sSubject.Surface(ii).FileName, bst_get('DirDefaultSubject')))
            file_delete(file_fullpath(sSubject.Surface(ii).FileName), 1);
        end
    end
end
% Reload subject
db_reload_subjects(iSubject);
% Update subject structure
sSubject = bst_get('Subject', iSubject);

   
%% ===== PREPARE CONDITION: HEADPOINTS =====
% Get condition
[sStudy, iStudy] = bst_get('StudyWithCondition', [SubjectName '/' ConditionHeadPoints]);
% If warping: we need a channel file in HeadPoints, this will be populated
% with the head points measured and saved in a .pos file
if isWarp
    % Create if condition doesnt exist
    if isempty(sStudy)
        iStudy = db_add_condition(SubjectName, ConditionHeadPoints);
        sStudy = bst_get('Study', iStudy);
    end
    
    % Copy default channel file to this condition
    DefChannelFile = bst_fullfile(bst_dir, 'defaults', 'meg', 'channel_ctf_default.mat');
    file_copy(DefChannelFile, bst_fileparts(file_fullpath(sStudy.FileName)));
    % Reload condition
    db_reload_studies(iStudy);

    % Get updated study definition
    sStudy = bst_get('Study', iStudy);
 
    % Update the channel file with the head points
    if isempty(PosFile)
        LastUsedDirs = bst_get('LastUsedDirs');
        PosFile = java_getfile( 'open', 'Select POS file...', LastUsedDirs.ImportChannel, 'single', 'files', ...
            {{'*.pos'}, 'POS files', 'POLHEMUS'}, 0);
        if isempty(PosFile)
            return;
        end
    end
    % Read POS file and channel file
    HeadMat = in_channel_pos(PosFile);
    HPChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = in_bst_channel(HPChannelFile);

    % Copy head points
    ChannelMat.HeadPoints = HeadMat.HeadPoints;
    % Force re-alignment on the new set of NAS/LPA/RPA (switch from CTF coil-based to SCS anatomical-based coordinate system)
    ChannelMat = channel_detect_type(ChannelMat, 1, 0);
    save(HPChannelFile, '-struct', 'ChannelMat');
    
else
    HPChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = in_bst_channel(HPChannelFile); 
end

% Get the transformation for HPI head coordinates (POS file) to Brainstorm
iTrans = find(~cellfun(@isempty,strfind(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF')));
if isempty(iTrans)
    bst_error('No SCS transformation in the channel file')
    return;
end
%ChannelMat.TransfMeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
trans = ChannelMat.TransfMeg{iTrans};
R = trans(1:3, 1:3);
T = trans(1:3, 4); %in meters


%% ===== WARP =====
if isWarp
    % Warp surface for new head points
    % bst_warp_prepare(ChannelFile, Options)
    %    Options     : Structure of the options
    %         |- tolerance    : Percentage of outliers head points, ignored in the calulation of the deformation. 
    %         |                 Set to more than 0 when you know your head points have some outliers.
    %         |                 If not specified: asked to the user (default 
    %         |- isInterp     : If 0, do not do a full interpolation (default: 1)
    %         |- isScaleOnly  : If 1, do not perform the full deformation but only a linear scaling in the three directions (default: 0)
    %         |- isSurfaceOnly: If 1, do not warp/scale the MRI (default: 0)
    %         |- isInteractive: If 0, do not ask anything to the user (default: 1)
    Options.tolerance = 0.02;
    Options.isInterp = [];
    Options.isScaleOnly = 0;
    Options.isSurfaceOnly = 1;
    Options.isInteractive = 1;
    hFig = bst_warp_prepare(HPChannelFile, Options);

    % Close figure
    close(hFig);
    % Update subject structure
    sSubject = bst_get('Subject', iSubject);
end


%% ===== PREPARE CONDITION: CHANNEL POSITIONS =====
% Get condition
[sStudyChan, iStudyChan] = bst_get('StudyWithCondition', [SubjectName '/' ConditionChan]);
% Create if condition doesnt exist, this will be populated with sensor
% positions measured from real-time res4 file
if isempty(sStudyChan)
    iStudyChan = db_add_condition(SubjectName, ConditionChan);
    sStudyChan = bst_get('Study', iStudyChan);
end

%% ===== INITIALIZE FIELDTRIP BUFFER =====
% find and kill any old matlab processes
pid = feature('getpid');
[tmp,tasks] = system('tasklist');
pat = '\s+';
str=tasks;
s = regexp(str, pat, 'split'); 
iMatlab = find(~cellfun(@isempty, strfind(s, 'MATLAB.exe')));

if numel(iMatlab) > 1
    % kill the extra matlab(s)
    disp('An old MATLAB process is still running, stopping now...');
    temp = str2double(s(iMatlab+1));
    iKill = find(temp ~= pid);
    for ii=1:length(iKill)
        [status,result] = system(['Taskkill /PID ' num2str(temp(iKill(ii))) ' /F']);
        if status
            disp(result);
            disp('The process could not be stopped.  Please stop it manually');
        else
            disp(result);
        end
    end
end
    
% Initialize the buffer
try
    disp('BST> Initializing FieldTrip buffer...');
    buffer('tcpserver', 'init', hostIP, TCPIP);
catch
    disp('BST> Warning: FieldTrip buffer is already initialized.');
    buffer('flush_hdr', [], hostIP, TCPIP);
end
% disp('BST> Remember to type ''clear buffer'' once done with head tracking.'); % Doesn't work: freezes. 
% Waiting for acquisition to start
disp('BST> Waiting for acquisition to start...');
while (1) % To fix: This loop can make Matlab crash if wait is too long.
    try
        % [nsamples, nevents, timeout]
        numbers = buffer('wait_dat', [1 -1 1000], hostIP, TCPIP);        
        disp('BST> Acquisition started.');
        break;
    catch
        pause(1);
    end
end

%% ===== READING RES4 INFO =====
% Reading header
hdr = buffer('get_hdr', [], hostIP, TCPIP);

% Write .res4 file
res4_file = bst_fullfile(tmp_dir, 'temp.res4');
fid = fopen(res4_file, 'w', 'l');
fwrite(fid, hdr.ctf_res4, 'uint8');
fclose(fid);
% Write empty .meg4
meg4_file = bst_fullfile(tmp_dir, 'temp.meg4');
fid = fopen(meg4_file, 'w', 'l');
fclose(fid);
% Reading structured res4
SensorPositionMat = in_channel_ctf(res4_file);
% Add channel file to the SensorPositions study
SensorPositionFile = db_set_channel(iStudyChan, SensorPositionMat, 2, 2);

%% ===== HEAD TRACKING =====
% Display subject's head
hFig = view_surface(sSubject.Surface(sSubject.iScalp).FileName);
% Set view from the left
figure_3d('SetStandardView', hFig, 'front');
% Check for RealtimeAlign
if isRealtimeAlign
    % Create save button
    btn = uicontrol('Style', 'pushbutton', 'String', 'Save',...
        'Position', [20 20 50 20],...
        'Callback', @SaveAlignCallback);
    [sStudyAlign, iStudyAlign] = bst_get('StudyWithCondition', [SubjectName '/' ConditionRealtimeAlign]);
else
    sStudyAlign = [];
end
ColorTable = [1,0,0; 0,1,0; 0,0,1];
colorInd = 2;
if ~isempty(sStudyAlign)
    % Display CTF helmet
    view_helmet_local(sStudyAlign.Channel.FileName, hFig); % _local
    % Get the helmet patch
    hHelmetPatch = findobj(hFig, 'Tag', 'HelmetPatch'); 
    color = ColorTable(mod(colorInd-1,size(ColorTable,1))+1,:);
    set(hHelmetPatch, 'FaceColor', color, 'FaceAlpha', .3, 'SpecularStrength', 0, ...
                            'EdgeColor', color, 'EdgeAlpha', .2, 'LineWidth', 1, ...
                            'Marker', 'none', 'Tag', 'MultipleSensorsPatches');
    AlignVertices = get(hHelmetPatch, 'Vertices');                    
end

% Display current position helmet
colorInd = 1;
% Display CTF helmet
view_helmet_local(SensorPositionFile, hFig);
% Get the helmet patch
hHelmetPatch = findobj(hFig, 'Tag', 'HelmetPatch');
color = ColorTable(mod(colorInd-1,size(ColorTable,1))+1,:);
set(hHelmetPatch, 'FaceColor', color, 'FaceAlpha', .3, 'SpecularStrength', 0, ...
                        'EdgeColor', color, 'EdgeAlpha', .2, 'LineWidth', 1, ...
                        'Marker', 'none', 'Tag', 'MultipleSensorsPatches', ...
                        'Visible', 'on');
% Get XYZ coordinates of the helmet patch object
InitVertices = get(hHelmetPatch, 'Vertices');

% Loop to update positions
while (1)
    % Number of samples to read
    nSamples = 300;
    % Read the last nSamples fiducial positions
    hdr = buffer('get_hdr', [], hostIP, TCPIP);
    currentSample = hdr.nsamples;
    if currentSample < nSamples-1
        % Wait
        pause(.2);
        continue;
    end
    dat = buffer('get_dat', [currentSample-nSamples-1,currentSample-1], hostIP, TCPIP);
    % Average in time
    buf = mean(double(dat.buf), 2);
    Fid = [buf(1:3), buf(4:6), buf(7:9)] ./ 1e3; % convert to mm
    % Get fiducial positions
    sMri.SCS.NAS = Fid(:,1)';
    sMri.SCS.LPA = Fid(:,2)';
    sMri.SCS.RPA = Fid(:,3)';
    % Compute transformation Dewar=>Native (CTF head coils)
    transfSCS = cs_compute(sMri, 'scs'); % NAS, LPA and RPA in mm
    sMri.SCS.R = transfSCS.R;
    sMri.SCS.T = transfSCS.T;
    sMri.SCS.Origin = transfSCS.Origin;
    % Apply transformation to helmet vertices.  sMri is in mm and vertices
    % are in m (as it should be according to cs_convert code).
    Vertices = cs_convert(sMri, 'mri', 'scs', InitVertices);
    % Convert HPI coordinates to Brainstorm coordinates (based on cardinal points)
    Vertices = bst_bsxfun(@plus, R * Vertices', T)';
    % Stop if the window was closed
    if ~ishandle(hHelmetPatch)
        break;
    end
    % Update helmet patch
    set(hHelmetPatch, 'Vertices', Vertices);
    
    % check difference between current and align position
    if ~isempty(sStudyAlign)
        maxDiff = (max(max(100*abs(AlignVertices - Vertices)/AlignVertices)));
        
        if maxDiff < 10
            colorInd = 2;
            color = ColorTable(mod(colorInd-1,size(ColorTable,1))+1,:);
            set(hHelmetPatch, 'FaceColor', color, 'FaceAlpha', .3, 'SpecularStrength', 0, ...
                                'EdgeColor', color, 'EdgeAlpha', .2, 'LineWidth', 1, ...
                                'Marker', 'none', 'Tag', 'MultipleSensorsPatches');
        else
            colorInd = 1;
            color = ColorTable(mod(colorInd-1,size(ColorTable,1))+1,:);
            set(hHelmetPatch, 'FaceColor', color, 'FaceAlpha', .3, 'SpecularStrength', 0, ...
                                'EdgeColor', color, 'EdgeAlpha', .2, 'LineWidth', 1, ...
                                'Marker', 'none', 'Tag', 'MultipleSensorsPatches');
        end
    end
    
    if isSaveAlignChannelFile
        % Check for RealtimeAlign condition
        [tmp, iStudyAlign] = bst_get('StudyWithCondition', [SubjectName '/' ConditionRealtimeAlign]);
        if isempty(iStudyAlign)
            % create the condition and channel file with the current sensor positions for subsequent alignment
            iStudyAlign = db_add_condition(SubjectName, ConditionRealtimeAlign);
        end
        SensorPositionMat.SCS = sMri.SCS; % in mm
        db_set_channel(iStudyAlign, SensorPositionMat, 2, 0);
        SaveAlignChannelFile(HPChannelFile, iStudyAlign, SensorPositionMat);
    end
    % Wait
    pause(.2);
end
end
%% SaveAlignCallback
function SaveAlignCallback(source,callbackdata)
    global isSaveAlignChannelFile
    isSaveAlignChannelFile = 1;
end
%% Head Localization
function SaveAlignChannelFile(HPChannelFile, iStudyAlign, ChannelMat)
    global isSaveAlignChannelFile
    % ChannelMat.SCS already contains the transformation Dewar=>Native (CTF
    % head coils), in mm

    % Get transformation Native=>Brainstorm/CTF (anatomical NAS/LPA/RPA)
    % from head points file.
    HPChannelMat = in_bst_channel(HPChannelFile);
    iTrans = find(~cellfun(@isempty,strfind(HPChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF')));
    if isempty(iTrans)
        bst_error('No SCS transformation in the head points channel file')
        return;
    end
    % Get the translation and rotation from the HeadPoints tranformation
    trans = HPChannelMat.TransfMeg{iTrans};
    anatR = trans(1:3, 1:3);
    anatT = trans(1:3, 4) * 1000; % convert from m to mm

    % Combine the tranformations
    transfAnat = [anatR, anatT; 0 0 0 1]*[ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1]; % in mm

    % Update the ChannelMat structure
    ChannelMat.SCS.R = transfAnat(1:3, 1:3);
    ChannelMat.SCS.T = transfAnat(1:3, 4); % in mm
    
    % Process each sensor
    for i = 1:length(ChannelMat.Channel)
        if ~isempty(ChannelMat.Channel(i).Loc)
            % Converts the locations. ChannelMat.SCS is in mm and locations
            % are in m (as it should be according to cs_convert code).
            ChannelMat.Channel(i).Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.Channel(i).Loc')';
        end
    end

    % Also transform the fiducial positions, temporarily converted to m.
    ChannelMat.SCS.NAS = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.NAS ./ 1000) .* 1000; % still in mm
    ChannelMat.SCS.LPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.LPA ./ 1000) .* 1000;
    ChannelMat.SCS.RPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.RPA ./ 1000) .* 1000;

    % Update the list of transformations.  Here the translation must be in
    % m.
    if isempty(ChannelMat.TransfMegLabels)
        iTrans = [];
    else
        iTrans = find(~cellfun(@isempty,strfind(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF')));
    end

    if isempty(iTrans)
        ChannelMat.TransfMeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T ./ 1000; 0 0 0 1];
        ChannelMat.TransfMegLabels{end+1} = 'Native=>Brainstorm/CTF';
        ChannelMat.TransfEeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T ./ 1000; 0 0 0 1];
        ChannelMat.TransfEegLabels{end+1} = 'Native=>Brainstorm/CTF';
    else
        ChannelMat.TransfMeg{iTrans} = [ChannelMat.SCS.R, ChannelMat.SCS.T ./ 1000; 0 0 0 1];
        ChannelMat.TransfMegLabels{iTrans} = 'Native=>Brainstorm/CTF';
        ChannelMat.TransfEeg{iTrans} = [ChannelMat.SCS.R, ChannelMat.SCS.T ./ 1000; 0 0 0 1];
        ChannelMat.TransfEegLabels{iTrans} = 'Native=>Brainstorm/CTF';
    end

    % Save new channel file to the target studies.
    db_set_channel(iStudyAlign, ChannelMat, 2, 0);
    isSaveAlignChannelFile = 0;

end


function view_helmet_local(ChannelFile, hFig)
% Local trimmed down version of view_helmet, such that it also uses
% channel_tesselate_local which was modified to work in dewar coordinates.
% The only change, at the end of this function, is that the sensor patch is
% deleted instead of making it invisible.

Modality = 'MEG';

% hFig = view_channels(ChannelFile, Modality, 1, 0, hFig);
  [hFig] = bst_figures('GetFigure', hFig);
  %   iDS = bst_memory('GetDataSetChannel', ChannelFile);
  %   if isempty(hFig)
  %       % Prepare FigureId structure
  %       FigureId = db_template('FigureId');
  %       FigureId.Type     = '3DViz';
  %       FigureId.SubType  = '';
  %       FigureId.Modality = Modality;
  %       % Create figure
  %       [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId);
  %       % If figure was not created: Display an error message and return
  %       if isempty(hFig)
  %           bst_error('Cannot create figure', '3D figure creation...', 0);
  %           return;
  %       end
  %   end
  
%   figure_3d('ViewSensors', hFig, 1, 0, 1, Modality);
    % Load channel file
    ChannelMat = in_bst_channel(ChannelFile);
    Channel = ChannelMat.Channel;
    selChan = good_channel(Channel, [], Modality);
    % Get sensors positions
    
%     [tmp, markersLocs] = GetChannelPositions(iDS, selChan);
    % Initialize returned variables
    vertices    = zeros(3,0);
    % Get device type
    Device = bst_get('ChannelDevice', ChannelFile);
    % Get selected channels
    Channel = Channel(selChan);
    % Find magnetometers
    if strcmpi(Device, 'Vectorview306')
        iMag = good_channel(Channel, [], 'MEG MAG');
    end
    % Loop on all the sensors
    for i = 1:length(Channel)
        % If position is not defined
        if isempty(Channel(i).Loc)
            Channel(i).Loc = [0;0;0];
        end
        % Get number of integration points or coils
        nIntegPoints = size(Channel(i).Loc, 2);
        % Switch depending on the device
        switch (Device)
            case {'CTF', '4D', 'KIT', 'RICOH'}
                if (nIntegPoints >= 4)
                    vertices    = [vertices,    Channel(i).Loc(:,1:4)]; %#ok<*AGROW>
                else
                    vertices    = [vertices,    Channel(i).Loc];
                end
            case 'KRISS'
                if (nIntegPoints >= 4)
                    vertices    = [vertices,    Channel(i).Loc(:,1:4)];
                else
                    vertices    = [vertices,    Channel(i).Loc(:,1)];
                end
            case 'Vectorview306'
                if isempty(iMag) || ismember(i, iMag)
                    vertices = [vertices, Channel(i).Loc];
                end
            case 'BabySQUID'
                vertices    = [vertices,    Channel(i).Loc(:,1)];
            case 'BabyMEG'
                vertices    = [vertices,    Channel(i).Loc];
            case {'NIRS-BRS', 'NIRS'}
                Factor = 1;
                % Position of the channel: mid-way between source and detector, organized in layers by wavelength
                vertices    = [vertices,    mean(Channel(i).Loc,2) .* Factor];
            otherwise
                vertices    = [vertices,    Channel(i).Loc];
        end
    end
    vertices    = double(vertices');
% End of content from GetChannelPositions subfunction.    
    
    % Put focus on target figure
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    
%     PlotSensorsNet(hAxes, markersLocs, 1, isMesh, markersOrient);  
      faces = channel_tesselate_local( vertices );
      % === DISPLAY PATCH ===
      % Display faces / edges / vertices
      FaceColor = [.7 .7 .5];
      EdgeColor = [.4 .4 .3];
      LineWidth = 1;
      % Create sensors patch
      hNet = patch(...
        'Vertices',         vertices, ...
        'Faces',            faces, ...
        'FaceVertexCData',  repmat([1 1 1], [length(vertices), 1]), ...
        'Parent',           hAxes, ...
        'Marker',           'o', ...
        'LineWidth',        LineWidth, ...
        'FaceColor',        FaceColor, ...
        'FaceAlpha',        1, ...
        'EdgeColor',        EdgeColor, ...
        'EdgeAlpha',        1, ...
        'MarkerEdgeColor',  [.4 .4 .3], ...
        'MarkerFaceColor',  'flat', ...
        'MarkerSize',       6, ...
        'BackfaceLighting', 'lit', ...
        'AmbientStrength',  0.5, ...
        'DiffuseStrength',  0.5, ...
        'SpecularStrength', 0.2, ...
        'SpecularExponent', 1, ...
        'SpecularColorReflectance', 0.5, ...
        'FaceLighting',     'gouraud', ...
        'EdgeLighting',     'gouraud', ...
        'Tag',              'SensorsPatch');
% End of content from figure_3d.

  % Update lights
  camlight(findobj(hFig, 'Tag', 'FrontLight'), 'headlight');
  % Update figure name
  bst_figures('UpdateFigureName', hFig);
  % Camera basic orientation
  %   if isNewFig
  %       figure_3d('SetStandardView', hFig, 'top');
  %   end
  % Show figure
  set(hFig, 'Visible', 'on');
% End of content from view_channels.

% Get sensors patch
hSensorsPatch = findobj(hFig, 'Tag', 'SensorsPatch');
if isempty(hSensorsPatch)
    return
elseif numel(hSensorsPatch) > 1
    hSensorsPatch = hSensorsPatch(1);
end
% Get sensors positions
vert = get(hSensorsPatch, 'Vertices');

% ===== CREATE HELMET SURFACE =====
% Get the acquisition device
Device = bst_get('ChannelDevice', ChannelFile);
% Distance sensors/helmet
switch (Device)
    case 'Vectorview306'
        dist = .019;
    case 'CTF'
        dist = .015;
    case '4D'
        dist = .015;
    case 'KIT'
        dist = .020;
    case 'KRISS'
        dist = .025;
    case 'BabyMEG'
        dist = .008;
    case 'RICOH'
        dist = .020;
    otherwise
        dist = 0;
end
% Shrink sensor patch to create the inner helmet surface
if (dist > 0)
    center = mean(vert);
    vert = bst_bsxfun(@minus, vert, center);
    [th,phi,r] = cart2sph(vert(:,1),vert(:,2),vert(:,3));
    [vert(:,1),vert(:,2),vert(:,3)] = sph2cart(th, phi, r - dist);
    vert = bst_bsxfun(@plus, vert, center);
end

% ===== DISPLAY HELMET SURFACE =====
% Copy sensor patch object
hHelmetPatch = copyobj(hSensorsPatch, get(hSensorsPatch,'Parent'));
% Make the sensor patch invisible
% set(hSensorsPatch, 'Visible', 'off');
delete(hSensorsPatch);
% Set patch properties
set(hHelmetPatch, 'Vertices',   vert, ...
                   'LineWidth',  1, ...
                   'EdgeColor',  [.5 .5 .5], ...
                   'EdgeAlpha',  1, ...
                   'FaceColor',  'y', ...
                   'FaceAlpha',  .3, ...
                   'Marker',     'none', ...
                   'Tag',        'HelmetPatch');
                 
end



function Faces = channel_tesselate_local( Vertices, isPerimThresh )
% Modified copy of channel_tesselate to work in dewar coordinates:
% 2d projection changed to "centered - max(z)" coordinates and
% thresholdPerim increased to 8 std instead of 6 to avoid helmet holes.

% CHANNEL_TESSELATE: Tesselate a set of EEG or MEG sensors, for display purpose only.
%
% USAGE:  Faces = channel_tesselate( Vertices, isPerimThresh=1 )
%
% INPUT:  
%    - Vertices      : [Nx3], set of 3D points (MEG or EEG sensors)
%    - isPerimThresh : If 1, remove the Faces that are too big
% OUTPUT:
%    - Faces    : [Mx3], result of the tesselation

% Parse inputs
if (nargin < 2) || isempty(isPerimThresh)
    isPerimThresh = 1;
end

% === TESSELATE ===
% Compute best fitting sphere
bfs_center = bst_bfs(Vertices)';
% Center Vertices on BFS center
coordC = bst_bsxfun(@minus, Vertices, bfs_center);
    % 2D Projection   
    % Use centered points in case points are not in SCS coordinates, which
    % is the case e.g. when doing real-time head position display (dewar
    % coordinates).
    [X,Y] = bst_project_2d(coordC(:,1), coordC(:,2), coordC(:,3)-max(coordC(:,3)), '2dcap');
% Normalize coordinates
coordC = bst_bsxfun(@rdivide, coordC, sqrt(sum(coordC.^2,2)));
% Tesselation of the sensor array
Faces = convhulln(coordC);

% === REMOVE UNNECESSARY TRIANGLES ===
% For instance: the holes for the ears on high-density EEG caps
if isPerimThresh
    % Get border of the representation
    border = convhull(X,Y);
    % Keep Faces inside the border
    iInside = find(~(ismember(Faces(:,1),border) & ismember(Faces(:,2),border)& ismember(Faces(:,3),border)));
    %Faces   = Faces(iInside, :);

    % Compute perimeter
    triPerimeter = tess_perimeter(Vertices, Faces);
    % Threshold values
    thresholdPerim = mean(triPerimeter(iInside)) + 8 * std(triPerimeter(iInside));
    % Apply threshold
    iFacesOk = intersect(find(triPerimeter <= thresholdPerim), iInside);
    % Find Vertices that are not in the Faces matrix
    iVertNotInFaces = setdiff(1:length(Vertices), unique(Faces(:)));
    if ~isempty(iVertNotInFaces)
        disp(['CHANNEL_TESSELATE> WARNING: Some sensors are not in the Faces list: ' sprintf('%d ', iVertNotInFaces)]);
    end
    % Loop until all the Vertices are visible
    isMissing = 1;
    while isMissing
        % List all the Vertices ignored by the reduced mesh
        iVertOk = unique(reshape(Faces(iFacesOk,:),[],1));
        iVertMissing = setdiff(1:length(Vertices), iVertOk);
        iVertMissing = setdiff(iVertMissing, iVertNotInFaces);
        % If all the Vertices are included, next step
        if isempty(iVertMissing)
            isMissing = 0;
        else
            % Find Faces connected to the first missing vertex
            iFacesAdd = find(any(Faces == iVertMissing(1), 2));
            % From the potential candidate Faces, keep the one that has the smaller perimeter
            [minP, iMinP] = min(triPerimeter(iFacesAdd));
            % Add the smallest face to the list of Faces we keep
            iFacesOk(end+1) = iFacesAdd(iMinP);
        end
    end
    % Remove the Faces
    Faces = Faces(sort(iFacesOk),:);
end

end

