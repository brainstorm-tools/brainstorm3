function [ varargout ] = bst_memory( varargin )
% BST_MEMORY: Manages all loaded data (GlobalData variable).
%
% USAGE:          iDS = bst_memory('LoadDataFile',         DataFile, isReloadForced)
%                       bst_memory('LoadRecordingsMatrix', iDS)
%      [iDS, iResult] = bst_memory('LoadResultsFile',      ResultsFile)
%                       bst_memory('LoadResultsMatrix',    iDS, iResult)
%      [iDS, iResult] = bst_memory('LoadResultsFileFull',  ResultsFile)
%      [iDS, iDipole] = bst_memory('LoadDipolesFile',      DipolesFile)
%       [iDS, iTimef] = bst_memory('LoadTimefreqFile',     TimefreqFile)
%                       bst_memory('LoadMri',              iDS, MriFile);
%      [sSurf, iSurf] = bst_memory('LoadSurface',          iSubject, SurfaceType)
%      [sSurf, iSurf] = bst_memory('LoadSurface',          MriFile,  SurfaceType)
%      [sSurf, iSurf] = bst_memory('LoadSurface',          SurfaceFile)
%         [sFib,iFib] = bst_memory('LoadFiber',            FibFile)
%         [sFib,iFib] = bst_memory('LoadFiber',            iSubject)
%
%          DataValues = bst_memory('GetRecordingsValues',  iDS, iChannel, iTime)
%       ResultsValues = bst_memory('GetResultsValues',     iDS, iRes, iVertices, TimeValues)
%       DipolesValues = bst_memory('GetDipolesValues',     iDS, iDipoles, TimeValues)
%      TimefreqValues = bst_memory('GetTimefreqValues',    iDS, iTimefreq, TimeValues)
%              minmax = bst_memory('GetResultsMaximum',    iDS, iTimefreq)
%              minmax = bst_memory('GetTimefreqMaximum',   iDS, iTimefreq, Function)
%                 iDS = bst_memory('GetDataSetData',       DataFile, isStatic)
%                 iDS = bst_memory('GetDataSetData',       DataFile)
%                 iDS = bst_memory('GetDataSetStudyNoData',StudyFile)
%                 iDS = bst_memory('GetDataSetStudy',      StudyFile)
%                 iDS = bst_memory('GetDataSetChannel',    ChannelFile)
%                 iDS = bst_memory('GetDataSetSubject',    SubjectFile, createSubject)
%                 iDS = bst_memory('GetDataSetEmpty')
%      [iDS, iResult] = bst_memory('GetDataSetResult',     ResultsFile)
%      [iDS, iResult] = bst_memory('GetDataSetDipoles',    DipolesFile)
%      [iDS, iTimefr] = bst_memory('GetDataSetTimefreq',   TimefreqFile)
%             iResult = bst_memory('GetResultInDataSet',   iDS, ResultsFile)
%             iResult = bst_memory('GetDipolesInDataSet',  iDS, DipolesFile)
%           iTimefreq = bst_memory('GetTimefreqInDataSet', iDS, TimefreqFile)
%                 iDS = bst_memory('GetRawDataSet');
% [TimeVector, iTime] = bst_memory('GetTimeVector', ...) 
%                isOk = bst_memory('CheckTimeWindows')
%                isOk = bst_memory('CheckFrequencies')
%                       bst_memory('ReloadAllDataSets')
%                       bst_memory('ReloadStatDataSets')
%                       bst_memory('UnloadAll',          OPTIONS)
%                       bst_memory('UnloadDataSets',     iDS)
%                       bst_memory('UnloadDataSetResult, ResultsFile)
%                       bst_memory('UnloadDataSetResult, iDS, iResult)
%                       bst_memory('UnloadSubject',      SubjectFile)
%                       bst_memory('UnloadMri',          MriFile)
%                       bst_memory('UnloadSurface',      SurfaceFile, isCloseFig=0)
%                       bst_memory('UnloadSurface')

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
% Authors: Francois Tadel, 2008-2020; Martin Cousineau, 2019

eval(macro_method);
end


%% =========================================================================================
%  ===== ANATOMY ===========================================================================
%  =========================================================================================
%% ===== LOAD MRI =====
% USAGE:  [sMri,iMri] = bst_memory('LoadMri', MriFile)
%         [sMri,iMri] = bst_memory('LoadMri', iSubject)
function [sMri,iMri] = LoadMri(MriFile)
    global GlobalData;
    % ===== PARSE INPUTS =====
    % If argument is a subject indice
    if isnumeric(MriFile)
        % Get subject
        iSubject = MriFile;
        sSubject = bst_get('Subject', iSubject);
        % If subject does not have a MRI
        if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
            error('No MRI avaialable for subject "%s".', sSubject.Name);
        end
        % Get MRI file
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    else
        sSubject = bst_get('MriFile', MriFile);
    end

    % ===== CHECK IF LOADED =====
    % Use short file name
    MriFile = file_short(MriFile);
    % Check if surface is already loaded
    iMri = find(file_compare({GlobalData.Mri.FileName}, MriFile));
    % If MRI is not loaded yet: load it
    if isempty(iMri)
        % Unload the unused Anatomies (surfaces + MRIs)
        UnloadAll('KeepSurface');
        % Create default structure
        sMri = db_template('LoadedMri');
        % Load MRI matrix
        MriMat = in_mri_bst(MriFile);
        % Build MRI structure
        for field = fieldnames(sMri)'
            if isfield(MriMat, field{1})
                sMri.(field{1}) = MriMat.(field{1});
            end
        end
        % Set filename
        sMri.FileName = file_win2unix(MriFile);
        
        % === MULTIPLE VOLUMES ===
        n4 = size(sMri.Cube,4);
        if (n4 > 1)
            % If there is another volume with the same 4th dimension loaded: keep as it is
            if isequal(GlobalData.UserTimeWindow.Time, [1, n4])
                % Keep loading
            % If there is no time data loaded: load as time-varying volume
            elseif isempty(GlobalData.UserTimeWindow.Time)
                % Create Measures structure
                Measures = db_template('Measures');
                Measures.Time            = [1, n4];
                Measures.SamplingRate    = 1;
                Measures.NumberOfSamples = n4;
                Measures.DataType        = 'volume';
                Measures.DisplayUnits    = 'vol';
                % Get existing dataset for this subject, or create new dataset
                iDS = GetDataSetSubject(sSubject.FileName, 1);
                GlobalData.DataSet(iDS).Measures    = Measures;
                GlobalData.DataSet(iDS).SubjectFile = file_short(sSubject.FileName);
                GlobalData.DataSet(iDS).Measures    = Measures;
                % Update time window
                CheckTimeWindows();
            % Otherwise: keep only the first one, discard all the other volumes
            else
                sMri.Cube = sMri.Cube(:,:,:,1);
            end
        end
        
        % === REFERENCE VOLUME ===
        % Copy SCS and NCS fields from reference volume
        if ~isempty(sSubject.iAnatomy) && ~file_compare(MriFile, sSubject.Anatomy(sSubject.iAnatomy).FileName) && ...
            (~isfield(sMri, 'SCS') || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || ~isfield(sMri, 'NCS') || isempty(sMri.NCS) || isempty(sMri.NCS.AC))
            % Load reference volume for this subject
            sMriRef = bst_memory('LoadMri', sSubject.Anatomy(sSubject.iAnatomy).FileName);
            % Copy SCS field
            if (~isfield(sMri, 'SCS') || isempty(sMri.SCS) || isempty(sMri.SCS.NAS)) && isfield(sMriRef, 'SCS') && ~isempty(sMriRef.SCS) && ~isempty(sMriRef.SCS.NAS)
                sMri.SCS = sMriRef.SCS;
            end
            % Copy NCS field
            if (~isfield(sMri, 'NCS') || isempty(sMri.NCS) || isempty(sMri.NCS.AC)) && isfield(sMriRef, 'NCS') && ~isempty(sMriRef.NCS) && ~isempty(sMriRef.NCS.AC)
                sMri.NCS = sMriRef.NCS;
            end
        end
        % === REGISTER NEW MRI ===
        % Add MRI to loaded MRIs in this protocol
        iMri = length(GlobalData.Mri) + 1;
        % Save MRI in memory
        GlobalData.Mri(iMri) = sMri;
        
    % Else: Return the existing instance
    else
        sMri = GlobalData.Mri(iMri);
    end
end


%% ===== GET MRI =====
function [sMri, iMri] = GetMri(MriFile) %#ok<DEFNU>
    global GlobalData;
    % Check if surface is already loaded
    iMri = find(file_compare({GlobalData.Mri.FileName}, MriFile));
    if ~isempty(iMri)
        sMri = GlobalData.Mri(iMri);
    else
        sMri = [];
    end
end


%% ===== LOAD FIBERS =====
% USAGE:  [sFib,iFib] = bst_memory('LoadFiber', FibFile)
%         [sFib,iFib] = bst_memory('LoadFiber', iSubject)
function [sFib,iFib] = LoadFibers(FibFile)
    global GlobalData;
    % ===== PARSE INPUTS =====
    % If argument is a subject indice
    if isnumeric(FibFile)
        % Get subject
        iSubject = FibFile;
        sSubject = bst_get('Subject', iSubject);
        % If subject does not have fibers
        if isempty(sSubject.Surface) || isempty(sSubject.iFibers)
            error('No fiber available for subject "%s".', sSubject.Name);
        end
        % Get fibers file
        FibFile = sSubject.Surface(sSubject.iFibers).FileName;
    else
        [sSubject, iSubject, iSurfDb] = bst_get('SurfaceFile', FibFile);
    end

    % ===== CHECK IF LOADED =====
    % Check if surface is already loaded
    iFib = find(file_compare({GlobalData.Fibers.FileName}, FibFile));
    % If fiber is not loaded yet: load it
    if isempty(iFib)
        % Unload the unused Anatomies (surfaces + MRIs)
        UnloadAll('KeepSurface');
        % Create default structure
        sFib = db_template('LoadedFibers');
        % Load fibers matrix
        FibMat = load(file_fullpath(FibFile));
        % Build fibers structure
        for field = fieldnames(sFib)'
            if isfield(FibMat, field{1})
                sFib.(field{1}) = FibMat.(field{1});
            end
        end
        % Set filename
        sFib.FileName = file_win2unix(FibFile);
        iFib = length(GlobalData.Fibers) + 1;
        % Save fibers in memory
        GlobalData.Fibers(iFib) = sFib;
    % Else: Return the existing instance
    else
        sFib = GlobalData.Fibers(iFib);
    end
end


%% ===== GET FIBERS =====
function [sFib, iFib] = GetFibers(FibFile) %#ok<DEFNU>
    global GlobalData;
    % Check if surface is already loaded
    iFib = find(file_compare({GlobalData.Fibers.FileName}, FibFile));
    if ~isempty(iFib)
        sFib = GlobalData.Fibers(iFib);
    else
        sFib = [];
    end
end


%% ===== LOAD SURFACE =====
% Load a surface in memory, or get a loaded surface
% Usage:  [sSurf, iSurf] = LoadSurface(iSubject, SurfaceType)
%         [sSurf, iSurf] = LoadSurface(MriFile,  SurfaceType)
%         [sSurf, iSurf] = LoadSurface(SurfaceFile)
function [sSurf, iSurf] = LoadSurface(varargin)
    global GlobalData;
    % ===== PARSE INPUTS =====
    if (nargin == 1)
        SurfaceFile = varargin{1};
    elseif (nargin == 2)
        % Get inputs
        iSubject = varargin{1};
        SurfaceType = varargin{2};
        % Get surface
        sDbSurf = bst_get('SurfaceFileByType', iSubject, SurfaceType);
        SurfaceFile = sDbSurf.FileName;
    end
    % Get subject and surface type
    [sSubject, iSubject, iSurfDb] = bst_get('SurfaceFile', SurfaceFile);
    if isempty(iSubject)
        SurfaceType = 'Other';
    else
        SurfaceType = sSubject.Surface(iSurfDb).SurfaceType;
    end
            
    % ===== LOAD FILE =====
    % Check if surface is already loaded
    if ~isempty(GlobalData.Surface)
        iSurf = find(file_compare({GlobalData.Surface.FileName}, SurfaceFile));
    else
        iSurf = [];
    end
    % If file not loaded: load it
    if isempty(iSurf)
        % Check if progressbar is visible
        isProgressBar = bst_progress('isVisible');
        % Unload the unused Anatomies (surfaces + MRIs)
        UnloadAll('KeepMri', 'KeepRegSurface');
        % Re-open progress bar
        if isProgressBar
            bst_progress('show');
            bst_progress('text', 'Loading surface file...');
        end
        % Create default structure
        sSurf = db_template('LoadedSurface');
        % Load surface matrix
        surfMat = in_tess_bst(SurfaceFile);
        % Get interesting fields
        sSurf.Comment         = surfMat.Comment;
        sSurf.Faces           = double(surfMat.Faces);
        sSurf.Vertices        = double(surfMat.Vertices);
        sSurf.VertConn        = surfMat.VertConn;
        sSurf.VertNormals     = surfMat.VertNormals;
        [tmp, sSurf.VertArea] = tess_area(surfMat.Vertices, surfMat.Faces);
        sSurf.SulciMap        = double(surfMat.SulciMap);

        % Get interpolation matrix MRI<->Surface if it exists
        if isfield(surfMat, 'tess2mri_interp')
            sSurf.tess2mri_interp = surfMat.tess2mri_interp;
        end
        % Get the mrimask for this surface, if it exists
        if isfield(surfMat, 'mrimask')
            sSurf.mrimask = surfMat.mrimask;
        end
        % Fix atlas structure
        sSurf.Atlas = panel_scout('FixAtlasStruct', surfMat.Atlas);
        % Default atlas
        if isempty(surfMat.iAtlas) || (surfMat.iAtlas < 1) || (surfMat.iAtlas > length(sSurf.Atlas))
            sSurf.iAtlas = 1;
        else
            sSurf.iAtlas = surfMat.iAtlas;
        end
        % Save surface file and type
        sSurf.FileName = file_win2unix(SurfaceFile);
        sSurf.Name     = SurfaceType;
        % Add surface to loaded surfaces list in this protocol (if not already loaded)
        iSurf = length(GlobalData.Surface) + 1;
        % Save surface in memory
        GlobalData.Surface(iSurf) = sSurf;
        
    % Else, return the existing instance
    else
        sSurf = GlobalData.Surface(iSurf);
    end
end


%% ===== GET INTERPOLATION SURF-MRI =====
% USAGE:  [tess2mri_interp, sMri] = GetTess2MriInterp(iSurf, MriFile) 
%         [tess2mri_interp, sMri] = GetTess2MriInterp(iSurf)          : Use the database to get MriFile
function [tess2mri_interp, sMri] = GetTess2MriInterp(iSurf, MriFile)
    global GlobalData;
    if (nargin < 2) || isempty(MriFile)
        MriFile = [];
    end
    % Get existing interpolation
    tess2mri_interp = GlobalData.Surface(iSurf).tess2mri_interp;
    % Get anatomy
    if (nargout >= 2) || isempty(tess2mri_interp)
        % Get surface file name
        SurfaceFile = GlobalData.Surface(iSurf).FileName;
        % Load subject MRI
        if ~isempty(MriFile)
            sMri = LoadMri(MriFile);
        else
            [sSubject, iSubject] = bst_get('SurfaceFile', SurfaceFile);
            sMri = LoadMri(iSubject);
        end
    end
    % If interpolation matrix was not lready computed: return it
    if isempty(tess2mri_interp)
        % Compute or load interpolation matrix
        tess2mri_interp = tess_interp_mri(SurfaceFile, sMri);
        % Store result for future use
        GlobalData.Surface(iSurf).tess2mri_interp = tess2mri_interp;
    end
end


%% ===== GET INTERPOLATION GRID-MRI =====
function grid2mri_interp = GetGrid2MriInterp(iDS, iResult, GridSmooth) %#ok<DEFNU>
    global GlobalData;
    % Default grid smooth: yes
    if (nargin < 3) || isempty(GridSmooth)
        GridSmooth = 1;
    end
    % If matrix was already computed: return it
    if ~isempty(GlobalData.DataSet(iDS).Results(iResult).grid2mri_interp)
        grid2mri_interp = GlobalData.DataSet(iDS).Results(iResult).grid2mri_interp;
    % Else: compute it
    else
        % Get subject
        [sSubject, iSubject] = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
        SurfaceFile = GlobalData.DataSet(iDS).Results(iResult).SurfaceFile;
        % Load MRI
        sMri = LoadMri(iSubject);
        % Get the grid points to interpolate
        switch (GlobalData.DataSet(iDS).Results(iResult).HeadModelType)
            case 'volume'
                GridLoc = GlobalData.DataSet(iDS).Results(iResult).GridLoc;
                % Compute interpolation
                grid2mri_interp = grid_interp_mri(GridLoc, sMri, SurfaceFile, 1, [], [], GridSmooth);
            case 'mixed'
                % Compute the surface interpolation
                tess2mri_interp = tess_interp_mri(SurfaceFile, sMri);
                % Initialize returned interpolation matrix
                GridAtlas = GlobalData.DataSet(iDS).Results(iResult).GridAtlas;
                grid2mri_interp = sparse(numel(sMri.Cube(:,:,:,1)), size(GridAtlas.Grid2Source,1)); 
                % Process each region separately
                ind = 1;
                sScouts = GlobalData.DataSet(iDS).Results(iResult).GridAtlas.Scouts;
                for i = 1:length(sScouts)
                    % Indices in the interpolation matrix
                    iGrid = ind + (0:length(sScouts(i).GridRows) - 1);
                    ind = ind + length(sScouts(i).GridRows);
                    % Interpolation depends on the type of region (volume or surface)
                    switch (sScouts(i).Region(2))
                        case 'V'
                            GridLoc = GlobalData.DataSet(iDS).Results(iResult).GridLoc(sScouts(i).GridRows,:);
                            grid2mri_interp(:,iGrid) = grid_interp_mri(GridLoc, sMri, SurfaceFile, 1, [], [], GridSmooth);
                        case 'S'
                            grid2mri_interp(:,iGrid) = tess2mri_interp(:, sScouts(i).Vertices);
                    end
                end
            otherwise
                error('Invalid headmodel.');
        end

        % Store result for future use
        GlobalData.DataSet(iDS).Results(iResult).grid2mri_interp = grid2mri_interp;
    end
end


%% ===== GET SURFACE MASK =====
% USAGE:  GetSurfaceMask(SurfaceFile, MriFile)
%         GetSurfaceMask(SurfaceFile)          : MriFile is retrieved from the database
function [mrimask, sMri, sSurf] = GetSurfaceMask(SurfaceFile, MriFile) %#ok<DEFNU>
    global GlobalData;
    if (nargin < 2) || isempty(MriFile)
        MriFile = [];
    end
    % Load surface
    [sSurf, iSurf] = LoadSurface(SurfaceFile);
    % Get the tess -> MRI interpolation
    [tess2mri_interp, sMri] = GetTess2MriInterp(iSurf, MriFile);
    % Get an existing mrimask
    if ~isempty(sSurf.mrimask)
        mrimask = sSurf.mrimask;
    % MRI mask do not exist yet
    else
        % Compute mrimask
        mrimask = tess_mrimask(size(sMri.Cube(:,:,:,1)), tess2mri_interp);
        % Add it to loaded structure
        GlobalData.Surface(iSurf).mrimask = mrimask;
        % Save new mrimask into file
        SurfaceFile = file_fullpath(SurfaceFile);
        s.mrimask = mrimask;
        if file_exist(SurfaceFile)
            bst_save(SurfaceFile, s, 'v7', 1);
        end
    end
end


%% ===== GET SURFACE =====
function [sSurf, iSurf] = GetSurface(SurfaceFile)
    global GlobalData;
    % Check if surface is already loaded
    iSurf = find(file_compare({GlobalData.Surface.FileName}, SurfaceFile));
    if ~isempty(iSurf)
        sSurf = GlobalData.Surface(iSurf);
    else
        % Remove full path
        SurfaceFile = file_short(SurfaceFile);
        % Check again
        iSurf = find(file_compare({GlobalData.Surface.FileName}, SurfaceFile));
        if ~isempty(iSurf)
            sSurf = GlobalData.Surface(iSurf);
        else
            sSurf = [];
        end
    end
end


%% ===== GET SURFACE ENVELOPE =====
function [sEnvelope, sSurf] = GetSurfaceEnvelope(SurfaceFile, nVertices, isRemesh, dilateMask)
    global GlobalData;
    % Parse inputs
    if (nargin < 4) || isempty(dilateMask)
        dilateMask = 1;
    end
    if (nargin < 3) || isempty(isRemesh)
        isRemesh = 1;
    end
    % Load surface
    [sSurf, iSurf] = LoadSurface(SurfaceFile);
    % Get an existing mrimask
    fieldName = sprintf('v%d', nVertices);
    if ~isempty(sSurf.envelope) && isfield(sSurf.envelope, fieldName) && ~isempty(sSurf.envelope.(fieldName))
        sEnvelope = sSurf.envelope.(fieldName);
    % MRI mask do not exist yet
    else
        % Compute mrimask
        sEnvelope = tess_envelope(SurfaceFile, 'mask_cortex', nVertices, [], [], isRemesh, dilateMask);
        % Add it to loaded structure
        GlobalData.Surface(iSurf).envelope.(fieldName) = sEnvelope;
    end
end


%% =========================================================================================
%  ===== FUNCTIONAL DATA ===================================================================
%  =========================================================================================
%% ===== GET FILE INFORMATION =====
% Get all the information related with a DataFile.
function [sStudy, iData, ChannelFile, FileType, sItem] = GetFileInfo(DataFile)
    % Get file in database
    [sStudy, iStudy, iData, FileType, sItem] = bst_get('AnyFile', DataFile);
    % If this data file does not belong to any study
    if isempty(sStudy)
        error('File is not registered in database.');
    end
    % If Channel is not defined yet : get it from Study description
    Channel = bst_get('ChannelForStudy', iStudy);
    if ~isempty(Channel)
        ChannelFile = Channel.FileName;
    else
        ChannelFile = '';
    end
end


%% ===== LOAD CHANNEL FILE =====
function LoadChannelFile(iDS, ChannelFile)
    global GlobalData;
    % If a channel file is defined
    if ~isempty(ChannelFile)
        % Check if this channel file is already loaded and modified in another DataSet
        iDSother = setdiff(1:length(GlobalData.DataSet), iDS);
        if ~isempty(iDSother) && any([GlobalData.DataSet(iDSother).isChannelModified])
            % Ask user
            isSave = java_dialog('confirm', ...
                ['This channel file is being edited in another window.' 10 ...
                 'Save the modifications so the new figure can show updated positions?'], 'Save modifications');
            % Force saving of the modifications
            if isSave
                bst_memory('SaveChannelFile', iDSother(1));
            end
        end

        % Load channel
        ChannelMat = in_bst_channel(ChannelFile);
        % Check coherence between Channel and Measures.F dimensions
        nChannels = length(ChannelMat.Channel);
        nDataChan = length(GlobalData.DataSet(iDS).Measures.ChannelFlag);
        if (nDataChan > 0) && (nDataChan ~= nChannels)
            error('Number of channels in ChannelFile (%d) and DataFile (%d) do not match. Aborting...', nChannels, nDataChan);
        end
        % Save in DataSet structure
        GlobalData.DataSet(iDS).ChannelFile     = file_win2unix(ChannelFile);
        GlobalData.DataSet(iDS).Channel         = ChannelMat.Channel;
        GlobalData.DataSet(iDS).IntraElectrodes = ChannelMat.IntraElectrodes;
        GlobalData.DataSet(iDS).MegRefCoef      = ChannelMat.MegRefCoef;
        GlobalData.DataSet(iDS).Projector       = ChannelMat.Projector;
        % If extra channel info available (such as head points in FIF format)
        if isfield(ChannelMat, 'HeadPoints')
            GlobalData.DataSet(iDS).HeadPoints = ChannelMat.HeadPoints;
        end
        % If there are some ECOG/SEEG channels: Create new temporary montages automatically
        if any(ismember({'ECOG', 'SEEG'}, {ChannelMat.Channel.Type}))
            SubjectName = bst_fileparts(GlobalData.DataSet(iDS).SubjectFile);
            panel_montage('AddAutoMontagesSeeg', SubjectName, ChannelMat);
        end
        % If there are some NIRS channels: Create new temporary montages automatically
        if ismember('NIRS', {ChannelMat.Channel.Type})
            panel_montage('AddAutoMontagesNirs', ChannelMat);
        end
        
    % No channel file: create a fake structure
    elseif ~isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
        nChan = length(GlobalData.DataSet(iDS).Measures.ChannelFlag);
        GlobalData.DataSet(iDS).Channel = repmat(db_template('ChannelDesc'), [1 nChan]);
        for i = 1:nChan
            GlobalData.DataSet(iDS).Channel(i).Name = sprintf('E%d', i);
            GlobalData.DataSet(iDS).Channel(i).Loc  = [0;0;0];
            GlobalData.DataSet(iDS).Channel(i).Type = 'EEG';
        end
        GlobalData.DataSet(iDS).MegRefCoef      = []; 
        GlobalData.DataSet(iDS).Projector       = []; 
        GlobalData.DataSet(iDS).IntraElectrodes = [];
    end
end


%% ===== LOAD DATA FILE (& CREATE DATASET) =====
% Load all recordings information but the recordings matrix itself (F).
% USAGE:  [iDS, ChannelFile] = LoadDataFile(DataFile, isReloadForced, isTimeCheck)
%         [iDS, ChannelFile] = LoadDataFile(DataFile, isReloadForced)
%         [iDS, ChannelFile] = LoadDataFile(DataFile)
function [iDS, ChannelFile] = LoadDataFile(DataFile, isReloadForced, isTimeCheck)
    global GlobalData;
    % ===== PARSE INPUTS =====
    if (nargin < 3)
        isTimeCheck = 1;
    end
    if (nargin < 2)
        isReloadForced = 0;
    end
    % Get data file information from database
    [sStudy, iData, ChannelFile, FileType] = GetFileInfo(DataFile);
    % Get data type
    switch lower(FileType)
        case 'data'
            DataType = sStudy.Data(iData).DataType;
            DataFile = sStudy.Data(iData).FileName;
        case 'pdata'
            DataType = 'stat';
            DataFile = sStudy.Stat(iData).FileName;
            % Show "stat" tab
            gui_brainstorm('ShowToolTab', 'Stat');
        otherwise
            error('Invalid file type.');
    end

    % ===== LOAD DATA =====
    % Create Measures structure
    Measures = db_template('Measures');
    % Load file description
    if strcmpi(DataType, 'raw')
        % Is loaded dataset
        iDS = GetDataSetData(DataFile, 0);
        % Load file
        if isempty(iDS)
            bst_progress('start', 'Loading raw file', 'Reading file header...');
            MeasuresMat = in_bst_data(DataFile, 'F', 'ChannelFlag', 'ColormapType', 'DisplayUnits');
            sFile = MeasuresMat.F;
        else
            MeasuresMat = GlobalData.DataSet(iDS).Measures;
            sFile = MeasuresMat.sFile;
        end
        % Rebuild Time vector
        Time = panel_time('GetRawTimeVector', sFile);
        
        % Check if file exists
        isRetry = 1;
        while isRetry
            if ~file_exist(sFile.filename)
                % File does not exist: ask the user what to do
                res = java_dialog('question', [...
                    'The following file has been moved, deleted, is used by another program,', 10, ...
                    'or is on a drive that is currently not connected to your computer.' 10 ...
                    'If the file is accessible at another location, click on "Pick file".' 10 10 ...
                    sFile.filename 10 10], ...
                    'Load continuous file', [], {'Pick file...', 'Retry', 'Cancel'}, 'Cancel');
                % Cancel
                if isempty(res) || strcmpi(res, 'Cancel')
                    iDS = [];
                    bst_progress('stop');
                    return;
                end
                % Retry
                if strcmpi(res, 'Retry')
                    continue;
                % Pick file
                else
                    sFile = panel_record('FixFileLink', DataFile, sFile);
                    if isempty(sFile)
                        iDS = [];
                        bst_progress('stop');
                        return;
                    end
                end
            else
                isRetry = 0;
            end
        end
    else
        MeasuresMat = in_bst_data(DataFile, 'Time', 'ChannelFlag', 'ColormapType', 'Events', 'DisplayUnits');
        Time = MeasuresMat.Time;
        % Duplicate time if only one time frame
        if (length(Time) == 1)
            Time = [0,0.001] + Time;
        end
        % Create fake "sFile" structure
        sFile = db_template('sFile');
        % Store events
        if ~isempty(MeasuresMat.Events)
            sFile.events = MeasuresMat.Events;
        else
            sFile.events = repmat(db_template('event'), 0);
        end
        sFile.format       = 'BST';
        sFile.filename     = DataFile;
        sFile.prop.times   = Time([1 end]);
        sFile.prop.sfreq   = 1 ./ (Time(2) - Time(1));
    end
    Measures.DataType     = DataType;
    Measures.ChannelFlag  = MeasuresMat.ChannelFlag;
    Measures.sFile        = sFile;
    Measures.ColormapType = MeasuresMat.ColormapType;
    Measures.DisplayUnits = MeasuresMat.DisplayUnits;
    clear MeasuresMat;
    
    % ===== TIME =====
    if (length(Time) > 1)
        % Default time selection: all the samples
        iTime = [1, length(Time)];
        % For raw recordings: limit to the user option
        if strcmpi(DataType, 'raw')
            RawViewerOptions = bst_get('RawViewerOptions', sFile);
            % If current time window can be re-used
            if ~isempty(GlobalData.UserTimeWindow.Time) && (GlobalData.UserTimeWindow.NumberOfSamples > 2) && (GlobalData.UserTimeWindow.Time(1) >= Time(1)) && (GlobalData.UserTimeWindow.Time(2) <= Time(end))
                iTime = bst_closest(GlobalData.UserTimeWindow.Time, Time);
            elseif (length(Time) > floor(RawViewerOptions.PageDuration * sFile.prop.sfreq))
                iTime = [1, floor(RawViewerOptions.PageDuration * sFile.prop.sfreq)];
            end
        end
        Measures.Time            = double(Time([iTime(1), iTime(2)])); 
        Measures.SamplingRate    = double(Time(2) - Time(1));
        Measures.NumberOfSamples = iTime(2) - iTime(1) + 1;
    else
        Measures.Time            = [0 0.001]; 
        Measures.SamplingRate    = 0.002;
        Measures.NumberOfSamples = 2;
    end
    
    % ===== EXISTING DATASET ? =====
    % Check if a DataSet already exists for this DataFile
    isStatic = (Measures.NumberOfSamples <= 2);
    iDS = GetDataSetData(DataFile, isStatic);
    if (length(iDS) > 1)
        iDS = iDS(1);
    end
    % If dataset already exist AND IS DEFINED FOR THE RIGHT SUBJECT, just return its index
    if ~isempty(iDS) && ~isReloadForced
        if ~isempty(sStudy.BrainStormSubject) && ~file_compare(sStudy.BrainStormSubject, GlobalData.DataSet(iDS).SubjectFile)
            iDS = [];
        else
            GlobalData.DataSet(iDS).Measures.DataType    = Measures.DataType;
            GlobalData.DataSet(iDS).Measures.ChannelFlag = Measures.ChannelFlag;
            % GlobalData.DataSet(iDS).Measures.sFile       = Measures.sFile;
            if ~isempty(Measures.sFile) && isempty(GlobalData.DataSet(iDS).Measures.sFile)
                GlobalData.DataSet(iDS).Measures.sFile = Measures.sFile;
            end
            return
        end
    end
    
    % ===== CHECK FOR OTHER RAW FILES =====
    if strcmpi(DataType, 'raw') && ~isempty(GlobalData.FullTimeWindow) && ~isempty(GlobalData.FullTimeWindow.CurrentEpoch) && ~isReloadForced
        res = java_dialog('question', [...
            'Cannot open two continuous viewers at the same time.' 10 ...
            'Unload all the other files first?' 10 10], 'Load recordings', [], {'Unload other files', 'Cancel'});
        % Cancel: Unload the new dataset
        if isempty(res) || strcmpi(res, 'Cancel')
            iDS = [];
            return;
        % Otherwise: unload all the other datasets
        else
            % Unload everything
            UnloadAll('Forced');
            % If not everything was unloaded correctly (eg. the user cancelled half way when asked to save the modifications)
            if ~isempty(GlobalData.DataSet)
                iDS = [];
                return;
            end
            % New dataset = only dataset
            iDS = 1;
        end
    end
    
    % ===== STORE IN GLOBALDATA =====
    % If no DataSet is available for this data file
    if isempty(iDS)
        % Create new dataset
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS) = db_template('DataSet');
    end
    % Store DataSet in GlobalData
    GlobalData.DataSet(iDS).SubjectFile = file_short(sStudy.BrainStormSubject);
    GlobalData.DataSet(iDS).StudyFile   = file_short(sStudy.FileName);
    GlobalData.DataSet(iDS).DataFile    = file_short(DataFile);
    GlobalData.DataSet(iDS).Measures    = Measures;
    
    % ===== LOAD CHANNEL FILE =====
    LoadChannelFile(iDS, ChannelFile);
    
    % ===== Check time window consistency with previously loaded data =====
    if isTimeCheck
        % Update time window
        isTimeCoherent = CheckTimeWindows();
        % If loaded data is not coherent with previous data
        if ~isTimeCoherent
            res = java_dialog('question', [...
                'The time definition is not compatible with previously loaded files.' 10 ...
                'Unload all the other files first?' 10 10], 'Load recordings', [], {'Unload other files', 'Cancel'});
            % Cancel: Unload the new dataset
            if isempty(res) || strcmpi(res, 'Cancel')
                UnloadDataSets(iDS);
                iDS = [];
                return;
            % Otherwise: unload all the other datasets
            else
                % Save newly created dataset
                bakDS = GlobalData.DataSet(iDS);
                % Unload everything
                UnloadAll('Forced');
                % If not everything was unloaded correctly (eg. the user cancelled half way when asked to save the modifications)
                if ~isempty(GlobalData.DataSet)
                    % Unload the new dataset
                    UnloadDataSets(iDS);
                    iDS = [];
                    return;
                end
                % Restore new dataset
                GlobalData.DataSet = bakDS;
                iDS = 1;
                % Update time window
                isTimeCoherent = CheckTimeWindows();
            end
        end
    end
    
    % ===== UPDATE TOOL TABS =====
    if ~isempty(iDS) && strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw')
        % Initialize tab with new RAW information
        panel_record('InitializePanel');
    end
    panel_cluster('UpdatePanel');
    panel_time('UpdatePanel');
end


%% ===== GET RAW DATASET =====
function iDS = GetRawDataSet() %#ok<DEFNU>
    global GlobalData;
    iDS = [];
    % No raw data loaded
    if isempty(GlobalData.FullTimeWindow) || isempty(GlobalData.FullTimeWindow.CurrentEpoch)
        return
    end
    % Look for the raw data loaded in all the datasets
    for i = 1:length(GlobalData.DataSet)
        if isequal(GlobalData.DataSet(i).Measures.DataType, 'raw')
            iDS = i;
            return;
        end
    end
end

    
%% ===== LOAD F MATRIX FOR A GIVEN DATA FILE =====
% Load the F matrix for a dataset that has already been pre-loaded (with LoadDataFile)
function LoadRecordingsMatrix(iDS)
    global GlobalData;
    % Check dataset index integrity
    if isempty(iDS) || (iDS <= 0) || (iDS > length(GlobalData.DataSet))
        error('Invalid DataSet index : %d', iDS);
    end   
    % Relative filename : add the SUBJECTS path
    DataFile = file_fullpath(GlobalData.DataSet(iDS).DataFile);
    
    % Load F Matrix
    if strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat')
        % Load stat file
        StatMat = in_bst_data(DataFile, 'pmap', 'tmap', 'df', 'SPM', 'ChannelFlag', 'Correction', 'StatClusters', 'Time');
        % Get only relevant sensors as multiple tests
        iChannels = good_channel(GlobalData.DataSet(iDS).Channel, StatMat.ChannelFlag, {'MEG', 'EEG', 'SEEG', 'ECOG', 'NIRS'});
        if isfield(StatMat, 'pmap') && ~isempty(StatMat.pmap)
            StatMat.pmap = StatMat.pmap(iChannels,:,:);
        end
        if isfield(StatMat, 'tmap') && ~isempty(StatMat.tmap)
            StatMat.tmap = StatMat.tmap(iChannels,:,:);
        end
        if isfield(StatMat, 'df') && ~isempty(StatMat.df) && (numel(StatMat.df) > 1)
            StatMat.df = StatMat.df(iChannels,:,:);
        end
        % Initialize matrix
        GlobalData.DataSet(iDS).Measures.F = zeros(length(GlobalData.DataSet(iDS).Measures.ChannelFlag), GlobalData.DataSet(iDS).Measures.NumberOfSamples);
        % Apply threshold, and duplicate time if there is only one time point
        [threshMap, tThreshUnder, tThreshOver] = process_extract_pthresh('Compute', StatMat);
        if ( size(threshMap,2) == 1) && (GlobalData.DataSet(iDS).Measures.NumberOfSamples == 2)
            threshMap = cat(2, threshMap, threshMap);
        end
        GlobalData.DataSet(iDS).Measures.F(iChannels,:,:) = threshMap;
        GlobalData.DataSet(iDS).Measures.StatThreshUnder = tThreshUnder;
        GlobalData.DataSet(iDS).Measures.StatThreshOver = tThreshOver;
        % Copy stat clusters
        GlobalData.DataSet(iDS).Measures.StatClusters = StatMat.StatClusters;
        GlobalData.DataSet(iDS).Measures.StatClusters.Correction = StatMat.Correction;
    else
        % If RAW file: load a block from the file
        if strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw')
            DataMat.F = LoadRecordingsRaw(iDS);
            % If not data could be loaded from the file: return
            if isempty(DataMat.F)
                return
            end   
        % Else: Load data file
        else
            DataMat = in_bst_data(DataFile, 'F', 'Std');
        end

        % ===== APPLY FILTERING =====
        % Check if the online filters should be applied to the recordings
        ColormapType = GlobalData.DataSet(iDS).Measures.ColormapType;
        UseFilterData = ~ismember(GlobalData.DataSet(iDS).Measures.DataType, {'zscore','stat'}) && (isempty(ColormapType) || ~ismember(ColormapType, {'stat1','stat2'}));
        % Check if the online filters should be applied on the sources
        UseFilterResults = 1;
        for iRes = 1:length(GlobalData.DataSet(iDS).Results)
            % Is this a Z-score file?
            ColormapTypeRes = GlobalData.DataSet(iDS).Results(iRes).ColormapType;
            isZscore = ~isempty(GlobalData.DataSet(iDS).Results(iRes).ZScore) || ...
                       ~isempty(strfind(GlobalData.DataSet(iDS).Results(iRes).FileName, '_zscore')) || ...
                       (~isempty(ColormapTypeRes) && ismember(ColormapTypeRes, {'stat1', 'stat2'}));
            % Do not figure recordings if it is attached to a Z-scored source file
            if ~isempty(GlobalData.DataSet(iDS).Results(iRes).ImagingKernel) && isZscore
                UseFilterResults = 0;
            end
        end
        % Apply filters
        if UseFilterData && UseFilterResults
            sfreq = 1./GlobalData.DataSet(iDS).Measures.SamplingRate;
            DataMat.F = FilterLoadedData(DataMat.F, sfreq);
            GlobalData.DataSet(iDS).Measures.isFiltered = 1;
        else
            GlobalData.DataSet(iDS).Measures.isFiltered = 0;
        end

        % If data was loaded : store it in GlobalData
        if ~isempty(DataMat.F)
             GlobalData.DataSet(iDS).Measures.F = double(DataMat.F);
        end
        if isfield(DataMat, 'Std') && ~isempty(DataMat.Std)
            GlobalData.DataSet(iDS).Measures.Std = double(DataMat.Std);
        end
    end
    % If there is only one time sample : copy it to get 2 time samples
    if (size(GlobalData.DataSet(iDS).Measures.F, 2) == 1)
        GlobalData.DataSet(iDS).Measures.F = repmat(GlobalData.DataSet(iDS).Measures.F, [1,2]);
        % Also duplicate Std if present
        if isfield(DataMat, 'Std') && ~isempty(DataMat.Std)
            GlobalData.DataSet(iDS).Measures.Std = repmat(GlobalData.DataSet(iDS).Measures.Std, [1,2]);
        end    
    end
end


%% ===== LOAD RAW DATA ====
% Load a block of 
function F = LoadRecordingsRaw(iDS)
    global GlobalData;
    % Get values data to read
    iEpoch    = GlobalData.FullTimeWindow.CurrentEpoch;
    TimeRange = GlobalData.DataSet(iDS).Measures.Time;
    % Get raw viewer options
    RawViewerOptions = bst_get('RawViewerOptions');
    UseSsp = 1;
    % Rebuild a minimalist ChannelMat
    ChannelMat = struct('Channel',    GlobalData.DataSet(iDS).Channel, ...
                        'Projector',  GlobalData.DataSet(iDS).Projector, ...
                        'MegRefCoef', GlobalData.DataSet(iDS).MegRefCoef);
    % Read data block
    F = panel_record('ReadRawBlock', GlobalData.DataSet(iDS).Measures.sFile, ChannelMat, iEpoch, TimeRange, 1, RawViewerOptions.UseCtfComp, RawViewerOptions.RemoveBaseline, UseSsp);
end


%% ===== FILTER LOADED DATA =====
function F = FilterLoadedData(F, sfreq)
    global GlobalData;
    isLowPass     = GlobalData.VisualizationFilters.LowPassEnabled;
    isHighPass    = GlobalData.VisualizationFilters.HighPassEnabled;
    isSinRemoval  = GlobalData.VisualizationFilters.SinRemovalEnabled;
    % isMirror      = GlobalData.VisualizationFilters.MirrorEnabled;
    isMirror = 0;
    % Get time vector
    nTime = size(F,2);
    % Band-pass filter is active: apply it (only if real recordings => ignore time averages)
    if (isHighPass || isLowPass) && (nTime > 2)
        % LOW-PASS
        if ~isLowPass || isequal(GlobalData.VisualizationFilters.LowPassValue, 0)
            LowPass = [];
        else
            LowPass = GlobalData.VisualizationFilters.LowPassValue;
        end
        % HI-PASS
        if ~isHighPass || isequal(GlobalData.VisualizationFilters.HighPassValue, 0)
            HighPass = [];
        else
            HighPass = GlobalData.VisualizationFilters.HighPassValue;
        end
        % Check if bounds are correct
        if ~isempty(HighPass) && ~isempty(LowPass) && (HighPass == LowPass)
            errordlg('Please check the filter settings before loading data', 'Display error');
        end
        % Filter data
        isRelax = 1;
        [F, FiltSpec, Messages] = process_bandpass('Compute', F, sfreq, HighPass, LowPass, 'bst-hfilter-2019', isMirror, isRelax);
        if ~isempty(Messages)
            disp(['Warning: ' Messages]);
        end
    end
    % Sin removal filter is active
    if isSinRemoval && ~isempty(GlobalData.VisualizationFilters.SinRemovalValue) && (nTime > 2)
        % Filter data
        F = process_notch('Compute', F, sfreq, GlobalData.VisualizationFilters.SinRemovalValue);
    end
end

%% ===== RELOAD ALL DATA FILES ======
% Reload all the data files.
% (needed for instance after changing the visualization filters parameters).
function ReloadAllDataSets() %#ok<DEFNU>
    global GlobalData;
    % Process all the loaded datasets
    for iDS = 1:length(GlobalData.DataSet)
        % If F matrix is loaded: reload it
        if ~isempty(GlobalData.DataSet(iDS).Measures.F)
            LoadRecordingsMatrix(iDS);
        end
        % For the FULL sources: reload source time series
        for iRes = 1:length(GlobalData.DataSet(iDS).Results)
            if ~isempty(GlobalData.DataSet(iDS).Results(iRes).ImageGridAmp)
                LoadResultsMatrix(iDS, iRes);
            end
        end
    end
end


%% ===== RELOAD STAT DATA FILES ======
% Reload all the stat files.
% (needed for instance after changing the statistical thresholding options).
function ReloadStatDataSets() %#ok<DEFNU>
    global GlobalData;
    % Process all the loaded datasets
    for iDS = 1:length(GlobalData.DataSet)
        % If F matrix is loaded: reload it
        if ~isempty(GlobalData.DataSet(iDS).Measures.F) && strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat')
            LoadRecordingsMatrix(iDS);
        end
%         % Go through the results files
%         for iRes = 1:length(GlobalData.DataSet(iDS).Results)
%             % Reload the full results
%             if ~isempty(GlobalData.DataSet(iDS).Results(iRes).ImageGridAmp)
%                 LoadResultsMatrix(iDS, iRes);
%             end
%         end
        % Go through the timefreq files
        for iTf = 1:length(GlobalData.DataSet(iDS).Timefreq)
             fileType = file_gettype(GlobalData.DataSet(iDS).Timefreq(iTf).FileName);
             if strcmpi(fileType, 'ptimefreq')
                 LoadTimefreqFile(GlobalData.DataSet(iDS).Timefreq(iTf).FileName, 0, 0, 1);
             end
        end
    end
end


%% ===== LOAD RESULT FILE (& CREATE DATASET) =====
% Load result file (some informative fields, not all the calculated matrices)
% Usage :  [iDS, iResult] = LoadResultsFile(ResultsFile)
%          [iDS, iResult] = LoadResultsFile(ResultsFile) 
function [iDS, iResult] = LoadResultsFile(ResultsFile, isTimeCheck)
    global GlobalData;
    if (nargin < 2)
        isTimeCheck = 1;
    end
    % Initialize returned values
    iResult  = [];
    
    % ===== GET FILE INFORMATION =====
    % Get file information
    [sStudy, iFile, ChannelFile, FileType] = GetFileInfo(ResultsFile);
    % Get associated data file
    switch(FileType)
        case {'results', 'link'}
            DataFile = sStudy.Result(iFile).DataFile;
            isLink = sStudy.Result(iFile).isLink;
            DataType = 'results';
        case 'presults'
            DataFile = sStudy.Stat(iFile).DataFile;
            isLink = 0;
            DataType = 'stat';
    end
    % Make relative filenames
    if ~isLink
        ResultsFile = file_short(ResultsFile);
    end
    % Resolve link
    ResultsFullFile = file_resolve_link( ResultsFile );    
    % Get variables list
    File_whos = whos('-file', ResultsFullFile);
    
    % ===== Is Result file is already loaded ? ====  
    % If Result file is dependent from a Data file
    if ~isempty(DataFile)
        % Load (or simply get) DataSet associated with DataFile
        isForceReload = isLink;
        iDS = LoadDataFile(DataFile, isForceReload);
        % If error loading the data file
        if isempty(iDS)
            return;
        end
        % Check if result file is already loaded in this DataSet
        iResult = GetResultInDataSet(iDS, ResultsFile);
    else
        % Check if result file is already loaded in this DataSet
        [iDS, iResult] = GetDataSetResult(ResultsFile);
    end
    % If dataset for target ResultsFile already exists, just return its index
    if ~isempty(iDS) && ~isempty(iResult)
        return
    end
    
    % ===== If Result file need and independent DataSet structure =====
    if isempty(iDS)
        % Create a new DataSet only for results
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS)             = db_template('DataSet');
        GlobalData.DataSet(iDS).DataFile    = '';
    end
    GlobalData.DataSet(iDS).SubjectFile = file_short(sStudy.BrainStormSubject);
    GlobalData.DataSet(iDS).StudyFile   = file_short(sStudy.FileName);
    
    % === NORMAL RESULTS FILE ===
    NumberOfSamples = [];
    SamplingRate = [];
    if any(strcmpi('ImageGridAmp', {File_whos.name}))
        % Load results .Mat
        ResultsMat = in_bst_results(ResultsFullFile, 0, 'Comment', 'Time', 'ChannelFlag', 'SurfaceFile', 'HeadModelType', 'ColormapType', 'DisplayUnits', 'GoodChannel', 'Atlas');
        % Raw file: Use only the loaded time window
        if ~isempty(DataFile) && strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw') && ~isempty(strfind(ResultsFullFile, '_KERNEL_'))
            Time = GlobalData.DataSet(iDS).Measures.Time;
            NumberOfSamples = GlobalData.DataSet(iDS).Measures.NumberOfSamples;
            SamplingRate = GlobalData.DataSet(iDS).Measures.SamplingRate;
        % If Time does not exist, try to rebuild it
        elseif isempty(ResultsMat.Time)
            % If DataSet.Measures is empty (if no data was loaded)
            if isempty(GlobalData.DataSet(iDS).Measures.Time)
                % It is impossible to reconstruct the time vector => impossible to load ResultsFile
                error(['Missing time information for file "' ResultsFile '".']);
            else
                % If Time vector is defined in results (indices in initial Data time vector)
                if ~isempty(ResultsMat.Time)
                    Time = ResultsMat.Time;
                % Else: Rebuild Measures time vector
                else
                    Time = linspace(GlobalData.DataSet(iDS).Measures.Time(1), ...
                                    GlobalData.DataSet(iDS).Measures.Time(end), ...
                                    GlobalData.DataSet(iDS).Measures.NumberOfSamples);
                end
            end
        % Else: use Time vector from file
        else
            Time = ResultsMat.Time;
        end
    % === STAT ON RESULTS ===
    elseif all(ismember({'Comment', 'Time', 'tmap', 'ChannelFlag'}, {File_whos.name}))
        % Show stat tab
        gui_brainstorm('ShowToolTab', 'Stat');
        % Load results .Mat
        ResultsMat = in_bst_results(ResultsFullFile, 0, 'Comment', 'Time', 'ChannelFlag', 'SurfaceFile', 'HeadModelType', 'ColormapType', 'DisplayUnits', 'GoodChannel', 'Atlas');
        Time = ResultsMat.Time;
    else
        error('File does not follow Brainstorm file format.');
    end
    % Duplicate time if only one time frame
    if (length(Time) == 1)
        Time = [0,0.001] + Time;
    end
    % Sampling rate and number of samples
    if isempty(NumberOfSamples)
        NumberOfSamples = length(Time);
    end
    if isempty(SamplingRate)
        SamplingRate = Time(2)-Time(1);
    end
    
    % ===== LOAD CHANNEL FILE =====
    if ~isempty(ChannelFile)
        LoadChannelFile(iDS, ChannelFile);
    end
 
    % ===== Create new Results entry =====
    % Create Results structure
    Results = db_template('LoadedResults');
    % Copy information
    Results.FileName        = file_win2unix(ResultsFile);
    Results.DataType        = DataType;
    Results.HeadModelType   = ResultsMat.HeadModelType;
    Results.SurfaceFile     = ResultsMat.SurfaceFile;
    Results.Comment         = ResultsMat.Comment;
    Results.Time            = Time([1, end]);
    Results.NumberOfSamples = NumberOfSamples;
    Results.SamplingRate    = SamplingRate;
    Results.ColormapType    = ResultsMat.ColormapType;
    Results.DisplayUnits    = ResultsMat.DisplayUnits;
    Results.Atlas           = ResultsMat.Atlas;
    % If channel flag not specified in results (pure kernel file)
    if isempty(ResultsMat.ChannelFlag) && ~isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag) 
        Results.ChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
    else
        Results.ChannelFlag = ResultsMat.ChannelFlag;
    end
    % If number of channels doesn't match the list of bad channels, fix it
    if ~isempty(Results.ChannelFlag) && ~isempty(GlobalData.DataSet(iDS).Channel) && (length(Results.ChannelFlag) ~= length(GlobalData.DataSet(iDS).Channel))
        Results.ChannelFlag = ones(length(GlobalData.DataSet(iDS).Channel), 1);
        Results.GoodChannel = 1:length(Results.ChannelFlag);
    % If GoodChannel not specified, consider that is is all the channels
    elseif isempty(ResultsMat.GoodChannel)
        Results.GoodChannel = 1:length(Results.ChannelFlag);
    else
        Results.GoodChannel = ResultsMat.GoodChannel;
    end
    
    % Store new Results structure in GlobalData
    iResult = length(GlobalData.DataSet(iDS).Results) + 1;
    GlobalData.DataSet(iDS).Results(iResult) = Results;
    
    % ===== Check time window consistency with previously loaded result =====
    % Save measures information if no DataFile is available
    % Create Measures structure
    if isempty(GlobalData.DataSet(iDS).Measures) || isempty(GlobalData.DataSet(iDS).Measures.Time)
        GlobalData.DataSet(iDS).Measures.Time            = double(Results.Time); 
        GlobalData.DataSet(iDS).Measures.SamplingRate    = double(Results.SamplingRate);
        GlobalData.DataSet(iDS).Measures.NumberOfSamples = Results.NumberOfSamples;
        if isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag) || (length(GlobalData.DataSet(iDS).Measures.ChannelFlag) ~= length(Results.ChannelFlag))
            GlobalData.DataSet(iDS).Measures.ChannelFlag = Results.ChannelFlag;
        end
    end
    % Update time window
    if isTimeCheck
        isTimeCoherent = CheckTimeWindows();
        % If loaded results are not coherent with previous data
        if ~isTimeCoherent
            % Remove it
            GlobalData.DataSet(iDS).Results(iResult) = [];
            iDS = [];
            iResult  = [];
            bst_error(['Time definition for this file is not compatible with the other files' 10 ...
                       'already loaded in Brainstorm.' 10 10 ...
                       'Close existing windows before opening this file, or use the Navigator.'], 'Load results', 0);
            return
        end
    end
    % Update TimeWindow panel, if it exists
    panel_time('UpdatePanel');
