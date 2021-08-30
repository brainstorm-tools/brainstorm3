function [sFile, ChannelMat, errMsg] = in_fopen_kit(RawFile)
% IN_FOPEN_KIT: Open a KIT file, and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat, errMsg] = in_fopen_kit(RawFile)
%
% This function is based on the Yokogawa MEG reader toolbox version 1.4.
% For copyright and license information and software documentation, 
% please refer to the contents of the folder brainstorm3/external/yokogawa

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
% Authors: Francois Tadel, 2013-2021


%% ===== READ HEADER =====
header.system   = getYkgwHdrSystem(RawFile);    % Get information about the MEG system.
header.sensors  = getYkgwHdrChannel(RawFile);   % Get information about the data channels.
header.acq      = getYkgwHdrAcqCond(RawFile);   % Get information about data acquisition condition.
header.events   = getYkgwHdrEvent(RawFile);     % Get information about trigger events.
header.bookmark = getYkgwHdrBookmark(RawFile);  % Get information about bookmark.
header.coreg    = getYkgwHdrCoregist(RawFile);  % Get information about coregistration.
% header.coreg  = KitReadCoreg(RawFile);
header.digitize = getYkgwHdrDigitize(RawFile);  % Get information about digitization.
header.subject  = getYkgwHdrSubject(RawFile);   % Get information about subject.
%header.sources  = getYkgwHdrSource(RawFile);   % Get information analyzed sources.
errMsg = [];

    
%% ===== READ DIGITIZER FILES =====
% In the software with the KIT system at NYU, there is no "Export" option that allows the access to the digitized head points.
% These points can be provided separately: "_Marker1*.sqd/.mrk", "_HS.txt" and "_Points.txt".
% The format of the files must be in the FastSCAN format (one line per point [x y z] in millimeters in the Polhemus ALS coordinate system, comment lines starting with "%")

