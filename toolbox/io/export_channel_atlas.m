function TsvFile = export_channel_atlas(ChannelFile, Modality, TsvFile, Radius, isProba, isInteractive)
% EXPORT_CHANNEL_ATLAS: Compute anatomical labels for SEEG/ECOG contacts from volume and surface parcellations
%
% USAGE:  TsvFile = export_channel_atlas(ChannelFile, Modality='ECOG+SEEG', TsvFile=[ask], Radius=[ask], isProba=[ask], isInteractive=1)
%         TsvFile = export_channel_atlas(ChannelFile, iChannels,            TsvFile=[ask], Radius=[ask], isProba=[ask], isInteractive=1)
%
% INPUT: 
%     - ChannelFile   : Path to Brainstorm channel file to be processed
%     - Modality      : String, export only the channel with the selected modality
%     - iChannels     : Array of integers, export only the selected channel indices
%     - TsvFile       : Output text file (tab-separated values)
%     - Radius        : Size in millimeters of the neighborhood to consider around each contact
%     - IsInteractive : If 1, display the output table at the end of the process
%     - iChannels     : Limit export to a subset of channel indices
% 
% REFERENCES:
%     - MERCIER M, 2021:
%       "Because of the uncertainty on the 3D locations described above, we recommend to consider 
%        a region around the contact centroid (e.g., 3x3x3mm with respect to the size of the electrode 
%        that is no more than ~ 2mm wide) and counting the number of voxels of each label in this 
%        neighborhood volume (probabilistic approach in space, for an example of implementation see 
%        the Proximal Tissue Density index introduced in Mercier eta al., 2017)"
%     - INTRANAT SOFTWARE:
%       Sphere of 3mm radius around the closest voxel to the SEEG contacts, 5mm for bipolar contacts

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
% Authors: Francois Tadel, 2021


% ===== PASRSE INPUTS =====
if (nargin < 6) || ismpety(isInteractive)
    isInteractive = 1;
end
if (nargin < 5) || ismpety(isProba)
    isProba = [];
end
if (nargin < 4) || ismpety(Radius)
    Radius = [];
end
if (nargin < 3) || ismpety(TsvFile)
    TsvFile = [];
end
if (nargin < 2) || isempty(Modality)
    Modality = 'ECOG+SEEG';
end
if (nargin < 1) || isempty(ChannelFile)
    error('Brainstorm:InvalidCall', 'Invalid use of export_channel_atlas()');
end
% Get input study/subject
sStudy = bst_get('ChannelFile', ChannelFile);
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
% Get the subject's MRI
if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
    error('You need the subject anatomy in order to export the sensors positions.');
end
% List of columnes to export: {Name, Description, Labels, Probabilities}
Columns = cell(0,4);
isSelect = [];


% ===== SELECT OUTPUT FILE =====
if isempty(TsvFile)
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Default output filename
    if (iSubject == 0) || isequal(sSubject.UseDefaultChannel, 2)
        baseFile = 'channel';
    else
        baseFile = sSubject.Name;
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportChannel, [baseFile, '.tsv']);
    
    % === Ask user filename ===
    [TsvFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export labels...', ...    % Window title
        DefaultOutputFile, ...       % Default directory
        'single', 'files', ...       % Selection mode
        {{'.tsv'},   'ASCII: Tab-separated (*.tsv)', 'ASCII-TSV'}, 'ASCII-TSV');
    % Save new default export path
    if ~isempty(TsvFile)
        LastUsedDirs.ExportChannel = bst_fileparts(TsvFile);
        bst_set('LastUsedDirs', LastUsedDirs);
    end
end


% ===== GET COORDINATES: SCS =====
% Load channel file
ChannelMat = in_bst_channel(ChannelFile);
% Get channel indices
if ischar(Modality)
    iChannelMod = channel_find(ChannelMat.Channel, Modality);
elseif isnumeric(Modality)
    iChannelMod = Modality;
