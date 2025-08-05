function [isSuccess, OutFilesMri, OutFilesMeg] = bst_save_coregistration(iSubjects, isBids, RecreateMegCoordJson)
    % Save MRI-MEG coregistration info in imported raw BIDS dataset, or MRI fiducials only if not BIDS.
    % IMPORTANT: isSuccess currently not working, can often be true despite skipping studies or subjects.
    %
    %   [isSuccess, OutFilesMri, OutFilesMeg] = bst_save_coregistration(iSubjects, isBids=<detect>)
    % 
    % Save MRI-MEG coregistration by adding AnatomicalLandmarkCoordinates to the
    % _T1w.json MRI metadata, in 0-indexed voxel coordinates, and to the
    % _coordsystem.json files for functional data, in native coordinates (e.g. CTF).
    % The points used are the anatomical fiducials marked in Brainstorm on the MRI
    % that define the Brainstorm subject coordinate system (SCS).
    %
    % RecreateMegCoordJson: if true, this file will be deleted and recreated with
    % BidsBuildRecordingFiles before adding coregistration info to it (was added because fiducial
    % descriptions were updated).
    %
    % If the raw data is not BIDS, the anatomical fiducials are saved in a
    % fiducials.m file next to the raw MRI file, in Brainstorm MRI coordinates.
    %
    % Discussion about saving MRI-MEG coregistration in BIDS:
    % https://groups.google.com/g/bids-discussion/c/BeyUeuNGl7I

    if nargin < 3 || isempty(RecreateMegCoordJson)
        RecreateMegCoordJson = false;
    end
    if nargin < 2 || isempty(isBids)
        isBids = [];
    end
    sSubjects = bst_get('ProtocolSubjects');
    if nargin < 1 || isempty(iSubjects)
        % Try to get all subjects from currently loaded protocol.
        nSub = numel(sSubjects.Subject);
        iSubjects = 1:nSub;
    else
        nSub = numel(iSubjects);
    end

    bst_progress('start', 'Save co-registration', ' ', 0, nSub);

    % Avoid useless warnings. I don't understand why they warn about this, a cell of char vectors is what I want.
    warning('off', 'MATLAB:table:PreallocateCharWarning'); 

    OutFilesMri = cell(nSub, 1);
    OutFilesMeg = cell(nSub, 1);
    isSuccess = false(nSub, 1);
    BidsRoot = '';
    for iOutSub = 1:nSub
        iSub = iSubjects(iOutSub);
        fprintf('%3d %s\n', iSub, sSubjects.Subject(iSub).Name);
        % Get anatomical file.
        if ~contains(sSubjects.Subject(iSub).Anatomy(sSubjects.Subject(iSub).iAnatomy).Comment, 'MRI', 'ignorecase', true) && ...
                ~contains(sSubjects.Subject(iSub).Anatomy(sSubjects.Subject(iSub).iAnatomy).Comment, 't1w', 'ignorecase', true)
            warning('Selected anatomy is not ''MRI''. Skipping subject %s.', sSubjects.Subject(iSub).Name);
            continue;
        end
        sMri = load(file_fullpath(sSubjects.Subject(iSub).Anatomy(sSubjects.Subject(iSub).iAnatomy).FileName));
        ImportedFile = strrep(sMri.History{1,3}, 'Import from: ', '');
        if ~exist(ImportedFile, 'file')
            warning('Imported anatomy file not found. Skipping subject %s.', sSubjects.Subject(iSub).Name);
            continue;
        end
        % Get all linked raw data files.
        sStudies = bst_get('StudyWithSubject', sSubjects.Subject(iSub).FileName);
        if isempty(isBids)
            % Try to find root BIDS folder.
            BidsRoot = bst_fileparts(bst_fileparts(ImportedFile)); % go back through "anat" and subject folders at least (session not mandatory).
            isBids = true; % changed if not found below
            while ~exist(fullfile(BidsRoot, 'dataset_description.json'), 'file')
                if isempty(BidsRoot) || ~exist(BidsRoot, 'dir')
                    isBids = false;
                    fprintf('BST> bst_save_coregistration detected that raw imported data is NOT structured as BIDS.');
                    break;
                end
                BidsRoot = bst_fileparts(BidsRoot);
            end
        end
        if isBids
            if isempty(BidsRoot)
                BidsRoot = bst_fileparts(bst_fileparts(ImportedFile)); % go back through "anat" and subject folders at least (session not mandatory).
                while ~exist(fullfile(BidsRoot, 'dataset_description.json'), 'file')
                    if isempty(BidsRoot) || ~exist(BidsRoot, 'dir')
                        error('Cannot find BIDS root folder and dataset_description.json file; subject %s.', sSubjects.Subject(iSub).Name);
                    end
                    BidsRoot = bst_fileparts(BidsRoot);
                end
            end

            % MRI _t1w.json
            % Save anatomical landmarks in Nifti voxel coordinates
            [MriPath, MriName, MriExt] = bst_fileparts(ImportedFile);
            if strcmpi(MriExt, '.gz')
                [~, MriName, MriExt2] = fileparts(MriName);
                MriExt = [MriExt2, MriExt]; %#ok<AGROW>
            end
            if ~strncmpi(MriExt, '.nii', 4)
                warning('Imported anatomy not BIDS. Skipping subject %s.', sSubjects.Subject(iSub).Name);
                continue;
            end
            MriJsonFile = fullfile(MriPath, [MriName, '.json']);
            if ~exist(MriJsonFile, 'file')
                warning('Imported anatomy BIDS json file not found for subject %s. Creating new file.', sSubjects.Subject(iSub).Name);
                sMriJson = struct();
            else
                sMriJson = bst_jsondecode(MriJsonFile, false);
                % Make backup in derivatives folder.
                BakMriJsonFile = replace(MriJsonFile, BidsRoot, fullfile(BidsRoot, 'derivatives'));
                if ~exist(BakMriJsonFile, 'file')
                    BakFolder = fileparts(BakMriJsonFile);
                    if ~exist(BakFolder, 'dir')
                        [isOk, Msg] = mkdir(BakFolder);
                        if ~isOk, warning(Msg); end
                        if ~exist(BakFolder, 'dir')
                            warning('Unable to create backup folder %s. Skipping subject %s.', BakFolder, sSubjects.Subject(iSub).Name);
                            continue;
                        end
                    end
                    [isOk, Msg] = copyfile(MriJsonFile, BakMriJsonFile);
                    if ~isOk, warning(Msg); end
                    if ~exist(BakMriJsonFile, 'file')
                        warning('Unable to back up anatomy BIDS json file. Skipping subject %s.', sSubjects.Subject(iSub).Name);
                        continue;
                    end
                end
            end
            % We ignore other fiducials after the 3 we use for coregistration.
            % These were likely not placed well, only automatically by initial
            % linear template alignment.
            BstFids = {'NAS', 'LPA', 'RPA'}; %, 'AC', 'PC', 'IH'};
            % We need to go to original Nifti voxel coordinates, but Brainstorm may have
            % flipped/permuted dimensions to bring voxels to RAS orientation.  If it did, it modified
            % all sMRI fields accordingly, including under .Header, and it saved the transformation
            % under .InitTransf 'reorient'.
            iTransf = find(strcmpi(sMri.InitTransf(:,1), 'reorient'));
            if ~isempty(iTransf)
                tReorient = sMri.InitTransf{iTransf(1),2};  % Voxel 0-based transformation, from original to Brainstorm
                tReorientInv = inv(tReorient);
                tReorientInv(4,:) = [];
            end

            if isfield(sMriJson, 'AnatomicalLandmarkCoordinates')
                isPrevJsonLandmarks = true;
                % Remove previous landmarks regardless. The existing backup in derivatives may or
                % may not have those - only one original backup is kept - but no practical use in
                % keeping multiple previous aligments.
                % Set empty instead of removing field, so that it keeps its order. Could use
                % orderfields, but more complicated when list of fields differ (set diff first but need all fields).
                % sMriJson = rmfield(sMriJson, 'AnatomicalLandmarkCoordinates');
                sMriJson.AnatomicalLandmarkCoordinates = []; 
            else
                isPrevJsonLandmarks = false;
            end
            isLandmarksFound = true;
            for iFid = 1:numel(BstFids)
                if iFid < 4
                    CS = 'SCS';
                else
                    CS = 'NCS';
                end
                Fid = BstFids{iFid};
                % Voxel coordinates (Nifti: 0-indexed, but orientation not standardized, world coords are RAS)
                % Bst MRI coordinates are in mm and voxels are 1-indexed, so subtract 1 voxel after going from mm to voxels.
                if isfield(sMri, CS) && isfield(sMri.(CS), Fid) && ~isempty(sMri.(CS).(Fid)) && any(sMri.(CS).(Fid))
                    % Round to 0.001 voxel.
                    % Voxsize has 3 elements, ok for non-isotropic voxel size
                    FidCoord = round(1000 * (sMri.(CS).(Fid)./sMri.Voxsize - 1)) / 1000;
                    if ~isempty(iTransf)
                        % Go from Brainstorm RAS-oriented voxels, back to original Nifti voxel orientation.
                        % Both are 0-indexed in this transform.
                        FidCoord = [FidCoord, 1] * tReorientInv';
                    end
                    sMriJson.AnatomicalLandmarkCoordinates.(Fid) = FidCoord;
                else
                    isLandmarksFound = false;
                    break;
                end
            end
            if ~isLandmarksFound
                if isPrevJsonLandmarks
                    warning('MRI landmark coordinates not found, but previously saved in T1w.json file. Removing field and skipping subject %s.', sSubjects.Subject(iSub).Name);
                else
                    warning('MRI landmark coordinates not found. Skipping subject %s.', sSubjects.Subject(iSub).Name);
                end
                % In case some were found but not all, just remove them all again.
                sMriJson.AnatomicalLandmarkCoordinates = [];
            elseif isPrevJsonLandmarks
                fprintf('Replacing previous MRI landmark coordinates for subject %s.\n', sSubjects.Subject(iSub).Name);
            end
            % Remove field if empty. There are no other anat landmark fields in MRI json (as opposed to MEG, see below).
            if isempty(sMriJson.AnatomicalLandmarkCoordinates)
                sMriJson = rmfield(sMriJson, 'AnatomicalLandmarkCoordinates');
            end
            WriteJson(MriJsonFile, sMriJson);
            OutFilesMri{iOutSub} = MriJsonFile;
            if ~isLandmarksFound
                continue;
            end


            % --------------------------------------------------------------------------------------
            % MEG _coordsystem.json
            % Save MRI anatomical landmarks in SCS coordinates and link to MRI.
            % This includes coregistration refinement using head points, if used.

            % Convert from mri to scs.
            for iFid = 1:3
                Fid = BstFids{iFid};
                % cs_convert mri is in meters
                sMriScs.SCS.(Fid) = cs_convert(sMri, 'mri', 'scs', sMri.SCS.(Fid) ./ 1000);
            end
            sMriNative = sMriScs; % transformed below

            % MEG _coordsystem.json are shared between studies (recordings) within a session. 
            % Get a list of: (studies >) channel files and (linked original MEG recordings >) json.
            % For each unique json, update with first channel file, and check consistency of each
            % additional channel file.
            MegList = table('Size', [0, 3], 'VariableNames', {'CoordJson', 'Channel', 'Recording'}, 'VariableTypes', {'char', 'char', 'char'});
            for iStudy = 1:numel(sStudies)
                % Try to find the first link to raw file in this study.
                isLinkToRaw = false;
                for iData = 1:numel(sStudies(iStudy).Data)
                    if strcmpi(sStudies(iStudy).Data(iData).DataType, 'raw')
                        isLinkToRaw = true;
                        break;
                    end
                end
                % Skip study if no raw file found.
                if ~isLinkToRaw
                    continue;
                end
                Recording = load(file_fullpath(sStudies(iStudy).Data(iData).FileName));
                Recording = Recording.F.filename;
                % Skip empty-room noise recordings
                if contains(Recording, 'sub-emptyroom') || contains(Recording, 'task-noise')
                    % No warning, just skip.
                    continue;
                end
                % Skip if original MEG file not found.
                if ~exist(Recording, 'file')
                    warning('Missing original raw MEG file. Skipping study %s.', Recording);
                    continue;
                end

                % Find MEG _coordsystem.json, should be 1 per session.
                if strcmpi(Recording(end-4:end), '.meg4')
                    Recording = fileparts(Recording);
                end
                MegPath = fileparts(Recording);
                MegCoordJsonFile = dir(fullfile(MegPath, '*_coordsystem.json'));
                % Skip if MEG json file not found, or more than one.
                if isempty(MegCoordJsonFile)
                    warning('MEG BIDS _coordsystem.json file not found. Skipping study %s.', Recording);
                    continue;
                elseif numel(MegCoordJsonFile) > 1
                    warning('MEG BIDS issue: found multiple _coordsystem.json files. Skipping study %s.', Recording);
                    continue;
                end
                % Add to be processed.
                MegList(end+1, :) = {fullfile(MegCoordJsonFile.folder, MegCoordJsonFile.name), ...
                    sStudies(iStudy).Channel.FileName, Recording}; %#ok<AGROW>
            end

            % Sort and unique table rows
            MegList = unique(MegList, 'rows');
            nChan = size(MegList, 1);
            ChanNativeTransf = zeros(3, 4);
            iOutMeg = 0;
            for iChan = 1:nChan
                ChannelMat = in_bst_channel(MegList.Channel{iChan});
                % ChannelMat.SCS are *digitized* anatomical landmarks (if present, otherwise might be
                % digitized head coils) in Brainstorm/SCS coordinates (defined as CTF but with
                % anatomical landmarks). They are NOT updated after refining with head points, so we
                % don't rely on them but use those saved in sMri, and update them now with
                % UpdateChannelMatScs.
                %
                % We applied MRI=>SCS (from sMri) to the MRI anat landmarks above, and now need to apply
                % SCS=>Native (from ChannelMat). We ignore head motion related adjustments, which are
                % dataset specific. We need original raw Native coordinates.  UpdateChannelMatScs also
                % adds a "Native" copy of .SCS, which represents the digitized anatomical fiducials in
                % Native coordinates. Here we just use the transformation, as we want the MRI anat
                % fids, not the digitized ones (which can be different if another session).
                ChannelMat = process_adjust_coordinates('UpdateChannelMatScs', ChannelMat);
                % If no digitization, native transformation will be missing. Could warn and use
                % identity, assuming MRI fids actually match the head coils, not anatomical points.
                % But we would still need to modify the descriptions to indicate the points are
                % coils, which can only be true if there was no previous session with points - and
                % we should therefore check that. For now, just warn and move on.
                % TODO: button to display initial MEG coils as fid points on coreg edit figure.
                if ~isfield(ChannelMat, 'Native')
                    %warning('Could not get native transformation, which possibly indicates missing digitized head points. Assuming that MRI fiducials are then actually head coils and not anatomical points, as is customary without digitized points. %s', MegList.Channel{iChan});
                    %ChanNativeTransf = [eye(3) zeros(3,1)];
                    warning('Could not get native transformation, which possibly indicates missing digitized head points. For single session, coregistration could be saved with head coils on MRI, but this is not yet implemented here. %s', MegList.Channel{iChan});
                    continue;
                end
                    
                % If same json as previous, just check consistency and continue.
                if iChan > 1 && strcmp(MegList.CoordJson{iChan}, MegList.CoordJson{iChan-1})
                    % Verify that SCS>Native transformation matches previous channel file for
                    % this same session.
                    if any(abs(ChanNativeTransf(:) - [ChannelMat.Native.R(:); ChannelMat.Native.T(:)]) > 1e-6)
                        warning('Inconsistent alignment within MEG session, SCS>Native different than previous channel files: %s', MegList.Channel{iChan})
                    end
                    continue;
                end

                % TODO, TEMPORARY HACK: we've only coregistered the first session for each subject so far.
                % Skip other sessions.
                % if iChan > 1 % implies not first session here
                %     % Skipping other sessions.
                %     break;
                % end

                % New json, store SCS>Native transformation to compare with next channel files in this session.
                ChanNativeTransf = [ChannelMat.Native.R, ChannelMat.Native.T];

                % Convert MRI fids from (possibly adjusted) SCS to Native, and m to cm.
                for iFid = 1:3
                    Fid = BstFids{iFid};
                    sMriNative.SCS.(Fid)(:) = 100 * ChanNativeTransf * [sMriScs.SCS.(Fid)'; 1];
                    % Round to um.
                    sMriNative.SCS.(Fid) = round(sMriNative.SCS.(Fid) * 10000) / 10000;
                end

                % Check MRI-digitized anat fids match, and prepare values.
                % The description here will be appended to what already describes the coils and anat
                % fids, which should explain cases when one or the other are missing.  The wording
                % added here is valid for these cases, though this could be slightly confusing (yet
                % should be inconsequential).
                [~, isMriUpdated, isMriMatch, isSessionMatch] = process_adjust_coordinates('CheckPrevAdjustments', ChannelMat, sMri);
                if ~isMriUpdated
                    % For now we skip if the mri was not updated, as this is our workflow for coreg.
                    warning('MRI landmarks have not been updated. This is unexpected in our current workflow and should be verified. Study %s.', Recording);
                    %continue; % Don't skip, we had one participant where the initial fids were good!
                end
                if ~isMriMatch && isSessionMatch 
                    % The sMri and digitized anat fids match in terms of shape, but they are not
                    % aligned. Probably some other alignment was performed after updating the sMri.
                    % This is unexpected and should be checked.
                    warning('MRI and digitized anat fids are from the same session, but not aligned. This is unexpected and should be verified. Skipping study %s.', Recording);
                    continue;
                end
                IntendedForMri = strrep(ImportedFile, [BidsRoot filesep], 'bids::');

                % Make backup in derivatives folder. May not be very useful since it can be
                % recreated easily except for coreg data which is not yet saved.
                BakMegJsonFile = replace(MegList.CoordJson{iChan}, BidsRoot, fullfile(BidsRoot, 'derivatives'));
                if ~exist(BakMegJsonFile, 'file')
                    BakFolder = fileparts(BakMegJsonFile);
                    if ~exist(BakFolder, 'dir')
                        [isOk, Msg] = mkdir(BakFolder);
                        if ~isOk, warning(Msg); end
                        if ~exist(BakFolder, 'dir')
                            warning('Unable to create backup folder %s. Skipping session.', BakFolder);
                            continue;
                        end
                    end
                    [isOk, Msg] = copyfile(MegList.CoordJson{iChan}, BakMegJsonFile);
                    if ~isOk, warning(Msg); end
                    if ~exist(BakMegJsonFile, 'file')
                        warning('Unable to back up MEG coordinates BIDS json file. Skipping session %s.', MegList.CoordJson{iChan});
                        continue;
                    end
                end
                % Load existing json
                sMegJson = bst_jsondecode(MegList.CoordJson{iChan});
                % Update MEG json file.
                % Possibly fully recreate the content, e.g. if descriptions were updated.
                if RecreateMegCoordJson
                    % EEG may not be present in all runs, so check if it was there
                    if isfield(sMegJson, 'EEGCoordinateSystem')
                        isEeg = true;
                    else
                        isEeg = false;
                    end
                    [~, BidsInfo] = BidsParseRecordingName(MegList.Recording{iChan}, [], false);
                    sMegJson = BidsBuildRecordingFiles(MegList.Recording{iChan}, BidsInfo, [], false); % Don't save, will just output structure.
                    % Keep only content of _coordsystem.json
                    sMegJson = sMegJson.CoordSystem;
                    if ~isfield(sMegJson, 'EEGCoordinateSystem') && isEeg
                        % Double check digitized points are present, but should be the case.
                        if ~isfield(sMegJson, 'DigitizedHeadPointsCoordinateSystem')
                            warning('EEG were present, but no head points when trying to recreate %s', MegList.CoordJson{iChan});
                        else
                            % Add back
                            sMegJson.EEGCoordinateSystem = sMegJson.DigitizedHeadPointsCoordinateSystem;
                            sMegJson.EEGCoordinateUnits = sMegJson.DigitizedHeadPointsCoordinateUnits;
                            sMegJson.EEGCoordinateSystemDescription = sMegJson.DigitizedHeadPointsCoordinateSystemDescription;
                        end
                    end
                end
                % Check if the coreg was done with anat or coils, before adding or modifying anat.
                isAnatFids = isfield(sMegJson, 'AnatomicalLandmarkCoordinates');
                if isMriMatch % implies session matches
                    if isAnatFids
                        LandmarkDescrip = 'They correspond to digitized landmarks from this session. ';
                    else
                        LandmarkDescrip = 'They correspond to digitized head coils from this session, as no anatomical landmarks were digitized. They are still named NAS/LPA/RPA for consistency throughout this dataset, therefore simplifying importing coregistration info. ';
                    end
                elseif ~isSessionMatch
                    % We still use the sMri fids, whether they were updated (different session) or not.
                    LandmarkDescrip = 'They correspond to a set of digitized landmarks from another session, used for coregistration for this subject. They are usually anatomical points, but sometimes head coils in older data. ';
                end
                AddFidDescrip = [' The anatomical landmarks saved here match those in the associated T1w image (see IntendedFor field). ', ...
                    LandmarkDescrip, ...
                    'Coregistration with the T1w image was performed with Brainstorm before defacing, ', ...
                    'initially with an automatic procedure fitting head points to the scalp surface, but ', ...
                    'often adjusted manually, and validated with pictures of MEG head coils on the participant when available. ', ...
                    'As such, these landmarks and the corresponding alignment should be preferred.'];
                % Remove previous coordinates, though for MEG it may never get saved unless it's filled below.
                % Still good practice in case it was done wrong previously (e.g. bad field names)
                % Set empty instead of removing field, so that it keeps its order. Could use
                % orderfields, but more complicated when list of fields differ (set diff first but need all fields).
                sMegJson.AnatomicalLandmarkCoordinates = []; 
                % Here we want to only point to the aligned MRI, even if there are multiple MRIs in
                % this BIDS subject and they were all listed. But inform about any change.
                if isfield(sMegJson, 'IntendedFor') && ~isempty(sMegJson.IntendedFor)
                    if iscell(sMegJson.IntendedFor)
                        if numel(sMegJson.IntendedFor)
                            fprintf('Replaced "IntendedFor" MEG json field (had multiple). %s\n', MegList.CoordJson{iChan});
                            sMegJson.IntendedFor = IntendedForMri; % to simplify following checks, but we do it again below for every case.
                        else % single cell; we don't expect this case
                            sMegJson.IntendedFor = sMegJson.IntendedFor{1};
                        end
                    end
                    % Check if it's different and not just the new BIDS path convention.
                    if ~strcmpi(sMegJson.IntendedFor, IntendedForMri) && ...
                            ~contains(sMegJson.IntendedFor, strrep(IntendedForMri, 'bids::', ''))
                        fprintf('Replaced "IntendedFor" MEG json field: %s > %s in %s\n', sMegJson.IntendedFor, IntendedForMri, MegList.CoordJson{iChan});
                    end
                end
                % Save the single aligned MRI.
                sMegJson.IntendedFor = IntendedForMri;
                % Save native coordinates (rounded to um above).
                for iFid = 1:3
                    Fid = BstFids{iFid};
                    sMegJson.AnatomicalLandmarkCoordinates.(Fid) = sMriNative.SCS.(Fid);
                end
                if ~isfield(sMegJson, 'HeadCoilCoordinateSystem')
                    warning('No head coils when trying to copy for anat landmark system fields %s', MegList.CoordJson{iChan});
                else
                    sMegJson.AnatomicalLandmarkCoordinateSystem = sMegJson.HeadCoilCoordinateSystem;
                    sMegJson.AnatomicalLandmarkCoordinateUnits = sMegJson.HeadCoilCoordinateUnits;
                    sMegJson.AnatomicalLandmarkCoordinateSystemDescription = sMegJson.HeadCoilCoordinateSystemDescription;
                end
                % System descriptions are saved in BidsBuildRecordingFiles.                
                
                if ~isfield(sMegJson, 'FiducialsDescription')
                    sMegJson.FiducialsDescription = '';
                end
                % Append description, if not already there.
                if isempty(strfind(sMegJson.FiducialsDescription, AddFidDescrip))
                    % Remove possibly inaccurate description of anat fids from other session.
                    if ~isSessionMatch
                        % This regexp matches the given words, followed by max number of non-period characters, then a period (escaped) '\.', and 0 or 1 space ' ?'
                        sMegJson.FiducialsDescription = regexprep(sMegJson.FiducialsDescription, 'The anatomical landmarks[^.]*\. ?', '');
                    end
                    sMegJson.FiducialsDescription = strtrim([sMegJson.FiducialsDescription, AddFidDescrip]);
                end
                % Remove fields if anat coords empty, though should not really happen.
                if isempty(sMegJson.AnatomicalLandmarkCoordinates)
                    AnatLandmarkFields = {'AnatomicalLandmarkCoordinates', 'AnatomicalLandmarkCoordinateSystem', 'AnatomicalLandmarkCoordinateUnits', 'AnatomicalLandmarkCoordinateSystemDescription'};
                    isFieldFound = ismember(AnatLandmarkFields, fieldnames(sMriJson));
                    sMriJson = rmfield(sMriJson, AnatLandmarkFields(isFieldFound));
                    warning('No anat landmark coordinates in %s\n', MegList.CoordJson{iChan});
                end
                % Reorder fields according to this full list of all possible fields.
                CoordJsonFields = {'MEGCoordinateSystem', 'MEGCoordinateUnits', 'MEGCoordinateSystemDescription', ...
                    'EEGCoordinateSystem', 'EEGCoordinateUnits', 'EEGCoordinateSystemDescription', ...
                    'DigitizedHeadPoints', 'DigitizedHeadPointsCoordinateSystem', 'DigitizedHeadPointsCoordinateUnits', 'DigitizedHeadPointsCoordinateSystemDescription', ...
                    'HeadCoilCoordinates', 'HeadCoilCoordinateSystem', 'HeadCoilCoordinateUnits', 'HeadCoilCoordinateSystemDescription', ...
                    'AnatomicalLandmarkCoordinates', 'AnatomicalLandmarkCoordinateSystem', 'AnatomicalLandmarkCoordinateUnits', 'AnatomicalLandmarkCoordinateSystemDescription', ...
                    'FiducialsDescription', 'IntendedFor'};
                % But we must give a matching list, no extras.
                sMegJson = orderfields(sMegJson, CoordJsonFields(ismember(CoordJsonFields, fieldnames(sMegJson))));
                % Save
                WriteJson(MegList.CoordJson{iChan}, sMegJson);
                iOutMeg = iOutMeg + 1;
                OutFilesMeg{iOutSub}{iOutMeg} = MegList.CoordJson{iChan};
            end % channel file (studies/sessions) loop
        else
            % Not BIDS, save in fiducials.m file.
            FidsFile = fullfile(bst_fileparts(ImportedFile), 'fiducials.m');
            FidsFile = figure_mri('SaveFiducialsFile', sMri, FidsFile);
            if ~exist(FidsFile, 'file')
                warning('Fiducials.m file not written for subject %s.', sSubjects.Subject(iSub).Name);
                continue;
            end
            OutFilesMri{iOutSub} = FidsFile;
        end

        isSuccess(iOutSub) = true;
        bst_progress('inc', 1);
    end % subject loop

    bst_progress('stop');

end


