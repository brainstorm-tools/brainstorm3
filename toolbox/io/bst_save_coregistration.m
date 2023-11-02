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
            BidsRoot = bst_fileparts(bst_fileparts(bst_fileparts(ImportedFile)));
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
        BstFids = {'NAS', 'LPA', 'RPA', 'AC', 'PC', 'IH'};
        isLandmarksFound = true;
        for iFid = 1:numel(BstFids)
            if iFid < 4
                CS = 'SCS';
            else
                CS = 'NCS';
            end
            Fid = BstFids{iFid};
            % Voxel coordinates (Nifti: RAS and 0-indexed)
            % Bst MRI coordinates are in mm and voxels are 1-indexed, so subtract 1 voxel after going from mm to voxels.
            if isfield(sMri, CS) && isfield(sMri.(CS), Fid) && ~isempty(sMri.(CS).(Fid)) && any(sMri.(CS).(Fid))
                % Round to 0.001 voxel.
                sMriJson.AnatomicalLandmarkCoordinates.(Fid) = round(1000 * (sMri.(CS).(Fid)./sMri.Voxsize - 1)) / 1000;
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
        sMriNative = sMriScs;

        for iStudy = 1:numel(sStudies)
            % Is it a link to raw file?
            isLinkToRaw = false;
            for iData = 1:numel(sStudies(iStudy).Data)
                if strcmpi(sStudies(iStudy).Data(iData).DataType, 'raw')
                    isLinkToRaw = true;
                    break;
                end
            end
            if ~isLinkToRaw
                continue;
            end

            % Find MEG _coordsystem.json
            Link = load(file_fullpath(sStudies(iStudy).Data(iData).FileName));
            if ~exist(Link.F.filename, 'file')
                warning('Missing raw MEG file. Skipping study %s.', Link.F.filename);
                continue;
            end
            [MegPath, MegName, MegExt] = bst_fileparts(Link.F.filename);
            if strcmpi(MegExt, '.meg4')
                [MegPath, MegName, MegExt] = bst_fileparts(MegPath);
            end
            MegCoordJsonFile = file_find(MegPath, '*_coordsystem.json', 1, false); % max depth 1, not just one file

            if isempty(MegCoordJsonFile)
                warning('Imported MEG BIDS _coordsystem.json file not found. Skipping study %s.', Link.F.filename);
                continue;
            end

            ChannelMat = in_bst_channel(sStudies(iStudy).Channel.FileName);
            % ChannelMat.SCS are *digitized* anatomical landmarks (if present, otherwise might be
            % digitized head coils) in Brainstorm/SCS coordinates (CTF from anatomical landmarks).
            % Not updated after refine with head points, so we don't rely on them but use those
            % saved in sMri.
            %
            % We applied MRI=>SCS from sMri to MRI anat landmarks above, and now need to apply
            % SCS=>Native from ChannelMat. We ignore head motion related adjustments, which are
            % dataset specific. We need original raw Native coordinates.
            ChannelMat = process_adjust_coordinates('UpdateChannelMatScs', ChannelMat);
            % Convert from (possibly adjusted) SCS to Native, and m to cm.
            for iFid = 1:3
                Fid = BstFids{iFid};
                sMriNative.SCS.(Fid)(:) = 100 * [ChannelMat.Native.R, ChannelMat.Native.T] * [sMriScs.SCS.(Fid)'; 1];
            end

            for c = 1:numel(MegCoordJsonFile)
                sMegJson = bst_jsondecode(MegCoordJsonFile{c});
                if ~isfield(sMegJson, 'IntendedFor') || isempty(sMegJson.IntendedFor)
                    sMegJson.IntendedFor = strrep(ImportedFile, [BidsRoot filesep], 'bids::');
                end
                for iFid = 1:3
                    Fid = BstFids{iFid};
                    %if isfield(sMri, 'SCS') && isfield(sMri.SCS, Fid) && ~isempty(sMri.SCS.(Fid)) && any(sMri.SCS.(Fid))
                    % Round to um.
                    sMegJson.AnatomicalLandmarkCoordinates.(Fid) = round(sMriNative.SCS.(Fid) * 10000) / 10000;
                end
                sMegJson.AnatomicalLandmarkCoordinateSystem = 'CTF';
                sMegJson.AnatomicalLandmarkCoordinateUnits = 'cm';
                %sMegJson.AnatomicalLandmarkCoordinateSystemDescription = 'Based on the digitized locations of the head coils. The origin is exactly between the left ear head coil (coilL near LPA) and the right ear head coil (coilR near RPA); the X-axis goes towards the nasion head coil (coilN near NAS); the Y-axis goes approximately towards coilL, orthogonal to X and in the plane spanned by the 3 head coils; the Z-axis goes approximately towards the vertex, orthogonal to X and Y';
                %sMegJson.HeadCoilCoordinateSystemDescription = sMegJson.AnatomicalLandmarkCoordinateSystemDescription;
                [~, isMriUpdated, isMriMatch, ChannelMat] = process_adjust_coordinates('CheckPrevAdjustments', ChannelMat, sMri);
                if ~isfield(sMegJson, 'FiducialsDescription')
                    sMegJson.FiducialsDescription = '';
                end
                if isMriUpdated && isMriMatch
                    AddFidDescrip = ' The anatomical landmarks saved here match those in the associated T1w image (see IntendedFor field). They correspond to the anatomical landmarks from the digitized head points, averaged if measured more than once. Coregistration with the T1w image was performed with Brainstorm before defacing, initially with an automatic procedure fitting head points to the scalp surface, but often adjusted manually, and validated with pictures of MEG head coils on the participant. As such, these landmarks and the corresponding alignment should be preferred.';
                else
                    AddFidDescrip = ' The anatomical landmarks saved here match those in the associated T1w image (see IntendedFor field). They do not correspond to the digitized landmarks from this session. Coregistration with the T1w image was performed with Brainstorm before defacing, initially with an automatic procedure fitting head points to the scalp surface, but often adjusted manually, and validated with pictures of MEG head coils on the participant. As such, these landmarks and the corresponding alignment should be preferred.';
                end
                if isempty(strfind(sMegJson.FiducialsDescription, AddFidDescrip))
                    sMegJson.FiducialsDescription = strtrim([sMegJson.FiducialsDescription, AddFidDescrip]);
                end
                WriteJson(MegCoordJsonFile{c}, sMegJson);
                OutFilesMeg{iOutSub}{c} = MegCoordJsonFile{c};
            end
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