end



%% ===== LOAD RESULTS MATRIX =====
% Load the calculated matrices for a Results entry in a given dataset
% Results entry must have already been pre-loaded (with LoadResultsFile)
function LoadResultsMatrix(iDS, iResult)
    global GlobalData;
    % Check dataset and result indices integrity
    if (iDS <= 0) || (iDS > length(GlobalData.DataSet))
        error('Invalid DataSet index : %d', iDS);
    end
    if (iResult <= 0) || (iResult > length(GlobalData.DataSet(iDS).Results))
        error('Invalid Results index : %d', iResult);
    end
    
    % === NORMAL RESULTS ===
    if ~strcmpi(GlobalData.DataSet(iDS).Results(iResult).DataType, 'stat')
        % Load results matrix
        ResultsFile = GlobalData.DataSet(iDS).Results(iResult).FileName;
        FileMat = in_bst_results(ResultsFile, 0, 'ImageGridAmp', 'ImagingKernel', 'nComponents', 'GridLoc', 'GridOrient', 'GridAtlas', 'OpticalFlow', 'ZScore', 'Std');   
        % Is this a Z-score file?
        ColormapType = GlobalData.DataSet(iDS).Results(iResult).ColormapType;
        isZscore = ~isempty(GlobalData.DataSet(iDS).Results(iResult).ZScore) || ...
                   ~isempty(strfind(ResultsFile, '_zscore')) || ...
                   (~isempty(ColormapType) && ismember(ColormapType, {'stat1', 'stat2'}));
        % FULL RESULTS MATRIX
        if isfield(FileMat, 'ImageGridAmp') && ~isempty(FileMat.ImageGridAmp)
            % Apply online filters
            UseFilterResults = GlobalData.VisualizationFilters.FullSourcesEnabled;
            if UseFilterResults && ~isZscore
                sfreq = 1./GlobalData.DataSet(iDS).Measures.SamplingRate;
                FileMat.ImageGridAmp = FilterLoadedData(FileMat.ImageGridAmp, sfreq);
                %disp(sprintf('BST> Warning: Applying the online filters to the %d source signals. For faster display, apply the filter with a process before.', size(FileMat.ImageGridAmp,1)));
            end
            % Store results in memory
            GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp  = FileMat.ImageGridAmp; % FT 11-Jan-10: Remove "single"
            GlobalData.DataSet(iDS).Results(iResult).ImagingKernel = [];
            GlobalData.DataSet(iDS).Results(iResult).OpticalFlow   = FileMat.OpticalFlow;
            % Copy standard deviation if available
            if isfield(FileMat, 'Std') && ~isempty(FileMat.Std)
                GlobalData.DataSet(iDS).Results(iResult).Std = double(FileMat.Std);
            end
        % KERNEL ONLY
        elseif isfield(FileMat, 'ImagingKernel') && ~isempty(FileMat.ImagingKernel)
            GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp  = [];
            GlobalData.DataSet(iDS).Results(iResult).ImagingKernel = FileMat.ImagingKernel; % FT 11-Jan-10: Remove "single"
            GlobalData.DataSet(iDS).Results(iResult).OpticalFlow   = FileMat.OpticalFlow;
            GlobalData.DataSet(iDS).Results(iResult).ZScore        = FileMat.ZScore;
            % Make sure that recordings matrix is loaded
            if isempty(GlobalData.DataSet(iDS).Measures.F)
                LoadRecordingsMatrix(iDS);
            % If loading a Z-score source file and there are some visualization filters currently selected: reload data and figures
            elseif isZscore && GlobalData.DataSet(iDS).Measures.isFiltered && (GlobalData.VisualizationFilters.LowPassEnabled || GlobalData.VisualizationFilters.HighPassEnabled || GlobalData.VisualizationFilters.SinRemovalEnabled)
                LoadRecordingsMatrix(iDS);
                bst_figures('ReloadFigures');
            end
        % ERROR
        else
            error(['Invalid results file : ' GlobalData.DataSet(iDS).Results(iResult).FileName]);
        end

    % === STAT/RESULTS FILE ===
    else
        % Load stat matrix
        StatFile = GlobalData.DataSet(iDS).Results(iResult).FileName;
        FileMat = in_bst_results(StatFile, 0, 'pmap', 'tmap', 'df', 'SPM', 'nComponents', 'GridLoc', 'GridOrient', 'GridAtlas', 'Correction', 'StatClusters', 'Time');
        % For stat with more than one components: take the maximum t-value
        if (FileMat.nComponents ~= 1)
            % Extract one value at each grid point
            if ~isempty(FileMat.pmap)
                FileMat.pmap = bst_source_orient([], FileMat.nComponents, FileMat.GridAtlas, FileMat.pmap, 'min');
            end
            [FileMat.tmap, FileMat.GridAtlas] = bst_source_orient([], FileMat.nComponents, FileMat.GridAtlas, FileMat.tmap, 'absmax');
            % If unconstrained: consider as constrained
            if (FileMat.nComponents == 3)
                FileMat.nComponents = 1;
            end
            % Display message on the console
            disp('BST> This file is based on an unconstrained source model. Using the lowest p-value at each point.');
        end
        % Store results in GlobalData
        [thresholdedStatMap, tThreshUnder, tThreshOver] = process_extract_pthresh('Compute', FileMat);
        GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp  = thresholdedStatMap;
        GlobalData.DataSet(iDS).Results(iResult).StatThreshUnder = tThreshUnder;
        GlobalData.DataSet(iDS).Results(iResult).StatThreshOver = tThreshOver;        
        GlobalData.DataSet(iDS).Results(iResult).ImagingKernel = [];
        % Copy stat clusters
        GlobalData.DataSet(iDS).Results(iResult).StatClusters = FileMat.StatClusters;
        GlobalData.DataSet(iDS).Results(iResult).StatClusters.Correction = FileMat.Correction;
    end
    % Duplicate time if only one time frame
    if (size(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp,2) == 1)
        GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp = repmat(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp, [1 2]);
    end
    % Common fields
    GlobalData.DataSet(iDS).Results(iResult).nComponents = FileMat.nComponents;
    GlobalData.DataSet(iDS).Results(iResult).GridLoc     = FileMat.GridLoc;
    GlobalData.DataSet(iDS).Results(iResult).GridOrient  = FileMat.GridOrient;
    GlobalData.DataSet(iDS).Results(iResult).GridAtlas   = FileMat.GridAtlas;