% If the coregistration is not done yet (files were not exported properly from the Yokogawa software)
if (header.coreg.done == 0)
    % === FIND FILES ===
    % Get the dataset folder
    [fPath, fBase, fExt] = bst_fileparts(RawFile);
    disp(['KIT> Dataset folder: ' fPath]);
    % Marker file: *_Marker1*.sqd, *_Marker1*.mrk or *.mrk
    MrkFile = dir(bst_fullfile(fPath, '*_Marker1*'));
    if isempty(MrkFile)
        MrkFile = dir(bst_fullfile(fPath, '*.mrk'));
    end
    if isempty(MrkFile)
        disp('KIT>    | Error: Marker file missing: *_Marker1* or *.mrk');
    elseif (length(MrkFile) > 1)
        disp(['KIT>    | Error: More than one marker files: ' sprintf('%s, ', MrkFile.name)]);
        MrkFile = [];
    else
        disp(['KIT>    | Marker file: ' MrkFile(1).name]);
        MrkFile = bst_fullfile(fPath, MrkFile(1).name);
    end
    % Digitized fiducials: *_Points.txt or *.elp
    FidFile = dir(bst_fullfile(fPath, '*_Points.txt'));
    if isempty(FidFile)
        FidFile = dir(bst_fullfile(fPath, '*.elp'));
    end
    if isempty(FidFile)
        disp('KIT>    | Error: Digitized fiducials missing: *_Points.txt or *.elp');
    elseif (length(FidFile) > 1)
        disp(['KIT>    | Error: More than one fiducials files: ' sprintf('%s, ', FidFile.name)]);
        FidFile = [];
    else
        disp(['KIT>    | Digitized fiducials: ' FidFile(1).name]);
        FidFile = bst_fullfile(fPath, FidFile(1).name);
    end
    % Head shape: *_HS.txt or *.hsp
    HsFile = dir(bst_fullfile(fPath, '*_HS.txt'));
    if isempty(HsFile)
        HsFile = dir(bst_fullfile(fPath, '*.hsp'));
    end
    if isempty(HsFile)
        disp('KIT>    | Error: Digitized head shape missing: *_HS.txt');
    elseif (length(HsFile) > 1)
        disp(['KIT>    | Error: More than one head shape files: ' sprintf('%s, ', HsFile.name)]);
        HsFile = [];
    else
        disp(['KIT>    | Digitized head shape: ' HsFile(1).name]);
        HsFile = bst_fullfile(fPath, HsFile(1).name);
    end
    
    % === READ FILES ===
    if ~isempty(MrkFile) && ~isempty(FidFile)
        % Read marker file
        % header.coreg = KitReadCoreg(MrkFile);
        header.coreg = getYkgwHdrCoregist(MrkFile);
        xyzMeg = cat(1, header.coreg.hpi.meg_pos)';
        % Read digitized fiducials (the file should contain 8 points)
        xyzDig = ReadPolhemus(FidFile, 0);
        if isempty(xyzDig) || (size(xyzDig,2) ~= 8)
            error(['The fiducials file must contain 8 points:' FileName]);
        end
        % Read head shape
        if ~isempty(HsFile)
            xyzHs = ReadPolhemus(HsFile, 1);
            % If there are more than 2000 points: downsample randomly
            if (length(xyzHs) > 2000)
                nVert = length(xyzHs);
                nStep = round(nVert / 2000);
                xyzHs = xyzHs(:, 1:nStep:nVert);
                disp(sprintf('KIT>    | Keeping only %d digitized points (initially %d)', length(xyzHs), nVert));
            end
        else
            xyzHs = [];
        end   

        % === COMPUTE DIG2MEG TRANSFORMATION ===
        % Compute transformation: Digitizer => MEG device
        [R,T] = rot3dfit(xyzDig(:,4:end)', xyzMeg');
        R = R'; 
        T = T';
        % Report in 4x4 format
        header.digitize.info.digitizer2meg = [R, T; 0 0 0 1];
        header.digitize.info.meg2digitizer = inv(header.digitize.info.digitizer2meg);
        header.digitize.info.done = 1;
        % Add the position of the digitized points to the header
        nPoints = size(xyzDig,2) + size(xyzHs,2);
        cellPos = num2cell([xyzDig, xyzHs]);
        cellLab = cat(2, {'fidnz', 'fidt9', 'fidt10', 'LPA', 'RPA', 'CPF', 'LPF', 'RPF'}, repmat({'hs'}, 1, size(xyzHs,2)));
        header.digitize.point = repmat(struct('name', '', 'x', [0 0 0], 'y', [0 0 0], 'z', [0 0 0]), [1,nPoints]);
        [header.digitize.point.x] = deal(cellPos{1,:});
        [header.digitize.point.y] = deal(cellPos{2,:});
        [header.digitize.point.z] = deal(cellPos{3,:});
        [header.digitize.point.name] = deal(cellLab{:});
    end
end