end
if isempty(iChannelMod)
    error('No channels available for the selected modality.');
end
% Get locations for all channels
ChanInd = [];
ChanScs = [];
ChanNames = {};
for i = 1:length(iChannelMod)
    sChan = ChannelMat.Channel(iChannelMod(i));
    if (length(sChan.Loc) == 3) && ~all(sChan.Loc == 0)
        ChanInd(end+1) = iChannelMod(i);
        ChanScs(end+1,:) = [sChan.Loc(1), sChan.Loc(2), sChan.Loc(3)];
        ChanNames{end+1} = sChan.Name;
    end
end
Columns(end+1,:) = {'SCS', 'SCS coordinates (mm)', ChanScs, []};
isSelect(end+1) = 1;


% ===== GET COORDINATES: MNI, WORLD =====
% Load the MRI
MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
sMri = load(MriFile, 'SCS', 'NCS', 'InitTransf', 'Voxsize');
% MNI coordinates
if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'R') && ~isempty(sMri.SCS.R) && isfield(sMri, 'NCS') && ~((~isfield(sMri.NCS, 'R') || isempty(sMri.NCS.R)) && (~isfield(sMri.NCS, 'y') || isempty(sMri.NCS.y)))
    ChanMni = cs_convert(sMri, 'scs', 'mni', ChanScs);
    if ~isempty(ChanMni)
        Columns(end+1,:) = {'MNI', 'MNI coordinates (mm)', ChanMni, []};
        isSelect(end+1) = 1;
    end
else
    ChanMni = [];
end
% WORLD coordinates
if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && ismember('vox2ras', sMri.InitTransf(:,1))
    ChanWorld = cs_convert(sMri, 'scs', 'world', ChanScs);
    if ~isempty(ChanWorld)
        Columns(end+1,:) = {'World', 'World coordinates (mm)', ChanWorld, []};
        isSelect(end+1) = 1;
    end
else
    ChanWorld = [];
end