end


%% ===== LOAD RESULTS : FULL LOAD & CHECK =====
function [iDS, iResult] = LoadResultsFileFull(ResultsFile)
    global GlobalData;
    % Load Results file
    [iDS, iResult] = LoadResultsFile(ResultsFile);
    % Check if dataset was not created
    if isempty(iDS) || isempty(iResult)
        bst_progress('stop');
        iDS = [];
        iResult = [];
        return;
    end
    % Check if results ImageGridAmp matrix is already loaded
    if isempty(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp) ...
            && isempty(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel)
        % Load associated matrix
        LoadResultsMatrix(iDS, iResult);
    end
    % Check again if restults matrix was loaded
    if isempty(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp) ...
            && isempty(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel)
        bst_progress('stop');
        error('Results matrix is not loaded or empty');
    end
end


%% ===== LOAD DIPOLES FILE =====
function [iDS, iDipoles] = LoadDipolesFile(DipolesFile, isTimeCheck) %#ok<DEFNU>
    global GlobalData;
    if (nargin < 2)
        isTimeCheck = 1;
    end
    % Show dipoles tab
    gui_brainstorm('ShowToolTab', 'Dipoles');

    % ===== GET ALL INFORMATION =====
    % Check whether file paths are absolute or relative
    if file_exist(DipolesFile)
        % Absolute filename (set from outside the GUI)
        DipolesFullFile = DipolesFile;
        DipolesFile = file_short(DipolesFile);
    else
        % Relative filename : add the STUDIES path
        DipolesFullFile = file_fullpath(DipolesFile);
    end
    % Get file information
    [sStudy, iDip, ChannelFile] = GetFileInfo(DipolesFile);

    % ===== ARE DIPOLES ALREADY LOADED ? ====
    % Check if file is already loaded in this DataSet
    [iDS, iDipoles] = GetDataSetDipoles(DipolesFile);
    % If dataset for target file already exists, just return its index
    if ~isempty(iDS) && ~isempty(iDipoles)
        return
    end
    
    % ===== GET/CREATE A NEW DATASET =====
    % Load results from which it depends
    if isempty(iDS) && ~isempty(sStudy.Dipoles(iDip).DataFile)
        switch file_gettype(sStudy.Dipoles(iDip).DataFile)
            case 'data'
                [iDS, iResults] = LoadDataFile(sStudy.Dipoles(iDip).DataFile);
            case {'results', 'link'}
                [iDS, iResults] = LoadResultsFile(sStudy.Dipoles(iDip).DataFile, 1);
        end
    else
        iResults = [];
    end
    % Get dataset with same study
    if isempty(iDS)
        iDS = GetDataSetStudy(sStudy.FileName);
        if ~isempty(iDS)
            iDS = iDS(1);
        end
    end
    % StudyFile not found in DataSets, try SubjectFile
    if isempty(iDS)
        iDS = GetDataSetSubject(sStudy.BrainStormSubject, 0);
        % Do not accept DataSet if an other DataFile is already attributed to the DataSet
        if ~isempty(iDS)
            iDS = iDS(cellfun(@(c)isempty(c), {GlobalData.DataSet(iDS).DataFile}));
            if ~isempty(iDS)
                iDS = iDS(1);
            end
        end
    end
    % Create dataset
    if isempty(iDS)
        % Create a new DataSet only for results
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS)             = db_template('DataSet');
        GlobalData.DataSet(iDS).SubjectFile = file_short(sStudy.BrainStormSubject);
    end
    if isempty(iDipoles) && isempty(iResults)
        GlobalData.DataSet(iDS).StudyFile   = file_short(sStudy.FileName);
        if ~isempty(ChannelFile)
            GlobalData.DataSet(iDS).ChannelFile = file_short(ChannelFile);
        end
        GlobalData.DataSet(iDS).DataFile    = '';
    end
    
    % ===== LOAD DIPOLES FILE =====
    % Load results .Mat
    DipolesMat = load(DipolesFullFile);
    Time = DipolesMat.Time;
    % If there is only one dipole, add artifical temporal dimension
    if (length(Time) == 1)
        Time = [Time Time+0.001];
    end
    % Backward compatible with dipole files that do not have subsets...
    if ~isfield(DipolesMat, 'Subset')
        DipolesMat.Subset = [];
    end
    if ~isfield(DipolesMat, 'DataFile')
        DipolesMat.DataFile = '';
    end
    if ~isfield(DipolesMat, 'PreferredTimes')
        DipolesMat.PreferredTimes = zeros(1,length(DipolesMat.DipoleNames));
    end
    % Backward compatible with dipole files that do not have all fields...
    if ~isfield(DipolesMat.Dipole, 'Khi2')
        DipolesMat.Dipole(end).Khi2 = [];
    end
    if ~isfield(DipolesMat.Dipole, 'DOF')
        DipolesMat.Dipole(end).DOF = [];
    end
    if ~isfield(DipolesMat.Dipole, 'ConfVol')
        DipolesMat.Dipole(end).ConfVol = [];
    end
    if ~isfield(DipolesMat.Dipole, 'Perform')
        DipolesMat.Dipole(end).Perform = [];
    end
    
    % ===== CREATE NEW DIPOLES ENTRY =====
    % Create structure
    Dipoles = db_template('LoadedDipoles');
    % Copy information
    Dipoles.FileName        = DipolesFile;
    Dipoles.Comment         = DipolesMat.Comment;
    Dipoles.Dipole          = DipolesMat.Dipole;
    Dipoles.DipoleNames     = DipolesMat.DipoleNames;
    Dipoles.Time            = Time([1, end]);
    Dipoles.NumberOfSamples = length(Time);
    Dipoles.SamplingRate    = Time(2)-Time(1);
    Dipoles.Subset          = DipolesMat.Subset;
    Dipoles.DataFile        = DipolesMat.DataFile;
    Dipoles.PreferredTimes  = DipolesMat.PreferredTimes;
    % Store new Results structure in GlobalData
    iDipoles = length(GlobalData.DataSet(iDS).Dipoles) + 1;
    GlobalData.DataSet(iDS).Dipoles(iDipoles) = Dipoles;  
    
    % ===== Check time window consistency with previously loaded files =====
    % Save measures information if no DataFile is available
    % Create Measures structure
    if isempty(GlobalData.DataSet(iDS).Measures) || isempty(GlobalData.DataSet(iDS).Measures.Time)
        GlobalData.DataSet(iDS).Measures.Time            = double(Dipoles.Time); 
        GlobalData.DataSet(iDS).Measures.SamplingRate    = double(Dipoles.SamplingRate);
        GlobalData.DataSet(iDS).Measures.NumberOfSamples = Dipoles.NumberOfSamples;
    end
    if isTimeCheck
        % Update time window
        isTimeCoherent = CheckTimeWindows();
        % If loaded results are not coherent with previous data
        if ~isTimeCoherent
            % Remove it
            GlobalData.DataSet(iDS).Dipoles(iDipoles) = [];
            iDS = [];
            iDipoles  = [];
            bst_error(['Time definition for this file is not compatible with the other files' 10 ...
                       'already loaded in Brainstorm.' 10 10 ...
                       'Close existing windows before opening this file, or use the Navigator.'], 'Load dipoles', 0);
            return
        end
    end
    % Update TimeWindow panel
    panel_time('UpdatePanel');