%% ===== GET CHANNEL INFORMATION =====
nChannels = length(header.sensors.channel);
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'KIT channels';
ChannelMat.Channel = repmat(db_template('ChannelDesc'), 1, nChannels);
% Initialize counters for the different types of sensors
nNull = 1;
nGrad = 1;
nMag  = 1;
nTrigger = 1;
nEeg  = 1;
nEcg  = 1;
nMisc = 1;
% Count number of each type of basic MEG sensors
nMegMag = nnz([header.sensors.channel.type] == 1);
nMegGradAxial = nnz([header.sensors.channel.type] == 2);
nMegGradPlanar = nnz([header.sensors.channel.type] == 3);
% Loop on each channel
for i = 1:nChannels
    % Switch according to sensor type
    switch (header.sensors.channel(i).type)
        case 0  % NullChannel
            ChannelMat.Channel(i).Name = sprintf('Null%03d', nNull);
            ChannelMat.Channel(i).Type = 'Null';
            nNull = nNull + 1;
            
        % === MAGNETO ===
        case {1, 257}  % MagnetoMeter / ReferenceMagnetoMeter
            % Channel name
            if ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('M%03d', nMag - 1);
            end
            % Type: Reference/Brain sensor
            if (header.sensors.channel(i).type == 1)
                % In case of unique type of sensors: use only the simplified naming "MEG"
                if (nMegGradAxial == 0) && (nMegGradPlanar == 0)
                    ChannelMat.Channel(i).Type = 'MEG';
                else
                    ChannelMat.Channel(i).Type = 'MEG MAG';
                end
            else
                ChannelMat.Channel(i).Type = 'MEG REF';
            end
            % Comment including the size (used by ctf_add_coil_defs)
            ChannelMat.Channel(i).Comment = sprintf('KIT Magnetometer size = %1.2f  mm', 1000*header.sensors.channel(i).data.size);
            % Position/Orientation
            ChannelMat.Channel(i).Loc = [header.sensors.channel(i).data.x; ...
                                         header.sensors.channel(i).data.y; ...
                                         header.sensors.channel(i).data.z];
            ChannelMat.Channel(i).Orient = [sin(header.sensors.channel(i).data.zdir ./ 180 * pi) * cos(header.sensors.channel(i).data.xdir ./ 180 * pi); ...
                                            sin(header.sensors.channel(i).data.zdir ./ 180 * pi) * sin(header.sensors.channel(i).data.xdir ./ 180 * pi); ...
                                            cos(header.sensors.channel(i).data.zdir ./ 180 * pi)];
            ChannelMat.Channel(i).Weight = 1;
            nMag = nMag + 1;
            
        % === AXIAL GRADIO ===
        case {2, 258}  % AxialGradioMeter / ReferenceAxialGradioMeter
            % Channel name
            if ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('AG%03d', nGrad - 1);
            end
            % Type: Reference/Brain sensor
            if (header.sensors.channel(i).type == 2)
                % In case of unique type of sensors: use only the simplified naming "MEG"
                if (nMegMag == 0) && (nMegGradPlanar == 0)
                    ChannelMat.Channel(i).Type = 'MEG';
                else
                    ChannelMat.Channel(i).Type = 'MEG GRAD';
                end
            else
                ChannelMat.Channel(i).Type = 'MEG REF';
            end
            % Comment including the size (used by ctf_add_coil_defs)
            %ChannelMat.Channel(i).Comment = sprintf('KIT Axial Gradiometer size = %1.2f  mm base = %1.2f  mm', 1000*header.sensors.channel(i).data.size, 1000*header.sensors.channel(i).data.baseline);
            ChannelMat.Channel(i).Comment = '6001';
            % Inner coil
            ChannelMat.Channel(i).Loc = [header.sensors.channel(i).data.x; ...
                                         header.sensors.channel(i).data.y; ...
                                         header.sensors.channel(i).data.z];
            ChannelMat.Channel(i).Orient = [sin(header.sensors.channel(i).data.zdir ./ 180 * pi) * cos(header.sensors.channel(i).data.xdir ./ 180 * pi); ...
                                            sin(header.sensors.channel(i).data.zdir ./ 180 * pi) * sin(header.sensors.channel(i).data.xdir ./ 180 * pi); ...
                                            cos(header.sensors.channel(i).data.zdir ./ 180 * pi)];
            % Add outer coil
            ChannelMat.Channel(i).Loc = [ChannelMat.Channel(i).Loc, ...
                                         ChannelMat.Channel(i).Loc + ChannelMat.Channel(i).Orient * header.sensors.channel(i).data.baseline];
            ChannelMat.Channel(i).Orient = [ChannelMat.Channel(i).Orient, ChannelMat.Channel(i).Orient];
            % Weight of the two coils
            ChannelMat.Channel(i).Weight = [1, -1];
            nGrad = nGrad + 1;
            
        % === PLANAR GRADIO ===
        case {3, 259}  % PlanarGradioMeter / ReferencePlanarGradioMeter
            % Channel name
            if isfield(header.sensors.channel(i).data, 'name') && ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('PG%03d', nGrad - 1);
            end
            % Type: Reference/Brain sensor
            if (header.sensors.channel(i).type == 3)
                % In case of unique type of sensors: use only the simplified naming "MEG"
                if (nMegMag == 0) && (nMegGradAxial == 0)
                    ChannelMat.Channel(i).Type = 'MEG';
                else
                    ChannelMat.Channel(i).Type = 'MEG GRAD';
                end
            else
                ChannelMat.Channel(i).Type = 'MEG REF';
            end
            % Comment including the size (used by ctf_add_coil_defs)
            ChannelMat.Channel(i).Comment = sprintf('KIT Planar Gradiometer size = %1.2f  mm base = %1.2f  mm', 1000*header.sensors.channel(i).data.size, 1000*header.sensors.channel(i).data.baseline);
            % Pickup coil
            ChannelMat.Channel(i).Loc = [header.sensors.channel(i).data.x; ...
                                         header.sensors.channel(i).data.y; ...
                                         header.sensors.channel(i).data.z];
            ChannelMat.Channel(i).Orient = [sin(header.sensors.channel(i).data.zdir1 ./ 180 * pi) * cos(header.sensors.channel(i).data.xdir1 ./ 180 * pi); ...
                                            sin(header.sensors.channel(i).data.zdir1 ./ 180 * pi) * sin(header.sensors.channel(i).data.xdir1 ./ 180 * pi); ...
                                            cos(header.sensors.channel(i).data.zdir1 ./ 180 * pi)];
            % "Baseline direction": indicate the vector orientation from the center of the pickup coil to the reference coil
            baselineOrient = [sin(header.sensors.channel(i).data.zdir2 ./ 180 * pi) * cos(header.sensors.channel(i).data.xdir2 ./ 180 * pi); ...
                              sin(header.sensors.channel(i).data.zdir2 ./ 180 * pi) * sin(header.sensors.channel(i).data.xdir2 ./ 180 * pi); ...
                              cos(header.sensors.channel(i).data.zdir2 ./ 180 * pi)];
            % Add reference coil
            ChannelMat.Channel(i).Loc = [ChannelMat.Channel(i).Loc, ...
                                         ChannelMat.Channel(i).Loc + baselineOrient * header.sensors.channel(i).data.baseline];
            ChannelMat.Channel(i).Orient = [ChannelMat.Channel(i).Orient, ChannelMat.Channel(i).Orient];
            % Weight of the two coils
            ChannelMat.Channel(i).Weight = [1, -1];
            nGrad = nGrad + 1;
            
        % === OTHER ===
        case -1   % TriggerChannel
            if ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('Trigger%02d', nTrigger);
            end
            ChannelMat.Channel(i).Type = 'Trigger';
            nTrigger = nTrigger + 1;
            
        case -2   % EegChannel
            if ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('EEG%03d', nEeg);
            end
            ChannelMat.Channel(i).Type = 'EEG';
            ChannelMat.Channel(i).Weight = 1;
            nEeg = nEeg + 1;
            
        case -3   % EcgChannel
            if ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('ECG%d', nEcg);
            end
            ChannelMat.Channel(i).Type = 'ECG';
            nEcg = nEcg + 1;
            
        case -4   % EtcChannel
            if ~isempty(header.sensors.channel(i).data.name)
                ChannelMat.Channel(i).Name = header.sensors.channel(i).data.name;
            else
                ChannelMat.Channel(i).Name = sprintf('Misc%02d', nMisc);
            end
            ChannelMat.Channel(i).Type = 'Misc';
            nMisc = nMisc + 1;
    end
