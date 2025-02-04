function [isSuccess, OutFilesMri, OutFilesMeg] = bst_save_coregistration(iSubjects, isBids)
    % Save MRI-MEG coregistration info in imported raw BIDS dataset, or MRI fiducials only if not BIDS.
    %
    % Save MRI-MEG coregistration by adding AnatomicalLandmarkCoordinates to the
    % _T1w.json MRI metadata, in 0-indexed voxel coordinates, and to the
    % _coordsystem.json files for functional data, in native coordinates (e.g. CTF).
    % The points used are the anatomical fiducials marked in Brainstorm on the MRI
    % that define the Brainstorm subject coordinate system (SCS).
    %
    % If the raw data is not BIDS, the anatomical fiducials are saved in a
    % fiducials.m file next to the raw MRI file, in Brainstorm MRI coordinates.
    %
    % Discussion about saving MRI-MEG coregistration in BIDS:
    % https://groups.google.com/g/bids-discussion/c/BeyUeuNGl7I

    if nargin < 2 || isempty(isBids)
        isBids = false;
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

    OutFilesMri = cell(nSub, 1);
    OutFilesMeg = cell(nSub, 1);
    isSuccess = false(nSub, 1);
    BidsRoot = '';
    for iOutSub = 1:nSub
        iSub = iSubjects(iOutSub);
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
                warning('Imported anatomy BIDS json file not found. Skipping subject %s.', sSubjects.Subject(iSub).Name);
                continue;
            end
            sMriJson = bst_jsondecode(MriJsonFile, false);
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
                warning('MRI landmark coordinates not found. Skipping subject %s.', sSubjects.Subject(iSub).Name);
                continue;
            end
            WriteJson(MriJsonFile, sMriJson);
            OutFilesMri{iOutSub} = MriJsonFile;

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
            MegList = table('VariableNames', {'CoordJson', 'Channel'}, 'VariableTypes', {'char', 'char'});
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
                % Skip if original MEG file not found.
                if ~exist(Recording, 'file')
                    warning('Missing original raw MEG file. Skipping study %s.', Recording);
                    continue;
                end
                % Skip empty-room noise recordings
                if contains(Recording, 'sub-emptyroom') || contains(Recording, 'task-noise')
                    % No warning, just skip.
                    continue;
                end

                % Find MEG _coordsystem.json, should be 1 per session.
                [MegPath, ~, MegExt] = fileparts(Recording);
                if strcmpi(MegExt, '.meg4')
                    MegPath = fileparts(MegPath);
                end
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
                    sStudies(iStudy).Channel.FileName}; %#ok<AGROW>
            end

            % Sort and unique table rows
            MegList = unique(MegList, 'rows');
            nChan = size(MegList, 1);
            ChanNativeTransf = zeros(3, 4);
            iOutMeg = 0;
            for iChan = 1:nChan
                ChannelMat = in_bst_channel(MegList.Channel(iChan));
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

                % If same json as previous, just check consistency and continue.
                if iChan > 1 && strcmp(MegList.CoordJson(iChan), MegList.CoordJson(iChan-1))
                    % Verify that SCS>Native transformation matches previous channel file for
                    % this same session.
                    if any(abs(ChanNativeTransf - [ChannelMat.Native.R, ChannelMat.Native.T]) > 1e-6)
                        warning('Inconsistent alignment within MEG session, SCS>Native different than previous channel files: %s', MegList.Channel(iChan))
                    end
                    continue;
                end

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
                [~, isMriUpdated, isMriMatch, isSessionMatch] = process_adjust_coordinates('CheckPrevAdjustments', ChannelMat, sMri);
                if isMriUpdated && isMriMatch % implies session matches
                    AddFidDescrip = ' The anatomical landmarks saved here match those in the associated T1w image (see IntendedFor field). They correspond to the anatomical landmarks from the digitized head points, averaged if measured more than once. Coregistration with the T1w image was performed with Brainstorm before defacing, initially with an automatic procedure fitting head points to the scalp surface, but often adjusted manually, and validated with pictures of MEG head coils on the participant. As such, these landmarks and the corresponding alignment should be preferred.';
                elseif ~isSessionMatch
                    % We still use the sMri fids, whether they were updated (different session) or not.
                    AddFidDescrip = ' The anatomical landmarks saved here match those in the associated T1w image (see IntendedFor field). They do not correspond to the digitized landmarks from this session. Coregistration with the T1w image was performed with Brainstorm before defacing, initially with an automatic procedure fitting head points to the scalp surface, but often adjusted manually, and validated with pictures of MEG head coils on the participant. As such, these landmarks and the corresponding alignment should be preferred.';
                elseif ~isMriMatch && isSessionMatch % practically implies isMriUpdated
                    % The sMri and digitized anat fids match in terms of shape, but they are not
                    % aligned. Probably some other alignment was performed after updating the sMri.
                    % This is unexpected and should be checked.
                    warning('MRI and digitized anat fids are from the same session, but not aligned. This is unexpected and should be verified. Skipping study %s.', Recording.F.filename);
                    continue;
                end
                IntendedForMri = strrep(ImportedFile, [BidsRoot filesep], 'bids::');

                % Update MEG json file.
                sMegJson = bst_jsondecode(MegList.CoordJson(iChan));
                % Here we want to only point to the aligned MRI, even if there are multiple MRIs in
                % this BIDS subject and they were all listed. But inform about any change.
                if isfield(sMegJson, 'IntendedFor') && ~isempty(sMegJson.IntendedFor)
                    if iscell(sMegJson.IntendedFor)
                        if numel(sMegJson.IntendedFor)
                            fprintf('Replaced "IntendedFor" MEG json field (had multiple). %s\n', MegList.CoordJson(iChan));
                            sMegJson.IntendedFor = IntendedForMri; % to simplify following checks, but we do it again below for every case.
                        else % single cell; we don't expect this case
                            sMegJson.IntendedFor = sMegJson.IntendedFor{1};
                        end
                    end
                    % Check if it's different and not just the new BIDS path convention.
                    if ~strcmpi(sMegJson.IntendedFor, IntendedForMri) && ...
                            ~contains(sMegJson.IntendedFor, strrep(IntendedForMri, 'bids::', ''))
                        fprintf('Replaced "IntendedFor" MEG json field: %s > %s in %s\n', sMegJson.IntendedFor, IntendedForMri, MegList.CoordJson(iChan));
                    end
                end
                % Save the single aligned MRI.
                sMegJson.IntendedFor = IntendedForMri;
                % Save native coordinates (rounded to um above).
                for iFid = 1:3
                    Fid = BstFids{iFid};
                    sMegJson.AnatomicalLandmarkCoordinates.(Fid) = sMriNative.SCS.(Fid);
                end
                sMegJson.AnatomicalLandmarkCoordinateSystem = 'CTF';
                sMegJson.AnatomicalLandmarkCoordinateUnits = 'cm';
                %sMegJson.AnatomicalLandmarkCoordinateSystemDescription = 'Based on the digitized locations of the head coils. The origin is exactly between the left ear head coil (coilL near LPA) and the right ear head coil (coilR near RPA); the X-axis goes towards the nasion head coil (coilN near NAS); the Y-axis goes approximately towards coilL, orthogonal to X and in the plane spanned by the 3 head coils; the Z-axis goes approximately towards the vertex, orthogonal to X and Y';
                %sMegJson.HeadCoilCoordinateSystemDescription = sMegJson.AnatomicalLandmarkCoordinateSystemDescription;
                if ~isfield(sMegJson, 'FiducialsDescription')
                    sMegJson.FiducialsDescription = '';
                end
                if isempty(strfind(sMegJson.FiducialsDescription, AddFidDescrip))
                    sMegJson.FiducialsDescription = strtrim([sMegJson.FiducialsDescription, AddFidDescrip]);
                end
                WriteJson(MegList.CoordJson(iChan), sMegJson);
                iOutMeg = iOutMeg + 1;
                OutFilesMeg{iOutSub}{iOutMeg} = MegList.CoordJson(iChan);
            end
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