end
    

%% ===== LOAD TIME-FREQ FILE =====
function [iDS, iTimefreq, iResults] = LoadTimefreqFile(TimefreqFile, isTimeCheck, isLoadResults, isForceReload, PacOption)
    global GlobalData;
    if (nargin < 5) || isempty(PacOption)
        PacOption = '';   % {'MaxPAC'='', 'DynamicPAC', 'DynamicNesting'}
    end
    if (nargin < 4) || isempty(isForceReload)
        isForceReload = 0;
    end
    if (nargin < 3) || isempty(isLoadResults)
        isLoadResults = 0;
    end
    if (nargin < 2) || isempty(isTimeCheck)
        isTimeCheck = 1;
    end

    % ===== GET ALL INFORMATION =====
    % Get file information
    [sStudy, iTf, ChannelFile, FileType, sItem] = GetFileInfo(TimefreqFile);
    TimefreqMat = in_bst_timefreq(TimefreqFile, 0, 'DataType');
    % Get DataFile
    TimefreqFile = sItem.FileName;
    ParentFile = sItem.DataFile;
    
    % ===== IS FILE ALREADY LOADED ? ====
    iDS      = [];
    iResults = [];
    DataFile = '';
    if ~isempty(ParentFile)
        switch (TimefreqMat.DataType)
            case 'data'
                DataFile = ParentFile;
                % Load (or simply get) DataSet associated with DataFile
                % isForceReload = 0;
                % iDS = LoadDataFile(DataFile, isForceReload);
            case 'results'
                % Get data file associated with the results file
                [sStudy,iStudy,iRes] = bst_get('ResultsFile', ParentFile);
                DataFile = sStudy.Result(iRes).DataFile;
                % Load (or simply get) DataSet associated with ResultsFile (load inverse kernel if it has to be applied to the TF matrix)
                if isLoadResults || ~isempty(strfind(TimefreqFile, '_KERNEL_'))
                    [iDS, iResults] = LoadResultsFileFull(ParentFile);
                end
            case {'cluster', 'scout', 'matrix'}
                % Load (or simply get) DataSet associated with MatrixFile
                % iDS = LoadMatrixFile(ParentFile);
        end
    end
    % Force DataFile to be a string, and not a double empty matrix
    if isempty(DataFile)
        DataFile = '';
    end
    % Load timefreq file
    if ~isempty(iDS)
        iTimefreq = GetTimefreqInDataSet(iDS, TimefreqFile);
    else
        [iDS, iTimefreq] = GetDataSetTimefreq(TimefreqFile);
    end
    % If dataset for target file already exists, just return its index
    if ~isForceReload && ~isempty(iDS) && ~isempty(iTimefreq)
        return
    end
    
    % ===== LOAD TIME-FREQ FILE =====
    isStat = strcmpi(FileType, 'ptimefreq');
    if ~isStat
        % Load .Mat
        TimefreqMat = in_bst_timefreq(TimefreqFile, 0, 'TF', 'TFmask', 'Time', 'Freqs', 'DataFile', 'DataType', 'Comment', 'TimeBands', 'RowNames', 'RefRowNames', 'Measure', 'Method', 'Options', 'ColormapType', 'DisplayUnits', 'Atlas', 'HeadModelFile', 'SurfaceFile', 'sPAC', 'GridLoc', 'GridAtlas');