end
% Add definition of sensors
ChannelMat.Channel = ctf_add_coil_defs(ChannelMat.Channel, 'KIT');


%% ===== GET FIDUCIALS =====
% Get coregistration: If the position of the HPI coils is saved, use them as an approximation to the fiducials
if ~isempty(header.coreg) && (header.coreg.done == 1) && ~isempty(header.coreg.hpi)
    % Find the fiducials we need in the list of HPI points 
    iNAS = find(strcmpi({header.coreg.hpi.label}, 'CPF'));
    iLPA = find(strcmpi({header.coreg.hpi.label}, 'LPA'));
    iRPA = find(strcmpi({header.coreg.hpi.label}, 'RPA'));
    % If all of them are available: save them to re-align the MEG on the MRI
    if ~isempty(iNAS) && ~isempty(iLPA) && ~isempty(iRPA) && ...
       ~isempty(header.coreg.hpi(iNAS).meg_pos) && ~isempty(header.coreg.hpi(iLPA).meg_pos) && ~isempty(header.coreg.hpi(iRPA).meg_pos) && ...
       ~all(header.coreg.hpi(iNAS).meg_pos == 0) && ~all(header.coreg.hpi(iLPA).meg_pos == 0) && ~all(header.coreg.hpi(iRPA).meg_pos == 0)
        ChannelMat.SCS.NAS = header.coreg.hpi(iNAS).meg_pos(:)';
        ChannelMat.SCS.LPA = header.coreg.hpi(iLPA).meg_pos(:)';
        ChannelMat.SCS.RPA = header.coreg.hpi(iRPA).meg_pos(:)';
    end