% ===== LIST AVAILABLE ATLASES =====
% List volume atlases
tagVol = 'Vol: ';
iAnatAtlases = find(~cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
for i = 1:length(iAnatAtlases)
    Columns(end+1,:) = {sSubject.Anatomy(iAnatAtlases(i)).Comment, [tagVol, sSubject.Anatomy(iAnatAtlases(i)).Comment], sSubject.Anatomy(iAnatAtlases(i)).FileName, []};
    isSelect(end+1) = 1;
end
% List surfaces
tagSurf = 'Surf: ';
iCortex = find(strcmpi({sSubject.Surface.SurfaceType}, 'Cortex'));
nVertices = zeros(1, length(iCortex));
isWhite = zeros(1, length(iCortex));
for i = 1:length(iCortex)
    Columns(end+1,:) = {sSubject.Surface(iCortex(i)).Comment, [tagSurf, sSubject.Surface(iCortex(i)).Comment], sSubject.Surface(iCortex(i)).FileName, []};
    VarInfo = whos('-file', file_fullpath(sSubject.Surface(iCortex(i)).FileName), 'Vertices');
    nVertices(i) = VarInfo.size(1);
    isWhite(i) = ~isempty(strfind(sSubject.Surface(iCortex(i)).Comment, 'white'));
end
% Select high-resolution white surface if available, otherwise any high-resolution surface
if ~isempty(iCortex)
    if any(isWhite)
        isSelect = [isSelect, isWhite & (nVertices == max(nVertices))];
    else
        isSelect = [isSelect, nVertices == max(nVertices)];
    end
end
% Checkboxes
isSelect = java_dialog('checkbox', 'Select information to export:', 'Compute contact labels', [], Columns(:,2), isSelect);
if ~any(isSelect)
    return;
end
% Keep only the selected columns
Columns = Columns(isSelect == 1, :);


% ===== SELECT SURFACE ATLASES ======
% List all the surface atlases
SurfAtlases = {};
iColSurf = find(~cellfun(@(c)isempty(strfind(c, tagSurf)), Columns(:,2)));
if ~isempty(iColSurf)
    % List the surface atlases in each selected surface
    for i = 1:length(iColSurf)
        % Load atlases
        sSurf = load(file_fullpath(Columns{iColSurf(i),3}), 'Atlas');
        % List all atlases
        if ~isempty(sSurf.Atlas)
            for iAtlas = 1:length(sSurf.Atlas)
                isVolumeAtlas = panel_scout('ParseVolumeAtlas', sSurf.Atlas(iAtlas).Name);
                if ~isVolumeAtlas && ~isempty(sSurf.Atlas(iAtlas).Scouts) && ~strcmpi(sSurf.Atlas(iAtlas).Name, 'Structures')
                    SurfAtlases{end+1} = sSurf.Atlas(iAtlas).Name;
                end
            end
        end
    end
    % Ask user which surfaces atlases to keep
    if ~isempty(SurfAtlases)
        SurfAtlases = unique(SurfAtlases);
        % Pad first atlas name so that it is displayed in columns by java_dialog (only if > 20 char)
        SurfAtlasesGui = SurfAtlases;
        if (length(SurfAtlasesGui{1}) <= 20)
            SurfAtlasesGui{1} = [SurfAtlasesGui{1}, repmat(' ', 1, 23-length(SurfAtlasesGui{1}))];
        end
        % Checkboxes
        isSelect = java_dialog('checkbox', 'Select surface atlases to export:', 'Compute contact labels', [], SurfAtlasesGui, true(1,length(SurfAtlasesGui)));
        if ~isempty(isSelect) && any(isSelect)
            SurfAtlases = SurfAtlases(isSelect == 1);
        else
            Columns(iColSurf,:) = [];
            SurfAtlases = {};
            iColSurf = [];
        end
    end
end


% ===== SPHERE PROBE =====
% Ask sphere radius to users
if isempty(Radius)
    Radius = java_dialog('input', [...
        '<HTML>Radius of the sphere (in millimeters).<BR><BR>' ...
        'To match a SEEG contact with an anatomical label from an atlas, we consider<BR>' ...
        'a sphere around the center of the contact instead of a single voxel.<BR><BR>' ...
        '<B>Surface atlas</>: The vertices within the sphere are detected, the most prevalent<BR>' ...
        'scout label among them is returned. High-resolution white matter recommended.<BR><BR>' ...
        '<B>Volume atlas</B>: All the voxels within the sphere are extracted, the most prevalent<BR>' ...
        'anatomical label among them is returned as the contact label.<BR><BR>' ...
        '<FONT COLOR="#777777"><B>1.74mm</B>: 27 voxels, all adjacent to the central voxel (cube 3x3x3mm).<BR>' ...
        '<B>3mm</B>: 93 voxels, recommended for isotropic MRI with a 1x1x1mm resolution.<BR>' ...
        '<B>5mm</B>: 335 voxels, recommended for bipolar contacts (ie. applied bipolar montage).</FONT><BR><BR>'], ...
        'Contact neighborhood', [], '3');
    if isempty(Radius) || (length(str2num(Radius)) ~= 1)
        return
    end
    Radius = str2num(Radius);
end
% Compute sphere
if all(Radius > sMri.Voxsize)
    % Get sphere dimensions in voxels
    sphSize = ceil(Radius .* sMri.Voxsize);
    % Grid of all voxel coordinates in the sphere
    [sphX, sphY, sphZ] = meshgrid(-sphSize(1):sphSize(1), -sphSize(2):sphSize(2), -sphSize(3):sphSize(3));
    % Keep only the voxels inside the sphere
    iInside = (sqrt(((sphX(:) .* sMri.Voxsize(1)) .^ 2) + ((sphY(:) .* sMri.Voxsize(2)) .^ 2) + ((sphZ(:) .* sMri.Voxsize(3)) .^ 2)) < Radius);
    sphXYZ = [sphX(iInside), sphY(iInside), sphZ(iInside)];
    disp(sprintf('BST> Sphere mask: [%dx%dx%d] voxels, with %d voxels selected.', sphSize*2+1, size(sphXYZ,1)));
else
    sphSize = [1 1 1];
    sphXYZ = [0 0 0];
    disp('BST> Volume atlas: Selecting closest voxel only.');
end


% ===== VOLUME ATLASES =====
% List volume atlases
iColVol = find(~cellfun(@(c)isempty(strfind(c, tagVol)), Columns(:,2)));
% Ask about including probability
if ~isempty(iColVol) && isempty(isProba)
    isProba = java_dialog('confirm', [...
        '<HTML>Include probability columns?<BR><BR>' ...
        '<FONT COLOR="#707070">For each volume atlas, add a column indicating the spatial probability of the label:<BR>' ...
        'prob = number of voxels with the label / number of voxels in the sphere * 100</FONT><BR><BR>'], ...
        'Contact probability');
end
% Open progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Atlas labelling', 'Initialization...', 0, length(iColSurf) + length(iColVol));
end
% Loop on volume atlases
for i = 1:length(iColVol)
    % === LOAD VOLUME ===
    bst_progress('text', ['Volume atlas: ' Columns{iColVol(i), 1}]);
    % Load volume
    sMriAtlas = in_mri_bst(Columns{iColVol(i), 3});
    % Convert coordinates from SCS to voxels
    xyzAtlas = cs_convert(sMriAtlas, 'scs', 'voxel', ChanScs);
    if isempty(xyzAtlas)
        disp(['BST> Error: Volume atlas ' Columns{iColVol(i), 1} ': Missing SCS transformation.']);
        Columns{iColVol(i), 3} = [];
        continue;
    end

    % === LOOP ON CHANNELS ===
    % For each sensor: Get label from the volume atlas
    ChanLabel = cell(1,size(ChanScs,1));
    ChanProba = cell(1,size(ChanScs,1));
    isWarningNoText = 1;
    for iChan = 1:size(ChanScs,1)
        % Coordinates of the closest voxel
        C = round(xyzAtlas(iChan,:));
        % If there are multiple voxels
        if (size(sphXYZ, 1) > 1)
            % Exclude contacts too close to the border of the MRI
            if (C(1) - sphSize(1) <= 0) || (C(1) + sphSize(1) > size(sMriAtlas.Cube,1)) || ...
               (C(2) - sphSize(2) <= 0) || (C(2) + sphSize(2) > size(sMriAtlas.Cube,2)) || ...
               (C(3) - sphSize(3) <= 0) || (C(3) + sphSize(3) > size(sMriAtlas.Cube,3))
                disp(['BST> Error: Volume atlas ' Columns{iColVol(i), 1} ': Contact "' ChanNames{iChan} '" is outside of the volume.']);
                continue;
            end
            % Indices of all the voxels within the sphere, around the contact
            voxInd = sub2ind(size(sMriAtlas.Cube), C(1)+sphXYZ(:,1), C(2)+sphXYZ(:,2), C(3)+sphXYZ(:,3));
            % Count each label in the sphere
            voxVal = sMriAtlas.Cube(voxInd);
            % Remove background values (zero)
            voxVal(voxVal == 0) = [];
            % Make sure the there are some non-zero voxels
            if ~isempty(voxVal)
                [uniqueVal,tmp,J] = unique(voxVal);
                % If there are multiple values: Get the most prevalent label
                if (length(uniqueVal) > 1)
                    nVal = accumarray(J(:),1);
                    [nMax,iMax] = max(nVal);
                    intLabel = uniqueVal(iMax);
                    probLabel = nMax / size(sphXYZ,1);
                else
                    intLabel = uniqueVal;
                    probLabel = length(voxVal) / size(sphXYZ,1);
                end
            else
                intLabel = 0;
                probLabel = 0;
            end
        else
            % Exclude contacts outside of the MRI
            if any(C <= 0) || any(C > size(sMriAtlas.Cube))
                disp(['BST> Error: Volume atlas ' Columns{iColVol(i), 1} ': Contact "' ChanNames{iChan} '" is outside of the volume.']);
                continue;
            end
            % Get label at the selected coordinates
            intLabel = sMriAtlas.Cube(C(1), C(2), C(3));
            probLabel = 1;
        end
        % Get text label
        if ~isempty(intLabel) && isfield(sMriAtlas, 'Labels') && ~isempty(sMriAtlas.Labels)
            iLabel = find(intLabel == [sMriAtlas.Labels{:,1}]);
            if (intLabel == 0)
                ChanLabel{iChan} = 'N/A';
            elseif (length(iLabel) == 1)
                ChanLabel{iChan} = sMriAtlas.Labels{iLabel, 2};
            else
                ChanLabel{iChan} = num2str(intLabel);
                if isWarningNoText
                    isWarningNoText = 0;
                    disp(['BST> Error: Volume atlas ' Columns{iColVol(i), 1} ': Text labels not available, saving integer label.']);
                end
            end
            if isProba
                ChanProba{iChan} = probLabel;
            end
        end
    end
    % Save labels
    Columns{iColVol(i), 3} = ChanLabel;
    if isProba
        Columns{iColVol(i), 4} = ChanProba;
    end
    bst_progress('inc',1);
end


% ===== SURFACE ATLASES =====
SurfColumns = cell(0,4);
% Loop on surface atlases
for i = 1:length(iColSurf)
    bst_progress('text', ['Surface atlas: ' Columns{iColSurf(i), 1}]);
    % Load surface
    sSurf = load(file_fullpath(Columns{iColSurf(i), 3}), 'Atlas', 'Vertices');
    % Loop on channels
    ChanLabel = repmat({'N/A'}, size(ChanScs,1), length(sSurf.Atlas));
    for iChan = 1:size(ChanScs,1)
        % Get vertices within the sphere
        iSphVert = find(sqrt(sum(bst_bsxfun(@minus, sSurf.Vertices, ChanScs(iChan,:)) .^ 2, 2)) < Radius / 1000);
        if isempty(iSphVert)
            continue;
        end
        % Loop on atlases
        for iAtlas = 1:length(sSurf.Atlas)
            % Atlas not selected: skip
            if ~ismember(sSurf.Atlas(iAtlas).Name, SurfAtlases)
                continue;
            end
            % Count vertices for each scout
            nScout = zeros(1,length(sSurf.Atlas(iAtlas).Scouts));
            for iScout = 1:length(sSurf.Atlas(iAtlas).Scouts)
                if ~isempty(sSurf.Atlas(iAtlas).Scouts(iScout).Vertices)
                    nScout(iScout) = nnz(ismember(iSphVert, sSurf.Atlas(iAtlas).Scouts(iScout).Vertices));
                end
            end
            % Find the scout with the highest prevalence
            if ~all(nScout == 0)
                [nMax,iMax] = max(nScout);
                ChanLabel{iChan, iAtlas} = sSurf.Atlas(iAtlas).Scouts(iMax).Label;
            end
        end
    end
    % Loop on atlases to report results
    for iAtlas = 1:length(sSurf.Atlas)
        % Atlas not selected: skip
        if ~ismember(sSurf.Atlas(iAtlas).Name, SurfAtlases)
            continue;
        end
        % Save channel labels as a new column
        SurfColumns(end+1, 1:4) = {[Columns{iColSurf(i),1} ':' sSurf.Atlas(iAtlas).Name], Columns{iColSurf(i),2}, ChanLabel(:,iAtlas), []};
    end
    bst_progress('inc',1);
end
% Save new columns: Remove original columns, add one column for each pair (surface x atlas)
Columns(iColSurf,:) = [];
if ~isempty(SurfColumns)
    Columns = cat(1, Columns, SurfColumns);
end

% ===== GENERATE TABLE =====
% Column headers
ChanTable = cell(size(ChanScs,1) + 1, size(Columns,1) + nnz(~cellfun(@isempty, Columns(:,4))) + 1);
ChanTable{1,1} = 'Channel';
iEntry = 2;
for iCol = 1:size(Columns,1)
    ChanTable{1, iEntry} = Columns{iCol,1};
    iEntry = iEntry + 1;
    if ~isempty(Columns{iCol,4})
        ChanTable{1, iEntry} = [Columns{iCol,1}, '_prob'];
        iEntry = iEntry + 1;
    end
end
% Loop on channels (rows)
for iChan = 1:size(ChanScs,1)
    ChanTable{iChan+1, 1} = ChanNames{iChan};
    iEntry = 2;
    % Loop on atlases (columns)
    for iCol = 1:size(Columns,1)
        % Numeric value (xyz coordinates - millimeters)
        if isnumeric(Columns{iCol,3}) && (iChan <= size(Columns{iCol,3},1)) && (size(Columns{iCol,3},2) == 3)
            ChanTable{iChan+1, iEntry} = sprintf('[%1.3f,%1.3f,%1.3f]', 1000 * Columns{iCol,3}(iChan,:));
        % Text value (atlas label)
        elseif iscell(Columns{iCol,3}) && (iChan <= length(Columns{iCol,3}))
            ChanTable{iChan+1, iEntry} = Columns{iCol,3}{iChan};
            % Add probability
            if ~isempty(Columns{iCol,4})
                if (Columns{iCol,4}{iChan} > 0) && ~strcmpi(Columns{iCol,3}{iChan}, 'N/A')
                    ChanTable{iChan+1, iEntry+1} = sprintf('%d%%', round(100 * Columns{iCol,4}{iChan}));
                else
                    ChanTable{iChan+1, iEntry+1} = 'N/A';
                end
                iEntry = iEntry + 1;
            end
        % Not available
        else
            ChanTable{iChan+1, iEntry} = 'N/A';
        end
        iEntry = iEntry + 1;
    end
end


% ===== SAVE TSV FILE =====
% Save TSV
if ~isempty(TsvFile)
    % Generate file contents
    strTable = [];
    for iRow = 1:size(ChanTable,1)
        for iCol = 1:size(ChanTable,2)
            strTable = [strTable, ChanTable{iRow, iCol}];
            if (iCol < size(ChanTable,2))
                strTable = [strTable, sprintf('\t')];
            end
        end
        strTable = [strTable, sprintf('\n')];
    end
    % Open file
    fid = fopen(TsvFile, 'w');
    if (fid < 0)
       error('Cannot open file'); 
    end
    % Save contents
    fwrite(fid, strTable);
    % Close file
    fclose(fid);
end
% Close progress bar
bst_progress('stop');


% ===== SHOW TABLE =====
if isInteractive
    % Extract maximum string length for each column
    MaxLen = zeros(1, size(ChanTable,2));
    for iCol = 1:size(ChanTable,2)
        MaxLen(iCol) = max(cellfun(@length, ChanTable(:,iCol)));
    end
    % Generate file contents
    strTable = [];
    for iRow = 1:size(ChanTable,1)
        for iCol = 1:size(ChanTable,2)
            % Pad with spaces to the maximum column text length
            strTable = [strTable, ChanTable{iRow, iCol}, repmat(' ', 1, MaxLen(iCol) - length(ChanTable{iRow, iCol}) + 2)];
        end
        strTable = [strTable, sprintf('\n')];
    end
    % Display text
    if ~isempty(TsvFile)
        wndTitle = TsvFile;
    else
        wndTitle = 'SEEG contact labels';
    end
    view_text([strTable 10 10], wndTitle);
end