%         % Load inverse kernel that goes with it if applicable
%         if ~isempty(ParentFile) && strcmpi(TimefreqMat.DataType, 'results') % && (size(TimefreqMat.TF,1) < length(TimefreqMat.RowNames))
%             [iDS, iResults] = LoadResultsFileFull(ParentFile);
%         end
    else
        % Load stat matrix
        TimefreqMat = in_bst_timefreq(TimefreqFile, 0, 'pmap', 'tmap', 'df', 'SPM', 'TFmask', 'Time', 'Freqs', 'DataFile', 'DataType', 'Comment', 'TF', 'TimeBands', 'RowNames', 'RefRowNames', 'Measure', 'Method', 'Options', 'ColormapType', 'DisplayUnits', 'Atlas', 'HeadModelFile', 'SurfaceFile', 'sPAC', 'GridLoc', 'GridAtlas', 'Correction', 'StatClusters');
        % Report thresholded maps
        [TimefreqMat.TF, tThreshUnder, tThreshOver] = process_extract_pthresh('Compute', TimefreqMat);
        % Open the "Stat" tab
        gui_brainstorm('ShowToolTab', 'Stat');
    end
    % Replace some fields for DynamicPAC 
    if isequal(PacOption, 'DynamicPAC')
        TimefreqMat.TF = TimefreqMat.sPAC.DynamicPAC;
        TimefreqMat.Freqs = TimefreqMat.sPAC.HighFreqs;
    elseif isequal(PacOption, 'DynamicNesting')
        TimefreqMat.TF = TimefreqMat.sPAC.DynamicNesting;
        TimefreqMat.Freqs = TimefreqMat.sPAC.HighFreqs;
    end
    % If Freqs matrix is not well oriented
    if ~iscell(TimefreqMat.Freqs) && (size(TimefreqMat.Freqs, 1) > 1)
        TimefreqMat.Freqs = TimefreqMat.Freqs';
    end
    % Show frequency slider
    isStaticFreq = (size(TimefreqMat.TF,3) <= 1);
    if ~isStaticFreq
        gui_brainstorm('ShowToolTab', 'FreqPanel');
    end
    % Duplicate time if only one time frame
    if (length(TimefreqMat.Time) == 1)
        TimefreqMat.Time = [0,0.001] + TimefreqMat.Time;
    end
    if (size(TimefreqMat.TF,2) == 1)
        TimefreqMat.TF = repmat(TimefreqMat.TF, [1 2 1]);
    end
    
    % ===== CHECK FREQ COMPATIBILITY =====
    isFreqOk = 1;
    % Do not check if new files has no Frequency definition (Freqs = 1 value, or empty)
    if (length(TimefreqMat.Freqs) >= 2)
        if isempty(GlobalData.UserFrequencies.Freqs)
            GlobalData.UserFrequencies.Freqs = TimefreqMat.Freqs;
            % Update time-frenquecy panel
            panel_freq('UpdatePanel');
        elseif ~isempty(TimefreqMat.Freqs) && ~isequal(GlobalData.UserFrequencies.Freqs, TimefreqMat.Freqs)
            if iscell(GlobalData.UserFrequencies.Freqs) && iscell(TimefreqMat.Freqs) && isequal(GlobalData.UserFrequencies.Freqs(:,1), TimefreqMat.Freqs(:,1))
                isFreqOk = 1;
            elseif ~iscell(GlobalData.UserFrequencies.Freqs) && ~iscell(TimefreqMat.Freqs) && (length(GlobalData.UserFrequencies.Freqs) == length(TimefreqMat.Freqs)) && ...
                    all(abs(GlobalData.UserFrequencies.Freqs - TimefreqMat.Freqs) < 1e-5)
                isFreqOk = 1;
            else
                isFreqOk = 0;
            end
        else
            GlobalData.UserFrequencies.Freqs = TimefreqMat.Freqs;
        end
        % Error message if it doesn't match
        if ~isFreqOk
            res = java_dialog('question', [...
                'The frequency definition is not compatible with previously loaded files.' 10 ...
                'Unload all the other files first?' 10 10], 'Load time-frequency', [], {'Unload other files', 'Cancel'});
            % Cancel: Unload the new dataset
            if isempty(res) || strcmpi(res, 'Cancel')
                iDS = [];
                iTimefreq = [];
                iResults = [];
                return;
            % Otherwise: unload all the other datasets
            else
                % Save newly created dataset
                bakDS = GlobalData.DataSet(iDS);
                % Unload everything
                UnloadAll('Forced');
                % If not everything was unloaded correctly (eg. the user cancelled half way when asked to save the modifications)
                if ~isempty(GlobalData.DataSet)
                    iTimefreq = [];
                    iResults = [];
                    iDS = [];
                    return;
                end
                % Restore new dataset
                GlobalData.DataSet = bakDS;
                if ~isempty(iDS)
                    iDS = 1;
                end
                % Update frequencies
                GlobalData.UserFrequencies.Freqs = TimefreqMat.Freqs;
                gui_brainstorm('ShowToolTab', 'FreqPanel');
            end
        end
        % Current frequency
        if isempty(GlobalData.UserFrequencies.iCurrentFreq)
            GlobalData.UserFrequencies.iCurrentFreq = 1;
            panel_freq('UpdatePanel');
        end
    end
    
    % ===== GET/CREATE A NEW DATASET =====
    % Create dataset
    if isempty(iDS)
        % Create a new DataSet only for results
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS)             = db_template('DataSet');
        GlobalData.DataSet(iDS).SubjectFile = file_win2unix(sStudy.BrainStormSubject);
        GlobalData.DataSet(iDS).StudyFile   = file_win2unix(sStudy.FileName);
        GlobalData.DataSet(iDS).ChannelFile = file_win2unix(ChannelFile);
        GlobalData.DataSet(iDS).DataFile    = DataFile;
    end
    % Make sure that there is only one dataset selected
    iDS = iDS(1);
    
    % ===== CREATE A FAKE RESULT FOR GRID LOC =====
    % This is specifically for the case of timefreq files calculated on volume source grids, without a ParentFile
    % => In this case, the location of the source points is saved in GridLoc
    if ~isempty(TimefreqMat.GridLoc) && isempty(ParentFile)
        % Fake results file
        ParentFile = strrep(TimefreqFile, '.mat', '$.mat');
        TimefreqMat.DataFile = ParentFile;
        % Check if this fake file is already created
        if ~isempty(GlobalData.DataSet(iDS).Results)
            iResults = find(file_compare({GlobalData.DataSet(iDS).Results.FileName}, ParentFile) & (cellfun(@length, {GlobalData.DataSet(iDS).Results.GridLoc}) == length(TimefreqMat.GridLoc)));
        else
            iResults = [];
        end
        % Create new fake structure
        if isempty(iResults)
            iResults = length(GlobalData.DataSet(iDS).Results) + 1;
            GlobalData.DataSet(iDS).Results(iResults) = db_template('LoadedResults');
            GlobalData.DataSet(iDS).Results(iResults).FileName        = ParentFile;
            GlobalData.DataSet(iDS).Results(iResults).DataType        = 'results';
            GlobalData.DataSet(iDS).Results(iResults).Comment         = [TimefreqMat.Comment '$'];
            GlobalData.DataSet(iDS).Results(iResults).Time            = [TimefreqMat.Time(1), TimefreqMat.Time(end)];
            GlobalData.DataSet(iDS).Results(iResults).SamplingRate    = (TimefreqMat.Time(2) - TimefreqMat.Time(1));
            GlobalData.DataSet(iDS).Results(iResults).NumberOfSamples = length(TimefreqMat.Time);
            GlobalData.DataSet(iDS).Results(iResults).HeadModelType   = 'volume';
            GlobalData.DataSet(iDS).Results(iResults).HeadModelFile   = TimefreqMat.HeadModelFile;
            GlobalData.DataSet(iDS).Results(iResults).SurfaceFile     = TimefreqMat.SurfaceFile;
            GlobalData.DataSet(iDS).Results(iResults).GridLoc         = TimefreqMat.GridLoc;
            GlobalData.DataSet(iDS).Results(iResults).GridAtlas       = TimefreqMat.GridAtlas;
            GlobalData.DataSet(iDS).Results(iResults).nComponents     = 3;
        end
    end
    
    % ===== REMOVE NAN =====
    % Replace NaN values with 0, and add them to the mask
    iNan = find(isnan(TimefreqMat.TF));
    if ~isempty(iNan)
        disp(sprintf('BST> Error: There are %d abnormal NaN values in this file, check the computation process.', length(iNan)));
        TimefreqMat.TF(iNan) = 0;
    end
    
    % ===== CREATE NEW TIMEFREQ ENTRY =====
    % Create structure
    Timefreq = db_template('LoadedTimefreq');
    % Copy information
    Timefreq.FileName        = TimefreqFile;
    Timefreq.DataFile        = TimefreqMat.DataFile;
    Timefreq.DataType        = TimefreqMat.DataType;
    Timefreq.Comment         = TimefreqMat.Comment;
    Timefreq.TF              = TimefreqMat.TF;
    Timefreq.TFmask          = TimefreqMat.TFmask;
    Timefreq.Freqs           = TimefreqMat.Freqs;
    Timefreq.Time            = TimefreqMat.Time([1, end]);
    Timefreq.TimeBands       = TimefreqMat.TimeBands;
    Timefreq.RowNames        = TimefreqMat.RowNames;
    Timefreq.RefRowNames     = TimefreqMat.RefRowNames;
    Timefreq.Measure         = TimefreqMat.Measure;
    Timefreq.Method          = TimefreqMat.Method;
    Timefreq.NumberOfSamples = length(TimefreqMat.Time);
    Timefreq.SamplingRate    = TimefreqMat.Time(2) - TimefreqMat.Time(1);
    Timefreq.Options         = TimefreqMat.Options;
    Timefreq.ColormapType    = TimefreqMat.ColormapType;
    Timefreq.DisplayUnits    = TimefreqMat.DisplayUnits;
    Timefreq.SurfaceFile     = TimefreqMat.SurfaceFile;
    Timefreq.Atlas           = TimefreqMat.Atlas;
    Timefreq.GridLoc         = TimefreqMat.GridLoc;
    Timefreq.GridAtlas       = TimefreqMat.GridAtlas;
    Timefreq.sPAC            = TimefreqMat.sPAC;
    if isfield(TimefreqMat, 'StatClusters')
        Timefreq.StatClusters = TimefreqMat.StatClusters;
        Timefreq.StatClusters.Correction = TimefreqMat.Correction;
    end
    % ===== EXPAND SYMMETRIC MATRICES =====
    %if isfield(Timefreq.Options, 'isSymmetric') && Timefreq.Options.isSymmetric
    if (length(Timefreq.RowNames) == length(Timefreq.RefRowNames)) && (size(Timefreq.TF,1) < length(Timefreq.RowNames)^2)
        Timefreq.TF = process_compress_sym('Expand', Timefreq.TF, length(Timefreq.RowNames));
    end
    % Store new Timefreq structure in GlobalData
    if isempty(iTimefreq)
        iTimefreq = length(GlobalData.DataSet(iDS).Timefreq) + 1;
    end
    GlobalData.DataSet(iDS).Timefreq(iTimefreq) = Timefreq;  
    
    % ===== LOAD CHANNEL FILE =====
    if ~isempty(ChannelFile)
        LoadChannelFile(iDS, ChannelFile);
    end

    % ===== DETECT MODALITY =====
    if strcmpi(Timefreq.DataType, 'data')
        uniqueRows = unique(Timefreq.RowNames);
        % Find channels
        iChannels = [];
        for iRow = 1:length(uniqueRows)
            iChan = find(strcmpi({GlobalData.DataSet(iDS).Channel.Name}, uniqueRows{iRow}));
            if ~isempty(iChan)
                iChannels(end+1) = iChan;
            end
        end
        % Detect modality
        Modality = unique({GlobalData.DataSet(iDS).Channel(iChannels).Type});
        % Convert the Neuromag MEG GRAD/MEG MAG, as just "MEG"
        if isequal(Modality, {'MEG GRAD', 'MEG MAG'})
            Modality = {'MEG'};
        end
        % Copy list to all modalities
        GlobalData.DataSet(iDS).Timefreq(iTimefreq).AllModalities = Modality;
        % If only one modality: consider it as the "type" of the file
        if (length(Modality) == 1)
            GlobalData.DataSet(iDS).Timefreq(iTimefreq).Modality = Modality{1};
            % If the good/bad channels for the dataset are not defined yet
            if isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
                % PSD: Remove bad channels defined in parent data file
                if strcmpi(Timefreq.Method, 'psd') && ~isempty(Timefreq.DataFile) && strcmpi(file_gettype(Timefreq.DataFile), 'data')
                    ParentMat = in_bst_data(Timefreq.DataFile, 'ChannelFlag');
                    if ~isempty(ParentMat) && ~isempty(ParentMat.ChannelFlag)
                        GlobalData.DataSet(iDS).Measures.ChannelFlag = ParentMat.ChannelFlag;
                    end
                end
                % Otherwise: Set all the channels as good by default
                if isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
                    GlobalData.DataSet(iDS).Measures.ChannelFlag = ones(length(GlobalData.DataSet(iDS).Channel), 1);
                end
                % Set all the channel in the file as good, and the other channels from the same modality as bad
                iChanMod = good_channel(GlobalData.DataSet(iDS).Channel, [], Modality{1});
                iBadChan = setdiff(iChanMod, iChannels);
                if ~isempty(iBadChan)
                    GlobalData.DataSet(iDS).Measures.ChannelFlag(iBadChan) = -1;
                end
            end
        end
    end
    
    % ===== Check time window consistency with previously loaded files =====
    % Save measures information if no DataFile is available
    % Create Measures structure
    if isempty(GlobalData.DataSet(iDS).Measures) || isempty(GlobalData.DataSet(iDS).Measures.Time)
        GlobalData.DataSet(iDS).Measures.Time            = double(Timefreq.Time); 
        GlobalData.DataSet(iDS).Measures.SamplingRate    = double(Timefreq.SamplingRate);
        GlobalData.DataSet(iDS).Measures.NumberOfSamples = Timefreq.NumberOfSamples;
    end
    % Update time window
    if isTimeCheck
        isTimeCoherent = CheckTimeWindows();
        % If loaded results are not coherent with previous data
        if ~isTimeCoherent
            % Remove it
            GlobalData.DataSet(iDS).Timefreq(iTimefreq) = [];
            iDS = [];
            iTimefreq  = [];
            bst_error(['Time definition for this file is not compatible with the other files' 10 ...
                       'already loaded in Brainstorm.' 10 10 ...
                       'Close existing windows before opening this file, or use the Navigator.'], 'Load time-frequency', 0);
            return
        end
    end
    % Update TimeWindow panel
    panel_time('UpdatePanel');
end


%% ===== RESHAPE CONNECTIVITY MATRIX =====
function R = ReshapeConnectMatrix(iDS, iTfRef, TF, selRefRow) %#ok<DEFNU>
    global GlobalData;
    % Parse inputs
    if (nargin < 4)
        selRefRow = [];
    end
    % Names of the rows and columns of the connectivity matrix
    RefRowNames = GlobalData.DataSet(iDS).Timefreq(iTfRef).RefRowNames;
    RowNames    = GlobalData.DataSet(iDS).Timefreq(iTfRef).RowNames;
    nTime       = size(TF, 2);
    nFreq       = size(TF, 3);
    % Reshape connectivity matrix: [Nrow x Ncol x Ntime x nFreq]
    R = reshape(TF, [length(RefRowNames), length(RowNames), nTime, nFreq]);
    % Keep only the selected row
    if ~isempty(selRefRow)
        % Find target row
        iSel = find(strcmpi(selRefRow, RefRowNames));
        if isempty(iSel)
            return
        end
        % Select only the required row
        R = R(iSel, :, :, :);
    end
end


%% ===== GET CONNECT MATRIX =====
function R = GetConnectMatrix(Timefreq) %#ok<DEFNU>
    % Expand symmetric matrix
    %if isfield(Timefreq.Options, 'isSymmetric') && Timefreq.Options.isSymmetric
    if (length(Timefreq.RowNames) == length(Timefreq.RefRowNames)) && (size(Timefreq.TF,1) < length(Timefreq.RowNames)^2)
        Timefreq.TF = process_compress_sym('Expand', Timefreq.TF, length(Timefreq.RowNames));
    end
    % Reshape TF matrix: [Nrow x Ncol x Ntime x nFreq]
    nTime = size(Timefreq.TF, 2);
    nFreq = size(Timefreq.TF, 3);
    R = reshape(Timefreq.TF, [length(Timefreq.RefRowNames), length(Timefreq.RowNames), nTime, nFreq]);
end

%% ===== GET CONNECT MATRIX (STD) =====
function R = GetConnectMatrixStd(Timefreq) %#ok<DEFNU>
    % Expand symmetric matrix
    %if isfield(Timefreq.Options, 'isSymmetric') && Timefreq.Options.isSymmetric
    if (length(Timefreq.RowNames) == length(Timefreq.RefRowNames)) && (size(Timefreq.Std,1) < length(Timefreq.RowNames)^2)
        Timefreq.Std = process_compress_sym('Expand', Timefreq.Std, length(Timefreq.RowNames));
    end
    % Reshape Std matrix: [Nrow x Ncol x Ntime x nFreq x nBounds]
    nTime   = size(Timefreq.Std, 2);
    nFreq   = size(Timefreq.Std, 3);
    nBounds = size(Timefreq.Std, 4);
    R = reshape(Timefreq.Std, [length(Timefreq.RefRowNames), length(Timefreq.RowNames), nTime, nFreq, nBounds]);
end




%% ===== LOAD MATRIX FILE =====
function [iDS, iMatrix] = LoadMatrixFile(MatFile, iDS, iMatrix) %#ok<DEFNU>
    global GlobalData;
    % Force to load in a specific slot?
    if (nargin < 3) || isempty(iDS) || isempty(iMatrix)
        iDS = [];
        iMatrix = [];
        isUpdateDef = 0;
    else
        isUpdateDef = 1;
    end
        
    % ===== GET/CREATE A NEW DATASET =====
    % Get study
    sStudy = bst_get('AnyFile', MatFile);
    if isempty(sStudy)
        iDS = [];
        return;
    end
    % Get time definition
    Mat = in_bst_matrix(MatFile, 'Time', 'Description', 'Events', 'Comment', 'Atlas', 'SurfaceFile', 'StatClusters', 'Correction', 'DisplayUnits');
    % Duplicate time if only one time frame
    if (length(Mat.Time) == 1)
        Mat.Time = [0,0.001] + Mat.Time;
    end
    % Look for file in all the datasets
    if isempty(iDS)
        [iDS, iMatrix] = GetDataSetMatrix(MatFile);
    end
    % Get dataset with same study
    if isempty(iDS) && isempty(Mat.Events)
        iDS = GetDataSetStudy(sStudy.FileName);
    end
    % Create dataset
    if isempty(iDS)
        % Create a new DataSet only for results
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS)             = db_template('DataSet');
        GlobalData.DataSet(iDS).SubjectFile = file_short(sStudy.BrainStormSubject);
        GlobalData.DataSet(iDS).StudyFile   = file_short(sStudy.FileName);
    end
    % Make sure that there is only one dataset selected
    iDS = iDS(1);
 
    % ===== CHECK TIME =====
    % If there time in this file
    if (length(Mat.Time) >= 2)
        isTimeOkDs = 1;
        % Save measures information if no DataFile is available
        if isempty(GlobalData.DataSet(iDS).Measures) || isempty(GlobalData.DataSet(iDS).Measures.Time)
            GlobalData.DataSet(iDS).Measures.Time            = double(Mat.Time([1, end])); 
            GlobalData.DataSet(iDS).Measures.SamplingRate    = double(Mat.Time(2) - Mat.Time(1));
            GlobalData.DataSet(iDS).Measures.NumberOfSamples = length(Mat.Time);
        elseif (abs(Mat.Time(1)   - GlobalData.DataSet(iDS).Measures.Time(1)) > 1e-5) || ...
               (abs(Mat.Time(end) - GlobalData.DataSet(iDS).Measures.Time(2)) > 1e-5) || ...
               ~isequal(length(Mat.Time), GlobalData.DataSet(iDS).Measures.NumberOfSamples)
            isTimeOkDs = 0;
        end
        % Update time window
        isTimeCoherent = CheckTimeWindows();
        % If loaded file are not coherent with previous data
        if ~isTimeCoherent || ~isTimeOkDs
            iDS = [];
            bst_error(['Time definition for this file is not compatible with the other files' 10 ...
                       'already loaded in Brainstorm.' 10 10 ...
                       'Close existing windows before opening this file, or use the Navigator.'], 'Load matrix', 0);
            return
        end
        % Update TimeWindow panel
        panel_time('UpdatePanel');
    end
        
    % ===== REFERENCE FILE =====
    % Reference matrix file in the dataset
    if isempty(iMatrix)
        iMatrix = length(GlobalData.DataSet(iDS).Matrix) + 1;
        isUpdateDef = 1;
    end
    if isUpdateDef
        GlobalData.DataSet(iDS).Matrix(iMatrix).FileName     = MatFile;
        GlobalData.DataSet(iDS).Matrix(iMatrix).Comment      = Mat.Comment;
        GlobalData.DataSet(iDS).Matrix(iMatrix).Description  = Mat.Description;
        GlobalData.DataSet(iDS).Matrix(iMatrix).DisplayUnits = Mat.DisplayUnits;
        GlobalData.DataSet(iDS).Matrix(iMatrix).SurfaceFile  = Mat.SurfaceFile;
        GlobalData.DataSet(iDS).Matrix(iMatrix).Atlas        = Mat.Atlas;
        GlobalData.DataSet(iDS).Matrix(iMatrix).StatClusters = Mat.StatClusters;
        GlobalData.DataSet(iDS).Matrix(iMatrix).StatClusters.Correction = Mat.Correction;
        % Store events
        if ~isempty(Mat.Events)
            sFile.events = Mat.Events;
        else
            sFile.events = repmat(db_template('event'), 0);
        end
        GlobalData.DataSet(iDS).Measures.sFile = sFile;
        % Display units
        GlobalData.DataSet(iDS).Measures.DisplayUnits = Mat.DisplayUnits;
    end
end


%% ===== GET RECORDINGS VALUES =====
% USAGE:  [DataValues, Std] = GetRecordingsValues(iDS, iChannel, iTime, isGradMagScale)
%         [DataValues, Std] = GetRecordingsValues(iDS, iChannel, 'UserTimeWindow')
%         [DataValues, Std] = GetRecordingsValues(iDS, iChannel, 'CurrentTimeIndex')
%         [DataValues, Std] = GetRecordingsValues(iDS, iChannel)                        : Get recordings for UserTimeWindow
%         [DataValues, Std] = GetRecordingsValues(iDS)                                  : Get all the channels
function [DataValues, Std] = GetRecordingsValues(iDS, iChannel, iTime, isGradMagScale) %#ok<DEFNU>
    global GlobalData;
    
    % ===== PARSE INPUTS =====
    % Default iChannel: all
    if (nargin < 2) || isempty(iChannel)
        iChannel = 1:length(GlobalData.DataSet(iDS).Channel);
    end
    % Default time values: current user time window
    if (nargin < 3) || isempty(iTime)
        % Static dataset: use the whole time window
        if (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2)
            iTime = [1 2];
        % Else: use the current user time window
        else
            iTime = 'UserTimeWindow';
        end
    end
    % Get generic time selections
    if ischar(iTime)
        % iTime possible values: 'UserTimeWindow', 'CurrentTimeIndex'
        [TimeVector, iTime] = GetTimeVector(iDS, [], iTime);
    end
    % Is it needed to apply Gradiometer/Magnetometers scaling factor for Neuromag recordings ?
    if (nargin < 4) || isempty(isGradMagScale)
        isGradMagScale = 1;
    end
    
    % ===== LOAD DATA MATRIX =====
    if isempty(GlobalData.DataSet(iDS).Measures.F)
        LoadRecordingsMatrix(iDS);
    end
    
    % ===== GET RECORDINGS =====
    % If values are loaded in memory
    if ~isempty(GlobalData.DataSet(iDS).Measures.F)
        % Get recording values
        DataValues = GlobalData.DataSet(iDS).Measures.F(iChannel, iTime);
        DataType = GlobalData.DataSet(iDS).Measures.DataType;
        % Get standard deviation
        if ~isempty(GlobalData.DataSet(iDS).Measures.Std)
            Std = GlobalData.DataSet(iDS).Measures.Std(iChannel, iTime, :, :);
        else
            Std = [];
        end
        % Gradio/magnetometers scale
        if isGradMagScale && ~isempty(DataType) && ismember(DataType, {'recordings', 'raw'})
            % Scale gradiometers / magnetometers:
            %    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert in fT/cm
            %    - CTF: Apply factor to MEG REF gradiometers
            DataValues = bst_scale_gradmag( DataValues, GlobalData.DataSet(iDS).Channel(iChannel));
            % Normalize standard deviation too
            if ~isempty(Std)
                for iBound = 1:size(Std, 4)
                    Std(:,:,:,iBound) = bst_scale_gradmag(Std(:,:,:,iBound), GlobalData.DataSet(iDS).Channel(iChannel));
                end
            end
        end
    else
        DataValues = [];
        Std = [];
    end
end
        