else
    disp('KIT> Warning: The dataset has not been co-registered with the MRI with the Yokogawa/KIT software...');
end

%% ===== GET HEAD POINTS =====
header.isRegistered = 0;
if ~isempty(header.digitize.point)
    % Get all the head points
    ChannelMat.HeadPoints.Loc   = [[header.digitize.point.x]; [header.digitize.point.y]; [header.digitize.point.z]];
    ChannelMat.HeadPoints.Label = deblank({header.digitize.point.name});
    ChannelMat.HeadPoints.Type  = repmat({'EXTRA'}, 1, length(header.digitize.point));
    % Apply transformation: Digitizer => MEG
    ChannelMat.HeadPoints.Loc = header.digitize.info.digitizer2meg(1:3,1:3) * ChannelMat.HeadPoints.Loc;
    ChannelMat.HeadPoints.Loc = bst_bsxfun(@plus, ChannelMat.HeadPoints.Loc, header.digitize.info.digitizer2meg(1:3,4));
    % Detect anatomical matrkers (not the coils)
    iNas = find(strcmpi(ChannelMat.HeadPoints.Label, 'fidnz'));
    iLpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'fidt9'));
    iRpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'fidt10'));
    if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
        ChannelMat.SCS.NAS = ChannelMat.HeadPoints.Loc(:,iNas)';
        ChannelMat.SCS.LPA = ChannelMat.HeadPoints.Loc(:,iLpa)';
        ChannelMat.SCS.RPA = ChannelMat.HeadPoints.Loc(:,iRpa)';
        ChannelMat.HeadPoints.Type{iNas} = 'CARDINAL';
        ChannelMat.HeadPoints.Type{iLpa} = 'CARDINAL';
        ChannelMat.HeadPoints.Type{iRpa} = 'CARDINAL';
        header.isRegistered = 1;
    end
    % Detect EEG electrodes positions in the digitized head points (and remove them from the extra head points)
    iEEG = good_channel(ChannelMat.Channel, [], 'EEG');
    iNoLoc = [];
    for i = 1:length(iEEG)
        iFound = find(strcmpi(ChannelMat.Channel(iEEG(i)).Name, ChannelMat.HeadPoints.Label));
        if ~isempty(iFound)
            ChannelMat.Channel(iEEG(i)).Loc = ChannelMat.HeadPoints.Loc(:,iFound);
        else
            iNoLoc(end+1) = iEEG(i);
        end
    end
    % Change the type of the EEG channels that do not have any location (if some others do)
    if ~isempty(iNoLoc)
        [ChannelMat.Channel(iNoLoc).Type] = deal('EEG_NO_LOC');
    end