%% ===== GET RESULTS VALUES ======
% USAGE:  [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult, iVertices, ...,             , ApplyOrient=1, isVolumeAtlas=0)
%         [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult, iVertices, iTime)
%         [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult, iVertices, 'UserTimeWindow')
%         [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult, iVertices, 'CurrentTimeIndex')
%         [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult, iVertices)
%         [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult)
function [ResultsValues, nComponents, Std] = GetResultsValues(iDS, iResult, iVertices, iTime, ApplyOrient, isVolumeAtlas)
    global GlobalData;
    % ===== PARSE INPUTS =====
    Std = [];
    % Is iVertices obtained on a volume atlas
    if (nargin < 6) || isempty(isVolumeAtlas)
        isVolumeAtlas = 0;
    end
    % Get number of components
    nComponents = GlobalData.DataSet(iDS).Results(iResult).nComponents;
    % Default iVertices: all
    if (nargin < 3) || isempty(iVertices)
        iRows = [];
    % Adapt list of vertices to the number of components per vertex
    else
        iRows = bst_convert_indices(iVertices, nComponents, GlobalData.DataSet(iDS).Results(iResult).GridAtlas, ~isVolumeAtlas);
        if isempty(iRows)
            % bst_error('Invalid vertex indices.', 'Get source values', 0);
            ResultsValues = [];
            return;
        end
    end
    % Get results time window
    if (nargin < 4) || isempty(iTime)
        iTime = 'UserTimeWindow';
    end
    % Apply orientation (useful only for unconstrained results)
    if (nargin < 5) || isempty(ApplyOrient)
        ApplyOrient = 1;
    end
    % Get time window
    [TimeVector, iTime] = GetTimeVector(iDS, iResult, iTime);

    % ===== GET RESULTS VALUES =====
    % === FULL RESULTS ===
    if ~isempty(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp)
        % Get ImageGridAmp interesting sub-part
        if isempty(iRows)
            ResultsValues = double(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp(:, iTime));
            if ~isempty(GlobalData.DataSet(iDS).Results(iResult).Std)
                Std = double(GlobalData.DataSet(iDS).Results(iResult).Std(:, iTime, :, :));
            end
        else
            ResultsValues = double(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp(iRows, iTime));
            if ~isempty(GlobalData.DataSet(iDS).Results(iResult).Std)
                Std = double(GlobalData.DataSet(iDS).Results(iResult).Std(iRows, iTime, :, :));
            end
        end
    % === KERNEL ONLY ===
    elseif ~isempty(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel)
        % == LOAD DATA ==
        % If 'F' matrix is not loaded for this file
        if isempty(GlobalData.DataSet(iDS).Measures.F)
            % Load recording matrix
            LoadRecordingsMatrix(iDS);
        end

        % == MULTIPLICATION ==
        % Get selected channels
        GoodChannel = GlobalData.DataSet(iDS).Results(iResult).GoodChannel;
        % Get Data values
        Data = GlobalData.DataSet(iDS).Measures.F(GoodChannel, iTime);
        % Select only the needed vertices
        if isempty(iRows)
            ImagingKernel = GlobalData.DataSet(iDS).Results(iResult).ImagingKernel;
        else
            ImagingKernel = GlobalData.DataSet(iDS).Results(iResult).ImagingKernel(iRows,:);
        end
        % Get surface values and multiply them with Kernel
        ResultsValues = ImagingKernel * Data;

        % == APPLY DYNAMIC ZSCORE ==
        if ~isempty(GlobalData.DataSet(iDS).Results(iResult).ZScore)
            ZScore = GlobalData.DataSet(iDS).Results(iResult).ZScore;
            % Keep only the selected vertices
            if ~isempty(iRows) && ~isempty(ZScore.mean)
                ZScore.mean = ZScore.mean(iRows,:);
                ZScore.std  = ZScore.std(iRows,:);
            end
            % Calculate mean/std
            if isempty(ZScore.mean)
                [ResultsValues, ZScore] = process_zscore_dynamic('Compute', ResultsValues, ZScore, ...
                    TimeVector, ImagingKernel, GlobalData.DataSet(iDS).Measures.F(GoodChannel,:));
                % Check if something went wrong
                if isempty(ResultsValues)
                    bst_error('Baseline definition is not valid for this file.', 'Dynamic Z-score', 0);
                    ResultsValues = [];
                    return;
                end
                % If all the sources: report the changes in the ZScore structure
                if isempty(iRows)
                    GlobalData.DataSet(iDS).Results(iResult).ZScore = ZScore;
                end
            % Apply existing mean/std
            else
                ResultsValues = process_zscore_dynamic('Compute', ResultsValues, ZScore);
            end
        end
    end

    % ===== UNCONSTRAINED SOURCES =====
    % If unconstrained sources (0, 2 or 3 values per source) => Compute norm
    if ApplyOrient && (nComponents ~= 1)
        % STAT: Get the maximum along the different components
        if strcmpi(GlobalData.DataSet(iDS).Results(iResult).DataType, 'stat')
            compFunction = 'max';
        % Else: Take the norm
        else
            compFunction = 'rms';
        end
        % Group the components
        ResultsValues = bst_source_orient(iVertices, nComponents, GlobalData.DataSet(iDS).Results(iResult).GridAtlas, ResultsValues, compFunction);
        % Same for standard deviation
        if ~isempty(Std)
            Std = bst_source_orient(iVertices, nComponents, GlobalData.DataSet(iDS).Results(iResult).GridAtlas, Std, compFunction);
        end
    end
end


%% ===== GET DIPOLES VALUES ======
% USAGE:  DipolesValues = GetDipolesValues(iDS, iDipoles, iTime)
%         DipolesValues = GetDipolesValues(iDS, iDipoles, 'UserTimeWindow')
%         DipolesValues = GetDipolesValues(iDS, iDipoles, 'CurrentTimeIndex')
%         DipolesValues = GetDipolesValues(iDS, iDipoles)
function DipolesValues = GetDipolesValues(iDS, iDipoles, iTime) %#ok<DEFNU>
    global GlobalData;
    % ===== PARSE INPUTS =====
    % Get results time window
    if (nargin < 3)
        iTime = 'UserTimeWindow';
    end
    % Get time window
    [TimeVector, iTime] = GetTimeVector(iDS, iDipoles, iTime, 'Dipoles');

    % ===== GET DIPOLES VALUES =====
    iDip = find(sum(abs(bst_bsxfun(@minus, repmat([GlobalData.DataSet(iDS).Dipoles(iDipoles).Dipole.Time]', 1, length(iTime)), TimeVector(iTime))) < 1e-5, 2));  
    DipolesValues = GlobalData.DataSet(iDS).Dipoles(iDipoles).Dipole(iDip);
end


%% ===== GET TIME-FREQ VALUES =====
% USAGE:  [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, RowNames, iFreqs, iTime,              Function, RefRowName, FooofDisp)
%         [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, RowNames, iFreqs, 'UserTimeWindow')
%         [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, RowNames, iFreqs, 'CurrentTimeIndex')
%         [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, RowNames, iFreqs)
%         [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, RowNames)
%         [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, 'firstrow', ...)
%         [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq)
function [Values, iTimeBands, iRow, nComponents] = GetTimefreqValues(iDS, iTimefreq, RowNames, iFreqs, iTime, Function, RefRowName, FooofDisp)
    global GlobalData;
    % ===== PARSE INPUTS =====
    if (nargin < 8) || isempty(FooofDisp)
        FooofDisp = [];
        isFooof = false;
    else
        isFooof = isfield(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options, 'FOOOF') && ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF);
    end
    % Default RefRowName: all
    if (nargin < 7) || isempty(RefRowName)
        RefRowName = [];
    end
    % Default function: Unchanged
    if (nargin < 6) || isempty(Function)
        Function = [];
    end
    % Default time window
    if (nargin < 5) || isempty(iTime)
        iTime = 'UserTimeWindow';
    end
    % Get full time-freq matrix
    nRow  = size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF, 1);
    % Default frequencies: all
    if (nargin < 4) || isempty(iFreqs)
        iFreqs = 1:size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF, 3);
    end
    if (nargin < 3)
        RowNames = [];
    end
    iTimeBands = [];
    
    % ===== GET TIME =====
    % Get time window
    [TimeVector, iTime] = GetTimeVector(iDS, iTimefreq, iTime, 'Timefreq');
    % Time bands are defined
    TimeBands = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TimeBands;
    if ~isempty(TimeBands)
        BandBounds = process_tf_bands('GetBounds', TimeBands);
        % Get all the bands to be displayed
        for i = 1:size(TimeBands, 1)
            band = TimeVector(bst_closest(BandBounds(i,:), TimeVector));
            if any((TimeVector(iTime) >= band(1)) & (TimeVector(iTime) <= band(2)))
                iTimeBands(end+1) = i;
            end
        end
        % Fix for some weird cases where the input bands time resolution is too high compared with the sampling frequency of the files
        % => In some cases, one time point can correspond to two time bands
        if (length(iTime) == 1) && (length(iTimeBands) > 1) 
            iTime = iTimeBands(1);
        elseif ~isempty(iTimeBands)
            iTime = iTimeBands;
        end
    end
    % Only one time available in the file: return only one index
    if (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF, 2) == 1) && (length(iTime) > 1) 
        iTime = iTime(1);
    end
    
    % ===== GET ROW NAMES =====
    % Get the values from a REF ROWNAME
    if ~isempty(RefRowName)
        % Cannot handle both RefRowName and RowName
        if ~isempty(RowNames)
            error('Cannot extract values for both RowName and RefRowName.');
        end
        % Find the rows of TF corresponding to the specified RefRowName
        iRef = find(strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, RefRowName));
        iRow = iRef + length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames) * (0:length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)-1);
    % Default rows: all
    elseif isempty(RowNames)
        iRow = 1:nRow;
    elseif isequal(RowNames, 'firstrow')
        iRow = 1;
    else
        iRow = [];
        if ischar(RowNames)
            RowNames = {RowNames};
        end
        AllRows = figure_timefreq('GetRowNames', GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames);
        % Remove space characters
        if ~isempty(AllRows) && iscell(AllRows)
            AllRowsNoSpace = cellfun(@(c)strrep(c,' ',''), AllRows, 'UniformOutput', 0);
        end
        % Find selected rows
        for i = 1:length(RowNames)
            if iscell(RowNames) && iscell(AllRows)
                iFound = find(strcmpi(AllRows, RowNames{i}), 1);
                if isempty(iFound)
                    iFound = find(strcmpi(AllRowsNoSpace, RowNames{i}), 1);
                end
            elseif ~iscell(RowNames) && ~iscell(AllRows)
                iFound = find(AllRows == RowNames(i), 1);
            else
                iFound = [];
            end
            if ~isempty(iFound)
                iRow(end+1) = iFound;
            end
        end
    end
    % Kernel sources: read all recordings values
    isKernelSources = strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType, 'results') && strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, 'none') && (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,1) ~= length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames));
    if isKernelSources && ~isempty(RowNames)
        iRowInput = iRow;
        iRow = 1:nRow;
        if ~isempty(RefRowName)
            error('Not supported yet.'); 
        end
    else
        iRowInput = [];
    end
    
    % ===== GET VALUES =====
    % Extract values
    % FOOOF: Swap TF data for relevant FOOOF data
    if isFooof && ~isequal(FooofDisp, 'spectrum')
        isFooofFreq = ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs, GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.freqs);
        if isequal(FooofDisp, 'overlay')
            nFooofRow = 4;
        else
            nFooofRow = numel(iRow);
        end
        [s1 s2 s3] = size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF);
        Values = NaN([nFooofRow, s2, s3 ]);
        nFooofFreq = sum(isFooofFreq);
        % Check for old structure format with extra .FOOOF. level.
        if isfield(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data, 'FOOOF')
            for iiRow = 1:numel(iRow)
                GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow(iiRow)).fooofed_spectrum = ...
                    GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow(iiRow)).FOOOF.fooofed_spectrum;
                GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow(iiRow)).ap_fit = ...
                    GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow(iiRow)).FOOOF.ap_fit;
                GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow(iiRow)).peak_fit = ...
                    GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow(iiRow)).FOOOF.peak_fit;
            end
        end
        % Get requested FOOOF measure
        switch FooofDisp
            case 'overlay'
                Values(1,1,:) = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(iRow, 1, :);
                Values(4,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow).fooofed_spectrum], nFooofFreq, []), [2, 3, 1]);
                Values(2,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow).ap_fit], nFooofFreq, []), [2, 3, 1]);
                % Peaks are fit in log space, so they are multiplicative in linear space and not in the same scale, show difference instead. 
                Values(3,1,isFooofFreq) = Values(4,1,isFooofFreq) - Values(2,1,isFooofFreq); 
                %Values(3,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow).peak_fit], nFooofFreq, []), [2, 3, 1]);
                % Use TF min as cut-off level for peak display.
                YLowLim = min(Values(1,1,:));
                Values(3,1,Values(3,1,:) < YLowLim) = NaN;
            case 'model'
                Values(:,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow).fooofed_spectrum], nFooofFreq, []), [2, 3, 1]);
            case 'aperiodic'
                Values(:,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow).ap_fit], nFooofFreq, []), [2, 3, 1]);
            case 'peaks'
                Values(:,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.data(iRow).peak_fit], nFooofFreq, []), [2, 3, 1]);
            case 'error'
                Values(:,1,isFooofFreq) = permute(reshape([GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.FOOOF.stats(iRow).frequency_wise_error], nFooofFreq, []), [2, 3, 1]);
            otherwise
                error('Unknown FOOOF display option.');
        end
        isApplyFunction = ~isempty(Function);
    elseif isequal(Function, 'pacflow')
        Values = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.NestingFreq(iRow, iTime, iFreqs);
        isApplyFunction = 0;
    elseif isequal(Function, 'pacfhigh')
        Values = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.NestedFreq(iRow, iTime, iFreqs);
        isApplyFunction = 0;
    elseif isempty(Function) || ~ismember(Function, {'power', 'magnitude', 'log', 'phase', 'none'}) || ~ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, {'power', 'magnitude', 'log', 'phase', 'none'})
        % includes 'maxpac'
        Values = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(iRow, iTime, iFreqs);
        isApplyFunction = 0;
    else
        Values = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(iRow, iTime, iFreqs);
        isApplyFunction = ~isempty(Function);
    end
    
    % === INVERSION KERNEL ===
    % Timefreq on results: need to multiply with inversion kernel
    if isKernelSources
        % Get loaded recordings
        iRes = GetResultInDataSet(iDS, GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataFile);
        if ~isempty(iRes)
            nComponents = GlobalData.DataSet(iDS).Results(iRes).nComponents;
            % Get sources to extract
            if isempty(iRowInput)
                Kernel = GlobalData.DataSet(iDS).Results(iRes).ImagingKernel;
            else
                % Number of components per vertex
                iKernelRows = bst_convert_indices(iRowInput, nComponents, GlobalData.DataSet(iDS).Results(iRes).GridAtlas, 1);
                % Get only the kernel for specified source indices
                Kernel = GlobalData.DataSet(iDS).Results(iRes).ImagingKernel(iKernelRows, :);
            end
            % Multiply values by kernel
            MultValues = zeros(size(Kernel,1), size(Values,2), size(Values,3));
            for i = 1:size(Values,3)
                MultValues(:,:,i) = Kernel * Values(:,:,i);
            end
            Values = MultValues;

            % == APPLY DYNAMIC ZSCORE ==
            if ~isempty(GlobalData.DataSet(iDS).Results(iRes).ZScore)
                error('Not supported yet.');
    %             % Calculate mean/std
    %             if isempty(GlobalData.DataSet(iDS).Results(iResult).ZScore.mean)
    %                 [ResultsValues, GlobalData.DataSet(iDS).Results(iResult).ZScore] = process_zscore_dynamic('Compute', ResultsValues, ...
    %                     GlobalData.DataSet(iDS).Results(iResult).ZScore, ...
    %                     TimeVector, ImagingKernel, GlobalData.DataSet(iDS).Measures.F(GoodChannel,:));
    %             % Apply existing mean/std
    %             else
    %                 ResultsValues = process_zscore_dynamic('Compute', ResultsValues, GlobalData.DataSet(iDS).Results(iResult).ZScore);
    %             end
            end
        else
            nComponents = 1;
        end
    else
        nComponents = 1;
    end
    
    % ===== APPLY FUNCTION =====
    % If a measure is asked, different from what is saved in the file
    if isApplyFunction
        % Convert
        if isFooof
            isKeepNan = true;
        else
            isKeepNan = false;
        end
        [Values, isError] = process_tf_measure('Compute', Values, GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, Function, isKeepNan);
        % If conversion is impossible
        if isError
            error(['Invalid measure conversion: ' GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, ' => ' Function]);
        end
    end
end


%% ===== GET PAC VALUES =====
% Calculate an average on the fly if there are several rows
% USAGE:  [ValPAC, sPAC] = GetPacValues(iDS, iTimefreq, RowNames)
function [ValPAC, sPAC] = GetPacValues(iDS, iTimefreq, RowNames) %#ok<DEFNU>
    global GlobalData;
    % ===== GET ROW NAMES =====
    iRows = [];
    if ischar(RowNames)
        RowNames = {RowNames};
    end
    % Find selected rows
    if iscell(RowNames)
        for i = 1:length(RowNames)
            if iscell(RowNames)
                iRows(end+1) = find(strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames, RowNames{i}));
            else
                iRows(end+1) = find(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames == RowNames(i));
            end
        end
    else
        iRows = RowNames;
    end
    % ===== GET VALUES =====
    % Taking only the first time point for now
    iTime = 1;
    iFreq = 1;
    % Extract values
    ValPAC           = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(iRows, iTime, iFreq);
    sPAC.NestingFreq = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.NestingFreq(iRows, iTime, iFreq);
    sPAC.NestedFreq  = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.NestedFreq(iRows, iTime, iFreq);
    sPAC.LowFreqs    = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.LowFreqs;
    sPAC.HighFreqs   = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.HighFreqs;
    if isfield(GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC, 'DirectPAC') && ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.DirectPAC)
        sPAC.DirectPAC = GlobalData.DataSet(iDS).Timefreq(iTimefreq).sPAC.DirectPAC(iRows, iTime, :, :);
    end
    % Average if there are more than one row
    if (length(iRows) > 1)
        ValPAC = mean(ValPAC, 1);
        sPAC.NestingFreq = mean(sPAC.NestingFreq, 1);
        sPAC.NestedFreq  = mean(sPAC.NestedFreq, 1);
        if isfield(sPAC, 'DirectPAC') && ~isempty(sPAC.DirectPAC)
            sPAC.DirectPAC = mean(sPAC.DirectPAC, 1);
        end
    end
end


%% ===== GET MAXIMUM VALUES FOR RESULTS (SMART GFP VERSION) =====
% USAGE:  bst_memory('GetResultsMaximum', iDS, iResult)
function DataMinMax = GetResultsMaximum(iDS, iResult) %#ok<DEFNU>
    global GlobalData;
    % Kernel results
    if ~isempty(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel)
        % Get the sensors concerned but those results
        iChan = GlobalData.DataSet(iDS).Results(iResult).GoodChannel;
        % Compute the GFP of the recordings
        GFP = sum((GlobalData.DataSet(iDS).Measures.F(iChan,:)).^2, 1);
        % Get the time indice of the max GFP value
        [maxGFP, iMax] = max(GFP);
        % Get the results values at this particular time point
        sources = GetResultsValues(iDS, iResult, [], iMax);
    % Full results
    else
        % Get the maximum on the full results matrix
        sources = GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp;
    end
    % Store minimum and maximum of displayed data
    DataMinMax = [min(sources(:)), max(sources(:))];
end


%% ===== GET MAXIMUM VALUES FOR TIMEFREQ =====
% USAGE:  bst_memory('GetTimefreqMaximum', iDS, iTimefreq, Function)
function DataMinMax = GetTimefreqMaximum(iDS, iTimefreq, Function) %#ok<DEFNU>
    tic
    global GlobalData;
    % Get row names and numbers
    RowNames = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
    nRowsTF = size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,1);
    % If reading sources based on kernel: get the maximum of the sensors, and multiply by kernel
    isKernelSources = strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType, 'results') && (nRowsTF < length(RowNames));
    if isKernelSources
        % Get time of the maximum of the GFP(recordings TF)
        [maxTF, iMaxTF] = max(sum(sum(abs(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF) .^ 2, 1), 3));
        % Get the sources TF values for this time point
        values = GetTimefreqValues(iDS, iTimefreq, [], [], iMaxTF, Function);
    % If the number of values exceeds a certain threshold, compute only max for the first row
    elseif (numel(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF) > 5e6)
        if iscell(RowNames)
            values = GetTimefreqValues(iDS, iTimefreq, 'firstrow', [], [], Function);
        else
            values = GetTimefreqValues(iDS, iTimefreq, [], [], 'CurrentTimeIndex', Function);
        end
    % Get all timefreq values
    else
        values = GetTimefreqValues(iDS, iTimefreq, [], [], [], Function);
    end
    % Store minimum and maximum of displayed data
    DataMinMax = [min(values(:)), max(values(:))];
    % Ignore infinite values, possible due to log.
    if any(isinf(DataMinMax))
        isNotInf = ~isinf(values(:));
        DataMinMax = [min(values(isNotInf)), max(values(isNotInf))];
    end
    % Display warning message if analysis time was more than 3s
    t = toc;
    if (t > 3)
        disp(sprintf('bst_memory> WARNING: GetTimefreqMaximum() took %1.5f s', t));
    end
end


%% ===== GET DATASET (DATA) =====
function iDataSets = GetDataSetData(DataFile, isStatic)
    global GlobalData;
    % Parse inputs
    if (nargin < 2)
        isStatic = [];
    end
    % If target is empty : return and empty matrix
    if isempty(DataFile)
        iDataSets = [];
        return
    end
    iDataSets = find(file_compare({GlobalData.DataSet.DataFile}, DataFile));
    % Keep only the datasets with required properties
    if ~isempty(iDataSets) && ~isempty(isStatic)
        isStaticOk = [];
        for i = 1:length(iDataSets)
            isStaticDS = (GlobalData.DataSet(iDataSets(i)).Measures.NumberOfSamples <= 2);
            if isempty(isStaticDS) || (isStatic == isStaticDS)
                isStaticOk(end+1) = i;
            end
        end
        iDataSets = iDataSets(isStaticOk);
    end
end


% %% ===== GET DATASET (STUDY, WITH NO DATAFILE) =====
% function iDS = GetDataSetStudyNoData(StudyFile)
%     global GlobalData;
%     % Initialize returned value
%     iDS = [];
%     % If target is empty : return and empty matrix
%     if isempty(StudyFile)
%         return
%     end
%     % Look for dataset in all the registered datasets
%     iDS = find(file_compare({GlobalData.DataSet.StudyFile}, StudyFile) & ...
%                cellfun(@(c)isempty(c), {GlobalData.DataSet.DataFile}));
% end

%% ===== GET DATASET (STUDY) =====
function iDS = GetDataSetStudy(StudyFile)
    global GlobalData;
    % Initialize returned value
    iDS = [];
    % If target is empty : return and empty matrix
    if isempty(StudyFile)
        return
    end
    % Look for dataset in all the registered datasets
    iDS = find(file_compare({GlobalData.DataSet.StudyFile}, StudyFile));
end

%% ===== GET DATASET (CHANNEL) =====
function iDS = GetDataSetChannel(ChannelFile) %#ok<DEFNU>
    global GlobalData;
    % Initialize returned value
    iDS = [];
    % If target is empty : return and empty matrix
    if isempty(ChannelFile)
        return
    end
    iDS = find(file_compare({GlobalData.DataSet.ChannelFile}, ChannelFile));
end



%% ===== GET/CREATE SUBJECT-ONLY DATASET =====
% DataSet type used to display subject data (not attached to a study) 
function iDS = GetDataSetSubject(SubjectFile, createSubject)
    global GlobalData;
    % Parse inputs
    % Initialize returned values
    iDS = [];
    % If target is empty : return and empty matrix
    if isempty(SubjectFile)
        return
    end
    if (nargin < 2) 
        createSubject = 1;
    end
 
    % Look for subject in all the registered datasets
    % (subject-only, ie. without StudyFile defined)
    iDS = find(file_compare({GlobalData.DataSet.SubjectFile}, SubjectFile) & ...
               cellfun(@isempty, {GlobalData.DataSet.StudyFile}) & ...
               cellfun(@isempty, {GlobalData.DataSet.ChannelFile}));
    % If no dataset found for this subject : look if subject uses default subject
    if isempty(iDS)
        % Find subject in database (return default subject if needed)
        sSubject = bst_get('Subject', SubjectFile);
        if ~isempty(sSubject)
            % Look for the default subject file in the loaded DataSets
            iDS = find(file_compare({GlobalData.DataSet.SubjectFile}, sSubject.FileName) & ...
                       cellfun(@isempty, {GlobalData.DataSet.StudyFile}) & ...
                       cellfun(@isempty, {GlobalData.DataSet.ChannelFile}));
        end
    end
    
    % If DataSet not found, but subject required is the default anatomy: 
    % look for loaded subjects that use the default anatomy
    if isempty(iDS) && strcmpi(bst_fileparts(sSubject.FileName), bst_get('DirDefaultSubject'))
        % Get all protocol subjects
        ProtocolSubjects = bst_get('ProtocolSubjects');
        % If subjects are defined for the protocol
        if ~isempty(ProtocolSubjects.Subject)
            % Get subjects that use default anatomy
            DefAnatSubj = ProtocolSubjects.Subject([ProtocolSubjects.Subject.UseDefaultAnat] == 1);
            % Look for loaded subject that use the default anatomy
            for i = 1:length(DefAnatSubj)
                % Look for the subject file in the loaded DataSets
                iDS = find(file_compare({GlobalData.DataSet.SubjectFile}, DefAnatSubj(i).FileName));
                % If matching dataset is found
                if ~isempty(iDS)
                    break;
                end
            end
        end
    end
    
    % If no DataSet is found : create an empty one
    if isempty(iDS) && createSubject
        % Store DataSet in GlobalData
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS)             = db_template('DataSet');
        GlobalData.DataSet(iDS).SubjectFile = SubjectFile;
    end
end


%% ===== GET/CREATE EMPTY DATASET =====
% DataSet type used to display data/sources/surfaces without using Brainstorm GUI and database
function iDS = GetDataSetEmpty() %#ok<DEFNU>
    global GlobalData;
    % Initialize returned values
    iDS = [];
    % Look for empty dataset in all the registered datasets
    i = 1;
    while isempty(iDS) && (i <= length(GlobalData.DataSet))
        if isempty(GlobalData.DataSet(i).StudyFile) && ...
           isempty(GlobalData.DataSet(i).DataFile) && ...
           isempty(GlobalData.DataSet(i).SubjectFile) && ...
           isempty(GlobalData.DataSet(i).ChannelFile)
            iDS = i;
        else
            i = i + 1;
        end
    end

    % If no DataSet is found : create an empty one
    if isempty(iDS)
        % Store DataSet in GlobalData
        iDS = length(GlobalData.DataSet) + 1;
        GlobalData.DataSet(iDS) = db_template('DataSet');
    end
end



%% ===== GET RESULT IN ALL DATASETS =====
function [iDS, iResult] = GetDataSetResult(ResultsFile)
    global GlobalData;
    % Initialize returned values
    iDS = [];
    iResult  = [];
    % Search for ResultsFile in all DataSets
    for i = 1:length(GlobalData.DataSet)
        % Look for dataset in all the registered datasets
        iRes = find(file_compare({GlobalData.DataSet(i).Results.FileName}, ResultsFile));
        if ~isempty(iRes)
            iDS = i;
            iResult  = iRes;
            return
        end
    end
end

%% ===== GET RESULT IN ONE DATASET =====
function iResult = GetResultInDataSet(iDS, ResultsFile)
    global GlobalData;
    % If target is empty : return and empty matrix
    if isempty(ResultsFile)
        iResult = [];
        return
    end
    % Look for dataset in all the registered datasets
    iResult = find(file_compare({GlobalData.DataSet(iDS).Results.FileName}, ResultsFile));
end


%% ===== GET DIPOLES IN ALL DATASETS =====
function [iDS, iDipoles] = GetDataSetDipoles(DipolesFile)
    global GlobalData;
    % Initialize returned values
    iDS = [];
    iDipoles  = [];
    % Search for DipolesFile in all DataSets
    for i = 1:length(GlobalData.DataSet)
        % Look for dataset in all the registered datasets
        iDip = find(file_compare({GlobalData.DataSet(i).Dipoles.FileName}, DipolesFile));
        if ~isempty(iDip)
            iDS = i;
            iDipoles  = iDip;
            return
        end
    end
end

%% ===== GET MATRIX IN ALL DATASETS =====
function [iDS, iMatrix] = GetDataSetMatrix(MatrixFile)
    global GlobalData;
    % Initialize returned values
    iDS = [];
    iMatrix  = [];
    % Search for MatrixFile in all DataSets
    for i = 1:length(GlobalData.DataSet)
        % Look for dataset in all the registered datasets
        iMat = find(file_compare({GlobalData.DataSet(i).Matrix.FileName}, MatrixFile));
        if ~isempty(iMat)
            iDS = i;
            iMatrix  = iMat;
            return
        end
    end
end

%% ===== GET DIPOLES IN ONE DATASET =====
function iDipoles = GetDipolesInDataSet(iDS, DipolesFile) %#ok<DEFNU>
    global GlobalData;
    % If target is empty : return and empty matrix
    if isempty(DipolesFile)
        iDipoles = [];
        return
    end
    % Look for dataset in all the registered datasets
    iDipoles = find(file_compare({GlobalData.DataSet(iDS).Dipoles.FileName}, DipolesFile));
end


%% ===== GET TIME-FREQ IN ALL DATASETS =====
function [iDS, iTimefreq] = GetDataSetTimefreq(TimefreqFile)
    global GlobalData;
    % Initialize returned values
    iDS  = [];
    iTimefreq = [];
    if isempty(GlobalData) || isempty(GlobalData.DataSet)
        return;
    end
    % Search for TimefreqFile in all DataSets
    for i = 1:length(GlobalData.DataSet)
        % Look for dataset in all the registered datasets
        iTf = find(file_compare({GlobalData.DataSet(i).Timefreq.FileName}, TimefreqFile));
        if ~isempty(iTf)
            iDS  = i;
            iTimefreq = iTf;
            return
        end
    end
end


%% ===== GET TIME-FREQ IN ONE DATASET =====
function iTimefreq = GetTimefreqInDataSet(iDS, TimefreqFile)
    global GlobalData;
    % If target is empty : return and empty matrix
    if isempty(TimefreqFile)
        iTimefreq = [];
        return
    end
    % Look for dataset in all the registered datasets
    iTimefreq = find(file_compare({GlobalData.DataSet(iDS).Timefreq.FileName}, TimefreqFile));
end

%% ===== GET TIME-FREQ IN ONE DATASET =====
function iMatrix = GetMatrixInDataSet(iDS, MatrixFile)
    global GlobalData;
    % If target is empty : return and empty matrix
    if isempty(MatrixFile)
        iMatrix = [];
        return
    end
    % Look for dataset in all the registered datasets
    iMatrix = find(file_compare({GlobalData.DataSet(iDS).Matrix.FileName}, MatrixFile));
end


%% ===== CHECK TIME WINDOWS =====
% Only allows exactly similar time windows
function isOk = CheckTimeWindows()
    global GlobalData;
    % Initialize
    isOk = 1;
    listTime = [];
    listRate = [];
    listTimeAvg = [];

    % Process all the loaded data (=> existing DataSets)
    for iDS = 1:length(GlobalData.DataSet)
        % Measures
        if (GlobalData.DataSet(iDS).Measures.NumberOfSamples > 2)
            listTime = [listTime; GlobalData.DataSet(iDS).Measures.Time];
            listRate = [listRate, GlobalData.DataSet(iDS).Measures.SamplingRate];
        elseif (GlobalData.DataSet(iDS).Measures.NumberOfSamples == 2)
            listTimeAvg = [listTimeAvg; GlobalData.DataSet(iDS).Measures.Time];
        end        
        % Results
        for iRes = 1:length(GlobalData.DataSet(iDS).Results)
            if (GlobalData.DataSet(iDS).Results(iRes).NumberOfSamples > 2)
                listTime = [listTime; GlobalData.DataSet(iDS).Results(iRes).Time];
                listRate = [listRate, GlobalData.DataSet(iDS).Results(iRes).SamplingRate];
            elseif (GlobalData.DataSet(iDS).Results(iRes).NumberOfSamples == 2)
                listTimeAvg = [listTimeAvg; GlobalData.DataSet(iDS).Results(iRes).Time];
            end
        end
        % Timefreq
        for iTf = 1:length(GlobalData.DataSet(iDS).Timefreq)
            if (GlobalData.DataSet(iDS).Timefreq(iTf).NumberOfSamples > 2)
                listTime = [listTime; GlobalData.DataSet(iDS).Timefreq(iTf).Time];
                listRate = [listRate, GlobalData.DataSet(iDS).Timefreq(iTf).SamplingRate];
            elseif (GlobalData.DataSet(iDS).Timefreq(iTf).NumberOfSamples == 2)
                listTimeAvg = [listTimeAvg; GlobalData.DataSet(iDS).Timefreq(iTf).Time];
            end
        end
%         % Dipoles
%         for iDip = 1:length(GlobalData.DataSet(iDS).Dipoles)
%             if (GlobalData.DataSet(iDS).Dipoles(iDip).NumberOfSamples > 2)
%                 listTime = [listTime; GlobalData.DataSet(iDS).Dipoles(iDip).Time];
%                 listRate = [listRate, GlobalData.DataSet(iDS).Dipoles(iDip).SamplingRate];
%             end
%         end
    end
    
    % If there is only one average that is loaded
    if isempty(listTime) && ~isempty(listTimeAvg) && (size(unique(listTimeAvg,'rows'),1) == 1)
        listTime = listTimeAvg(1,:);
        listRate = listTimeAvg(1,2) - listTimeAvg(1,1);
    end

    % If no time window defined: return
    if isempty(listRate)
        % User time window
        GlobalData.UserTimeWindow.Time            = [];
        GlobalData.UserTimeWindow.SamplingRate    = [];
        GlobalData.UserTimeWindow.NumberOfSamples = 0;
        GlobalData.UserTimeWindow.CurrentTime     = [];
        % Full time window
        GlobalData.FullTimeWindow.Epochs       = [];
        GlobalData.FullTimeWindow.CurrentEpoch = [];
        return;
    end
    
    % === CHECK TIME WINDOWS ===
    Time = listTime(1,:);
    SamplingRate = listRate(1);
    % Check if there is a time window which is not compatible with the first one
    if any(abs(listTime(:,1)-Time(1)) > 1e-5) || any(abs(listTime(:,2)-Time(2)) > 1e-5) || any(abs(listRate-SamplingRate) > 1e-5)
        isOk = 0;
        return;
    end
    
    % === VALIDATE ===
    % Configure user time window
    GlobalData.UserTimeWindow.Time            = Time;
    GlobalData.UserTimeWindow.SamplingRate    = SamplingRate;
    GlobalData.UserTimeWindow.NumberOfSamples = round((GlobalData.UserTimeWindow.Time(2)-GlobalData.UserTimeWindow.Time(1)) / GlobalData.UserTimeWindow.SamplingRate) + 1;
    % Try to reuse the same current time
    if isempty(GlobalData.UserTimeWindow.CurrentTime)
        % Set time at t=0s if there is a baseline
        if (GlobalData.UserTimeWindow.Time(1) < 0) && (GlobalData.UserTimeWindow.Time(2) > 0)
            % Find the closest time sample to zero
            GlobalData.UserTimeWindow.CurrentTime = GlobalData.UserTimeWindow.Time(1) - round(GlobalData.UserTimeWindow.Time(1) ./ GlobalData.UserTimeWindow.SamplingRate) .* GlobalData.UserTimeWindow.SamplingRate;
        % Otherwise use the first time point available
        else
            GlobalData.UserTimeWindow.CurrentTime = GlobalData.UserTimeWindow.Time(1);
        end
    end
    panel_time('SetCurrentTime', GlobalData.UserTimeWindow.CurrentTime);

    % Update panel "Filters"
    panel_filter('TimeWindowChangedCallback');
end


%% ===== CHECK FREQUENCIES =====
function CheckFrequencies()
    global GlobalData;
    isReset = 1;
    % Look for a dataset that still has some time-frequency information loaded
    for iDS = 1:length(GlobalData.DataSet)
        if ~isempty(GlobalData.DataSet(iDS).Timefreq) 
            isReset = 0;
            break;
        end
    end
    % Reset frequency panel
    if isReset 
        GlobalData.UserFrequencies.iCurrentFreq = [];
        GlobalData.UserFrequencies.Freqs = [];
        panel_freq('UpdatePanel');
    end
end


%% ===== GET TIME VECTOR =====
% Usage:  [TimeVector, iTime] = GetTimeVector(iDS, iResult, iTime, DataType)
%         [TimeVector, iTime] = GetTimeVector(iDS, iResult, iTime)
%         [TimeVector, iTime] = GetTimeVector(iDS, iResult, 'UserTimeWindow')
%         [TimeVector, iTime] = GetTimeVector(iDS, iResult, 'CurrentTimeIndex')
%         [TimeVector, iTime] = GetTimeVector(iDS, iResult)  : Return current time
%         [TimeVector, iTime] = GetTimeVector(iDS)           : Return current time, for the recordings
function [TimeVector, iTime] = GetTimeVector(iDS, iResult, iTime, DataType)
    global GlobalData;
    % === GET TIME BOUNDS ===
    isDipole   = (nargin >= 4) && ~isempty(DataType) && strcmpi(DataType, 'Dipoles');
    isTimefreq = (nargin >= 4) && ~isempty(DataType) && strcmpi(DataType, 'Timefreq');
    isResult   = ~isDipole && ~isTimefreq && (nargin >= 2) && ~isempty(iResult);
    % If a dipole
    if isDipole
        Time = GlobalData.DataSet(iDS).Dipoles(iResult).Time;
        NumberOfSamples = GlobalData.DataSet(iDS).Dipoles(iResult).NumberOfSamples;
    % If a time-frequency map
    elseif isTimefreq
        Time = GlobalData.DataSet(iDS).Timefreq(iResult).Time;
        NumberOfSamples = GlobalData.DataSet(iDS).Timefreq(iResult).NumberOfSamples;
    % Not a result, OR a kernel result
    elseif ~isResult || ~isempty(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel)
        Time = GlobalData.DataSet(iDS).Measures.Time;
        NumberOfSamples = GlobalData.DataSet(iDS).Measures.NumberOfSamples;
    else
        Time = GlobalData.DataSet(iDS).Results(iResult).Time;
        NumberOfSamples = GlobalData.DataSet(iDS).Results(iResult).NumberOfSamples;
    end
    % If iTime was not defined
    if (nargin < 3)
        iTime = [];
    end
    
    % === BUILD TIME VECTOR ===
    is_static = (GlobalData.UserTimeWindow.NumberOfSamples > 2) && ...
                ((~isResult  && (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2)) || ...
                 (isResult   && (GlobalData.DataSet(iDS).Results(iResult).NumberOfSamples <= 2)) || ...
                 (isDipole   && (GlobalData.DataSet(iDS).Dipoles(iResult).NumberOfSamples <= 2)) || ...
                 (isTimefreq && (GlobalData.DataSet(iDS).Timefreq(iResult).NumberOfSamples <= 2)));
    % Static dataset: use the whole time window
    if is_static
        TimeVector = Time;
        if ~isempty(iTime) && (ischar(iTime) && strcmpi(iTime, 'UserTimeWindow'))
            iTime = [1,2];
        else
            iTime = 1;
        end
    % Else: use the current user time window
    else
        % Rebuild initial time vector
        TimeVector = linspace(Time(1), Time(2), NumberOfSamples);
        % Find CurrentTime index in the time vector
        if isempty(iTime) || (ischar(iTime) && strcmpi(iTime, 'CurrentTimeIndex'))
            if ~isempty(GlobalData.UserTimeWindow.CurrentTime)
                iTime = bst_closest(GlobalData.UserTimeWindow.CurrentTime, TimeVector);    
            else
                iTime = 1;
            end
        elseif (ischar(iTime) && strcmpi(iTime, 'UserTimeWindow'))
            if isempty(GlobalData.UserTimeWindow.Time)
                iTime = 1:length(TimeVector);
            elseif ~isempty(GlobalData.UserTimeWindow.CurrentTime)
                % Get the time range for the current user window
                iTimeRange = bst_closest(GlobalData.UserTimeWindow.Time, TimeVector);   
                % Get the number of samples between two recordings
                iTimeStep = bst_closest(GlobalData.UserTimeWindow.Time(1) + GlobalData.UserTimeWindow.SamplingRate, TimeVector) - iTimeRange(1);
                % Build list of indices for user time range
                iTime = iTimeRange(1):iTimeStep:iTimeRange(2);
            else
                iTime = [1 2];
            end
        end
    end
    iTime = double(iTime);
    TimeVector = double(TimeVector);