end
% Warning if not registered
if ~header.isRegistered
    errMsg = ['This file has not been exported properly from the Yokogawa software.' 10 ...
              'The MEG/MRI co-registration information is missing.' 10 10 ...
              'Please export data by using the "Third Party Export" function in advance.' 10 ...
              'In MegLaboratory this function is available under "Import and export" in the "File" menu.' 10 10 ...
              'Alternatively, you can specify the missing information with three files in the same folder:' 10 ...
              ' - *_Marker1_*/*.mrk: File with extension .mrk or .sqd with the HPI coils in MEG device coordinates.' 10 ...
              ' - *_Points.txt/*.elp: Polhemus file with the fiducials and HPI coils in digitizer coordinates.' 10 ...
              ' - *_HS.txt/*.hsp: Polhemus file with the head shape points in digitizer coordinates.'];
    % Send to the current report
    bst_report('Warning', 'process_import_data_raw', [], errMsg);
end
    

%% ===== REGISTER WITH MRI =====
if isfield(ChannelMat, 'SCS') && ~isempty(ChannelMat.SCS) && ~isempty(ChannelMat.SCS.NAS)
    % Compute transformation
    transfSCS = cs_compute(ChannelMat, 'scs');
    ChannelMat.SCS.R      = transfSCS.R;
    ChannelMat.SCS.T      = transfSCS.T;
    ChannelMat.SCS.Origin = transfSCS.Origin;
    % Convert the fiducials positions
    %   NOTE: The division/multiplication by 1000 is to compensate the T/1000 applied in the cs_convert().
    %         This hack was added becaue cs_convert() is intended to work on sMri structures, 
    %         in which NAS/LPA/RPA/T fields are in millimeters, while in ChannelMat they are in meters.
    ChannelMat.SCS.NAS = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.NAS ./ 1000) .* 1000;
    ChannelMat.SCS.LPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.LPA ./ 1000) .* 1000;
    ChannelMat.SCS.RPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.RPA ./ 1000) .* 1000;
    % Process each sensor
    for i = 1:length(ChannelMat.Channel)
        % Converts the locations to SCS (subject coordinates system)
        if ~isempty(ChannelMat.Channel(i).Loc)
            ChannelMat.Channel(i).Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.Channel(i).Loc' ./ 1000)' .* 1000;
        end
        % Converts the orientations
        if ~isempty(ChannelMat.Channel(i).Orient)
            ChannelMat.Channel(i).Orient = transfSCS.R * ChannelMat.Channel(i).Orient;
        end
    end
    % Process the head points
    if ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Type)
        ChannelMat.HeadPoints.Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.HeadPoints.Loc' ./ 1000)' .* 1000;
    end
    % Add to the list of MEG transformation
    ChannelMat.TransfMeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
    ChannelMat.TransfMegLabels{end+1} = 'Native=>Brainstorm/CTF';
    % Add to the list of EEG transformation
    ChannelMat.TransfEeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
    ChannelMat.TransfEegLabels{end+1} = 'Native=>Brainstorm/CTF';
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename   = RawFile;
sFile.format     = 'KIT';
sFile.device     = ['Yokogawa/KIT ' header.system.model_name];
sFile.comment    = strrep(deblank(header.system.system_name), char(10), ' ');
sFile.byteorder  = 's';
sFile.header     = header;
sFile.channelflag = ones(length(ChannelMat.Channel), 1);