end

 

%% =========================================================================================
%  ===== UNLOAD DATASETS ===================================================================
%  =========================================================================================
%% ===== UNLOAD ALL DATASETS =====
% Unload Brainstorm datasets and perform all needed updates (recalculate time window, update panels, etc...)
%
% USAGE: UnloadAll(OPTIONS)
% Possible OPTIONS (list of strings):
%     - 'Forced'         : All the figures are closed and all the datasets unloaded
%                          else, only the unused (no figures associated) are unloaded
%     - 'KeepMri'        : Do not unload the MRIs
%     - 'KeepSurface'    : Do not unload the surfaces
%     - 'KeepRegSurface' : Unload only the anonymous surfaces (created with view_surface_matrix)
%     - 'KeepChanEditor' : Do not close the channel editor
function isCancel = UnloadAll(varargin)
    global GlobalData;
    isCancel = 0;
    if isempty(GlobalData)
        return;
    end
    % Display progress bar
    isNewProgress = ~bst_progress('isVisible');
    if isNewProgress
        bst_progress('start', 'Unload all', 'Closing figures...');
    end
    % Parse inputs
    isForced       = any(strcmpi(varargin, 'Forced'));
    KeepMri        = any(strcmpi(varargin, 'KeepMri'));
    KeepSurface    = any(strcmpi(varargin, 'KeepSurface')); 
    KeepRegSurface = any(strcmpi(varargin, 'KeepRegSurface'));
    KeepChanEditor = any(strcmpi(varargin, 'KeepChanEditor'));
    
    % ===== UNLOAD FUNCTIONAL DATA =====
    % Process all datasets
    iDSToUnload = [];
    for iDS = length(GlobalData.DataSet):-1:1
        % If there are some figures left and if unload is not forced => Ignore DataSet 
        if ~isempty(GlobalData.DataSet(iDS).Figure) && ~isForced
            continue
        % Else : Unload dataset
        else
            iDSToUnload = [iDSToUnload, iDS]; %#ok<AGROW>
        end
    end  
    drawnow;
    % Unload all marked datasets
    isCancel = UnloadDataSets(iDSToUnload);
    if isCancel
        bst_progress('stop');
        return;
    end
    
    % ===== UNLOAD ANATOMIES =====
    unloadedSurfaces = {};
    % Forced unload MRI
    if isForced && ~KeepMri
        GlobalData.Mri = repmat(db_template('LoadedMri'), 0);
    end
    % Forced unload Fibers
    if isForced
        GlobalData.Fibers = repmat(db_template('LoadedFibers'), 0);
    end
    % Forced unload surfaces
    if isForced && ~KeepSurface
        unloadedSurfaces = {GlobalData.Surface.FileName};
        UnloadSurface();
    end
    % Unload UNUSED surfaces and MRIs
    if ~isForced && (~KeepMri || ~KeepSurface || KeepRegSurface)
        % Get all the figures
        hFigures = findobj(0,'-depth', 1, 'type','figure');
        % For each figure, get the list of anatomy objects displayed
        listFiles = {};
        for i = 1:length(hFigures)
            TessInfo = getappdata(hFigures(i), 'Surface');
            if ~isempty(TessInfo)
                listFiles = cat(2, listFiles, {TessInfo.SurfaceFile});
            end
        end
        listFiles = unique(listFiles);
        listFiles = setdiff(listFiles, {''});
        % Unload all the MRI that are not inside this list (no longer displayed => no longer loaded)
        if ~KeepMri
            iUnusedMri = find(~cellfun(@(c)any(file_compare(c,listFiles)), {GlobalData.Mri.FileName}));
            if ~isempty(iUnusedMri)
                GlobalData.Mri(iUnusedMri) = [];
            end
        end
        % Unload surfaces
        if ~KeepSurface
            % Get unused surfaces
            iUnusedSurfaces = find(~cellfun(@(c)any(file_compare(c,listFiles)), {GlobalData.Surface.FileName}));
            % Remove registered surfaces from unused surfaces if required
            if KeepRegSurface 
                iRegSurf = find(cellfun(@(c)isempty(strfind(c, 'view_surface_matrix')), {GlobalData.Surface.FileName}));
                iUnusedSurfaces = setdiff(iUnusedSurfaces, iRegSurf);
            end
            % Unload unused surfaces
            if ~isempty(iUnusedSurfaces)
                unloadedSurfaces = {GlobalData.Surface(iUnusedSurfaces).FileName};
                UnloadSurface(unloadedSurfaces);
            end
        end
    end
    
    % Remove unused scouts
    if (~KeepSurface && ~isempty(unloadedSurfaces)) || (isForced && isempty(iDSToUnload))
        drawnow
        % If the current surface was unloaded
        if any(file_compare(GlobalData.CurrentScoutsSurface, unloadedSurfaces))
            % If there are other surfaces still loaded: use the first one
            if ~isempty(GlobalData.Surface)
                warning('todo');
                CurrentSurface = '';
            else
                CurrentSurface = '';
            end
            % Get next surface
            panel_scout('SetCurrentSurface', CurrentSurface);
        end
        % Unload clusters
        panel_cluster('RemoveAllClusters');
    end
    % Empty the clipboard
    bst_set('Clipboard', []);
    % Empty row selection
    if isForced
        GlobalData.DataViewer.SelectedRows = {};
    end
    % Unselect clusters
    panel_cluster('SetSelectedClusters', [], 0);
    panel_cluster('UpdatePanel');
    % Update Event panel
    panel_record('UpdatePanel');
    
    % ===== FORCED =====
    if isForced
        GlobalData.DataViewer.DefaultFactor = [];
        % Unload interpolations
        GlobalData.Interpolations = [];
        % Close channel editor
        if ~KeepChanEditor
            gui_hide('ChannelEditor');
        end
        % Close report editor
        bst_report('Close');
        % Close all open files
        fclose all;
%         % Close all the non-brainstorm figures
%         hOtherFig = get(0, 'Children');
%         hOtherFig(strcmpi(get(hOtherFig, 'Name'), 'Brainstorm')) = [];
%         if ~isempty(hOtherFig)
%             delete(hOtherFig);
%         end
        % Close histograms
        hFigHist = findobj(0, 'Tag', 'FigHistograms', '-depth', 1);
        if ~isempty(hFigHist)
            delete(hFigHist);
        end
        % Close spike sorting figure
        process_spikesorting_supervised('CloseFigure');
        % Restore default window manager
        if ~ismember(bst_get('Layout', 'WindowManager'), {'TileWindows', 'WeightWindows', 'FullArea', 'FullScreen', 'None'})
            bst_set('Layout', 'WindowManager', 'TileWindows');
        end
        % Unload temporary montages
        panel_montage('UnloadAutoMontages');
        % Clear menu cache
        GlobalData.Program.ProcessMenuCache = struct();
        % Clear some display options
        GlobalData.Preferences.TopoLayoutOptions.TimeWindow = [];
    end
    % Close all unecessary tabs when forced, or when no data left
    if isForced || isempty(GlobalData.DataSet)
        gui_hide('Dipoles');
        gui_hide('FreqPanel');
        gui_hide('Display');
        gui_hide('Stat');
        gui_hide('iEEG');
        gui_hide('Spikes');
    end
    if isNewProgress
        bst_progress('stop');
    end
end


%% ===== UNLOAD DATASET =====
function isCancel = UnloadDataSets(iDataSets)
    global GlobalData;
    isCancel = 0;
    % Close all figures of each dataset
    for i = 1:length(iDataSets)
        iDS = iDataSets(i);
        % Invalid index
        if (iDS > length(GlobalData.DataSet))
            continue;
        end
        isRaw = ~isempty(GlobalData.DataSet(iDS).Measures) && strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
        % Raw files: save events and close files
        if ~isempty(GlobalData.DataSet(iDS).Measures) && ~isempty(GlobalData.DataSet(iDS).Measures.sFile) %  && ~isempty(GlobalData.DataSet(iDS).Measures.DataType)
            % If file was modified: ask the user to save it or not
            if GlobalData.DataSet(iDS).Measures.isModified
                if bst_get('ReadOnly')
                    java_dialog('warning', ['Read-only protocol:' 10 'Cannot save the modifications.'], 'Read-only');
                else
                    % Get open file name
                    if isRaw
                        [fPath, fBase, fExt] = bst_fileparts(GlobalData.DataSet(iDS).Measures.sFile.filename);
                        strFile = [' for file "' fBase, fExt '"'];
                    elseif ~isempty(GlobalData.DataSet(iDS).DataFile)
                        strFile = [' for file "' GlobalData.DataSet(iDS).DataFile '"'];
                    else
                        strFile = '';
                    end
                    % Regular interface: Ask user whether to save modifications
                    if (GlobalData.Program.GuiLevel == 1)
                        res = java_dialog('question', ...
                            ['Events were modified', strFile, '.' 10 10 'Save modifications ?'], ...
                            'Save file', [], {'Yes', 'No', 'Cancel'});
                        % User canceled operation
                        if isempty(res) || strcmpi(res, 'Cancel')
                            isCancel = 1;
                            return;
                        end
                    % Auto-pilot: Accept modifications by default
                    else
                        res = 'Yes';
                        % Track modifications for external usage
                        global BstAutoPilot;
                        BstAutoPilot.isEventsModified = 1;
                    end
                    % Save modifications
                    if strcmpi(res, 'Yes')
                        % Save modifications in Brainstorm database
                        panel_record('SaveModifications', iDS);
                    end
                end
            end
            % Force closing of SSP editor panel
            gui_hide('EditSsp');
        end
        % Save modified channel file
        if ~isempty(GlobalData.DataSet(iDS).ChannelFile) && isequal(GlobalData.DataSet(iDS).isChannelModified, 1)
            % Ask user for confirmation
            res = java_dialog('question', ['Save modifications to channel file : ' 10 GlobalData.DataSet(iDS).ChannelFile 10 10], ...
                              'Channel editor', [], {'Yes', 'No', 'Cancel'});
            % Closing was cancelled
            if isempty(res) || strcmpi(res, 'Cancel')
                isCancel = 1;
                return;
            end
            % Save channel file
            if strcmpi(res, 'Yes')
                SaveChannelFile(iDS);
            end
        end
        % Close all the figures
        for iFig = length(GlobalData.DataSet(iDS).Figure):-1:1
            bst_figures('DeleteFigure', GlobalData.DataSet(iDS).Figure(iFig).hFigure, 'NoUnload', 'NoLayout');
            drawnow
        end
    end
    % Check that dataset still exists
    if any(iDataSets > length(GlobalData.DataSet))
        return;
    end
    % Unload DataSets 
    GlobalData.DataSet(iDataSets) = [];
    % Recompute max time window
    CheckTimeWindows();
    panel_time('UpdatePanel');
    % Update frequency definition
    CheckFrequencies();
    % Reinitialize TimeSliderMutex
    global TimeSliderMutex;
    TimeSliderMutex = [];
    % Call layout manager
    gui_layout('Update');
end


%% ===== UNLOAD RESULTS IN DATASETS =====
% Usage: UnloadDataSetResult(ResultsFile)
%        UnloadDataSetResult(iDS, iResult)
function UnloadDataSetResult(varargin) %#ok<DEFNU>
    global GlobalData;
    % === PARSE INPUTS ===
    % CALL: UnloadDataSetResult(ResultsFile)
    if (nargin == 1) && ischar(varargin{1})
        ResultsFile = varargin{1}; 
        [iDS, iResult] = GetDataSetResult(ResultsFile);
    % CALL: UnloadDataSetResult(iDS, iResult)
    elseif (nargin == 2) && isnumeric(varargin{1}) && isnumeric(varargin{2}) 
       iDS = varargin{1};
       iResult = varargin{2};
    else
        error('Invalid call to UnloadDataSetResult()');
    end
    % === UNLOAD RESULTS ===
    if ~isempty(iDS) && ~isempty(iResult)
        GlobalData.DataSet(iDS).Results(iResult) = [];
        % If DataSet was here only to handle this results : delete it
        if isempty(GlobalData.DataSet(iDS).Results) && ...
                isempty(GlobalData.DataSet(iDS).DataFile)
            % Close figures
            for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
                close(GlobalData.DataSet(iDS).Figure(iFig).hFigure);
            end
        end
    end
end


%% ===== UNLOAD SURFACE =====
% USAGE:  bst_memory('UnloadSurface', SurfaceFile, isCloseFig=0) : Unloads one surface
%         bst_memory('UnloadSurface')                            : Unloads all the surfaces
function UnloadSurface(SurfaceFiles, isCloseFig)
    global GlobalData;
    % If request to close the surface
    if (nargin < 2) || isempty(isCloseFig)
        isCloseFig = 0;
    end
    % If surface is not specified: take all the surfaces
    if (nargin < 1) || isempty(SurfaceFiles)
        SurfaceFiles = {GlobalData.Surface.FileName};
    elseif ischar(SurfaceFiles)
        ProtocolInfo = bst_get('ProtocolInfo');
        SurfaceFiles = {strrep(SurfaceFiles, ProtocolInfo.SUBJECTS, '')};
    elseif iscell(SurfaceFiles)
        % Ok, nothing to do
    end
    % Get current scout surface
    CurrentSurface = GlobalData.CurrentScoutsSurface;
    
    % Save modifications to scouts
    iCloseSurf = [];
    for i = 1:length(SurfaceFiles)
        % If this is the current surface: empty it
        if ~isempty(CurrentSurface) && file_compare(SurfaceFiles{i}, CurrentSurface)
            panel_scout('SetCurrentSurface', '');
        end
        % Save modifications to the surfaces
        panel_scout('SaveModifications');
        % Check if surface is already loaded
        [sSurf, iSurf] = GetSurface(SurfaceFiles{i});
        % If surface is not loaded: skip
        if isempty(iSurf)
            continue;
        end
        % Add to list of surfaces to unload
        iCloseSurf = [iCloseSurf, iSurf];
    end
    % If it is: unload it
    if ~isempty(iCloseSurf)
        GlobalData.Surface(iCloseSurf) = [];
    end
    
    % Close associated figures
    if isCloseFig
        hClose = [];
        % Find surfaces that contain the figure
        for iDS = 1:length(GlobalData.DataSet)
            for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
                % Get surfaces in this figure
                hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
                TessInfo = getappdata(hFig, 'Surface');
                if isempty(TessInfo) || ~isfield(TessInfo, 'SurfaceFile')
                    continue;
                end
                % Loop on the surfaces to unload
                for i = 1:length(TessInfo)
                    if any(file_compare(TessInfo(i).SurfaceFile, SurfaceFiles)) || ...
                       (~isempty(TessInfo(i).DataSource) && ~isempty(TessInfo(i).DataSource.FileName) && any(file_compare(TessInfo(i).DataSource.FileName, SurfaceFiles)))
                        hClose = [hClose, hFig];
                        break;
                    end
                end
            end
        end
        % Close all the figures
        if ~isempty(hClose)
            close(hClose);
        end
    end
end

%% ===== UNLOAD MRI =====
function UnloadMri(MriFile) %#ok<DEFNU>
    global GlobalData;
    % Force relative path
    MriFile = file_short(MriFile);
    % Check if MRI is already loaded
    iMri = find(file_compare({GlobalData.Mri.FileName}, MriFile));
    if isempty(iMri)
        return;
    end
    % Unload MRI
    GlobalData.Mri(iMri) = [];
    % Get subject
    sSubject = bst_get('MriFile', MriFile);
    % Unload subject
    UnloadSubject(sSubject.FileName);
end


%% ===== UNLOAD SUBJECT =====
function UnloadSubject(SubjectFile)
    global GlobalData;
    iDsToUnload = [];
    % Process all the datasets
    for iDS = 1:length(GlobalData.DataSet)
        % Get subject filename (with default anat if it is the case)
        sSubjectDs = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
        % If this dataset uses the subject to unload
        if file_compare(sSubjectDs.FileName, SubjectFile)
            iDsToUnload = [iDsToUnload, iDS];
        end
    end
    % Force unload all the datasets for this subject
    if ~isempty(iDsToUnload)
        UnloadDataSets(iDsToUnload);
    end
end


%% ===== SAVE CHANNEL FILE =====
function SaveChannelFile(iDS)
    global GlobalData;
    % If nothing to save
    if isempty(iDS) || isempty(GlobalData) || (iDS > length(GlobalData.DataSet)) || isempty(GlobalData.DataSet(iDS).ChannelFile) || ~isequal(GlobalData.DataSet(iDS).isChannelModified, 1)
        return;
    end
    % Load channel file
    ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile);
    % Update comment if number of channels changed
    isNumChanged = (length(ChannelMat.Channel) ~= length(GlobalData.DataSet(iDS).Channel));
    if isNumChanged
        ChannelMat.Comment = sprintf('%s (%d)', str_remove_parenth(ChannelMat.Comment), length(GlobalData.DataSet(iDS).Channel));
    end
    % Get modified fields
    ChannelMat.Channel         = GlobalData.DataSet(iDS).Channel;
    ChannelMat.IntraElectrodes = GlobalData.DataSet(iDS).IntraElectrodes;
    % History: Edit channel file
    ChannelMat = bst_history('add', ChannelMat, 'edit', 'Edited manually');
    % Save file
    bst_save(file_fullpath(GlobalData.DataSet(iDS).ChannelFile), ChannelMat, 'v7');
    % Reset modification flag
    GlobalData.DataSet(iDS).isChannelModified = 0;
    % Update database reference
    [sStudy, iStudy] = bst_get('ChannelFile', GlobalData.DataSet(iDS).ChannelFile);
    [sStudy.Channel(1).Modalities, sStudy.Channel(1).DisplayableSensorTypes] = channel_get_modalities(ChannelMat.Channel);
    sStudy.Channel(1).Comment = ChannelMat.Comment;
    bst_set('Study', iStudy, sStudy);
    % Update tree
    if isNumChanged
        panel_protocols('UpdateNode', 'Study', iStudy);
    end
end