%% ===== READ DATA INFO =====
% Get sampling frequency
sFile.prop.sfreq = double(header.acq.sample_rate);
% Switch depending on the file type
switch (header.acq.acq_type)
    case 1   % AcqTypeContinuousRaw
        sFile.prop.times = [0, header.acq.sample_count - 1] ./ sFile.prop.sfreq;
        sFile.prop.nAvg  = 1;
        
    case 2   % AcqTypeEvokedAve
        sFile.prop.times = ([0, header.acq.frame_length - 1] - header.acq.pretrigger_length) ./ sFile.prop.sfreq;
        sFile.prop.nAvg  = header.acq.average_count;
        % TODO: Use "multi_trigger" field
        
    case 3   % AcqTypeEvokedRaw
        sFile.prop.times = ([0, header.acq.frame_length - 1] - header.acq.pretrigger_length) ./ sFile.prop.sfreq;
        sFile.prop.nAvg  = 1;
        % Get number of epochs
        nEpochs = header.acq.average_count;
        if (nEpochs > 1)
            % Build epochs structure
            for i = 1:nEpochs
                sFile.epochs(i).label = sprintf('Trial (#%d)', i);
                sFile.epochs(i).times       = sFile.prop.times;
                sFile.epochs(i).nAvg        = 1;
                sFile.epochs(i).select      = 1;
                sFile.epochs(i).bad         = 0;
                sFile.epochs(i).channelflag = [];
            end
        end
        % TODO: Use "multi_trigger" field
end


%% ===== EVENTS =====
% Read file
events = in_events_kit(sFile, sFile.filename);
% Copy events to returned structure
sFile.events = events;

end



%% ===== HELPER FUNCTIONS ========================================================
%  ===============================================================================

%% ===== FASTSCAN: READ POINTS =====
function [xyz, HeadPoints] = ReadPolhemus(FileName, isHeadShape)
    xyz = [];
    HeadPoints = [];
    % Get format
    [fPath, fBase, fExt] = bst_fileparts(FileName);
    switch lower(fExt)
        % Old FastScan
        case '.txt'
            % Open file
            fid = fopen(FileName, 'r');
            if (fid < 0)
                error(['Cannot open file: ' FileName]);
            end
            % Store everything in a cell array of string
            txtCell = textscan(fid, '%f%f%f', 'Delimiter', '\n', 'CommentStyle', '%');
            % Close file
            fclose(fid);
            % Convert to millimeters
            xyz = [txtCell{1}, txtCell{2}, txtCell{3}]' ./ 1000;
        % New Polhemus format
        case {'.elp', '.hsp'}
            ChannelMat = in_channel_emse_elp(FileName);
            if isHeadShape
                xyz = [ChannelMat.HeadPoints.Loc];
            else
                xyz = [ChannelMat.Channel.Loc];
            end
    end
end


% %% ===== KIT: READ COREG =====
% % NOT USED: USING YOKOGAWA FUNCTION INSTEAD
% function coreg = KitReadCoreg(KitFile)
%     % Initialize returned structure
%     coreg = struct();
%     % Open file
%     fid = fopen(KitFile, 'r');
%     if (fid < 0)
%         error(['Cannot open file: ' KitFile]);
%     end
%     % Read marker offset
%     KIT_MRK_INFO = 192;
%     fseek(fid, KIT_MRK_INFO, 'bof');
%     markerOffset = fread(fid, 1, 'int32');
%     fseek(fid, markerOffset, 'bof');
%     % Read registration information
%     coreg.done     = fread(fid, 1, 'int32');
%     coreg.meg2mri  = fread(fid, [4,4], 'double')';
%     coreg.mri2meg  = fread(fid, [4,4], 'double')';
%     nMarkers = fread(fid, 1, 'int32');
%     if (nMarkers == 5)
%         HpiLabels = {'LPA', 'RPA', 'CPF', 'LPF', 'RPF'};
%     else
%         HpiLabels = []; % How to get the labels???
%     end
%     % Read all the markers
%     for iMrk = 1:nMarkers
%         unused = fread(fid, [1 4], 'int32');
%         coreg.hpi(iMrk).mri_pos = fread(fid, [1 3], 'double');
%         coreg.hpi(iMrk).meg_pos = fread(fid, [1 3], 'double');
%         if ~isempty(HpiLabels)
%             coreg.hpi(iMrk).label = HpiLabels{iMrk};
%         else
%             coreg.hpi(iMrk).label = 'unknown';
%         end
%     end
%     % Skipping all the other fields
%     % Close file
%     fclose(fid);
% end


